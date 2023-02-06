<script>
  import { ArrowRight } from "svelte-heros-v2";
  import { fromChain, toChain } from "../../store/chain";
  import { CHAIN_MAINNET, CHAIN_TKO } from "../../domain/chain";
  import { signer } from "../../store/signer";
  import { ethers } from "ethers";
  import { errorToast, successToast } from "../../utils/toast";
  import { switchNetwork } from "@wagmi/core";

  const toggleChains = async () => {
    try {
      const chain = $fromChain === CHAIN_MAINNET ? CHAIN_TKO : CHAIN_MAINNET;
      await switchNetwork({
        chainId: chain.id,
      });
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      await provider.send("eth_requestAccounts", []);

      fromChain.set(chain);
      toChain.set(chain === CHAIN_MAINNET ? CHAIN_TKO : CHAIN_MAINNET);

      signer.set(provider.getSigner());
      successToast("Successfully changed chain");
    } catch (e) {
      console.error(e);
      errorToast("Error switching chain");
    }
  };
</script>

<div
  class="flex items-center justify-between w-full px-4 md:px-8 py-6 text-sm md:text-lg text-white"
>
  <div class="flex items-center w-2/5 justify-center">
    {#if $fromChain}
      <svelte:component this={$fromChain.icon} />
      <span class="ml-2">{$fromChain.name}</span>
    {:else}
      <svelte:component this={CHAIN_MAINNET.icon} />
      <span class="ml-2">{CHAIN_MAINNET.name}</span>
    {/if}
  </div>

  <button
    on:click={toggleChains}
    class="btn btn-square btn-sm toggle-chain"
    disabled={!$signer}><ArrowRight size="16" /></button
  >
  <div class="flex items-center w-2/5 justify-center">
    {#if $toChain}
      <svelte:component this={$toChain.icon} />
      <span class="ml-2">{$toChain.name}</span>
    {:else}
      <svelte:component this={CHAIN_TKO.icon} />
      <span class="ml-2">{CHAIN_TKO.name}</span>
    {/if}
  </div>
</div>
