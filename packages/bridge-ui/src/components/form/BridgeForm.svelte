<script lang="ts">
  import { _ } from "svelte-i18n";
  import { token } from "../../store/token";
  import { fromChain, toChain } from "../../store/chain";
  import { activeBridge, chainIdToBridgeAddress } from "../../store/bridge";
  import { signer } from "../../store/signer";
  import { BigNumber, ethers, Signer } from "ethers";
  import { toast } from "@zerodevx/svelte-toast";
  import ArrowDown from "../icons/ArrowDown.svelte";
  import { CHAIN_MAINNET, CHAIN_TKO } from "../../domain/chain";

  let amount: string;
  let btnDisabled: boolean = true;

  $: isBtnDisabled($signer, amount)
    .then((d) => (btnDisabled = d))
    .catch((e) => console.log(e));

  async function isBtnDisabled(signer: Signer, amount: string) {
    if (!signer) return true;
    if (!amount) return true;
    const balance = await signer.getBalance("latest");
    if (balance.lt(ethers.utils.parseUnits(amount, $token.decimals)))
      return true;

    return false;
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

      console.log("bridged", tx);
      toast.push($_("toast.transactionSent"));
    } catch (e) {
      console.log(e);
      toast.push($_("toast.errorSendingTransaction"));
    }
  }

  function toggleChains() {
    fromChain.update(val => val === CHAIN_MAINNET ? CHAIN_TKO : CHAIN_MAINNET);
    toChain.update(val => val === CHAIN_MAINNET ? CHAIN_TKO : CHAIN_MAINNET);
  }
</script>

<div class="form-control w-full">
  <label class="label" for="amount">
    <span class="label-text">{$_("home.from")}</span>
  </label>
  <label class="input-group relative rounded-lg overflow-hidden">
    <span class="bg-transparent border-transparent absolute top-0 left-0 h-full z-0">{$fromChain.name}</span>
    <input
    type="number"
    step="0.01"
    placeholder="0.01"
    min="0"
    bind:value={amount}
    class="input input-primary focus:input-accent bg-dark-4 input-lg rounded-lg! w-full text-right pl-20 pr-12 z-1"
    name="amount"
    />
    <span class="pl-0 bg-transparent border-transparent absolute top-0 right-0 h-full">ETH</span>
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
    <span class="bg-transparent border-transparent absolute top-0 left-0 h-full z-0">{$toChain.name}</span>
    <input
    type="number"
    step="0.01"
    placeholder="0.01"
    min="0"
    bind:value={amount}
    class="input input-primary focus:input-accent bg-dark-4 input-lg rounded-lg! w-full text-right pl-20 pr-12 z-1"
    name="amount-to"
    />
    <span class="pl-0 bg-transparent border-transparent absolute top-0 right-0 h-full">ETH</span>
  </label>
</div>

<button
  class="btn btn-accent text-sm mt-16 w-full"
  on:click={async () => await bridge()}
>
  {$_("home.bridge")}
</button>
