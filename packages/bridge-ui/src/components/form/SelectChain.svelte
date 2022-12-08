<script lang="ts">
  import ArrowRight from "../icons/ArrowRight.svelte";
  import { fromChain, toChain } from "../../store/chain";
  import { CHAIN_MAINNET, CHAIN_TKO } from "../../domain/chain";
  import { switchEthereumChain } from "../../utils/switchEthereumChain";
  import { ethereum } from "../../store/ethereum";
  import { ethers } from "ethers";
  import { signer } from "../../store/signer";

  const toggleChains = async () => {
    const chain = $fromChain === CHAIN_MAINNET ? CHAIN_TKO : CHAIN_MAINNET;
    await switchEthereumChain($ethereum, chain);
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    await provider.send("eth_requestAccounts", []);

    fromChain.set(chain);
    if (chain === CHAIN_MAINNET) {
      toChain.set(CHAIN_TKO);
    } else {
      toChain.set(CHAIN_MAINNET);
    }
    signer.set(provider.getSigner());
  };
</script>

<div class="flex items-center justify-between w-full p-8 py-6 text-lg">
  <div class="flex items-center w-2/5 justify-center">
    {#if $fromChain}
      <svelte:component this={$fromChain.icon} />
      <span class="ml-2">{$fromChain.name}</span>
    {:else}
      <svelte:component this={CHAIN_MAINNET.icon} />
      <span class="ml-2">{CHAIN_MAINNET.name}</span>
    {/if}
  </div>

  <button on:click={toggleChains} class="btn btn-square btn-xs"
    ><ArrowRight /></button
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
