<script lang="ts">
  import * as Sentry from '@sentry/svelte';
  import { Contract, errors, type Transaction, utils } from 'ethers';
  import { createEventDispatcher } from 'svelte';
  import { onDestroy, onMount } from 'svelte';
  import { ArrowTopRightOnSquare } from 'svelte-heros-v2';
  import { _ } from 'svelte-i18n';
  import { UserRejectedRequestError } from 'wagmi';

  import { bridges } from '../../bridge/bridges';
  import { chains } from '../../chain/chains';
  import { bridgeABI } from '../../constants/abi';
  import { BridgeType } from '../../domain/bridge';
  import type { ChainID } from '../../domain/chain';
  import { MessageStatus } from '../../domain/message';
  import type { NoticeOpenArgs } from '../../domain/modal';
  import {
    type BridgeTransaction,
    TxExtendedStatus,
    type TxUIStatus,
  } from '../../domain/transaction';
  import { providers } from '../../provider/providers';
  import { srcChain } from '../../store/chain';
  import { signer } from '../../store/signer';
  import { token } from '../../store/token';
  import { pendingTransactions } from '../../store/transaction';
  import { isETHByMessage } from '../../utils/isETHByMessage';
  import { isOnCorrectChain } from '../../utils/isOnCorrectChain';
  import { isTransactionProcessable } from '../../utils/isTransactionProcessable';
  import { getLogger } from '../../utils/logger';
  import { switchNetwork } from '../../utils/switchNetwork';
  import { tokenVaults } from '../../vault/tokenVaults';
  import Button from '../Button.svelte';
  import ButtonWithTooltip from '../ButtonWithTooltip.svelte';
  import Loading from '../Loading.svelte';
  import {
    errorToast,
    successToast,
    warningToast,
  } from '../NotificationToast.svelte';

  const log = getLogger('component:Transaction');

  export let transaction: BridgeTransaction;

  const dispatch = createEventDispatcher<{
    claimNotice: NoticeOpenArgs;
    tooltipStatus: void;
    insufficientBalance: void;
    transactionDetails: BridgeTransaction;
  }>();

  let loading: boolean;
  let processable: boolean = false;
  let interval: ReturnType<typeof setInterval>;
  let txToChain = chains[transaction.destChainId];
  let txFromChain = chains[transaction.srcChainId];
  // let alreadyInformedAboutClaim = false;

  function setTxStatus(status: TxUIStatus) {
    transaction.status = status;
    // If we want reactivity on props change, we need to reassign (Svelte thing)
    transaction = transaction;
  }

  // TODO: not very convinced about this annoying notice. Rethink it.
  // async function onClaimClick() {
  //   // Has the user sent processing fees?. We also check if the user
  //   // has already been informed about the relayer auto-claim.
  //   const processingFee = transaction.message?.processingFee.toString();
  //   if (processingFee && processingFee !== '0' && !alreadyInformedAboutClaim) {
  //     dispatch('claimNotice', {
  //       name: transaction.hash,
  //       onConfirm: async (informed: true) => {
  //         alreadyInformedAboutClaim = informed;
  //         await claim(transaction);
  //       },
  //     });
  //   } else {
  //     await claim(transaction);
  //   }
  // }

  async function ensureCorrectChain(
    currentChainId: ChainID,
    wannaBeChainId: ChainID,
    pendingTx: Transaction[],
  ) {
    const isCorrectChain = currentChainId === wannaBeChainId;
    log(`Are we on the correct chain? ${isCorrectChain}`);

    if (!isCorrectChain) {
      if (pendingTx && pendingTx.length > 0) {
        throw new Error('pending transactions ongoing', {
          cause: 'pending_tx',
        });
      }

      await switchNetwork(wannaBeChainId);
    }
  }

  // TODO: move outside of component
  async function claim(bridgeTx: BridgeTransaction) {
    try {
      loading = true;

      await ensureCorrectChain(
        $srcChain.id,
        bridgeTx.destChainId,
        $pendingTransactions,
      );

      // Confirm after switch chain that it worked
      const isCorrectChain = await isOnCorrectChain(
        $signer,
        bridgeTx.destChainId, // we claim on the destination chain
      );

      if (!isCorrectChain) {
        errorToast('You are connected to the wrong chain in your wallet');
        return;
      }

      // For now just handling this case for when the user has near 0 balance
      // during their first bridge transaction to L2
      // TODO: estimate Claim transaction
      const userBalance = await $signer.getBalance('latest');
      if (!userBalance.gt(utils.parseEther('0.0001'))) {
        // TODO: magic number 0.0001. Config?
        dispatch('insufficientBalance');
        return;
      }

      const bridgeType = isETHByMessage(bridgeTx.message)
        ? BridgeType.ETH
        : BridgeType.ERC20;
      const bridge = bridges[bridgeType];

      log(`Claiming ${bridgeType} for transaction`, bridgeTx);

      const tx = await bridge.claim({
        signer: $signer,
        message: bridgeTx.message,
        msgHash: bridgeTx.msgHash,
        destBridgeAddress: chains[bridgeTx.destChainId].bridgeAddress,
        srcBridgeAddress: chains[bridgeTx.srcChainId].bridgeAddress,
      });

      successToast('Transaction sent to claim your funds.');

      // TODO: the problem here is: what if this takes some time and the user
      //       closes the page? We need to keep track of this state, storage?
      setTxStatus(TxExtendedStatus.Claiming);

      // TODO: here we need the promise in order to be able to cancel (AbortController)
      //       it in case Relayer has claimed the funds already.
      await pendingTransactions.add(tx, $signer);

      // We're done here, no need to poll anymore since we've claimed manually
      stopPolling();

      // Could happen that the poller has picked up the change of status
      // already, also it might have been claimed by the relayer. In that
      // case we don't want to show the success toast again.
      if (transaction.status !== MessageStatus.Done) {
        setTxStatus(MessageStatus.Done);
        successToast(
          `<strong>Transaction completed!</strong><br />Your funds have been successfully claimed on ${$srcChain.name}.`,
        );
      }

      // Re-selecting the token triggers reactivity, updating balances
      $token = $token;
    } catch (error) {
      console.error(error);

      Sentry.captureException(error, {
        extra: {
          srcChain: $srcChain.id,
          bridgeTx,
        },
      });

      const headerError = '<strong>Failed to claim funds</strong>';

      // TODO: let's change this to a switch(true)? I think it's more readable.
      if (error.cause?.status === 0) {
        // How about this: Relayer has already claimed the funds, in which case
        // the status of this transaction is no longer NEW, but DONE (poller has
        // already taken care of chanding the status). This will throw an error,
        // B_STATUS_MISMATCH, therefore receipt.status === 0. Checks that the
        // transaction.status is not DONE, otherwise get out without complaining.
        // TODO: cancel claiming promise instead?
        // if (transaction.status === MessageStatus.Done) {
        //   log('Relayer has already claimed the funds, no need to complain');
        //   return;
        // }

        const explorerUrl = `${$srcChain.explorerUrl}/tx/${error.cause.transactionHash}`;
        const htmlLink = `<a href="${explorerUrl}" target="_blank"><b><u>here</u></b></a>`;
        errorToast(
          `${headerError}<br />Click ${htmlLink} to see more details on the explorer.`,
          true, // dismissible
        );
      } else if (
        error instanceof UserRejectedRequestError ||
        [error.code, error.cause?.code].includes(errors.ACTION_REJECTED)
      ) {
        warningToast(`Transaction has been rejected.`);
      } else if (error.cause === 'pending_tx') {
        warningToast(
          'You have pending transactions. Please wait for them to complete.',
        );
      } else {
        errorToast(`${headerError}<br />Try again later.`);
      }
    } finally {
      loading = false;
    }
  }

  // TODO: move outside of component
  async function release(bridgeTx: BridgeTransaction) {
    try {
      loading = true;

      await ensureCorrectChain(
        $srcChain.id,
        bridgeTx.srcChainId,
        $pendingTransactions,
      );

      // Confirm after switch chain that it worked
      const isCorrectChain = await isOnCorrectChain(
        $signer,
        bridgeTx.srcChainId, // we release on the source chain
      );

      if (!isCorrectChain) {
        errorToast('You are connected to the wrong chain in your wallet');
        return;
      }

      const bridgeType = isETHByMessage(bridgeTx.message)
        ? BridgeType.ETH
        : BridgeType.ERC20;
      const bridge = bridges[bridgeType];

      log(`Releasing ${bridgeType} for transaction`, bridgeTx);

      const tx = await bridge.release({
        signer: $signer,
        message: bridgeTx.message,
        msgHash: bridgeTx.msgHash,
        destBridgeAddress: chains[bridgeTx.destChainId].bridgeAddress,
        srcBridgeAddress: chains[bridgeTx.srcChainId].bridgeAddress,
        destProvider: providers[bridgeTx.destChainId],
        srcTokenVaultAddress: tokenVaults[bridgeTx.srcChainId],
      });

      successToast('Transaction sent to release your funds.');

      // TODO: storage?
      setTxStatus(TxExtendedStatus.Releasing);

      await pendingTransactions.add(tx, $signer);

      setTxStatus(TxExtendedStatus.Released);

      successToast(
        `<strong>Transaction completed!</strong><br />Your funds have been successfully released back to ${$srcChain.name}.`,
      );

      // Re-selecting to trigger reactivity on selected token
      $token = $token;
    } catch (error) {
      console.error(error);

      Sentry.captureException(error, {
        extra: {
          srcChain: $srcChain.id,
          bridgeTx,
        },
      });

      const headerError = '<strong>Failed to release funds</strong>';

      if (error.cause?.status === 0) {
        const explorerUrl = `${$srcChain.explorerUrl}/tx/${error.cause.transactionHash}`;
        const htmlLink = `<a href="${explorerUrl}" target="_blank"><b><u>here</u></b></a>`;
        errorToast(
          `${headerError}<br />Click ${htmlLink} to see more details on the explorer.`,
          true, // dismissible
        );
      } else if (
        [error.code, error.cause?.code].includes(errors.ACTION_REJECTED)
      ) {
        warningToast(`Transaction has been rejected.`);
      } else if (error.cause === 'pending_tx') {
        warningToast(
          'You have pending transactions. Please wait for them to complete.',
        );
      } else {
        errorToast(`${headerError}<br />Try again later.`);
      }
    } finally {
      loading = false;
    }
  }

  function stopPolling() {
    if (interval) {
      log('Stop polling for transaction', transaction);
      clearInterval(interval);
      interval = null;
    }
  }

  // TODO: move this logic into a Web Worker
  // TODO: handle errors here
  function startPolling() {
    if (!interval) {
      log('Starting polling for transaction', transaction);

      interval = setInterval(async () => {
        processable = await isTransactionProcessable(transaction);

        const { destChainId, msgHash, status } = transaction;

        // It could happen that the transaction has been claimed manually
        // and by the time we poll it's already done, in which case we
        // stop polling.
        if (status === MessageStatus.Done) {
          stopPolling();
          return;
        }

        const destChain = chains[destChainId];
        const destProvider = providers[destChainId];

        const destBridgeContract = new Contract(
          destChain.bridgeAddress,
          bridgeABI,
          destProvider,
        );

        // We want to poll for status changes
        const msgStatus: MessageStatus =
          await destBridgeContract.getMessageStatus(msgHash);

        setTxStatus(msgStatus);

        if (msgStatus === MessageStatus.Done) {
          log('Poller has picked up the change of status to DONE');

          successToast(
            `<strong>Transaction completed!</strong><br />Your funds have been successfully claimed on ${$srcChain.name}.`,
          );

          stopPolling();

          // Triggers reactivity on selected token
          $token = $token;
        }
      }, 20 * 1000); // TODO: magic number. Config?
    }
  }

  onMount(async () => {
    processable = await isTransactionProcessable(transaction);

    if (transaction.status === MessageStatus.New) {
      startPolling();
    }
  });

  onDestroy(() => {
    if (interval) {
      clearInterval(interval);
    }
  });
