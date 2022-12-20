<script lang="ts">
  import { _ } from "svelte-i18n";

  import ChevDown from "./icons/ChevDown.svelte";
  import { fromChain, toChain } from "../store/chain";
  import MetaMask from "./icons/MetaMask.svelte";
  import { switchEthereumChain } from "../utils/switchEthereumChain";
  import { ethereum } from "../store/ethereum";
  import { CHAIN_MAINNET, CHAIN_TKO } from "../domain/chain";
  import type { Chain } from "../domain/chain";
  import { ethers } from "ethers";
  import { signer } from "../store/signer";
  const changeChain = async (chain: Chain) => {
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

<div class="dropdown dropdown-bottom dropdown-end mr-4">
  <label tabindex="0" class="btn btn-md md:btn-wide justify-around">
    <span class="font-normal flex-1 text-left mr-2">
      {#if $fromChain}
        <svelte:component this={$fromChain.icon} />
        <span class="ml-2 hidden md:inline-block">{$fromChain.name}</span>
      {:else}
        <span class="ml-2 hidden md:inline-block">Invalid Chain</span>
      {/if}
    </span>
  </label>
  <ul
    tabindex="0"
    class="dropdown-content flex menu p-2 shadow bg-dark-3 rounded-box w-[194px]"
  >
    <li>
      <button
        class="flex items-center px-2 py-4 hover:bg-dark-5 rounded-xl justify-around"
        on:click={async () => {
          await changeChain(CHAIN_MAINNET);
        }}
      >
        <svelte:component this={CHAIN_MAINNET.icon} height={24} />
        <span class="pl-1.5 text-left flex-1">{CHAIN_MAINNET.name}</span>
        <MetaMask />
      </button>
    </li>
    <li>
      <button
        class="flex items-center px-2 py-4 hover:bg-dark-5 rounded-xl justify-around"
        on:click={async () => {
          await changeChain(CHAIN_TKO);
        }}
      >
        <svelte:component this={CHAIN_TKO.icon} height={24} />
        <span class="pl-1.5 text-left flex-1">{CHAIN_TKO.name}</span>
        <MetaMask />
      </button>
    </li>
  </ul>
</div>

<style>
  .menu li > span {
    padding-left: 0px;
  }
</style>
