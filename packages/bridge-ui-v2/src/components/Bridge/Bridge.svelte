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
  import ChainSelector from '$components/ChainSelector/ChainSelector.svelte';
  import { Icon } from '$components/Icon';
  import IconFlipper from '$components/Icon/IconFlipper.svelte';
  import { NFTCard } from '$components/NFTCard';
  import { NFTList } from '$components/NFTList';
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
    type ERC721BridgeArgs,
    type ERC1155BridgeArgs,
    type ETHBridgeArgs,
    MessageStatus,
  } from '$libs/bridge';
  import { hasBridge } from '$libs/bridge/bridges';
  import type { ERC20Bridge } from '$libs/bridge/ERC20Bridge';
  import type { ERC721Bridge } from '$libs/bridge/ERC721Bridge';
  import type { ERC1155Bridge } from '$libs/bridge/ERC1155Bridge';
  import { fetchNFTs } from '$libs/bridge/fetchNFTs';
  import {
    ApproveError,
    InsufficientAllowanceError,
    NoAllowanceRequiredError,
    SendERC20Error,
    SendMessageError,
  } from '$libs/error';
  import { bridgeTxService } from '$libs/storage';
  import { ETHToken, getAddress, isDeployedCrossChain, type NFT, tokens, TokenType } from '$libs/token';
  import { checkOwnership } from '$libs/token/checkOwnership';
  import { getTokenWithInfoFromAddress } from '$libs/token/getTokenWithInfoFromAddress';
  import { refreshUserBalance } from '$libs/util/balance';
  import { getConnectedWallet } from '$libs/util/getConnectedWallet';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { type Account, account } from '$stores/account';
  import { type Network, network } from '$stores/network';
  import { pendingTransactions } from '$stores/pendingTransactions';

  import Actions from './Actions.svelte';
  import AddressInput from './AddressInput/AddressInput.svelte';
  import { AddressInputState } from './AddressInput/state';
  import Amount from './Amount.svelte';
  import IdInput from './IDInput/IDInput.svelte';
  import { IDInputState } from './IDInput/state';
  import { ProcessingFee } from './ProcessingFee';
  import Recipient from './Recipient.svelte';
  import {
    activeBridge,
    bridgeService,
    destNetwork as destinationChain,
    enteredAmount,
    notApproved,
    processingFee,
    recipientAddress,
    selectedToken,
  } from './state';
  import { BridgeTypes, NFTSteps } from './types';

  let amountComponent: Amount;
  let recipientComponent: Recipient;
  let processingFeeComponent: ProcessingFee;

  function onNetworkChange(newNetwork: Network, oldNetwork: Network) {
    updateForm();

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
    updateForm();
    if (account && account.isConnected && !$selectedToken) {
      $selectedToken = ETHToken;
    } else if (account && account.isDisconnected) {
      $selectedToken = null;
      $destinationChain = null;
    }
  }

  function updateForm() {
    tick().then(() => {
      if (manualNFTInput) {
        // run validations again if we are in manual mode
        runValidations();
      } else {
        resetForm();
      }
    });
  }

  async function approve() {
    if (!$selectedToken || !$network || !$destinationChain) return;

    try {
      if ($selectedToken.type === TokenType.ERC721) {
        const erc721Bridge = bridges[$selectedToken.type] as ERC721Bridge;
        const walletClient = await getConnectedWallet($network.id);

        const tokenAddress = $selectedToken.addresses[$network.id];

        if (!tokenAddress) {
          throw new Error('token address not found');
        }

        const spenderAddress = routingContractsMap[$network.id][$destinationChain.id].erc721VaultAddress;

        const tokenIds = nftIdArray
          ? nftIdArray.map((num) => BigInt(num))
          : selectedNFT.map((nft) => BigInt(nft.tokenId));

        const txHash = await erc721Bridge.approve({
          tokenAddress,
          spenderAddress,
          tokenIds,
          wallet: walletClient,
        });

        const { explorer } = chainConfig[$network.id].urls;

        infoToast({
          title: $t('bridge.actions.approve.tx.title'),
          message: $t('bridge.actions.approve.tx.message', {
            values: {
              token: $selectedToken.symbol,
              url: `${explorer}/tx/${txHash}`,
            },
          }),
        });

        // await pendingTransactions.add(txHash, $network.id);

        successToast({
          title: $t('bridge.actions.approve.success.title'),
          message: $t('bridge.actions.approve.success.message', {
            values: {
              token: $selectedToken.symbol,
            },
          }),
        });
      }
      if ($selectedToken.type === TokenType.ERC1155) {
        const erc1155Bridge = bridges[$selectedToken.type] as ERC1155Bridge;
        const walletClient = await getConnectedWallet($network.id);

        const tokenAddress = $selectedToken.addresses[$network.id];

        if (!tokenAddress) {
          throw new Error('token address not found');
        }

        const spenderAddress = routingContractsMap[$network.id][$destinationChain.id].erc1155VaultAddress;

        const tokenIds = nftIdArray
          ? nftIdArray.map((num) => BigInt(num))
          : selectedNFT.map((nft) => BigInt(nft.tokenId));

        const txHash = await erc1155Bridge.approve({
          tokenAddress,
          spenderAddress,
          tokenIds,
          wallet: walletClient,
        });

        const { explorer } = chainConfig[$network.id].urls;

        infoToast({
          title: $t('bridge.actions.approve.tx.title'),
          message: $t('bridge.actions.approve.tx.message', {
            values: {
              token: $selectedToken.symbol,
              url: `${explorer}/tx/${txHash}`,
            },
          }),
        });

        await pendingTransactions.add(txHash, $network.id);

        successToast({
          title: $t('bridge.actions.approve.success.title'),
          message: $t('bridge.actions.approve.success.message', {
            values: {
              token: $selectedToken.symbol,
            },
          }),
        });
      }
      if ($selectedToken.type === TokenType.ERC20) {
        const erc20Bridge = bridges.ERC20 as ERC20Bridge;
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

        infoToast({
          title: $t('bridge.actions.approve.tx.title'),
          message: $t('bridge.actions.approve.tx.message', {
            values: {
              token: $selectedToken.symbol,
              url: `${explorer}/tx/${txHash}`,
            },
          }),
        });

        await pendingTransactions.add(txHash, $network.id);

        successToast({
          title: $t('bridge.actions.approve.success.title'),
          message: $t('bridge.actions.approve.success.message', {
            values: {
              token: $selectedToken.symbol,
            },
          }),
        });

        // Let's run the validation again, which will update UI
        amountComponent.validateAmount();
      }
    } catch (err) {
      console.error(err);

      switch (true) {
        case err instanceof UserRejectedRequestError:
          warningToast({title: $t('bridge.errors.rejected')});
          break;
        case err instanceof NoAllowanceRequiredError:
          errorToast({title: $t('bridge.errors.no_allowance_required')});
          break;
        case err instanceof InsufficientAllowanceError:
          errorToast({title: $t('bridge.errors.insufficient_allowance')});
          break;
        case err instanceof ApproveError:
          // TODO: see contract for all possible errors
          errorToast({title: $t('bridge.errors.approve_error')});
          break;
        default:
          errorToast({title: $t('bridge.errors.unknown_error')});
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
          {
            //TODO: only handles single NFTs for now
            const tokenAddress = selectedNFT[0].addresses[$network.id];
            const tokenVaultAddress = routingContractsMap[$network.id][$destinationChain.id].erc721VaultAddress;

            const tokenIds = nftIdArray
              ? nftIdArray.map((num) => BigInt(num))
              : selectedNFT.map((nft) => BigInt(nft.tokenId));

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
              tokenIds,
              amounts: [BigInt(0)], // ERC721 is always 0
            } as ERC721BridgeArgs;
          }

          break;
        case TokenType.ERC1155:
          {
            //TODO: only handles single NFTs for now
            const tokenAddress = selectedNFT[0].addresses[$network.id];
            const tokenVaultAddress = routingContractsMap[$network.id][$destinationChain.id].erc1155VaultAddress;

            const tokenIds = nftIdArray
              ? nftIdArray.map((num) => BigInt(num))
              : selectedNFT.map((nft) => BigInt(nft.tokenId));

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
              tokenIds,
              amounts: [BigInt(1)], // TODO: Dynamic amount from user!
              wallet: walletClient,
            } as ERC1155BridgeArgs;
          }
          break;
        default:
          throw new Error('invalid token type');
      }

      const txHash = await $bridgeService.bridge(bridgeArgs);

      const explorer = chainConfig[bridgeArgs.srcChainId].urls.explorer;

      infoToast({
        title: $t('bridge.actions.bridge.tx.title'),
        message: $t('bridge.actions.bridge.tx.message', {
          values: {
            token: $selectedToken.symbol,
            url: `${explorer}/tx/${txHash}`,
          },
        }),
      });

      await pendingTransactions.add(txHash, $network.id);

      successToast({
        title: $t('bridge.actions.bridge.success.title'),
        message: $t('bridge.actions.bridge.success.message', {
          values: {
            network: $destinationChain.name,
          },
        }),
      });

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
          errorToast({title: $t('bridge.errors.insufficient_allowance')});
          break;
        case err instanceof SendMessageError:
          // TODO: see contract for all possible errors
          errorToast({title: $t('bridge.errors.send_message_error')});
          break;
        case err instanceof SendERC20Error:
          // TODO: see contract for all possible errors
          errorToast({title: $t('bridge.errors.send_erc20_error')});
          break;
        case err instanceof UserRejectedRequestError:
          // Todo: viem does not seem to detect UserRejectError
          warningToast({title: $t('bridge.errors.rejected')});
          break;
        case err instanceof TransactionExecutionError && err.shortMessage === 'User rejected the request.':
          //Todo: so we catch it by string comparison below, suboptimal
          warningToast({title: $t('bridge.errors.rejected')});
          break;
        default:
          errorToast({title: $t('bridge.errors.unknown_error')});
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
    manualNFTInput = false;
    scanned = false;
    isOwnerOfAllToken = false;
    foundNFTs = [];
    selectedNFT = [];
  };

  /**
   *   NFT Bridge
   */
  let activeStep: NFTSteps = NFTSteps.IMPORT;

  const nextStep = () => (activeStep = Math.min(activeStep + 1, NFTSteps.CONFIRM));
  const previousStep = () => (activeStep = Math.max(activeStep - 1, NFTSteps.IMPORT));

  let nftStepTitle: string;
  let nftStepDescription: string;
  let nextStepButtonText: string;

  let manualNFTInput: boolean = false;
  let nftIdArray: number[];
  let enteredIds: string = '';
  let contractAddress: Address | '';

  let addressInputComponent: AddressInput;
  let nftIdInputComponent: IdInput;

  let addressInputState: AddressInputState = AddressInputState.Default;
  let isOwnerOfAllToken: boolean = false;
  let validating: boolean = false;
  let detectedTokenType: TokenType | null = null;

  let scanning: boolean = false;
  let scanned: boolean = false;

  let foundNFTs: NFT[] = [];
  let selectedNFT: NFT[] = [];

  enum NFTView {
    CARDS,
    LIST,
  }
  let nftView: NFTView = NFTView.CARDS;

  function onAddressValidation(event: CustomEvent<{ isValidEthereumAddress: boolean; addr: Address }>) {
    const { isValidEthereumAddress, addr } = event.detail;
    addressInputState = AddressInputState.Validating;
    if (isValidEthereumAddress && typeof addr === 'string') {
      if (!$network?.id) throw new Error('network not found');
      const srcChainId = $network?.id;
      getTokenWithInfoFromAddress({ contractAddress: addr, srcChainId: srcChainId, owner: $account?.address })
        .then((token) => {
          if (!token) throw new Error('no token with info');
          addressInputState = AddressInputState.Valid;
          $selectedToken = token;
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

  const scanForNFTs = async () => {
    scanning = true;
    const accountAddress = $account?.address;
    const srcChainId = $network?.id;
    if (!accountAddress || !srcChainId) return;
    const nftsFromAPIs = await fetchNFTs(accountAddress, BigInt(srcChainId));
    foundNFTs = nftsFromAPIs.nfts;
    scanning = false;
    scanned = true;
  };

  const changeNFTView = () => {
    if (nftView === NFTView.CARDS) {
      nftView = NFTView.LIST;
    } else {
      nftView = NFTView.CARDS;
    }
  };

  const searchNFTs = () => {
    // TODO: implement
  };

  const getStepText = () => {
    if (activeStep === NFTSteps.REVIEW) {
      return $t('common.confirm');
    }
    if (activeStep === NFTSteps.CONFIRM) {
      return $t('common.ok');
    } else {
      return $t('common.continue');
    }
  };

  function updateApproval(tokenId: number, approval: boolean) {
    notApproved.update((currentMap) => {
      // Clone the current map
      const updatedMap = new Map(currentMap);
      // Update the approval status of the specified tokenId
      updatedMap.set(tokenId, approval);
      return updatedMap;
    });
  }

  // Whenever the user switches bridge types, we should reset the forms
  $: $activeBridge && (resetForm(), (activeStep = NFTSteps.IMPORT));

  $: {
    const stepKey = NFTSteps[activeStep].toLowerCase();
    nftStepTitle = $t(`bridge.title.nft.${stepKey}`);
    nftStepDescription = $t(`bridge.description.nft.${stepKey}`);
    nextStepButtonText = getStepText();
  }

  const manualImportAction = () => {
    if (!$network?.id) throw new Error('network not found');
    const srcChainId = $network?.id;
    const tokenId = nftIdArray[0];

    if (contractAddress && srcChainId)
      getTokenWithInfoFromAddress({ contractAddress, srcChainId, owner: $account?.address, tokenId })
        .then((token) => {
          if (!token) throw new Error('no token with info');

          selectedNFT = [token as NFT];
          $selectedToken = token;
        })
        .catch((err) => {
          console.error(err);
          detectedTokenType = null;
          addressInputState = AddressInputState.Invalid;
        });
    nextStep();
  };

  $: if (selectedNFT.length > 0) {
    //TODO: this needs changing if we do batch transfers in the future:
    // Update either selectedToken store to handle arrays or the actions to access a different store for NFTs
    $selectedToken = selectedNFT[0];
    const currentNetwork = $network?.id;
    if (currentNetwork && $destinationChain?.id && $selectedToken) {
      if (selectedNFT[0].type === TokenType.ERC721) {
        const sourceTokenVault = routingContractsMap[currentNetwork][$destinationChain?.id].erc721VaultAddress;
        const bridge = bridges[selectedNFT[0].type] as ERC721Bridge;
        bridge
          .requiresApproval({
            tokenAddress: selectedNFT[0].addresses[currentNetwork],
            spenderAddress: sourceTokenVault,
            tokenId: BigInt(selectedNFT[0].tokenId),
          })
          .then((isApproved: boolean) => {
            if (isApproved) {
              updateApproval(selectedNFT[0].tokenId, false);
            } else {
              updateApproval(selectedNFT[0].tokenId, true);
            }
          })
          .catch((err: Error) => {
            console.error(err);
            //TODO: handle error
          });
      } else if (selectedNFT[0].type === TokenType.ERC1155) {
        const sourceTokenVault = routingContractsMap[currentNetwork][$destinationChain?.id].erc1155VaultAddress;
        const bridge = bridges[selectedNFT[0].type] as ERC1155Bridge;
        bridge
          .isApprovedForAll({
            tokenAddress: selectedNFT[0].addresses[currentNetwork],
            spenderAddress: sourceTokenVault,
            tokenId: BigInt(selectedNFT[0].tokenId),
            owner: $account?.address,
          })
          .then((isApproved: boolean) => {
            if (isApproved) {
              updateApproval(selectedNFT[0].tokenId, true);
            } else {
              updateApproval(selectedNFT[0].tokenId, false);
            }
          })
          .catch((err: Error) => {
            console.error(err);
          });
      }
    }
  }

  $: {
    (async () => {
      if (addressInputState !== AddressInputState.Valid) return;
      if (contractAddress === '') return;
      validating = true;

      if ($account?.address && $network?.id && contractAddress)
        await checkOwnership(contractAddress, detectedTokenType, nftIdArray, $account?.address, $network?.id).then(
          (result) => {
            result;
            isOwnerOfAllToken = result.every((value) => value.isOwner === true);
          },
        );
      validating = false;
    })();
  }

  let idInputState: IDInputState;
  $: {
    if (isOwnerOfAllToken && nftIdArray?.length > 0) {
      idInputState = IDInputState.VALID;
    } else if (!isOwnerOfAllToken && nftIdArray?.length > 0) {
      idInputState = IDInputState.INVALID;
    } else {
      idInputState = IDInputState.DEFAULT;
    }
  }

  $: canProceed = manualNFTInput
    ? addressInputState === AddressInputState.Valid &&
      nftIdArray.length > 0 &&
      contractAddress &&
      $destinationChain &&
      isOwnerOfAllToken
    : selectedNFT.length > 0 && $destinationChain && scanned;

  $: canScan = $account?.isConnected && $network?.id && $destinationChain && !scanning;

  onDestroy(() => {
    resetForm();
  });
</script>

<!-- 
    ETH & ERC20 Bridge  
-->
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

  <!-- 
    NFT Bridge  
  -->
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
        <!-- IMPORT STEP -->
        {#if activeStep === NFTSteps.IMPORT}
          <div class="f-between-center gap-4">
            <ChainSelectorWrapper />
          </div>

          <!-- 
            Manual NFT Input 
          -->
          {#if manualNFTInput}
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

              <!-- TODO: limit to config -->
              <IdInput
                bind:this={nftIdInputComponent}
                bind:enteredIds
                bind:numbersArray={nftIdArray}
                bind:state={idInputState}
                limit={1}
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
          {:else}
            <!-- 
            Automatic NFT Input 
          -->
            <div class="f-between-center w-full gap-4">
              <Button
                disabled={!canScan}
                loading={scanning}
                type={scanned ? 'neutral' : 'primary'}
                class="px-[28px] py-[14px] rounded-full flex-1 text-white"
                on:click={scanForNFTs}>
                {#if !scanned}
                  {$t('bridge.actions.nft_scan')}
                {:else}
                  {$t('bridge.actions.nft_scan_again')}
                {/if}
              </Button>
            </div>

            <div class="f-col w-full gap-4">
              {#if scanned}
                <h2>{$t('bridge.nft.step.import.scan_screen.title')}</h2>
                <!-- Todo: also enable card view here? -->
                <NFTList bind:nfts={foundNFTs} chainId={$network?.id} bind:selectedNFT />

                <div class="flex items-center justify-between space-x-2">
                  <FlatAlert type="warning" message={$t('bridge.nft.step.import.scan_screen.description')} />
                  <Button
                    type="neutral"
                    class="bg-transparent !border border-primary-brand hover:border-primary-interactive-hover "
                    on:click={() => (manualNFTInput = !manualNFTInput)}>
                    {$t('bridge.actions.nft_manual')}
                  </Button>
                </div>
              {/if}
            </div>
          {/if}

          <!-- REVIEW STEP -->
        {:else if activeStep === NFTSteps.REVIEW}
          <div class="container mx-auto inline-block align-middle space-y-[25px]">
            <div class="flex justify-between mb-2 items-center">
              <div class="font-bold">{$t('common.destination')}</div>
              <div><ChainSelector small value={$destinationChain} readOnly /></div>
            </div>
            <div class="flex justify-between mb-2">
              <div class="font-bold">{$t('common.contract_address')}</div>
              <div class="text-secondary-content">
                <ul>
                  {#each selectedNFT as nft}
                    {@const currentChain = $network?.id}
                    {#if currentChain && $destinationChain?.id}
                      <li>
                        <a
                          class="flex justify-start link"
                          href={`${chainConfig[$destinationChain?.id].urls.explorer}`}
                          target="_blank">
                          {shortenAddress(nft.addresses[currentChain], 8, 12)}
                          <Icon type="arrow-top-right" fillClass="fill-primary-link" />
                        </a>
                      </li>
                    {/if}
                  {/each}
                </ul>
              </div>
            </div>

            <div class="flex justify-between">
              <div class="font-bold">{$t('bridge.nft.step.review.token_id')}</div>
              <div class="break-words text-right text-secondary-content">
                <ul>
                  {#each selectedNFT as nft}
                    <li>{nft.tokenId}</li>
                  {/each}
                </ul>
              </div>
            </div>
          </div>

          <div class="h-sep" />
          <!-- 
            Recipient & Processing Fee
           -->
          <div class="space-y-[16px]">
            <Recipient bind:this={recipientComponent} />
            <ProcessingFee bind:this={processingFeeComponent} />
          </div>

          <div class="h-sep" />
          <!-- 
            NFT List or Card View
           -->
          <section class="space-y-2">
            <div class="flex justify-between items-center w-full">
              <div class="flex items-center gap-2">
                <span>{$t('bridge.nft.step.review.your_tokens')}</span>
                <ChainSelector small value={$network} readOnly />
              </div>
              <div class="flex gap-2">
                <Button
                  disabled={true}
                  shape="circle"
                  type="neutral"
                  class="!w-9 !h-9 rounded-full"
                  on:click={searchNFTs}>
                  <Icon type="magnifier" fillClass="fill-primary-icon" size={24} vWidth={24} vHeight={24} />
                </Button>
                <IconFlipper
                  iconType1="list"
                  iconType2="cards"
                  selectedDefault="list"
                  class="bg-neutral w-9 h-9 rounded-full"
                  on:labelclick={changeNFTView} />
                <!-- <Icon type="list" fillClass="fill-primary-icon" size={24} vWidth={24} vHeight={24} /> -->
              </div>
            </div>
            {#if nftView === NFTView.LIST}
              <NFTList bind:nfts={selectedNFT} chainId={$network?.id} viewOnly />
            {:else if nftView === NFTView.CARDS}
              <div class="rounded-[20px] bg-neutral min-h-[200px] w-full p-2 f-center">
                {#each selectedNFT as nft}
                  <NFTCard {nft} />
                {/each}
              </div>
            {/if}
          </section>
          <!-- CONFIRM STEP -->
        {:else if activeStep === NFTSteps.CONFIRM}
          <div class="f-between-center gap-4">
            <ChainSelectorWrapper />
          </div>
        {/if}
        <div class="h-sep" />
        <!-- 
          User Actions
         -->
        <div class="f-between-center w-full gap-4">
          {#if activeStep !== NFTSteps.IMPORT}
            <Button
              type="neutral"
              class="px-[28px] py-[14px] rounded-full w-auto flex-1 bg-transparent !border border-primary-brand hover:border-primary-interactive-hover"
              on:click={previousStep}>
              <span class="body-bold">{$t('common.edit')}</span></Button>
          {/if}
          {#if activeStep === NFTSteps.REVIEW}
            <Actions {approve} {bridge} />
          {:else if activeStep === NFTSteps.IMPORT}
            {#if manualNFTInput}
              <Button
                disabled={!canProceed}
                type="primary"
                class="px-[28px] py-[14px] rounded-full flex-1 text-white"
                on:click={manualImportAction}><span class="body-bold">{nextStepButtonText} (manual)</span></Button>
            {:else}
              <Button
                disabled={!canProceed}
                type="primary"
                class="px-[28px] py-[14px] rounded-full flex-1 text-white"
                on:click={nextStep}><span class="body-bold">{nextStepButtonText}</span></Button>
            {/if}
          {/if}
        </div>
      </div>
    </Card>
  </div>
{/if}

<OnNetwork change={onNetworkChange} />
<OnAccount change={onAccountChange} />