</script>

<tr>
  <td>
    <svelte:component this={txFromChain.icon} height={18} width={18} />
    <span class="ml-2 hidden md:inline-block">{txFromChain.name}</span>
  </td>
  <td>
    <svelte:component this={txToChain.icon} height={18} width={18} />
    <span class="ml-2 hidden md:inline-block">{txToChain.name}</span>
  </td>
  <td>
    {#if Boolean(transaction.message) && isETHByMessage(transaction.message)}
      {@const { depositValue, callValue } = transaction.message}
      {utils.formatEther(depositValue.eq(0) ? callValue : depositValue)}
    {:else}
      {utils.formatUnits(transaction.amount, transaction.decimals)}
    {/if}
    {transaction.symbol || 'ETH'}
  </td>

  <td>
    <ButtonWithTooltip onClick={() => dispatch('tooltipStatus')}>
      <span slot="buttonText">
        {#if !processable}
          {$_('transaction.pending')}
        {:else if loading}
          <div class="inline-block">
            <Loading />
          </div>
        {:else if transaction.status === MessageStatus.New}
          <Button type="accent" size="sm" on:click={() => claim(transaction)}>
            {$_('transaction.claim')}
          </Button>
        {:else if transaction.status === MessageStatus.Retriable}
          <Button type="accent" size="sm" on:click={() => claim(transaction)}>
            {$_('transaction.retry')}
          </Button>
        {:else if transaction.status === MessageStatus.Done}
          <span class="border border-transparent p-0">
            {$_('transaction.claimed')}
          </span>
        {:else if transaction.status === MessageStatus.Failed}
          <Button type="accent" size="sm" on:click={() => release(transaction)}>
            {$_('transaction.release')}
          </Button>
        {:else if transaction.status === TxExtendedStatus.Released}
          <span class="border border-transparent p-0">
            {$_('transaction.released')}
          </span>
        {:else}
          <span class="border border-transparent p-0">Failed</span>
        {/if}
      </span>
    </ButtonWithTooltip>
  </td>

  <td>
    <button
      class="cursor-pointer inline-block"
      on:click={() => dispatch('transactionDetails', transaction)}>
      <ArrowTopRightOnSquare />
    </button>
  </td>
</tr>

<style>
  td {
    padding: 1rem;
  }
</style>
