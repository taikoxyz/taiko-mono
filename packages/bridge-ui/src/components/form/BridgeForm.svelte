<script lang="ts">
  import { _ } from "svelte-i18n";
  import { token } from "../../store/token";
  import { fromChain, toChain } from "../../store/chain";
  import {
    activeBridge,
    chainIdToBridgeAddress,
    bridgeType,
  } from "../../store/bridge";
  import { signer } from "../../store/signer";
  import { BigNumber, ethers, Signer } from "ethers";
  import { toast } from "@zerodevx/svelte-toast";
  import ArrowDown from "../icons/ArrowDown.svelte";
  import { CHAIN_MAINNET, CHAIN_TKO } from "../../domain/chain";
  import ProcessingFee from "./ProcessingFee.svelte";
  import type { Token } from "../../domain/token";
  import type { BridgeType } from "../../domain/bridge";
  import type { Chain } from "../../domain/chain";
  import { pendingTransactions } from "../../store/transactions";

  let amount: string;
  let btnDisabled: boolean = true;
  let requiresAllowance: boolean = true;

  $: isBtnDisabled($signer, amount, $token)
    .then((d) => (btnDisabled = d))
    .catch((e) => console.log(e));

  $: checkAllowance(amount, $token, $bridgeType, $fromChain, $signer)
    .then((a) => (requiresAllowance = a))
    .catch((e) => console.log(e));

  async function isBtnDisabled(signer: Signer, amount: string, token: Token) {
    if (!signer) return true;
    if (!amount) return true;
    if (!token) return true;
    if (requiresAllowance) return true;
    const balance = await signer.getBalance("latest");
    if (balance.lt(ethers.utils.parseUnits(amount, token.decimals)))
      return true;

    return false;
  }

  async function checkAllowance(
    amt: string,
    token: Token,
    bridgeType: BridgeType,
    fromChain: Chain,
    signer: Signer
  ) {
    const allowance = await $activeBridge.RequiresAllowance({
      amountInWei: amt
        ? ethers.utils.parseUnits(amt, token.decimals)
        : BigNumber.from(0),
      signer: signer,
      contractAddress: token.address,
      spenderAddress: $chainIdToBridgeAddress.get(fromChain.id),
    });

    return allowance;
  }

  async function approve() {
    try {
      if (!requiresAllowance)
        throw Error("does not require additional allowance");

      const tx = await $activeBridge.Approve({
        amountInWei: ethers.utils.parseUnits(amount, $token.decimals),
        signer: $signer,
        contractAddress: $token.address,
        spenderAddress: $chainIdToBridgeAddress.get($fromChain.id),
      });
      console.log("approved, waiting for confirmations ", tx);
      await $signer.provider.waitForTransaction(tx.hash, 3);

      pendingTransactions.update((store) => {
        store.push(tx);
        return store;
      });

      requiresAllowance = false;

      toast.push($_("toast.transactionSent"));
    } catch (e) {
      console.log(e);
      toast.push($_("toast.errorSendingTransaction"));
    }
  }

  async function bridge() {
    try {
      const tx = await $activeBridge.Bridge({
        amountInWei: ethers.utils.parseUnits(amount, $token.decimals),
        signer: $signer,
        tokenAddress: "",
        fromChainId: $fromChain.id,
        toChainId: $toChain.id,
        bridgeAddress: $chainIdToBridgeAddress.get($fromChain.id),
        processingFeeInWei: BigNumber.from(100),
        memo: "memo",
      });

      pendingTransactions.update((store) => {
        store.push(tx);
        return store;
      });

      toast.push($_("toast.transactionSent"));
    } catch (e) {
      console.log(e);
      toast.push($_("toast.errorSendingTransaction"));
    }
  }

  function toggleChains() {
    fromChain.update((val) =>
      val === CHAIN_MAINNET ? CHAIN_TKO : CHAIN_MAINNET
    );
    toChain.update((val) =>
      val === CHAIN_MAINNET ? CHAIN_TKO : CHAIN_MAINNET
    );
  }
</script>

<div class="form-control w-full">
  <label class="label" for="amount">
    <span class="label-text">{$_("home.from")}</span>
  </label>
  <label class="input-group relative rounded-lg overflow-hidden">
    <span
      class="bg-transparent border-transparent absolute top-0 left-0 h-full z-0"
      >{$fromChain.name}</span
    >
    <input
      type="number"
      step="0.01"
      placeholder="0.01"
      min="0"
      bind:value={amount}
      class="input input-primary focus:input-accent bg-dark-4 input-lg rounded-lg! w-full text-right pl-20 pr-12 z-1"
      name="amount"
    />
    <span
      class="pl-0 bg-transparent border-transparent absolute top-0 right-0 h-full"
      >ETH</span
    >
  </label>
</div>

<fieldset class="border border-b-0 border-dark-4 mt-10 mb-7">
  <legend class="h-0 flex items-center">
    <button class="btn btn-square btn-sm" on:click={toggleChains}>
      <ArrowDown />
    </button>
  </legend>
</fieldset>

<div class="form-control w-full">
  <label class="label" for="amount-to">
    <span class="label-text">{$_("home.to")}</span>
  </label>
  <label class="input-group relative rounded-lg overflow-hidden">
    <span
      class="bg-transparent border-transparent absolute top-0 left-0 h-full z-0"
      >{$toChain.name}</span
    >
    <input
      type="number"
      step="0.01"
      placeholder="0.01"
      min="0"
      bind:value={amount}
      class="input input-primary focus:input-accent bg-dark-4 input-lg rounded-lg! w-full text-right pl-20 pr-12 z-1"
      name="amount-to"
    />
    <span
      class="pl-0 bg-transparent border-transparent absolute top-0 right-0 h-full"
      >ETH</span
    >
  </label>
</div>
<ProcessingFee />

{#if !requiresAllowance}
  <button class="btn btn-accent" on:click={bridge} disabled={btnDisabled}>
    {$_("home.bridge")}
  </button>
{:else}
  <button class="btn btn-accent" on:click={approve} disabled={btnDisabled}>
    {$_("home.approve")}
  </button>
{/if}
