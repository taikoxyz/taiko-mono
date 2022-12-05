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
  import ProcessingFee from "./ProcessingFee.svelte";
  import { ETH } from "../../domain/token";
  import SelectToken from "../buttons/SelectToken.svelte";

  let amount: string;
  let btnDisabled: boolean = true;
  let tokenBalance: string;

  $: getUserBalance($signer, $token);
  
  async function getUserBalance(signer, token) {
    if(signer && token) {
      if(token.symbol == ETH.symbol) {
        const userBalance = await signer.getBalance('latest');
        tokenBalance = ethers.utils.formatEther(userBalance);
      } else {
        // TODO: read ERC20 balance from contract
      }
    }
  }

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

  function useFullAmount() {
    amount = tokenBalance;
  }
</script>

<div class="form-control w-full my-8">
  <label class="label" for="amount">
    <span class="label-text">{$_("bridgeForm.fieldLabel")}</span>
    {#if $signer && tokenBalance } <button class="label-text" on:click={useFullAmount}>{$_("bridgeForm.maxLabel")} {tokenBalance} ETH</button>{/if}
  </label>
  <label class="input-group relative rounded-lg bg-dark-4 justify-between items-center pr-4">
    <input
    type="number"
    step="0.01"
    placeholder="0.01"
    min="0"
    bind:value={amount}
    class="input input-primary bg-dark-4 input-lg"
    name="amount"
    />
    <SelectToken />
  </label>
</div>

<ProcessingFee />

<button
  class="btn btn-accent text-sm mt-16 w-full"
  on:click={async () => await bridge()}
>
  {$_("home.bridge")}
</button>
