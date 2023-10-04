<script lang="ts">
  import { onDestroy, tick } from 'svelte';
  import { t } from 'svelte-i18n';
  import { type Address, TransactionExecutionError, UserRejectedRequestError } from 'viem';

  import { routingContractsMap } from '$bridgeConfig';
  import { chainConfig } from '$chainConfig';
  import { FlatAlert } from '$components/Alert';
  import { Button } from '$components/Button';
  import { Card } from '$components/Card';
  import { ChainSelectorWrapper } from '$components/ChainSelector';
  import { successToast, warningToast } from '$components/NotificationToast';
  import { errorToast, infoToast } from '$components/NotificationToast/NotificationToast.svelte';
  import { OnAccount } from '$components/OnAccount';
  import { OnNetwork } from '$components/OnNetwork';
  import { Step, Stepper } from '$components/Stepper';
  import { TokenDropdown } from '$components/TokenDropdown';
  import {
    type BridgeArgs,
    bridges,
    type BridgeTransaction,
    type ERC20BridgeArgs,
    type ETHBridgeArgs,
    MessageStatus,
  } from '$libs/bridge';
  import { hasBridge } from '$libs/bridge/bridges';
  import type { ERC20Bridge } from '$libs/bridge/ERC20Bridge';
  import {
    ApproveError,
    InsufficientAllowanceError,
    NoAllowanceRequiredError,
    SendERC20Error,
    SendMessageError,
  } from '$libs/error';
  import { bridgeTxService } from '$libs/storage';
  import { ETHToken, getAddress, isDeployedCrossChain, type Token, tokens, TokenType } from '$libs/token';
  import { checkOwnership } from '$libs/token/checkOwnership';
  import { getTokenInfoFromAddress } from '$libs/token/getTokenInfo';
  import { refreshUserBalance } from '$libs/util/balance';
  import { getConnectedWallet } from '$libs/util/getConnectedWallet';
  import { type Account, account } from '$stores/account';
  import { type Network, network } from '$stores/network';
  import { pendingTransactions } from '$stores/pendingTransactions';

  import Actions from './Actions.svelte';
  import AddressInput from './AddressInput/AddressInput.svelte';
  import { AddressInputState } from './AddressInput/state';
  import Amount from './Amount.svelte';
  import IdInput from './IDInput.svelte';
  import { ProcessingFee } from './ProcessingFee';
  import Recipient from './Recipient.svelte';
  import {
    activeBridge,
    bridgeService,
    destNetwork as destinationChain,
    enteredAmount,
    processingFee,
    recipientAddress,
    selectedToken,
  } from './state';
  import { BridgeTypes, NFTSteps } from './types';

  let amountComponent: Amount;
  let recipientComponent: Recipient;
  let processingFeeComponent: ProcessingFee;

  function onNetworkChange(newNetwork: Network, oldNetwork: Network) {
    tick().then(() => {
      // run validations again
      runValidations();
    });

    if (newNetwork) {
      const destChainId = $destinationChain?.id;
      if (!$destinationChain?.id) return;
      // determine if we simply swapped dest and src networks
      if (newNetwork.id === destChainId) {
        destinationChain.set(oldNetwork);
        return;
      }
      // check if the new network has a bridge to the current dest network
      if (hasBridge(newNetwork.id, $destinationChain?.id)) {
        destinationChain.set(oldNetwork);
      } else {
        // if not, set dest network to null
        $destinationChain = null;
      }
    }
  }

  const runValidations = () => {
    if (amountComponent) amountComponent.validateAmount();
    if (addressInputComponent) addressInputComponent.validateAddress();
  };

  function onAccountChange(account: Account) {
    if (account && account.isConnected && !$selectedToken) {
      $selectedToken = ETHToken;
    } else if (account && account.isDisconnected) {
      $selectedToken = null;
      $destinationChain = null;
    }
  }

  async function approve() {
    if (!$selectedToken || !$network || !$destinationChain) return;

    const erc20Bridge = bridges.ERC20 as ERC20Bridge;

    try {
      const walletClient = await getConnectedWallet($network.id);

      const tokenAddress = await getAddress({
        token: $selectedToken,
        srcChainId: $network.id,
        destChainId: $destinationChain.id,
      });

      if (!tokenAddress) {
        throw new Error('token address not found');
      }

      const spenderAddress = routingContractsMap[$network.id][$destinationChain.id].erc20VaultAddress;

      const txHash = await erc20Bridge.approve({
        tokenAddress,
        spenderAddress,
        amount: $enteredAmount,
        wallet: walletClient,
      });

      const { explorer } = chainConfig[$network.id].urls;

      infoToast(
        $t('bridge.actions.approve.tx', {
          values: {
            token: $selectedToken.symbol,
            url: `${explorer}/tx/${txHash}`,
          },
        }),
      );

      await pendingTransactions.add(txHash, $network.id);

      successToast(
        $t('bridge.actions.approve.success', {
          values: {
            token: $selectedToken.symbol,
          },
        }),
      );

      // Let's run the validation again, which will update UI
      amountComponent.validateAmount();
    } catch (err) {
      console.error(err);

      switch (true) {
        case err instanceof UserRejectedRequestError:
          warningToast($t('bridge.errors.rejected'));
          break;
        case err instanceof NoAllowanceRequiredError:
          errorToast($t('bridge.errors.no_allowance_required'));
          break;
        case err instanceof InsufficientAllowanceError:
          errorToast($t('bridge.errors.insufficient_allowance'));
          break;
        case err instanceof ApproveError:
          // TODO: see contract for all possible errors
          errorToast($t('bridge.errors.approve_error'));
          break;
        default:
          errorToast($t('bridge.errors.unknown_error'));
      }
    }
  }

  async function bridge() {
    if (!$bridgeService || !$selectedToken || !$network || !$destinationChain || !$account?.address) return;

    try {
      const walletClient = await getConnectedWallet($network.id);

      // Common arguments for both ETH and ERC20 bridges
      let bridgeArgs = {
        to: $recipientAddress || $account.address,
        wallet: walletClient,
        srcChainId: $network.id,
        destChainId: $destinationChain.id,
        amount: $enteredAmount,
        fee: $processingFee,
      } as BridgeArgs;

      switch ($selectedToken.type) {
        case TokenType.ETH: {
          // Specific arguments for ETH bridge:
          // - bridgeAddress
          const bridgeAddress = routingContractsMap[$network.id][$destinationChain.id].bridgeAddress;
          bridgeArgs = { ...bridgeArgs, bridgeAddress } as ETHBridgeArgs;
          break;
        }

        case TokenType.ERC20: {
          // Specific arguments for ERC20 bridge
          // - tokenAddress
          // - tokenVaultAddress
          // - isTokenAlreadyDeployed
          const tokenAddress = await getAddress({
            token: $selectedToken,
            srcChainId: $network.id,
            destChainId: $destinationChain.id,
          });

          if (!tokenAddress) {
            throw new Error('token address not found');
          }

          const tokenVaultAddress = routingContractsMap[$network.id][$destinationChain.id].erc20VaultAddress;

          const isTokenAlreadyDeployed = await isDeployedCrossChain({
            token: $selectedToken,
            srcChainId: $network.id,
            destChainId: $destinationChain.id,
          });

          bridgeArgs = {
            ...bridgeArgs,
            token: tokenAddress,
            tokenVaultAddress,
            isTokenAlreadyDeployed,
          } as ERC20BridgeArgs;
          break;
        }
        case TokenType.ERC721:
          // todo: implement
          break;
        case TokenType.ERC1155:
          // todo: implement
          break;
        default:
          throw new Error('invalid token type');
      }

      const txHash = await $bridgeService.bridge(bridgeArgs);

      const explorer = chainConfig[bridgeArgs.srcChainId].urls.explorer;

      infoToast(
        $t('bridge.actions.bridge.tx', {
          values: {
            token: $selectedToken.symbol,
            url: `${explorer}/tx/${txHash}`,
          },
        }),
      );

      await pendingTransactions.add(txHash, $network.id);

      successToast(
        $t('bridge.actions.bridge.success', {
          values: {
            network: $destinationChain.name,
          },
        }),
      );

      // Let's add it to the user's localStorage
      const bridgeTx = {
        hash: txHash,
        from: $account.address,
        amount: $enteredAmount,
        symbol: $selectedToken.symbol,
        decimals: $selectedToken.decimals,
        srcChainId: BigInt($network.id),
        destChainId: BigInt($destinationChain.id),
        tokenType: $selectedToken.type,
        status: MessageStatus.NEW,
        timestamp: Date.now(),

        // TODO: do we need something else? we can have
        // access to the Transaction object:
        // TransactionLegacy, TransactionEIP2930 and
        // TransactionEIP1559
      } as BridgeTransaction;

      bridgeTxService.addTxByAddress($account.address, bridgeTx);

      // Reset the form
      resetForm();

      // Refresh user's balance
      refreshUserBalance();
    } catch (err) {
      console.error(err);

      switch (true) {
        case err instanceof InsufficientAllowanceError:
          errorToast($t('bridge.errors.insufficient_allowance'));
          break;
        case err instanceof SendMessageError:
          // TODO: see contract for all possible errors
          errorToast($t('bridge.errors.send_message_error'));
          break;
        case err instanceof SendERC20Error:
          // TODO: see contract for all possible errors
          errorToast($t('bridge.errors.send_erc20_error'));
          break;
        case err instanceof UserRejectedRequestError:
          // Todo: viem does not seem to detect UserRejectError
          warningToast($t('bridge.errors.rejected'));
          break;
        case err instanceof TransactionExecutionError && err.shortMessage === 'User rejected the request.':
          //Todo: so we catch it by string comparison below, suboptimal
          warningToast($t('bridge.errors.rejected'));
          break;
        default:
          errorToast($t('bridge.errors.unknown_error'));
      }
    }
  }

  $: if ($selectedToken && amountComponent) {
    amountComponent.validateAmount();
  }

  const resetForm = () => {
    //we check if these are still mounted, as the user might have left the page
    if (amountComponent) amountComponent.clearAmount();
    if (recipientComponent) recipientComponent.clearRecipient();
    if (processingFeeComponent) processingFeeComponent.resetProcessingFee();
    if (addressInputComponent) addressInputComponent.clearAddress();

    // Update balance after bridging
    if (amountComponent) amountComponent.updateBalance();
    if (nftIdInputComponent) nftIdInputComponent.clearIds();
    $selectedToken = ETHToken;
    contractAddress = '';
  };

  // NFT Bridge logic
  let activeStep: NFTSteps = NFTSteps.IMPORT;

  const nextStep = () => (activeStep = Math.min(activeStep + 1, NFTSteps.CONFIRM));
  const previousStep = () => (activeStep = Math.max(activeStep - 1, NFTSteps.IMPORT));

  let nftStepTitle: string;
  let nftStepDescription: string;
  let nftIdArray: number[];
  let enteredIds: string = '';
  let contractAddress: Address | '';
  let addressInputComponent: AddressInput;
  let nftIdInputComponent: IdInput;
  let addressInputState: AddressInputState = AddressInputState.Default;
  let isOwnerOfAllToken: boolean = false;
  let validating: boolean = false;
  let detectedTokenType: TokenType | null = null;

  function onAddressValidation(event: CustomEvent<{ isValidEthereumAddress: boolean; addr: Address }>) {
    const { isValidEthereumAddress, addr } = event.detail;
    addressInputState = AddressInputState.Validating;

    if (isValidEthereumAddress && typeof addr === 'string') {
      getTokenInfoFromAddress(addr)
        .then((details) => {
          if (!details) throw new Error('token details not found');
          if (!$network?.id) throw new Error('network not found');

          detectedTokenType = details.type;
          addressInputState = AddressInputState.Valid;

          $selectedToken = {
            type: details.type,
            symbol: details.symbol,
            decimals: details.decimals,
            name: details.name,
            logoURI: '',
            addresses: {
              [$network.id]: addr,
            },
          } as Token;
        })
        .catch((err) => {
          console.error(err);
          detectedTokenType = null;
          addressInputState = AddressInputState.Invalid;
        });
    } else {
      detectedTokenType = null;
      addressInputState = AddressInputState.Invalid;
    }
  }

  // Whenever the user switches bridge types, we should reset the forms
  $: $activeBridge && resetForm();

  $: {
    (async () => {
      if (addressInputState !== AddressInputState.Valid) return;
      if (contractAddress === '') return;
      validating = true;

      if ($account?.address && $network?.id && contractAddress)
        isOwnerOfAllToken = await checkOwnership(
          contractAddress,
          detectedTokenType,
          nftIdArray,
          $account?.address,
          $network?.id,
        );
      validating = false;
    })();
  }

  $: canProceed =
    addressInputState === AddressInputState.Valid &&
    nftIdArray.length > 0 &&
    contractAddress &&
    $destinationChain &&
    isOwnerOfAllToken;

  onDestroy(() => {
    resetForm();
  });
