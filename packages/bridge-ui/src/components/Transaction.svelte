<script lang="ts">
  import type { BridgeTransaction } from "../domain/transactions";
  import { chains, CHAIN_MAINNET, CHAIN_TKO } from "../domain/chain";
  import type { Chain } from "../domain/chain";
  import Loader from "./icons/Loader.svelte";
  import TransactionsIcon from "./icons/Transactions.svelte";
  import { MessageStatus } from "../domain/message";
  import { ethers } from "ethers";
  import { activeBridge } from "../store/bridge";
  import { signer } from "../store/signer";
  import { pendingTransactions } from "../store/transactions";
  import { errorToast, successToast } from "../utils/toast";
  import { _ } from "svelte-i18n";
  import { switchEthereumChain } from "../utils/switchEthereumChain";
  import { ethereum } from "../store/ethereum";
  import {
    fromChain as fromChainStore,
    toChain as toChainStore,
  } from "../store/chain";
  import { token } from "../store/token";

  export let transaction: BridgeTransaction;

  export let fromChain: Chain;
  export let toChain: Chain;

  async function claim(bridgeTx: BridgeTransaction) {
    if (fromChain.id !== bridgeTx.message.destChainId.toNumber()) {
      const chain = chains[bridgeTx.message.destChainId.toNumber()];
      await switchEthereumChain($ethereum, chain);
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      await provider.send("eth_requestAccounts", []);

      fromChainStore.set(chain);
      if (chain === CHAIN_MAINNET) {
        toChainStore.set(CHAIN_TKO);
      } else {
        toChainStore.set(CHAIN_MAINNET);
      }
      signer.set(provider.getSigner());
    }

    try {
      const tx = await $activeBridge.Claim({
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
</script>

<div class="p-2">
  <div class="flex items-center justify-between text-xs">
    <div class="flex items-center">
      <svelte:component this={fromChain.icon} height={18} width={18} />
      <span class="ml-2">From {fromChain.name}</span>
    </div>
    <div class="flex items-center">
      <svelte:component this={toChain.icon} height={18} width={18} />
      <span class="ml-2">To {toChain.name}</span>
    </div>
  </div>
  <div class="px-1 py-2 flex items-center justify-between">
    {transaction.message.data === "0x"
      ? ethers.utils.formatEther(transaction.message.depositValue)
      : ethers.utils.formatUnits(transaction.amountInWei)}
    {transaction.message.data && transaction.message.data !== "0x"
      ? transaction.symbol
      : "ETH"}

    <span
      class="cursor-pointer inline-block"
      on:click={() =>
        window.open(
          `${fromChain.explorerUrl}/tx/${transaction.ethersTx.hash}`,
          "_blank"
        )}
    >
      <TransactionsIcon />
    </span>

    {#if !transaction.receipt && transaction.status === MessageStatus.New}
      <div class="animate-spin">
        <Loader />
      </div>
    {:else if transaction.receipt?.status === 1 && transaction.status === MessageStatus.New}
      <span
        class="cursor-pointer"
        on:click={async () => await claim(transaction)}
      >
        Claim
      </span>
    {:else if transaction.status === MessageStatus.Done}
      Claimed
    {/if}
  </div>
</div>
