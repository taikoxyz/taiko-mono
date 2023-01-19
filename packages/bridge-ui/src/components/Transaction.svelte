<script lang="ts">
  import type { BridgeTransaction } from "../domain/transactions";
  import { chains, CHAIN_MAINNET, CHAIN_TKO } from "../domain/chain";
  import type { Chain } from "../domain/chain";
  import { ArrowTopRightOnSquare } from "svelte-heros-v2";
  import { MessageStatus } from "../domain/message";
  import { Contract, ethers } from "ethers";
  import { bridges } from "../store/bridge";
  import { signer } from "../store/signer";
  import {
    pendingTransactions,
    showTransactionDetails,
    showMessageStatusTooltip,
  } from "../store/transactions";
  import { errorToast, successToast } from "../utils/toast";
  import { _ } from "svelte-i18n";
  import {
    fromChain as fromChainStore,
    toChain as toChainStore,
  } from "../store/chain";
  import { BridgeType } from "../domain/bridge";
  import { onMount } from "svelte";

  import { LottiePlayer } from "@lottiefiles/svelte-lottie-player";
  import HeaderSync from "../constants/abi/HeaderSync";
  import { providers } from "../store/providers";
  import { fetchSigner, switchNetwork } from "@wagmi/core";
  import Tooltip from "./Tooltip.svelte";
  import Bridge from "../constants/abi/Bridge";
  import ButtonWithTooltip from "./ButtonWithTooltip.svelte";

  export let transaction: BridgeTransaction;

  export let fromChain: Chain;
  export let toChain: Chain;

  let processable: boolean = false;
  onMount(async () => {
    processable = await isProcessable();
  });

  async function claim(bridgeTx: BridgeTransaction) {
    if (fromChain.id !== bridgeTx.message.destChainId.toNumber()) {
      const chain = chains[bridgeTx.message.destChainId.toNumber()];
      await switchNetwork({
        chainId: chain.id,
      });
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      await provider.send("eth_requestAccounts", []);

      fromChainStore.set(chain);
      if (chain === CHAIN_MAINNET) {
        toChainStore.set(CHAIN_TKO);
      } else {
        toChainStore.set(CHAIN_MAINNET);
      }
      const wagmiSigner = await fetchSigner();
      signer.set(wagmiSigner);
    }

    try {
      const tx = await $bridges
        .get(bridgeTx.message.data === "0x" ? BridgeType.ETH : BridgeType.ERC20)
        .Claim({
          signer: $signer,
          message: bridgeTx.message,
          signal: bridgeTx.signal,
          destBridgeAddress:
            chains[bridgeTx.message.destChainId.toNumber()].bridgeAddress,
          srcBridgeAddress:
            chains[bridgeTx.message.srcChainId.toNumber()].bridgeAddress,
        });

      pendingTransactions.update((store) => {
        store.push(tx);
        return store;
      });

      successToast($_("toast.transactionSent"));
    } catch (e) {
      console.log(e);
      errorToast($_("toast.errorSendingTransaction"));
    }
  }

  async function isProcessable() {
    if (!transaction.receipt) return false;
    if (!transaction.message) return false;
    if (transaction.status !== MessageStatus.New) return true;

    const contract = new Contract(
      chains[transaction.message.destChainId.toNumber()].headerSyncAddress,
      HeaderSync,
      $providers.get(chains[transaction.message.destChainId.toNumber()].id)
    );

    const latestSyncedHeader = await contract.getLatestSyncedHeader();
    const srcBlock = await $providers
      .get(chains[transaction.message.srcChainId.toNumber()].id)
      .getBlock(latestSyncedHeader);
    return transaction.receipt.blockNumber <= srcBlock.number;
  }

  const interval = setInterval(async () => {
    processable = await isProcessable();
    const contract = new ethers.Contract(
      chains[transaction.toChainId].bridgeAddress,
      Bridge,
      $providers.get(chains[transaction.message.destChainId.toNumber()].id)
    );

    transaction.status = await contract.getMessageStatus(transaction.signal);
    transaction = transaction;
    if (transaction.status === MessageStatus.Done) clearInterval(interval);
  }, 20 * 1000);
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
    {transaction.message?.data === "0x"
      ? ethers.utils.formatEther(transaction.message.depositValue)
      : ethers.utils.formatUnits(transaction.amountInWei)}
    {transaction.message?.data !== "0x" ? transaction.symbol : "ETH"}
  </td>

  <td>
    <ButtonWithTooltip onClick={() => ($showMessageStatusTooltip = true)}>
      <span slot="buttonText">
    {#if !processable}
      Pending
    {:else if !transaction.receipt && transaction.status === MessageStatus.New}
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
          controlsLayout={[]}
        />
      </div>
        {:else if transaction.receipt && transaction.status === MessageStatus.New}
          <span
            class="cursor-pointer border rounded p-1"
            on:click={async () => await claim(transaction)}
          >
            Claim
          </span>
        {:else if transaction.status === MessageStatus.Retriable}
          <span
            class="cursor-pointer border rounded p-1"
            on:click={async () => await claim(transaction)}
          >
            Retry
          </span>
        {:else if transaction.status === MessageStatus.Failed}
          <!-- todo: releaseTokens() on src bridge with proof from destBridge-->
          Failed
        {:else if transaction.status === MessageStatus.Done}
          <span class="border border-transparent p-0">Claimed</span>
        {/if}
      </span>
    </ButtonWithTooltip>
  </td>

  <td>
    <span
      class="cursor-pointer inline-block"
      on:click={() => ($showTransactionDetails = transaction)}
    >
      <ArrowTopRightOnSquare />
    </span>
  </td>
</tr>

<style>
  td {
    padding: 1rem;
  }
</style>