</script>

{#if $activeBridge === BridgeTypes.FUNGIBLE}
  <Card class="w-full md:w-[524px]" title={$t('bridge.title.default')} text={$t('bridge.description.default')}>
    <div class="space-y-[30px]">
      <div class="f-between-center gap-4">
        <ChainSelectorWrapper />
      </div>

      <TokenDropdown {tokens} bind:value={$selectedToken} />

      <Amount bind:this={amountComponent} />

      <div class="space-y-[16px]">
        <Recipient bind:this={recipientComponent} />
        <ProcessingFee bind:this={processingFeeComponent} />
      </div>

      <div class="h-sep" />

      <Actions {approve} {bridge} />
    </div>
  </Card>
{:else if $activeBridge === BridgeTypes.NFT}
  <div class="f-col">
    <Stepper {activeStep}>
      <Step stepIndex={NFTSteps.IMPORT} currentStepIndex={activeStep} isActive={activeStep === NFTSteps.IMPORT}
        >{$t('bridge.title.nft.import')}</Step>
      <Step stepIndex={NFTSteps.REVIEW} currentStepIndex={activeStep} isActive={activeStep === NFTSteps.REVIEW}
        >{$t('bridge.title.nft.review')}</Step>
      <Step stepIndex={NFTSteps.CONFIRM} currentStepIndex={activeStep} isActive={activeStep === NFTSteps.CONFIRM}
        >{$t('bridge.title.nft.confirm')}</Step>
    </Stepper>

    <Card class="mt-[32px] w-full md:w-[524px]" title={nftStepTitle} text={nftStepDescription}>
      <div class="space-y-[30px]">
        {#if activeStep === NFTSteps.IMPORT}
          <div class="f-between-center gap-4">
            <ChainSelectorWrapper />
          </div>
          <AddressInput
            bind:this={addressInputComponent}
            bind:ethereumAddress={contractAddress}
            bind:state={addressInputState}
            class="bg-neutral-background border-0 h-[56px]"
            on:addressvalidation={onAddressValidation}
            labelText={$t('inputs.address_input.label.contract')}
            quiet />

          <div class="min-h-[20px] !mt-3">
            {#if detectedTokenType === TokenType.ERC721 && contractAddress}
              <FlatAlert type="success" forceColumnFlow message="todo: valid erc721" />
            {:else if detectedTokenType === TokenType.ERC1155 && contractAddress}
              <FlatAlert type="success" forceColumnFlow message="todo: valid erc1155" />
            {/if}

            <IdInput
              bind:this={nftIdInputComponent}
              bind:enteredIds
              bind:numbersArray={nftIdArray}
              class="bg-neutral-background border-0 h-[56px]" />
            <div class="min-h-[20px] !mt-3">
              {#if !isOwnerOfAllToken && nftIdArray?.length > 0 && !validating}
                <FlatAlert type="error" forceColumnFlow message="todo: must be owner of all token" />
              {/if}
            </div>

            {#if detectedTokenType === TokenType.ERC1155}
              <Amount bind:this={amountComponent} />
            {/if}
          </div>
        {:else if activeStep === NFTSteps.REVIEW}
          <div class="f-between-center gap-4">
            <div class="f-col">
              <p>Contract: {contractAddress}</p>
              <p>IDs: {nftIdArray.join(', ')}</p>
            </div>
          </div>
        {:else if activeStep === NFTSteps.CONFIRM}
          <div class="f-between-center gap-4">
            <ChainSelectorWrapper />
          </div>
        {/if}
        <div class="space-y-[16px]">
          <Recipient bind:this={recipientComponent} />
          <ProcessingFee bind:this={processingFeeComponent} />
        </div>
        <div class="h-sep" />
        <div class="f-between-center w-full gap-4">
          {#if activeStep !== NFTSteps.IMPORT}
            <Button
              type="secondary"
              class="px-[28px] py-[14px] rounded-full flex-1 text-secondary-content"
              on:click={previousStep}>Previous Step</Button>
          {/if}
          <Button
            disabled={!canProceed}
            type="primary"
            class="px-[28px] py-[14px] rounded-full flex-1 text-white"
            on:click={nextStep}>Next Step</Button>
        </div>
      </div></Card>
  </div>
{/if}

<OnNetwork change={onNetworkChange} />

<OnAccount change={onAccountChange} />
