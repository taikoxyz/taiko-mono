<script lang="ts">
  import { type Address,fetchBalance, switchNetwork } from '@wagmi/core';
  import { onDestroy, onMount } from 'svelte';
  import { t } from 'svelte-i18n';
  import { parseEther } from 'viem';

  import { infoToast, successToast } from '$components/NotificationToast/NotificationToast.svelte';
  import { StatusDot } from '$components/StatusDot';
  import { bridges,type BridgeTransaction, MessageStatus } from '$libs/bridge';
  import { PollingEvent, startPolling } from '$libs/bridge/bridgeTxMessageStatusPoller';
  import { chains,chainUrlMap } from '$libs/chain';
  import { getConnectedWallet } from '$libs/util/getConnectedWallet';
  import { getLogger } from '$libs/util/logger';
  import { account } from '$stores/account';
  import { network } from '$stores/network';
  import { pendingTransactions } from '$stores/pendingTransactions';

  const log = getLogger('components:Status');

  export let bridgeTx: BridgeTransaction;

  let polling: ReturnType<typeof startPolling>;

  // UI state
  let processable = false;
  let bridgeTxStatus: Maybe<MessageStatus> = bridgeTx.status;

  // TODO: enum?
  let loading: 'claiming' | 'releasing' | false = false;

  function onProcessable(isTxProcessable: boolean) {
    processable = isTxProcessable;
  }

  function onStatusChange(status: MessageStatus) {
    // We need to keep model and UI in sync
    bridgeTxStatus = bridgeTx.status = status;
  }

  async function ensureCorrectChain(currentChainId: number, wannaBeChainId: number) {
    const isCorrectChain = currentChainId === wannaBeChainId;
    log(`Are we on the correct chain? ${isCorrectChain}`);

    if (!isCorrectChain) {
      await switchNetwork({ chainId: wannaBeChainId });
    }
  }

  async function checkEnoughBalance(address: Address) {
    const balance = await fetchBalance({ address });
    return balance.value > parseEther('0.0001');
  }

  async function claim() {
    if (!$network || !$account?.address) return;

    loading = 'claiming';

    try {
      const { msgHash, message } = bridgeTx;

      if (!msgHash || !message) {
        throw new Error('Missing msgHash or message');
      }

      // Step 1: get the user's wallet
      const wallet = await getConnectedWallet();

      // Step 2: ensure correct chain
      await ensureCorrectChain(Number($network.id), Number(bridgeTx.destChainId));

      // Step 3: make sure the user has enough balance on the destination chain
      await checkEnoughBalance($account.address);

      // Step 4: Find out the type of bridge: ETHBridge, ERC20Bridge, etc
      const bridge = bridges[bridgeTx.tokenType];

      log(`Claiming ${bridgeTx.tokenType} for transaction`, bridgeTx);

      // Step 5: Call claim() method on the bridge
      const txHash = await bridge.claim({ msgHash, message, wallet });

      const explorerUrl = chains[Number(bridgeTx.destChainId)].blockExplorers?.default.url;

      infoToast(
        $t('activities.actions.claim.tx', {
          values: {
            url: `${explorerUrl}/tx/${txHash}`,
          },
        }),
      );

      await pendingTransactions.add(txHash, $network.id);

      successToast(
        $t('activities.actions.claim.success', {
          values: {
            network: $network.name,
          },
        }),
      );
    } catch (err) {
      console.error(err);

      // TODO: handle errors
    } finally {
      loading = false;
    }
  }

  async function release() {
    if (!$network || !$account?.address) return;

    loading = 'releasing';

    try {
      const { msgHash, message } = bridgeTx;

      if (!msgHash || !message) {
        throw new Error('Missing msgHash or message');
      }

      // Step 1: get the user's wallet
      const wallet = await getConnectedWallet();

      // Step 2: ensure correct chain
      await ensureCorrectChain(Number($network.id), Number(bridgeTx.srcChainId));

      // Step 3: make sure the user has enough balance on the source chain
      await checkEnoughBalance($account.address);

      // Step 4: Find out the type of bridge: ETHBridge, ERC20Bridge, etc
      const bridge = bridges[bridgeTx.tokenType];

      log(`Releasing ${bridgeTx.tokenType} for transaction`, bridgeTx);

      // Step 5: Call release() method on the bridge
      const txHash = await bridge.claim({ msgHash, message, wallet });

      const { explorerUrl } = chainUrlMap[Number(bridgeTx.destChainId)];

      infoToast(
        $t('activities.actions.release.tx', {
          values: {
            url: `${explorerUrl}/tx/${txHash}`,
          },
        }),
      );

      await pendingTransactions.add(txHash, $network.id);

      successToast(
        $t('activities.actions.release.success', {
          values: {
            network: $network.name,
          },
        }),
      );
    } catch (err) {
      console.error(err);

      // TODO: handle errors
    } finally {
      loading = false;
    }
  }

  onMount(() => {
    if (bridgeTx) {
      try {
        polling = startPolling(bridgeTx);

        // If there is no emitter, means the bridgeTx is already DONE
        // so we do nothing here
        if (polling?.emitter) {
          // The following listeners will trigger change in the UI
          polling.emitter.on(PollingEvent.PROCESSABLE, onProcessable);
          polling.emitter.on(PollingEvent.STATUS, onStatusChange);
        }
      } catch (err) {
        console.error(err);
        // TODO: handle error
      }
    }
  });

  onDestroy(() => {
    if (polling) {
      polling.destroy();
    }
  });
</script>

<div class="Status f-items-center space-x-1">
  {#if !processable}
    <StatusDot type="pending" />
    <span>{$t('activities.status.initiated')}</span>
  {:else if loading}
    TODO: add loading indicator and text for 'claiming', 'retrying', 'releasing'
  {:else if bridgeTxStatus === MessageStatus.NEW}
    <button class="status-btn w-full" on:click={claim}>
      {$t('activities.button.claim')}
    </button>
  {:else if bridgeTxStatus === MessageStatus.RETRIABLE}
    <button class="status-btn w-full" on:click={claim}>
      {$t('activities.button.claim')}
    </button>
  {:else if bridgeTxStatus === MessageStatus.DONE}
    <StatusDot type="success" />
    <span>{$t('activities.status.claimed')}</span>
  {:else if bridgeTxStatus === MessageStatus.FAILED}
    <button class="status-btn w-full" on:click={release}>
      {$t('activities.button.claim')}
    </button>
  {:else}
    <StatusDot type="error" />
    <span>{$t('activities.status.error')}</span>
  {/if}
</div>
