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
  import type { Token } from "../../domain/token";
  import type { BridgeType } from "../../domain/bridge";
  import type { Chain } from "../../domain/chain";

  let amount: string;
  let requiresAllowance: boolean = true;
  let btnDisabled: boolean = true;

  $: isBtnDisabled($signer, amount)
    .then((d) => (btnDisabled = d))
    .catch((e) => console.log(e));

  $: checkAllowance(amount, $token, $bridgeType, $fromChain, $signer)
    .then((a) => (requiresAllowance = a))
    .catch((e) => console.log(e));

  async function checkAllowance(
    amt: string,
    token: Token,
    bridgeType: BridgeType,
    fromChain: Chain,
    signer: Signer
  ) {
    if (!signer || !amt || !token || !fromChain) return true;

    return await $activeBridge.RequiresAllowance({
      amountInWei: amt
        ? ethers.utils.parseUnits(amt, token.decimals)
        : BigNumber.from(0),
      signer: signer,
      contractAddress: token.address,
      spenderAddress: $chainIdToBridgeAddress.get(fromChain.id),
    });
  }

  async function isBtnDisabled(signer: Signer, amount: string) {
    if (!signer) return true;
    if (!amount) return true;
    if (requiresAllowance) return true;
    const balance = await signer.getBalance("latest");
    if (balance.lt(ethers.utils.parseUnits(amount, $token.decimals)))
      return true;

    return false;
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
      $signer.provider.waitForTransaction(tx.hash, 3);

      requiresAllowance = false;

      toast.push($_("toast.transactionSent"));
    } catch (e) {
      console.log(e);
      toast.push($_("toast.errorSendingTransaction"));
    }
  }

  async function bridge() {
    try {
      if (requiresAllowance) throw Error("requires additional allowance");

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

      console.log("bridged", tx);
      toast.push($_("toast.transactionSent"));
    } catch (e) {
      console.log(e);
      toast.push($_("toast.errorSendingTransaction"));
    }
  }
</script>

<div class="form-control">
  <label class="label">
    <span class="label-text">{$_("home.from")}</span>
  </label>
  <label class="input-group">
    <input
      type="text"
      placeholder="0.01"
      bind:value={amount}
      class="input input-bordered"
    />
    <span>{$token.symbol}</span>
  </label>
</div>

<div class="form-control">
  <label class="label">
    <span class="label-text">{$_("home.to")}</span>
  </label>
  <label class="input-group">
    <input
      type="text"
      placeholder="0.01"
      bind:value={amount}
      class="input input-bordered"
    />
    <span>{$token.symbol}</span>
  </label>
</div>

{#if requiresAllowance}
  <button
    class="btn btn-accent"
    on:click={async () => await bridge()}
    disabled={btnDisabled}
  >
    {$_("home.bridge")}
  </button>
{:else}
  <button
    class="btn btn-accent"
    on:click={async () => await approve()}
    disabled={btnDisabled}
  >
    {$_("home.bridge")}
  </button>
{/if}
