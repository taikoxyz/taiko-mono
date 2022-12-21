<script lang="ts">
  import type { BridgeTransaction } from "../domain/transactions";
  import { chains, CHAIN_MAINNET, CHAIN_TKO } from "../domain/chain";
  import type { Chain } from "../domain/chain";
  import { ArrowTopRightOnSquare } from "svelte-heros-v2";
  import { MessageStatus } from "../domain/message";
  import { Contract, ethers } from "ethers";
  import { bridges } from "../store/bridge";
  import { signer } from "../store/signer";
  import { pendingTransactions } from "../store/transactions";
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
  import TooltipModal from "./modals/TooltipModal.svelte";

  export let transaction: BridgeTransaction;

  export let fromChain: Chain;
  export let toChain: Chain;

  let tooltipOpen: boolean = false;
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
</script>

<tr>
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
    <span
      class="cursor-pointer inline-block"
      on:click={() =>
        window.open(
          `${fromChain.explorerUrl}/tx/${transaction.ethersTx.hash}`,
          "_blank"
        )}
    >
      <ArrowTopRightOnSquare />
    </span>
  </td>

  <td>
    {#if !processable}
      Pending...
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
        class="cursor-pointer"
        on:click={async () => await claim(transaction)}
      >
        Claim
      </span>
    {:else if transaction.status === MessageStatus.Retriable}
      <span
        class="cursor-pointer"
        on:click={async () => await claim(transaction)}
      >
        Retry
      </span>
    {:else if transaction.status === MessageStatus.Failed}
      <!-- todo: releaseTokens() on src bridge with proof from destBridge-->
      Failed
    {:else if transaction.status === MessageStatus.Done}
      Claimed
    {/if}
    <span class="inline-block" on:click={() => (tooltipOpen = true)}>
      <Tooltip />
    </span>
  </td>
</tr>

<TooltipModal title="Message Status" bind:isOpen={tooltipOpen}>
  <span slot="body">
    <div class="text-left">
      A bridge message will pass through various states:
      <br /><br />
      <ul class="list-disc ml-4">
        <li class="mb-2">
          <strong>Pending</strong>: Your asset is not ready to be bridged. Taiko
          A1 => Ethereum A1 bridging can take several hours before being ready.
          Ethereum A1 => Taiko A1 should be available to claim within minutes.
        </li>
        <li class="mb-2">
          <strong>Claimable</strong>: Your asset is ready to be claimed on the
          destination chain, and requires a transaction.
        </li>
        <li class="mb-2">
          <strong>Claimed</strong>: Your asset has finished bridging, and is
          available to you on the destination chain.
        </li>
        <li class="mb-2">
          <strong>Retry</strong>: The relayer has failed to process this
          message, and you must retry the processing yourself.
        </li>
        <li class="mb-2">
          <strong>Failed</strong>: Your bridged asset is unable to be processed,
          and is available to you on the source chain.
        </li>
      </ul>
    </div>
  </span>
</TooltipModal>

<style>
  td {
    padding: 1rem;
  }
</style>
