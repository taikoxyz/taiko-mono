<script lang="ts">
  import { switchChain } from '@wagmi/core';
  import { log } from 'debug';
  import { createEventDispatcher } from 'svelte';
  import type { Hash } from 'viem';

  import { bridges, type BridgeTransaction } from '$libs/bridge';
  import { NotConnectedError } from '$libs/error';
  import { getConnectedWallet } from '$libs/util/getConnectedWallet';
  import { config } from '$libs/wagmi';
  import { account } from '$stores/account';
  import { connectedSourceChain } from '$stores/network';

  import { selectedRetryMethod } from './RetryDialog/state';
  import { RETRY_OPTION } from './RetryDialog/types';
  import { ClaimAction } from './Shared/types';

  const dispatch = createEventDispatcher();

  export let bridgeTx: BridgeTransaction;

  async function ensureCorrectChain(action: ClaimAction) {
    const currentChainId = Number($connectedSourceChain.id);
    const txDestChain = Number(bridgeTx.destChainId);
    const txSrcChain = Number(bridgeTx.srcChainId);

    let isCorrectChain: boolean;
    let expectedChainId: number;

    if (action === ClaimAction.RELEASE) {
      // If we are releasing, we need to be on the source chain
      expectedChainId = txSrcChain;
    } else {
      expectedChainId = txDestChain;
    }

    isCorrectChain = currentChainId === expectedChainId;

    log(`Are we on the correct chain? ${isCorrectChain}`);

    if (!isCorrectChain) {
      await switchChain(config, { chainId: expectedChainId });
    }
  }

  export const claim = async (action: ClaimAction) => {
    if (!$account.address) {
      throw new NotConnectedError('User is not connected');
    }

    try {
      const { msgHash, message } = bridgeTx;

      if (!msgHash || !message) {
        throw new Error('Missing msgHash or message');
      }

      // Step 1: make sure the user is on the correct chain
      await ensureCorrectChain(action);

      // Step 2: Find out the type of bridge: ETHBridge, ERC20Bridge, etc
      const bridge = bridges[bridgeTx.tokenType];

      // Step 3: get the user's wallet
      const wallet = await getConnectedWallet(Number(bridgeTx.destChainId));

      log(`Claiming ${bridgeTx.tokenType} for transaction`, bridgeTx);

      // Step 4: Call claim() method on the bridge
      let txHash: Hash;
      if ($selectedRetryMethod === RETRY_OPTION.RETRY_ONCE) {
        log('Claiming with lastAttempt flag');
        txHash = await bridge.processMessage({ wallet, bridgeTx, lastAttempt: true });
      } else {
        txHash = await bridge.processMessage({ wallet, bridgeTx });
      }

      dispatch('claimingTxSent', { txHash, action });
    } catch (err) {
      dispatch('error', { error: err, action });
    }
  };
</script>
