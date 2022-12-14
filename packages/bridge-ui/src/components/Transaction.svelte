<script lang="ts">
  import type { BridgeTransaction } from "../domain/transactions";
  import { chains, CHAIN_MAINNET, CHAIN_TKO } from "../domain/chain";
  import type { Chain } from "../domain/chain";
  import Loader from "./icons/Loader.svelte";
  import TransactionsIcon from "./icons/Transactions.svelte";
  import { MessageStatus } from "../domain/message";
  import { ethers } from "ethers";
  import { bridges } from "../store/bridge";
  import { signer } from "../store/signer";
  import { pendingTransactions, transactions } from "../store/transactions";
  import { errorToast, successToast } from "../utils/toast";
  import { _ } from "svelte-i18n";
  import { switchEthereumChain } from "../utils/switchEthereumChain";
  import { ethereum } from "../store/ethereum";
  import {
    fromChain as fromChainStore,
    toChain as toChainStore,
  } from "../store/chain";
  import { BridgeType } from "../domain/bridge";

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
      <TransactionsIcon />
    </span>
  </td>

  <td>
    {#if !transaction.receipt && transaction.status === MessageStatus.New}
      <div class="animate-spin">
        <Loader />
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
  </td>
</tr>

<style>
  td {
    padding: 1rem;
  }
</style>
