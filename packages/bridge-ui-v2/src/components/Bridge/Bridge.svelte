<script lang="ts">
  import type { Hash } from '@wagmi/core';
  import { onDestroy } from 'svelte';
  import { t } from 'svelte-i18n';
  import { getAddress } from 'viem';

  import { routingContractsMap } from '$bridgeConfig';
  import { chainConfig } from '$chainConfig';
  import { Card } from '$components/Card';
  import { ChainSelectorWrapper } from '$components/ChainSelector';
  import { successToast } from '$components/NotificationToast';
  import { infoToast } from '$components/NotificationToast/NotificationToast.svelte';
  import { OnAccount } from '$components/OnAccount';
  import { OnNetwork } from '$components/OnNetwork';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { type ApproveArgs, bridges, type BridgeTransaction, MessageStatus } from '$libs/bridge';
  import { hasBridge } from '$libs/bridge/bridges';
  import type { ERC20Bridge } from '$libs/bridge/ERC20Bridge';
  import { getBridgeArgs } from '$libs/bridge/getBridgeArgs';
  import { handleBridgeError } from '$libs/bridge/handleBridgeErrors';
  import { bridgeTxService } from '$libs/storage';
  import { ETHToken, tokens, TokenType } from '$libs/token';
  import { getCrossChainAddress } from '$libs/token/getCrossChainAddress';
  import { refreshUserBalance } from '$libs/util/balance';
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
  let actionsComponent: Actions;

  function onNetworkChange(newNetwork: Network, oldNetwork: Network) {
    resetForm();

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
    try {
      if (!$selectedToken || !$network || !$destinationChain) return;
      const type: TokenType = $selectedToken.type;
      const walletClient = await getConnectedWallet($network.id);
      let tokenAddress = await getAddress($selectedToken.addresses[$network.id]);

      if (!tokenAddress) {
        const crossChainAddress = await getCrossChainAddress({
          token: $selectedToken,
          srcChainId: $network.id,
          destChainId: $destinationChain.id,
        });
        if (!crossChainAddress) throw new Error('cross chain address not found');
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

        actionsComponent.checkTokensApproved();

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
    }
  }

  async function bridge() {
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

      // Refresh user's balance
      refreshUserBalance();
    } catch (err) {
      console.error(err);
      handleBridgeError(err as Error);
    }
  }

  const resetForm = () => {
    //we check if these are still mounted, as the user might have left the page
    if (amountComponent) amountComponent.clearAmount();
    if (recipientComponent) recipientComponent.clearRecipient();
    if (processingFeeComponent) processingFeeComponent.resetProcessingFee();

    // Update balance after bridging
    if (amountComponent) amountComponent.updateBalance();

    $selectedToken = ETHToken;
  };

  onDestroy(() => {
    resetForm();
  });
</script>

<!-- 
    ETH & ERC20 Bridge  
-->
{#if $activeBridge === BridgeTypes.FUNGIBLE}
  <Card class="w-full md:w-[524px]" title={$t('bridge.title.default')} text={$t('bridge.description.default')}>
    <div class="space-y-[30px] mt-[30px]">
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

      <Actions {approve} {bridge} bind:this={actionsComponent} />
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
