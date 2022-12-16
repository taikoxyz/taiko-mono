<script lang="ts">
  import { _ } from "svelte-i18n";
  import { processingFee } from "../../store/fee";
  import { ProcessingFeeMethod, PROCESSING_FEE_META } from "../../domain/fee";
  import { providers } from "../../store/providers";
  import { toChain, fromChain } from "../../store/chain";
  import { BigNumber, Contract, ethers, Signer } from "ethers";
  import type { Chain } from "../../domain/chain";
  import { token } from "../../store/token";
  import { ETH } from "../../domain/token";
  import type { Token } from "../../domain/token";
  import { chainIdToTokenVaultAddress } from "../../store/bridge";
  import TokenVault from "../../constants/abi/TokenVault";
  import { signer } from "../../store/signer";

  export let customFee: string;
  export let recommendedFee: string = "0";

  $: getRecommendedProcessingFee(
    $toChain,
    $fromChain,
    $processingFee,
    $token,
    $signer
  )
    .then((fee) => (recommendedFee = fee))
    .catch((e) => console.error(e));
  function selectProcessingFee(fee) {
    $processingFee = fee;
  }

  function updateAmount(e: any) {
    customFee = (e.target.value as number).toString();
  }

  async function getRecommendedProcessingFee(
    toChain: Chain,
    fromChain: Chain,
    feeType: ProcessingFeeMethod,
    token: Token,
    signer: Signer
  ) {
    if (!toChain || !feeType) return "0";
    const gasPrice = await $providers.get(toChain.id).getGasPrice();
    let gasLimit = 900000; // gasLimit for processMessage call for ETH is about ~800k. to make it enticiing, we say 900k.
    if (token.symbol.toLowerCase() !== ETH.symbol.toLowerCase()) {
      const srcChainAddr = token.addresses.find(
        (t) => t.chainId === fromChain.id
      ).address;

      const tokenVault = new Contract(
        $chainIdToTokenVaultAddress.get(fromChain.id),
        TokenVault,
        signer
      );

      const bridged = await tokenVault.canonicalToBridged(
        toChain.id,
        srcChainAddr
      );

      // gas limit for erc20 if not deployed on the dest chain already is about ~2.9m
      // so we add some to make it enticing
      if (bridged == ethers.constants.AddressZero) {
        gasLimit = 3100000;
      } else {
        // gas limit for erc20 if already deployed on the dest chain is about ~1m
        gasLimit = 1100000;
      }
    }

    const recommendedFee = BigNumber.from(gasPrice).mul(gasLimit);
    console.log("recommended fee", recommendedFee.toString());
    return ethers.utils.formatEther(recommendedFee);
  }
</script>

<div class="my-10 w-full">
  <h4 class="text-sm font-medium text-left mb-4">
    {$_("bridgeForm.processingFeeLabel")}
  </h4>
  <div class="flex items-center justify-around">
    {#each Array.from(PROCESSING_FEE_META) as fee}
      <button
        class="{$processingFee === fee[0]
          ? 'border-accent hover:border-accent'
          : ''} btn btn-sm md:btn-md"
        on:click={() => selectProcessingFee(fee[0])}
        >{fee[1].displayText}</button
      >
    {/each}
  </div>

  {#if $processingFee === ProcessingFeeMethod.CUSTOM}
    <label class="mt-2 input-group relative">
      <input
        type="number"
        step="0.01"
        placeholder="0.01"
        min="0"
        on:input={updateAmount}
        class="input input-primary md:input-lg flex-1 rounded-l-lg !rounded-r-none bg-dark-4"
        name="amount"
      />
      <span class="!rounded-r-lg bg-dark-4">ETH</span>
    </label>
  {:else if $processingFee === ProcessingFeeMethod.RECOMMENDED}
    <div class="flex items-left justify-between">
      <span class="mt-2 text-sm">{recommendedFee} ETH </span>
    </div>
  {/if}
</div>
