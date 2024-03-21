<script lang="ts">
  import { switchChain } from '@wagmi/core';
  import { log } from 'debug';
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import { ContractFunctionExecutionError, UserRejectedRequestError } from 'viem';

  import { errorToast, warningToast } from '$components/NotificationToast/NotificationToast.svelte';
  import { bridges, type BridgeTransaction } from '$libs/bridge';
  import {
    InsufficientBalanceError,
    InvalidProofError,
    NotConnectedError,
    ProcessMessageError,
    RetryError,
  } from '$libs/error';
  import { getConnectedWallet } from '$libs/util/getConnectedWallet';
  import { config } from '$libs/wagmi';
  import { account } from '$stores/account';
  import { connectedSourceChain } from '$stores/network';

  const dispatch = createEventDispatcher();

  export let bridgeTx: BridgeTransaction;

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

      // Step 1: make sure the user is on the correct chain
      await ensureCorrectChain(Number($connectedSourceChain.id), Number(bridgeTx.destChainId));

      // Step 2: Find out the type of bridge: ETHBridge, ERC20Bridge, etc
      const bridge = bridges[bridgeTx.tokenType];

      // Step 3: get the user's wallet
      const wallet = await getConnectedWallet(Number(bridgeTx.destChainId));

      log(`Claiming ${bridgeTx.tokenType} for transaction`, bridgeTx);

      // Step 4: Call claim() method on the bridge
      const txHash = await bridge.claim({ wallet, bridgeTx });

      dispatch('claimingTxSent', { txHash, type: 'claim' });
    } catch (err) {
      handleClaimError(err);

      dispatch('error', { error: err, action: 'claim' });
    }
  };

  const handleClaimError = (err: unknown) => {
    switch (true) {
      case err instanceof NotConnectedError:
        warningToast({ title: $t('messages.account.required') });
        break;
      case err instanceof UserRejectedRequestError:
        warningToast({ title: $t('transactions.actions.claim.rejected.title') });
        break;
      case err instanceof InsufficientBalanceError:
        dispatch('insufficientFunds', { tx: bridgeTx });
        break;
      case err instanceof InvalidProofError:
        errorToast({ title: $t('common.error'), message: $t('bridge.errors.invalid_proof_provided') });
        break;
      case err instanceof ProcessMessageError:
        errorToast({ title: $t('bridge.errors.process_message_error') });
        break;
      case err instanceof RetryError:
        errorToast({ title: $t('bridge.errors.retry_error') });
        break;
      case err instanceof ContractFunctionExecutionError:
        console.error('!========= ContractFunctionExecutionError', err);
        break;
      default:
        errorToast({
          title: $t('bridge.errors.unknown_error.title'),
          message: $t('bridge.errors.unknown_error.message'),
        });
        break;
    }
  };
</script>
