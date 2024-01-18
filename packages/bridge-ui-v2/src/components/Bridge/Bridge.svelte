<script lang="ts">
  import type { Hash } from '@wagmi/core';
  import { onDestroy } from 'svelte';
  import { t } from 'svelte-i18n';
  import { getAddress } from 'viem';

  import { routingContractsMap } from '$bridgeConfig';
  import { chainConfig } from '$chainConfig';
  import { Alert } from '$components/Alert';
  import { Card } from '$components/Card';
  import CombinedChainSelector from '$components/ChainSelectors/CombinedChainSelector.svelte';
  import { successToast } from '$components/NotificationToast';
  import { infoToast } from '$components/NotificationToast/NotificationToast.svelte';
  import { OnAccount } from '$components/OnAccount';
  import { OnNetwork } from '$components/OnNetwork';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { PUBLIC_SLOW_L1_BRIDGING_WARNING } from '$env/static/public';
  import { type ApproveArgs, bridges, type BridgeTransaction, MessageStatus } from '$libs/bridge';
  import { hasBridge } from '$libs/bridge/bridges';
  import type { ERC20Bridge } from '$libs/bridge/ERC20Bridge';
  import { getBridgeArgs } from '$libs/bridge/getBridgeArgs';
  import { handleBridgeError } from '$libs/bridge/handleBridgeErrors';
  import { LayerType } from '$libs/chain';
  import { BridgePausedError } from '$libs/error';
  import { bridgeTxService } from '$libs/storage';
  import { ETHToken, tokens, TokenType } from '$libs/token';
  import { checkTokenApprovalStatus } from '$libs/token/checkTokenApprovalStatus';
  import { getCrossChainInfo } from '$libs/token/getCrossChainInfo';
  import { refreshUserBalance } from '$libs/util/balance';
  import { isBridgePaused } from '$libs/util/checkForPausedContracts';
  import { getConnectedWallet } from '$libs/util/getConnectedWallet';
  import { type Account, account } from '$stores/account';
  import { type Network, network } from '$stores/network';
  import { pendingTransactions } from '$stores/pendingTransactions';

  import Actions from './Actions.svelte';
  import Amount from './Amount.svelte';
  import NFTBridge from './NFTBridge.svelte';
  import { ProcessingFee } from './ProcessingFee';
  import Recipient from './Recipient.svelte';
  import {
    activeBridge,
    allApproved,
    approving,
    bridgeService,
    destNetwork as destinationChain,
    enteredAmount,
    processingFee,
    recipientAddress,
    selectedToken,
  } from './state';
  import { BridgeTypes } from './types';

  let amountComponent: Amount;
  let recipientComponent: Recipient;
  let processingFeeComponent: ProcessingFee;
  let slowL1Warning = PUBLIC_SLOW_L1_BRIDGING_WARNING || false;

  let bridging = false;

  function onNetworkChange(newNetwork: Network, oldNetwork: Network) {
    resetForm();
    $selectedToken = ETHToken;

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

  function onAccountChange(account: Account) {
    resetForm();
    if (account && account.isConnected && !$selectedToken) {
      $selectedToken = ETHToken;
    } else if (account && account.isDisconnected) {
      $selectedToken = null;
      $destinationChain = null;
    }
  }

  async function approve() {
    isBridgePaused().then((paused) => {
      if (paused) throw new BridgePausedError('Bridge is paused');
    });
    try {
      if (!$selectedToken || !$network || !$destinationChain) return;
      const type: TokenType = $selectedToken.type;
      const walletClient = await getConnectedWallet($network.id);
      let tokenAddress = $selectedToken.addresses[$network.id];
      if (tokenAddress) {
        tokenAddress = await getAddress(tokenAddress);
      }
      if (!tokenAddress) {
        const crossChainInfo = await getCrossChainInfo({
          token: $selectedToken,
          srcChainId: $network.id,
          destChainId: $destinationChain.id,
        });
        if (!crossChainInfo) throw new Error('cross chain info not found');

        const { address: crossChainAddress } = crossChainInfo;

        tokenAddress = crossChainAddress;
      }
      if (!tokenAddress) {
        throw new Error('token address not found');
      }

      let txHash: Hash;
      if (type === TokenType.ERC20) {
        // ERC20 approval
        const spenderAddress = routingContractsMap[$network.id][$destinationChain.id].erc20VaultAddress;
        const args: ApproveArgs = { amount: $enteredAmount!, tokenAddress, spenderAddress, wallet: walletClient };
        txHash = await (bridges[type] as ERC20Bridge).approve(args);
        amountComponent.validateAmount();

        const { explorer } = chainConfig[$network.id].urls;

        if (txHash)
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

        await getTokenApprovalStatus($selectedToken);

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
    } catch (err) {
      console.error(err);
      handleBridgeError(err as Error);
      $approving = false;
    }
  }

  async function bridge() {
    isBridgePaused().then((paused) => {
      if (paused) throw new BridgePausedError('Bridge is paused');
    });

    if (!$bridgeService || !$selectedToken || !$network || !$destinationChain || !$account?.address) return;

    try {
      const walletClient = await getConnectedWallet($network.id);
      const commonArgs = {
        to: $recipientAddress || $account.address,
        wallet: walletClient,
        srcChainId: $network.id,
        destChainId: $destinationChain.id,
        fee: $processingFee,
      };

      const bridgeArgs = await getBridgeArgs($selectedToken, $enteredAmount, commonArgs);

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

      // Refresh user's ETH balance
      refreshUserBalance();

      // Update amount balance after bridging
      if (amountComponent) amountComponent.updateBalance();
    } catch (err) {
      console.error(err);
      handleBridgeError(err as Error);
      bridging = false;
    }
  }

  const resetForm = () => {
    //we check if these are still mounted, as the user might have left the page
    if (amountComponent) amountComponent.clearAmount();
    if (recipientComponent) recipientComponent.clearRecipient();
    if (processingFeeComponent) processingFeeComponent.resetProcessingFee();
    $allApproved = false;
    bridging = false;
    $recipientAddress = null;
  };

  onDestroy(() => {
    resetForm();
  });

  $: disabled = !$selectedToken || !$network || !$destinationChain || bridging;

  $: displayL1Warning =
    slowL1Warning && $destinationChain?.id && chainConfig[$destinationChain.id].type === LayerType.L1;
</script>

<!-- 
    ETH & ERC20 Bridge  
-->
{#if $activeBridge === BridgeTypes.FUNGIBLE}
  <Card class="w-full md:w-[524px] " title={$t('bridge.title.default')} text={$t('bridge.description.default')}>
    <div class="space-y-[30px] mt-[30px]">
      <CombinedChainSelector />

      {#if displayL1Warning}
        <Alert type="warning">{$t('bridge.alerts.slow_bridging')}</Alert>
      {/if}

      <TokenDropdown {tokens} bind:value={$selectedToken} bind:disabled />

      <Amount bind:this={amountComponent} bind:disabled />

      <div class="space-y-[16px]">
        <Recipient bind:this={recipientComponent} bind:disabled />
        <ProcessingFee bind:this={processingFeeComponent} bind:disabled />
      </div>

      <div class="h-sep" />

      <Actions {approve} {bridge} bind:bridging bind:disabled />
    </div>
  </Card>

  <!-- 
    NFT Bridge  
  -->
{:else if $activeBridge === BridgeTypes.NFT}
  <NFTBridge />
{/if}

<OnNetwork change={onNetworkChange} />
<OnAccount change={onAccountChange} />
