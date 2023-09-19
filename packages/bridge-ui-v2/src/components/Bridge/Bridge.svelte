<script lang="ts">
  import { t } from 'svelte-i18n';
  import { TransactionExecutionError, UserRejectedRequestError } from 'viem';

  import { routingContractsMap } from '$bridgeConfig';
  import { chainConfig } from '$chainConfig';
  import { FlatAlert } from '$components/Alert';
  import ChainSelectorWrapper from '$components/Bridge/ChainSelectorWrapper.svelte';
  import { Card } from '$components/Card';
  import { successToast, warningToast } from '$components/NotificationToast';
  import { errorToast, infoToast } from '$components/NotificationToast/NotificationToast.svelte';
  import { OnAccount } from '$components/OnAccount';
  import { OnNetwork } from '$components/OnNetwork';
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
  import { ETHToken, getAddress, isDeployedCrossChain, tokens, TokenType } from '$libs/token';
  import { refreshUserBalance } from '$libs/util/balance';
  import { getConnectedWallet } from '$libs/util/getConnectedWallet';
  import { type Account, account } from '$stores/account';
  import { type Network, network } from '$stores/network';
  import { pendingTransactions } from '$stores/pendingTransactions';

  import Actions from './Actions.svelte';
  import Amount from './Amount.svelte';
  import { ProcessingFee } from './ProcessingFee';
  import Recipient from './Recipient.svelte';
  import { bridgeService, destNetwork, enteredAmount, processingFee, recipientAddress, selectedToken } from './state';

  let amountComponent: Amount;
  let recipientComponent: Recipient;
  let processingFeeComponent: ProcessingFee;

  function onNetworkChange(newNetwork: Network, oldNetwork: Network) {
    if (newNetwork) {
      const destChainId = $destNetwork?.id;
      if (!$destNetwork?.id) return;
      // determine if we simply swapped dest and src networks
      if (newNetwork.id === destChainId) {
        destNetwork.set(oldNetwork);
        return;
      }
      // check if the new network has a bridge to the current dest network
      if (hasBridge(newNetwork.id, $destNetwork?.id)) {
        destNetwork.set(oldNetwork);
      } else {
        // if not, set dest network to null
        $destNetwork = null;
      }
    }
  }

  function onAccountChange(account: Account) {
    if (account && account.isConnected && !$selectedToken) {
      $selectedToken = ETHToken;
    } else if (account && account.isDisconnected) {
      $selectedToken = null;
      $destNetwork = null;
    }
  }

  async function approve() {
    if (!$selectedToken || !$network || !$destNetwork) return;

    const erc20Bridge = bridges.ERC20 as ERC20Bridge;

    try {
      const walletClient = await getConnectedWallet($network.id);

      const tokenAddress = await getAddress({
        token: $selectedToken,
        srcChainId: $network.id,
        destChainId: $destNetwork.id,
      });

      if (!tokenAddress) {
        throw new Error('token address not found');
      }

      const spenderAddress = routingContractsMap[$network.id][$destNetwork.id].erc20VaultAddress;

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
    if (!$bridgeService || !$selectedToken || !$network || !$destNetwork || !$account?.address) return;

    try {
      const walletClient = await getConnectedWallet($network.id);

      // Common arguments for both ETH and ERC20 bridges
      let bridgeArgs = {
        to: $recipientAddress || $account.address,
        wallet: walletClient,
        srcChainId: $network.id,
        destChainId: $destNetwork.id,
        amount: $enteredAmount,
        fee: $processingFee,
      } as BridgeArgs;

      switch ($selectedToken.type) {
        case TokenType.ETH: {
          // Specific arguments for ETH bridge:
          // - bridgeAddress
          const bridgeAddress = routingContractsMap[$network.id][$destNetwork.id].bridgeAddress;
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
            destChainId: $destNetwork.id,
          });

          if (!tokenAddress) {
            throw new Error('token address not found');
          }

          const tokenVaultAddress = routingContractsMap[$network.id][$destNetwork.id].erc20VaultAddress;

          const isTokenAlreadyDeployed = await isDeployedCrossChain({
            token: $selectedToken,
            srcChainId: $network.id,
            destChainId: $destNetwork.id,
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
            network: $destNetwork.name,
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
        destChainId: BigInt($destNetwork.id),
        tokenType: $selectedToken.type,
        status: MessageStatus.NEW,
        timestamp: Date.now(),

        // TODO: do we need something else? we can have
        // access to the Transaction object:
        // TransactionLegacy, TransactionEIP2930 and
        // TransactionEIP1559
      } as BridgeTransaction;

      bridgeTxService.addTxByAddress($account.address, bridgeTx);

      // Reset the form (we check if these are still mounted, as the user might have left the page)
      if (amountComponent) amountComponent.clearAmount();
      if (recipientComponent) recipientComponent.clearRecipient();
      if (processingFeeComponent) processingFeeComponent.resetProcessingFee();

      // Update balance after bridging
      if (amountComponent) amountComponent.updateBalance();

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
</script>

<Card class="w-full md:w-[524px]" title={$t('bridge.title.default')} text={$t('bridge.description')}>
  <div class="space-y-[30px]">
    <div class="f-between-center gap-4">
      <ChainSelectorWrapper />
    </div>

    <TokenDropdown {tokens} bind:value={$selectedToken} />
    {#if $selectedToken?.symbol === 'BLL' && !$selectedToken?.imported}
      <FlatAlert class="!mt-2" message={$t('bridge.errors.bll_token')} type="warning" />
    {/if}
    <Amount bind:this={amountComponent} />

    <div class="space-y-[16px]">
      <Recipient bind:this={recipientComponent} />
      <ProcessingFee bind:this={processingFeeComponent} />
    </div>

    <div class="h-sep" />

    <Actions {approve} {bridge} />
  </div>
</Card>

<OnNetwork change={onNetworkChange} />

<OnAccount change={onAccountChange} />
