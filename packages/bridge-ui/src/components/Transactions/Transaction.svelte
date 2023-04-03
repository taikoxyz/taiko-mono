<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import {
    ReceiptStatus,
    type BridgeTransaction,
    type TransactFn,
  } from '../../domain/transaction';
  import { ArrowTopRightOnSquare } from 'svelte-heros-v2';
  import { MessageStatus } from '../../domain/message';
  import { ethers } from 'ethers';
  import { _ } from 'svelte-i18n';
  import { onDestroy, onMount } from 'svelte';
  import BridgeABI from '../../constants/abi/Bridge';
  import ButtonWithTooltip from '../ButtonWithTooltip.svelte';
  import TokenVaultABI from '../../constants/abi/TokenVault';
  import { chains } from '../../chain/chains';
  import { providers } from '../../provider/providers';
  import { tokenVaults } from '../../vault/tokenVaults';
  import Button from '../buttons/Button.svelte';
  import { isTransactionProcessable } from '../../utils/isTransactionProcessable';
  import { claimToken } from '../../utils/claimToken';
  import { fromChain } from '../../store/chain';
  import { signer } from '../../store/signer';
  import { pendingTransactions } from '../../store/transaction';
  import { errorToast, successToast } from '../Toast.svelte';
  import { releaseToken } from '../../utils/releaseToken';
  import Loading from '../Loading.svelte';

  export let transaction: BridgeTransaction;

  const dispatch = createEventDispatcher<{
    tooltipClick: void;
    insufficientBalance: void;
    transactionDetailsClick: BridgeTransaction;
    relayerAutoClaim: (informed: boolean) => Promise<void>;
  }>();

  const txToChain = chains[transaction.toChainId];
  const txFromChain = chains[transaction.fromChainId];
  const { message, amountInWei, symbol, receipt, status } = transaction;
  const amount =
    message && (!message.data || message.data === '0x')
      ? ethers.utils.formatEther(
          message?.depositValue.eq(0)
            ? message?.callValue.toString()
            : message?.depositValue,
        )
      : ethers.utils.formatEther(amountInWei);

  let loading: boolean;
  let processable: boolean = false; // TODO: ???
  let interval: ReturnType<typeof setInterval>;
  // let alreadyInformedAboutClaim = false;

  onMount(async () => {
    processable = await isTransactionProcessable(transaction);
    interval = startInterval();
  });

  onDestroy(() => {
    if (interval) {
      clearInterval(interval);
    }
  });

  // async function onClaimClick() {
  //   // Has the user sent processing fees?. We also check if the user
  //   // has already been informed about the relayer auto-claim.
  //   const processingFee = transaction.message?.processingFee.toString();
  //   if (processingFee && processingFee !== '0' && !alreadyInformedAboutClaim) {
  //     dispatch(
  //       'relayerAutoClaim',
  //       // TODO: this is a hack. The idea is to move all these
  //       //       functions outside of the component, where they
  //       //       make more sense. We don't need to repeat the same
  //       //       logic per transaction.
  //       async (informed) => {
  //         alreadyInformedAboutClaim = informed;
  //         await claim(transaction);
  //       },
  //     );
  //   } else {
  //     await claim(transaction);
  //   }
  // }

  async function transact(fn: TransactFn) {
    try {
      loading = true;
      const tx = await fn(transaction, $fromChain.id, $signer);

      pendingTransactions.add(tx, $signer, () =>
        successToast('Transaction completed!'),
      );

      successToast($_('toast.transactionSent'));

      // TODO: keep the MessageStatus as contract and use another way.
      transaction.status = MessageStatus.ClaimInProgress;
    } catch (e) {
      console.error(e);
      errorToast($_('toast.errorSendingTransaction'));
    } finally {
      loading = false;
    }
  }

  // TODO: web worker?
  function startInterval() {
    // TODO: what's going on here?
    return setInterval(async () => {
      processable = await isTransactionProcessable(transaction);

      const contract = new ethers.Contract(
        chains[transaction.toChainId].bridgeAddress,
        BridgeABI,
        providers[chains[transaction.toChainId].id],
      );

      if (transaction.receipt && transaction.receipt.status !== 1) {
        clearInterval(interval);
        return;
      }

      transaction.status = await contract.getMessageStatus(transaction.msgHash);

      if (transaction.status === MessageStatus.Failed) {
        if (transaction.message?.data !== '0x') {
          const srcTokenVaultContract = new ethers.Contract(
            tokenVaults[transaction.fromChainId],
            TokenVaultABI,
            providers[chains[transaction.fromChainId].id],
          );
          const { token, amount } = await srcTokenVaultContract.messageDeposits(
            transaction.msgHash,
          );
          if (token === ethers.constants.AddressZero && amount.eq(0)) {
            transaction.status = MessageStatus.FailedReleased;
          }
        } else {
          const srcBridgeContract = new ethers.Contract(
            chains[transaction.fromChainId].bridgeAddress,
            BridgeABI,
            providers[chains[transaction.fromChainId].id],
          );
          const isFailedMessageResolved =
            await srcBridgeContract.isEtherReleased(transaction.msgHash);
          if (isFailedMessageResolved) {
            transaction.status = MessageStatus.FailedReleased;
          }
        }
      }
      if (
        [MessageStatus.Done, MessageStatus.FailedReleased].includes(
          transaction.status,
        )
      )
        clearInterval(interval);
    }, 20 * 1000); // TODO: magic numbers. Config?
  }
</script>

<tr class="text-transaction-table">
  <td>
    <svelte:component this={txFromChain.icon} height={18} width={18} />
    <span class="ml-2 hidden md:inline-block">{txFromChain.name}</span>
  </td>
  <td>
    <svelte:component this={txToChain.icon} height={18} width={18} />
    <span class="ml-2 hidden md:inline-block">{txToChain.name}</span>
  </td>
  <td>
    {amount}
    {symbol ?? 'ETH'}
  </td>

  <td>
    <ButtonWithTooltip onClick={() => dispatch('tooltipClick')}>
      <span slot="buttonText">
        {#if !processable}
          Pending
        {:else if (!receipt && status === MessageStatus.New) || loading}
          <div class="inline-block">
            <Loading />
          </div>
        {:else if receipt && [MessageStatus.New, MessageStatus.ClaimInProgress].includes(status)}
          <Button
            type="accent"
            size="sm"
            on:click={() => transact(claimToken)}
            disabled={status === MessageStatus.ClaimInProgress}>
            Claim
          </Button>
        {:else if status === MessageStatus.Retriable}
          <Button type="accent" size="sm" on:click={() => transact(claimToken)}>
            Retry
          </Button>
        {:else if transaction.status === MessageStatus.Failed}
          <!-- todo: releaseToken() on src bridge with proof from destBridge-->
          <Button
            type="accent"
            size="sm"
            on:click={() => transact(releaseToken)}>
            Release
          </Button>
        {:else if status === MessageStatus.Done}
          <span class="border border-transparent p-0">Claimed</span>
        {:else if status === MessageStatus.FailedReleased}
          <span class="border border-transparent p-0">Released</span>
        {:else if receipt && receipt.status !== ReceiptStatus.Successful}
          <!-- TODO: make sure this is now respecting the correct flow -->
          <span class="border border-transparent p-0">Failed</span>
        {/if}
      </span>
    </ButtonWithTooltip>
  </td>

  <td>
    <button
      class="cursor-pointer inline-block"
      on:click={() => dispatch('transactionDetailsClick', transaction)}>
      <ArrowTopRightOnSquare />
    </button>
  </td>
</tr>

<style>
  td {
    padding: 1rem;
  }
</style>
