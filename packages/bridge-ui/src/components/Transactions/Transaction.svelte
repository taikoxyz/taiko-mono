<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import type { BridgeTransaction } from '../../domain/transaction';
  import { ArrowTopRightOnSquare } from 'svelte-heros-v2';
  import { MessageStatus } from '../../domain/message';
  import { Contract, ethers } from 'ethers';
  import { signer } from '../../store/signer';
  import { pendingTransactions } from '../../store/transaction';
  import { _ } from 'svelte-i18n';
  import { fromChain } from '../../store/chain';
  import { BridgeType } from '../../domain/bridge';
  import { onDestroy, onMount } from 'svelte';

  import { LottiePlayer } from '@lottiefiles/svelte-lottie-player';
  import { errorToast, successToast } from '../Toast.svelte';
  import HeaderSyncABI from '../../constants/abi/HeaderSync';
  import BridgeABI from '../../constants/abi/Bridge';
  import ButtonWithTooltip from '../ButtonWithTooltip.svelte';
  import TokenVaultABI from '../../constants/abi/TokenVault';
  import { chains } from '../../chain/chains';
  import { providers } from '../../provider/providers';
  import { bridges } from '../../bridge/bridges';
  import { tokenVaults } from '../../vault/tokenVaults';
  import { isOnCorrectChain } from '../../utils/isOnCorrectChain';
  import Button from '../buttons/Button.svelte';
  import { switchChainAndSetSigner } from '../../utils/switchChainAndSetSigner';
  import { isTransactionProcessable } from '../../utils/isTransactionProcessable';

  export let transaction: BridgeTransaction;

  const dispatch = createEventDispatcher<{
    tooltipClick: void;
    insufficientBalance: void;
    transactionDetailsClick: BridgeTransaction;
    relayerAutoClaim: (informed: boolean) => Promise<void>;
  }>();

  let loading: boolean;
  let processable: boolean = false;
  let interval: ReturnType<typeof setInterval>;
  let txToChain = chains[transaction.toChainId];
  let txFromChain = chains[transaction.fromChainId];
  let alreadyInformedAboutClaim = false;

  onMount(async () => {
    processable = await isTransactionProcessable(transaction);
    interval = startInterval();
  });

  onDestroy(() => {
    if (interval) {
      clearInterval(interval);
    }
  });

  async function onClaimClick() {
    // Has the user sent processing fees?. We also check if the user
    // has already been informed about the relayer auto-claim.
    const processingFee = transaction.message?.processingFee.toString();
    if (processingFee && processingFee !== '0' && !alreadyInformedAboutClaim) {
      dispatch(
        'relayerAutoClaim',
        // TODO: this is a hack. The idea is to move all these
        //       functions outside of the component, where they
        //       make more sense. We don't need to repeat the same
        //       logic per transaction.
        async (informed) => {
          alreadyInformedAboutClaim = informed;
          await claim(transaction);
        },
      );
    } else {
      await claim(transaction);
    }
  }

  // TODO: move outside of component
  async function claim(bridgeTx: BridgeTransaction) {
    try {
      loading = true;
      // if the current "from chain", ie, the chain youre connected to, is not the destination
      // of the bridge transaction, we need to change chains so your wallet is pointed
      // to the right network.
      if ($fromChain.id !== bridgeTx.toChainId) {
        const chain = chains[bridgeTx.toChainId];
        await switchChainAndSetSigner(chain);
      }

      // confirm after switch chain that it worked.
      if (!(await isOnCorrectChain($signer, bridgeTx.toChainId))) {
        errorToast('You are connected to the wrong chain in your wallet');
        return;
      }

      // For now just handling this case for when the user has near 0 balance during their first bridge transaction to L2
      // TODO: estimate Claim transaction
      const userBalance = await $signer.getBalance('latest');
      if (!userBalance.gt(ethers.utils.parseEther('0.0001'))) {
        dispatch('insufficientBalance');
        return;
      }

      const tx = await bridges[
        bridgeTx.message?.data === '0x' || !bridgeTx.message?.data
          ? BridgeType.ETH
          : BridgeType.ERC20
      ].claim({
        signer: $signer,
        message: bridgeTx.message,
        msgHash: bridgeTx.msgHash,
        destBridgeAddress: chains[bridgeTx.toChainId].bridgeAddress,
        srcBridgeAddress: chains[bridgeTx.fromChainId].bridgeAddress,
      });

      pendingTransactions.add(tx, () => successToast('Transaction completed!'));

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

  // TODO: move outside of component
  async function releaseTokens(bridgeTx: BridgeTransaction) {
    try {
      loading = true;
      if ($fromChain.id !== bridgeTx.fromChainId) {
        const chain = chains[bridgeTx.fromChainId];
        await switchChainAndSetSigner(chain);
      }

      // confirm after switch chain that it worked.
      if (!(await isOnCorrectChain($signer, bridgeTx.fromChainId))) {
        errorToast('You are connected to the wrong chain in your wallet');
        return;
      }

      const tx = await bridges[
        bridgeTx.message?.data === '0x' || !bridgeTx.message?.data
          ? BridgeType.ETH
          : BridgeType.ERC20
      ].releaseTokens({
        signer: $signer,
        message: bridgeTx.message,
        msgHash: bridgeTx.msgHash,
        destBridgeAddress: chains[bridgeTx.toChainId].bridgeAddress,
        srcBridgeAddress: chains[bridgeTx.fromChainId].bridgeAddress,
        destProvider: providers[bridgeTx.toChainId],
        srcTokenVaultAddress: tokenVaults[bridgeTx.fromChainId],
      });

      pendingTransactions.add(tx, () => successToast('Transaction completed!'));

      successToast($_('toast.transactionSent'));
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
    <!-- TODO: function to check is we're dealing with ETH or ERC20? -->
    {transaction.message &&
    (transaction.message?.data === '0x' || !transaction.message?.data)
      ? ethers.utils.formatEther(
          transaction.message?.depositValue.eq(0)
            ? transaction.message?.callValue.toString()
            : transaction.message?.depositValue,
        )
      : ethers.utils.formatUnits(transaction.amountInWei)}
    {transaction.symbol ?? 'ETH'}
  </td>

  <td>
    <ButtonWithTooltip onClick={() => dispatch('tooltipClick')}>
      <span slot="buttonText">
        {#if !processable}
          Pending
        {:else if (!transaction.receipt && transaction.status === MessageStatus.New) || loading}
          <div class="inline-block">
            <LottiePlayer
              src="/lottie/loader.json"
              autoplay={true}
              loop={true}
              controls={false}
              renderer="svg"
              background="transparent"
              height={26}
              width={26}
              controlsLayout={[]} />
          </div>
        {:else if transaction.receipt && [MessageStatus.New, MessageStatus.ClaimInProgress].includes(transaction.status)}
          <!-- 
            TODO: we need some destructuring here. 
                  We keep on accessing transaction props
                  over and over again.
          -->
          <Button
            type="accent"
            size="sm"
            on:click={onClaimClick}
            disabled={transaction.status === MessageStatus.ClaimInProgress}>
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
        {:else if transaction.status === MessageStatus.FailedReleased}
          <span class="border border-transparent p-0">Released</span>
        {:else if transaction.receipt && transaction.receipt.status !== 1}
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
