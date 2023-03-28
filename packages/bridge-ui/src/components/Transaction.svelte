<script lang="ts">
  import type { BridgeTransaction } from '../domain/transactions';
  import type { Chain } from '../domain/chain';
  import { ArrowTopRightOnSquare } from 'svelte-heros-v2';
  import { MessageStatus } from '../domain/message';
  import { Contract, ethers } from 'ethers';
  import { signer } from '../store/signer';
  import { pendingTransactions } from '../store/transactions';
  import { _ } from 'svelte-i18n';
  import {
    fromChain as fromChainStore,
    toChain as toChainStore,
  } from '../store/chain';
  import { BridgeType } from '../domain/bridge';
  import { onDestroy, onMount } from 'svelte';

  import { LottiePlayer } from '@lottiefiles/svelte-lottie-player';
  import { errorToast, successToast } from './Toast.svelte';
  import HeaderSyncABI from '../constants/abi/HeaderSync';
  import { fetchSigner, switchNetwork } from '@wagmi/core';
  import BridgeABI from '../constants/abi/Bridge';
  import ButtonWithTooltip from './ButtonWithTooltip.svelte';
  import TokenVaultABI from '../constants/abi/TokenVault';
  import { chains, mainnetChain, taikoChain } from '../chain/chains';
  import { providers } from '../provider/providers';
  import { bridges } from '../bridge/bridges';
  import { tokenVaults } from '../vault/tokenVaults';
  import { isOnCorrectChain } from '../utils/isOnCorrectChain';

  export let transaction: BridgeTransaction;
  export let fromChain: Chain;
  export let toChain: Chain;

  export let onTooltipClick: (showInsufficientBalanceMessage: boolean) => void;
  export let onShowTransactionDetailsClick: () => void;

  let loading: boolean;

  let processable: boolean = false;
  let interval: ReturnType<typeof setInterval>;

  onMount(async () => {
    processable = await isProcessable();
    interval = startInterval();
  });

  onDestroy(() => {
    if (interval) {
      clearInterval(interval);
    }
  });

  async function switchChainAndSetSigner(chain: Chain) {
    await switchNetwork({
      chainId: chain.id,
    });
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    await provider.send('eth_requestAccounts', []);

    fromChainStore.set(chain);
    if (chain === mainnetChain) {
      toChainStore.set(taikoChain);
    } else {
      toChainStore.set(mainnetChain);
    }
    const wagmiSigner = await fetchSigner();
    signer.set(wagmiSigner);
  }

  async function claim(bridgeTx: BridgeTransaction) {
    try {
      loading = true;
      // if the current "from chain", ie, the chain youre connected to, is not the destination
      // of the bridge transaction, we need to change chains so your wallet is pointed
      // to the right network.
      if ($fromChainStore.id !== bridgeTx.toChainId) {
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
        onTooltipClick(true);
        return;
      }

      const tx = await bridges[
        bridgeTx.message?.data === '0x' || !bridgeTx.message?.data
          ? BridgeType.ETH
          : BridgeType.ERC20
      ].Claim({
        signer: $signer,
        message: bridgeTx.message,
        msgHash: bridgeTx.msgHash,
        destBridgeAddress: chains[bridgeTx.toChainId].bridgeAddress,
        srcBridgeAddress: chains[bridgeTx.fromChainId].bridgeAddress,
      });

      pendingTransactions.update((store) => {
        store.push(tx);
        return store;
      });

      successToast($_('toast.transactionSent'));
      transaction.status = MessageStatus.ClaimInProgress;
    } catch (e) {
      console.error(e);
      errorToast($_('toast.errorSendingTransaction'));
    } finally {
      loading = false;
    }
  }

  async function releaseTokens(bridgeTx: BridgeTransaction) {
    try {
      loading = true;
      if (fromChain.id !== bridgeTx.fromChainId) {
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
      ].ReleaseTokens({
        signer: $signer,
        message: bridgeTx.message,
        msgHash: bridgeTx.msgHash,
        destBridgeAddress: chains[bridgeTx.toChainId].bridgeAddress,
        srcBridgeAddress: chains[bridgeTx.fromChainId].bridgeAddress,
        destProvider: providers[bridgeTx.toChainId],
        srcTokenVaultAddress: tokenVaults[bridgeTx.fromChainId],
      });

      pendingTransactions.update((store) => {
        store.push(tx);
        return store;
      });

      successToast($_('toast.transactionSent'));
    } catch (e) {
      console.error(e);
      errorToast($_('toast.errorSendingTransaction'));
    } finally {
      loading = false;
    }
  }

  async function isProcessable() {
    if (!transaction.receipt) return false;
    if (!transaction.message) return false;
    if (transaction.status !== MessageStatus.New) return true;

    const contract = new Contract(
      chains[transaction.toChainId].headerSyncAddress,
      HeaderSyncABI,
      providers[chains[transaction.toChainId].id],
    );

    const latestSyncedHeader = await contract.getLatestSyncedHeader();
    const srcBlock = await providers[
      chains[transaction.fromChainId].id
    ].getBlock(latestSyncedHeader);

    return transaction.receipt.blockNumber <= srcBlock.number;
  }

  function startInterval() {
    return setInterval(async () => {
      processable = await isProcessable();
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
    }, 20 * 1000);
  }
</script>

<tr class="text-transaction-table">
  <td>
    <svelte:component this={fromChain.icon} height={18} width={18} />
    <span class="ml-2 hidden md:inline-block">{fromChain.name}</span>
  </td>
  <td>
    <svelte:component this={toChain.icon} height={18} width={18} />
    <span class="ml-2 hidden md:inline-block">{toChain.name}</span>
  </td>
  <td>
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
    <ButtonWithTooltip onClick={() => onTooltipClick(false)}>
      <span slot="buttonText">
        {#if transaction.receipt && transaction.receipt.status !== 1}
          <span class="border border-transparent p-0">Failed</span>
        {:else if !processable}
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
          <button
            class="cursor-pointer border rounded p-1 btn btn-sm border-white disabled:border-gray-800"
            on:click={async () => await claim(transaction)}
            disabled={transaction.status === MessageStatus.ClaimInProgress}>
            Claim
          </button>
        {:else if transaction.status === MessageStatus.Retriable}
          <button
            class="cursor-pointer border rounded p-1 btn btn-sm border-white"
            on:click={async () => await claim(transaction)}>
            Retry
          </button>
        {:else if transaction.status === MessageStatus.Failed}
          <!-- todo: releaseTokens() on src bridge with proof from destBridge-->
          <button
            class="cursor-pointer border rounded p-1 btn btn-sm border-white"
            on:click={async () => await releaseTokens(transaction)}>
            Release
          </button>
        {:else if transaction.status === MessageStatus.Done}
          <span class="border border-transparent p-0">Claimed</span>
        {:else if transaction.status === MessageStatus.FailedReleased}
          <span class="border border-transparent p-0">Released</span>
        {/if}
      </span>
    </ButtonWithTooltip>
  </td>

  <td>
    <button
      class="cursor-pointer inline-block"
      on:click={onShowTransactionDetailsClick}>
      <ArrowTopRightOnSquare />
    </button>
  </td>
</tr>

<style>
  td {
    padding: 1rem;
  }
</style>
