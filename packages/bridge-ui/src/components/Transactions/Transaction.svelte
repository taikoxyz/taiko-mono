<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import {
    type BridgeTransaction,
    type TxUIStatus,
    TxExtendedStatus,
  } from '../../domain/transaction';
  import { ArrowTopRightOnSquare } from 'svelte-heros-v2';
  import { MessageStatus } from '../../domain/message';
  import { ethers, Contract } from 'ethers';
  import { signer } from '../../store/signer';
  import { pendingTransactions } from '../../store/transactions';
  import { _ } from 'svelte-i18n';
  import { fromChain } from '../../store/chain';
  import { BridgeType } from '../../domain/bridge';
  import { onDestroy, onMount } from 'svelte';
  import {
    errorToast,
    successToast,
    warningToast,
  } from '../NotificationToast.svelte';
  import { bridgeABI } from '../../constants/abi';
  import ButtonWithTooltip from '../ButtonWithTooltip.svelte';
  import { chains } from '../../chain/chains';
  import { providers } from '../../provider/providers';
  import { bridges } from '../../bridge/bridges';
  import { tokenVaults } from '../../vault/tokenVaults';
  import { isOnCorrectChain } from '../../utils/isOnCorrectChain';
  import Button from '../Button.svelte';
  import { selectChain } from '../../utils/selectChain';
  import type { NoticeOpenArgs } from '../../domain/modal';
  import { isTransactionProcessable } from '../../utils/isTransactionProcessable';
  import { getLogger } from '../../utils/logger';
  import { isETHByMessage } from '../../utils/isETHByMessage';
  import Loading from '../Loading.svelte';

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
  let txToChain = chains[transaction.toChainId];
  let txFromChain = chains[transaction.fromChainId];
  let alreadyInformedAboutClaim = false;

  function setTxStatus(status: TxUIStatus) {
    transaction.status = status;
    // If we want reactivity on props change, we need to reassign (Svelte thing)
    transaction = transaction;
  }

  async function onClaimClick() {
    // Has the user sent processing fees?. We also check if the user
    // has already been informed about the relayer auto-claim.
    const processingFee = transaction.message?.processingFee.toString();
    if (processingFee && processingFee !== '0' && !alreadyInformedAboutClaim) {
      dispatch('claimNotice', {
        name: transaction.hash,
        onConfirm: async (informed: true) => {
          alreadyInformedAboutClaim = informed;
          await claim(transaction);
        },
      });
    } else {
      await claim(transaction);
    }
  }

  // TODO: move outside of component
  async function claim(bridgeTx: BridgeTransaction) {
    try {
      loading = true;

      // If the current "from chain", ie, the chain youre connected to, is not the destination
      // of the bridge transaction, we need to change chains so your wallet is pointed
      // to the right network.
      if ($fromChain.id !== bridgeTx.toChainId) {
        const chain = chains[bridgeTx.toChainId];
        await selectChain(chain);
      }

      // Confirm after switch chain that it worked
      const isCorrectChain = await isOnCorrectChain(
        $signer,
        bridgeTx.toChainId, // we claim on the destination chain
      );

      if (!isCorrectChain) {
        errorToast('You are connected to the wrong chain in your wallet');
        return;
      }

      // For now just handling this case for when the user has near 0 balance
      // during their first bridge transaction to L2
      // TODO: estimate Claim transaction
      const userBalance = await $signer.getBalance('latest');
      if (!userBalance.gt(ethers.utils.parseEther('0.0001'))) {
        // TODO: magic number 0.0001. Config?
        dispatch('insufficientBalance');
        return;
      }

      const bridgeType = isETHByMessage(bridgeTx.message)
        ? BridgeType.ETH
        : BridgeType.ERC20;
      const bridge = bridges[bridgeType];

      log(`Claiming ${bridgeType} for transaction`, bridgeTx);

      const tx = await bridge.Claim({
        signer: $signer,
        message: bridgeTx.message,
        msgHash: bridgeTx.msgHash,
        destBridgeAddress: chains[bridgeTx.toChainId].bridgeAddress,
        srcBridgeAddress: chains[bridgeTx.fromChainId].bridgeAddress,
      });

      successToast('Transaction sent to claim your funds.');

      // TODO: the problem here is: what if this takes some time and the user
      //       closes the page? We need to keep track of this state, storage?
      setTxStatus(TxExtendedStatus.Claiming);

      await pendingTransactions.add(tx, $signer);

      // We're done here, no need to poll anymore since we've claimed manually
      stopPolling();

      // Could happen that the poller has picked up the change of status
      // already, also it might have been claimed by the relayer. In that
      // case we don't want to show the success toast again.
      if (transaction.status !== MessageStatus.Done) {
        setTxStatus(MessageStatus.Done);
        successToast(
          `<strong>Transaction completed!</strong><br />Your funds have been successfully claimed on ${$fromChain.name} chain.`,
        );
      }
    } catch (error) {
      console.error(error);

      const headerError = '<strong>Failed to claim funds</strong>';
      if (error.cause?.status === 0) {
        const explorerUrl = `${$fromChain.explorerUrl}/tx/${error.cause.transactionHash}`;
        const htmlLink = `<a href="${explorerUrl}" target="_blank"><b><u>here</u></b></a>`;
        errorToast(
          `${headerError}<br />Click ${htmlLink} to see more details on the explorer.`,
          true, // dismissible
        );
      } else if (
        [error.code, error.cause?.code].includes(ethers.errors.ACTION_REJECTED)
      ) {
        warningToast(`Transaction has been rejected.`);
      } else {
        errorToast(`${headerError}<br />Try again later.`);
      }
    } finally {
      loading = false;
    }
  }

  // TODO: move outside of component
  async function releaseTokens(bridgeTx: BridgeTransaction) {
    try {
      loading = true;

      if ($fromChain.id !== bridgeTx.fromChainId) {
        const chain = chains[bridgeTx.fromChainId];
        await selectChain(chain);
      }

      // Confirm after switch chain that it worked
      const isCorrectChain = await isOnCorrectChain(
        $signer,
        bridgeTx.fromChainId, // we release on the source chain
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

      const tx = await bridge.ReleaseTokens({
        signer: $signer,
        message: bridgeTx.message,
        msgHash: bridgeTx.msgHash,
        destBridgeAddress: chains[bridgeTx.toChainId].bridgeAddress,
        srcBridgeAddress: chains[bridgeTx.fromChainId].bridgeAddress,
        destProvider: providers[bridgeTx.toChainId],
        srcTokenVaultAddress: tokenVaults[bridgeTx.fromChainId],
      });

      successToast('Transaction sent to release your funds.');

      // TODO: storage?
      setTxStatus(TxExtendedStatus.Releasing);

      await pendingTransactions.add(tx, $signer);

      setTxStatus(TxExtendedStatus.Released);

      successToast(
        `<strong>Transaction completed!</strong><br />Your funds have been successfully released back to ${$fromChain.name} chain.`,
      );
    } catch (error) {
      console.error(error);

      const headerError = '<strong>Failed to release funds</strong>';
      if (error.cause?.status === 0) {
        const explorerUrl = `${$fromChain.explorerUrl}/tx/${error.cause.transactionHash}`;
        const htmlLink = `<a href="${explorerUrl}" target="_blank"><b><u>here</u></b></a>`;
        errorToast(
          `${headerError}<br />Click ${htmlLink} to see more details on the explorer.`,
          true, // dismissible
        );
      } else if (
        [error.code, error.cause?.code].includes(ethers.errors.ACTION_REJECTED)
      ) {
        warningToast(`Transaction has been rejected.`);
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

        const { toChainId, receipt, msgHash, status } = transaction;

        // It could happen that the transaction has been claimed manually
        // and by the time we poll it's already done, in which case we
        // stop polling.
        if (
          (!receipt && receipt.status == 0) ||
          status === MessageStatus.Done
        ) {
          stopPolling();
          return;
        }

        const destChain = chains[toChainId];
        const destProvider = providers[toChainId];

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
          successToast($_('toast.fundsClaimed'));
          stopPolling();
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
    {isETHByMessage(transaction.message)
      ? ethers.utils.formatEther(
          transaction.message.depositValue.eq(0)
            ? transaction.message.callValue.toString()
            : transaction.message.depositValue,
        )
      : ethers.utils.formatUnits(transaction.amountInWei)}
    {transaction.symbol ?? 'ETH'}
  </td>

  <!-- 
    TODO: I'm not quite sure about the user of transaction.receipt here.
          I don't even think we would get to this point if the transaction
          had an issue while sending it. We would've got an error before, 
          and no transaction would've been created here.
  -->

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
          <Button type="accent" size="sm" on:click={onClaimClick}>
            {$_('transaction.claim')}
          </Button>
        {:else if transaction.status === MessageStatus.Retriable}
          <Button type="accent" size="sm" on:click={onClaimClick}>
            {$_('transaction.retry')}
          </Button>
        {:else if transaction.status === MessageStatus.Done}
          <span class="border border-transparent p-0">
            {$_('transaction.claimed')}
          </span>
        {:else if transaction.status === MessageStatus.Failed}
          <Button
            type="accent"
            size="sm"
            on:click={async () => await releaseTokens(transaction)}>
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
