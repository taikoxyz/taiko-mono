<script lang="ts">
  import { switchChain } from '@wagmi/core';
  import { log } from 'debug';
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';

  import { chainConfig } from '$chainConfig';
  import { successToast } from '$components/NotificationToast';
  import { infoToast } from '$components/NotificationToast/NotificationToast.svelte';
  import { bridges, type BridgeTransaction } from '$libs/bridge';
  import { NotConnectedError } from '$libs/error';
  import { getConnectedWallet } from '$libs/util/getConnectedWallet';
  import { config } from '$libs/wagmi';
  import { account } from '$stores/account';
  import { connectedSourceChain } from '$stores/network';
  import { pendingTransactions } from '$stores/pendingTransactions';

  const dispatch = createEventDispatcher();

  export let bridgeTx: BridgeTransaction;
  export let claimingDone = false;

  // export let isProcessable = false;
  // export let bridgeTxStatus: Maybe<MessageStatus>;

  export let claiming = false;

  async function ensureCorrectChain(currentChainId: number, wannaBeChainId: number) {
    const isCorrectChain = currentChainId === wannaBeChainId;
    log(`Are we on the correct chain? ${isCorrectChain}`);

    if (!isCorrectChain) {
      // TODO: shouldn't we inform the user about this change? wallet will popup,
      //       but it's not clear why
      await switchChain(config, { chainId: wannaBeChainId });
    }
  }

  export const claim = async () => {
    if (!$account.address) {
      throw new NotConnectedError('User is not connected');
    }

    try {
      const { msgHash, message } = bridgeTx;

      if (!msgHash || !message) {
        throw new Error('Missing msgHash or message');
      }

      claiming = true;

      // Step 1: make sure the user is on the correct chain
      await ensureCorrectChain(Number($connectedSourceChain.id), Number(bridgeTx.destChainId));

      // Step 2: Find out the type of bridge: ETHBridge, ERC20Bridge, etc
      const bridge = bridges[bridgeTx.tokenType];

      // Step 3: get the user's wallet
      const wallet = await getConnectedWallet(Number(bridgeTx.destChainId));

      log(`Claiming ${bridgeTx.tokenType} for transaction`, bridgeTx);

      // Step 4: Call claim() method on the bridge
      const txHash = await bridge.claim({ wallet, bridgeTx });

      const explorer = chainConfig[Number(bridgeTx.destChainId)]?.blockExplorers?.default.url;

      infoToast({
        title: $t('transactions.actions.claim.tx.title'),
        message: $t('transactions.actions.claim.tx.message', {
          values: {
            token: bridgeTx.symbol,
            url: `${explorer}/tx/${txHash}`,
          },
        }),
      });
      claimingDone = true;
      await pendingTransactions.add(txHash, Number(bridgeTx.destChainId));

      //Todo: just because we have a claim tx doesn't mean it was successful
      successToast({
        title: $t('transactions.actions.claim.success.title'),
        message: $t('transactions.actions.claim.success.message', {
          values: {
            network: $connectedSourceChain.name,
          },
        }),
      });

      // We trigger this event to manually to update the UI
      // onStatusChange(MessageStatus.DONE); //TODO:
    } catch (err) {
      dispatch('error', err);
    } finally {
      claiming = false;
    }
  };
</script>
