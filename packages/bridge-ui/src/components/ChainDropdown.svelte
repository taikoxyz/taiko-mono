<script lang="ts">
  import { _ } from "svelte-i18n";

  import ChevDown from "./icons/ChevDown.svelte";
  import { fromChain } from "../store/chain";
  import MetaMask from "./icons/MetaMask.svelte";
  import { switchEthereumChain } from "../utils/switchEthereumChain";
  import { ethereum } from "../store/ethereum";
  import { CHAIN_MAINNET, CHAIN_TKO } from "../domain/chain";
</script>

<div class="dropdown dropdown-bottom mr-4">
  <button tabindex="0" class="btn btn-wide justify-around">
    <span class="font-normal flex-1 text-left">
      {#if $fromChain}
        <svelte:component this={$fromChain.icon} />
        <span class="ml-2">{$fromChain.name}</span>
      {:else}
        <span class="ml-2">Invalid Chain</span>
      {/if}
    </span>

    <ChevDown />
  </button>
  <ul
    tabindex="0"
    class="dropdown-content flex menu p-2 shadow bg-dark-3 rounded-box w-[194px]"
  >
    <li>
      <button class="btn btn-wide justify-around">
        <svelte:component this={CHAIN_MAINNET.icon} />
        <span class="ml-2 text-left flex-1">{CHAIN_MAINNET.name}</span>
        <span
          class="cursor-pointer z-10"
          on:click={async () =>
            await switchEthereumChain($ethereum, CHAIN_MAINNET)}
        >
          <MetaMask />
        </span>
      </button>
    </li>
    <li>
      <button class="btn btn-wide justify-around">
        <svelte:component this={CHAIN_TKO.icon} />
        <span class="ml-2 text-left flex-1">{CHAIN_TKO.name}</span>
        <span
          class="cursor-pointer z-10"
          on:click={async () => await switchEthereumChain($ethereum, CHAIN_TKO)}
        >
          <MetaMask />
        </span>
      </button>
    </li>
  </ul>
</div>

<style>
  .menu li > span {
    padding-left: 0px;
  }
</style>
