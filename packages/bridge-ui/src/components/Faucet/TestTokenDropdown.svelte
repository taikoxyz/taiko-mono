<script lang="ts">
  import { ChevronDown } from 'svelte-heros-v2';

  import type { Token } from '../../domain/token';
  import { isTestToken, testERC20Tokens } from '../../token/tokens';
  import { selectTokenAndBridgeType } from '../../utils/selectTokenAndBridgeType';
  import Erc20 from '../icons/ERC20.svelte';

  export let selectedToken: Token;

  let dropdownElement: HTMLDivElement;

  function closeDropdown() {
    dropdownElement?.classList.remove('dropdown-open');
    if (document.activeElement instanceof HTMLElement) {
      document.activeElement.blur();
    }
  }

  function selectTokenAndCloseDropdown(selectedToken: Token) {
    selectTokenAndBridgeType(selectedToken);
    closeDropdown();
  }
</script>

<div class="dropdown dropdown-bottom">
  <button class="btn btn-md justify-around w-[194px]">
    <span class="font-normal flex items-center flex-1 text-left mr-2">
      {#if selectedToken && isTestToken(selectedToken)}
        {#if selectedToken.logoComponent}
          <svelte:component this={selectedToken.logoComponent} />
        {:else}
          <Erc20 />
        {/if}
        <span class="ml-2 inline-block">{selectedToken.name}</span>
      {:else}
        Select Test Token…
      {/if}
    </span>
    <ChevronDown size="20" />
  </button>

  <ul
    role="listbox"
    tabindex="0"
    class="dropdown-content rounded-box flex my-2 menu p-2 shadow bg-dark-2 w-[194px]">
    {#each testERC20Tokens as token (token.symbol)}
      <li>
        <button
          on:click={() => selectTokenAndCloseDropdown(token)}
          class="flex items-center px-2 py-4 hover:bg-dark-5 rounded-sm">
          <svelte:component this={token.logoComponent} height={24} />
          <span class="pl-1.5 text-left flex-1">
            {token.name}
          </span>
        </button>
      </li>
    {/each}
  </ul>
</div>
