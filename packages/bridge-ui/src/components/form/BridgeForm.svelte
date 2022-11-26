<script lang="ts">
  import { _ } from "svelte-i18n";
  import { token } from "../../store/token";
  import { fromChain, toChain } from "../../store/chain";
  import { activeBridge, chainIdToBridgeAddress } from "../../store/bridge";
  import { signer } from "../../store/signer";
  import { BigNumber, ethers, Signer } from "ethers";
  import { toast } from "@zerodevx/svelte-toast";

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

<button
  class="btn btn-accent"
  on:click={async () => await bridge()}
  disabled={btnDisabled}
>
  {$_("home.bridge")}
</button>
