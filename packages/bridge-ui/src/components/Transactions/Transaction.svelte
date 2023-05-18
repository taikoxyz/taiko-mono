<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import {
    type BridgeTransaction,
    type TxUIStatus,
    TxExtendedStatus,
  } from '../../domain/transactions';
  import { ArrowTopRightOnSquare } from 'svelte-heros-v2';
  import { MessageStatus } from '../../domain/message';
  import { ethers, Contract } from 'ethers';
  import { signer } from '../../store/signer';
  import { pendingTransactions } from '../../store/transactions';
  import { _ } from 'svelte-i18n';
  import { fromChain } from '../../store/chain';
  import { BridgeType } from '../../domain/bridge';
  import { onDestroy, onMount } from 'svelte';
  import { errorToast, successToast } from '../Toast.svelte';
  import { bridgeABI, tokenVaultABI } from '../../constants/abi';
  import ButtonWithTooltip from '../ButtonWithTooltip.svelte';
  import { chains } from '../../chain/chains';
  import { providers } from '../../provider/providers';
  import { bridges } from '../../bridge/bridges';
  import { tokenVaults } from '../../vault/tokenVaults';
  import { isOnCorrectChain } from '../../utils/isOnCorrectChain';
  import Button from '../buttons/Button.svelte';
  import { selectChain } from '../../utils/selectChain';
  import type { NoticeOpenArgs } from '../../domain/modal';
  import { isTransactionProcessable } from '../../utils/isTransactionProcessable';
  import { getLogger } from '../../utils/logger';
  import { isETHByMessage } from '../../utils/isETHByMessage';
  import Loading from '../Loading.svelte';
  import { isEthOrTokenReleased } from '../../utils/isEthOrTokenReleased';

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
    // If we want reactivity on props change, we need to
    // create a new object, otherwise svelte won't detect
    transaction = { ...transaction, status };
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
        bridgeTx.toChainId,
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

      const isEth = bridgeTx.message?.data === '0x' || !bridgeTx.message?.data;
      const bridgeType = isEth ? BridgeType.ETH : BridgeType.ERC20;
      const bridge = bridges[bridgeType];

      log(`Claiming ${bridgeType} for transaction`, bridgeTx);

      const tx = await bridge.Claim({
        signer: $signer,
        message: bridgeTx.message,
        msgHash: bridgeTx.msgHash,
        destBridgeAddress: chains[bridgeTx.toChainId].bridgeAddress,
        srcBridgeAddress: chains[bridgeTx.fromChainId].bridgeAddress,
      });

      successToast($_('toast.transactionSent'));

      // TODO: the problem here is: what if this takes some time and the user
      //       closes the page? We need to keep track of this state, storage?
      setTxStatus(TxExtendedStatus.Claiming);

      await pendingTransactions.add(tx, $signer);

      // At this point the transaction is already DONE, but we
      // still don't have it until the polling picks up the new state.
      // We change it manually
      setTxStatus(MessageStatus.Done);

      successToast($_('toast.transactionCompleted'));
    } catch (error) {
      console.error(error);
      errorToast($_('toast.errorSendingTransaction'));
    } finally {
      loading = false;
    }
  }

  // TODO: move outside of component
  async function releaseTokens(bridgeTx: BridgeTransaction) {
    try {
      loading = true;
      if (txFromChain.id !== bridgeTx.fromChainId) {
        const chain = chains[bridgeTx.fromChainId];
        await selectChain(chain);
      }

      // confirm after switch chain that it worked.
      if (!(await isOnCorrectChain($signer, bridgeTx.fromChainId))) {
        errorToast('You are connected to the wrong chain in your wallet');
        return;
      }

      const bridge =
        bridges[
          isETHByMessage(bridgeTx.message) ? BridgeType.ETH : BridgeType.ERC20
        ];

      const tx = await bridge.ReleaseTokens({
        signer: $signer,
        message: bridgeTx.message,
        msgHash: bridgeTx.msgHash,
        destBridgeAddress: chains[bridgeTx.toChainId].bridgeAddress,
        srcBridgeAddress: chains[bridgeTx.fromChainId].bridgeAddress,
        destProvider: providers[bridgeTx.toChainId],
        srcTokenVaultAddress: tokenVaults[bridgeTx.fromChainId],
      });

      successToast($_('toast.transactionSent'));

      // TODO: we need to test this
      setTxStatus(TxExtendedStatus.Releasing);

      await pendingTransactions.add(tx, $signer);

      setTxStatus(TxExtendedStatus.Released);

      successToast($_('toast.transactionCompleted'));
    } catch (error) {
      console.error(error);
      errorToast($_('toast.errorSendingTransaction'));
    } finally {
      loading = false;
    }
  }

  function isTransactionDone(bridgeTx: BridgeTransaction) {
    return (
      bridgeTx.status === MessageStatus.Done ||
      bridgeTx.status === TxExtendedStatus.Released
    );
  }

  // TODO: move this logic into a Web Worker
  // TODO: handle errors here
  function startInterval() {
    return setInterval(async () => {
      processable = await isTransactionProcessable(transaction);

      const { toChainId, receipt, msgHash } = transaction;

      if (receipt && receipt.status !== 1) {
        clearInterval(interval);
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

      if (msgStatus === MessageStatus.Failed) {
        const isFailedMessageResolved = await isEthOrTokenReleased(transaction);

        if (isFailedMessageResolved) {
          setTxStatus(TxExtendedStatus.Released);
        }
      }

      if (isTransactionDone(transaction)) {
        log('Stop polling for transaction', transaction);
        clearInterval(interval);
      }
    }, 20 * 1000); // TODO: magic number. Config?
  }

  onMount(async () => {
    processable = await isTransactionProcessable(transaction);

    if (!isTransactionDone(transaction)) {
      // We only want this polling to happen if the transaction is not done yet
      log('Starting polling for transaction', transaction);

      interval = startInterval();
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

  <td>
    <ButtonWithTooltip onClick={() => dispatch('tooltipStatus')}>
      <span slot="buttonText">
        {#if !processable}
          Pending
        {:else if loading || (!transaction.receipt && transaction.status === MessageStatus.New)}
          <div class="inline-block">
            <Loading />
          </div>
        {:else if transaction.receipt && [MessageStatus.New, TxExtendedStatus.Claiming].includes(transaction.status)}
          <!-- 
            TODO: we need some destructuring here. 
                  We keep on accessing transaction props
                  over and over again.
          -->
          <Button
            type="accent"
            size="sm"
            on:click={onClaimClick}
            disabled={transaction.status === TxExtendedStatus.Claiming}>
            Claim
          </Button>
        {:else if transaction.status === MessageStatus.Retriable}
          <Button type="accent" size="sm" on:click={onClaimClick}>Retry</Button>
        {:else if transaction.status === MessageStatus.Failed}
          <!-- todo: releaseTokens() on src bridge with proof from destBridge-->
          <Button
            type="accent"
            size="sm"
            on:click={async () => await releaseTokens(transaction)}>
            Release
          </Button>
        {:else if transaction.status === MessageStatus.Done}
          <span class="border border-transparent p-0">Claimed</span>
        {:else if transaction.status === TxExtendedStatus.Released}
          <span class="border border-transparent p-0">Released</span>
        {:else if transaction.receipt && transaction.receipt.status !== 1}
          <!-- TODO: make sure this is now respecting the correct flow -->
          <!-- TODO: do we still need this? -->
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
