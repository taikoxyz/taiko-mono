<script lang="ts">
  import { switchNetwork } from '@wagmi/core';
  import { ethers } from 'ethers';
  import { ChevronDown, ExclamationTriangle } from 'svelte-heros-v2';
  import { _ } from 'svelte-i18n';

  import { mainnetChain, taikoChain } from '../chain/chains';
  import type { Chain } from '../domain/chain';
  import { fromChain, toChain } from '../store/chain';
  import { signer } from '../store/signer';

  const changeChain = async (chain: Chain) => {
    await switchNetwork({
      chainId: chain.id,
    });
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    await provider.send('eth_requestAccounts', []);

    fromChain.set(chain);
    if (chain === mainnetChain) {
      toChain.set(taikoChain);
    } else {
      toChain.set(mainnetChain);
    }
    signer.set(provider.getSigner());
  };
</script>

<div class="dropdown dropdown-end mr-4">
  <!-- svelte-ignore a11y-label-has-associated-control -->
  <label
    role="button"
    tabindex="0"
    class="btn btn-md justify-around md:w-[194px]">
    <span class="font-normal flex-1 text-left mr-2">
      {#if $fromChain}
        <svelte:component this={$fromChain.icon} />
        <span class="ml-2 hidden md:inline-block">{$fromChain.name}</span>
      {:else}
        <span class="ml-2 flex items-center">
          <ExclamationTriangle class="mr-2" size="20" />
          <span class="hidden md:block">Invalid Chain</span>
        </span>
      {/if}
    </span>
    <ChevronDown size="20" />
  </label>
  <ul
    role="listbox"
    tabindex="0"
    class="dropdown-content address-dropdown-content flex my-2 menu p-2 shadow bg-dark-2 rounded-sm w-[194px]">
    <li>
      <button
        class="flex items-center px-2 py-4 hover:bg-dark-5 rounded-xl justify-around"
        on:click={async () => {
          await changeChain(mainnetChain);
        }}>
        <svelte:component this={mainnetChain.icon} height={24} />
        <span class="pl-1.5 text-left flex-1">{mainnetChain.name}</span>
      </button>
    </li>
    <li>
      <button
        class="flex items-center px-2 py-4 hover:bg-dark-5 rounded-xl justify-around"
        on:click={async () => {
          await changeChain(taikoChain);
        }}>
        <svelte:component this={taikoChain.icon} height={24} />
        <span class="pl-1.5 text-left flex-1">{taikoChain.name}</span>
      </button>
    </li>
  </ul>
</div>
