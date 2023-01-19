<script lang="ts">
  import { token } from "../../store/token";
  import { bridgeType } from "../../store/bridge";
  import { ETH, tokens } from "../../domain/token";
  import type { Token } from "../../domain/token";
  import { BridgeType } from "../../domain/bridge";
  import { ChevronDown } from "svelte-heros-v2";
  import { successToast } from "../../utils/toast";

  let dropdownElement: HTMLDivElement;

  async function select(t: Token) {
    if (t === $token) return;
    token.set(t);
    if (t.symbol.toLowerCase() == ETH.symbol.toLowerCase()) {
      bridgeType.set(BridgeType.ETH);
    } else {
      bridgeType.set(BridgeType.ERC20);
    }
    successToast(`Token changed to ${t.symbol.toUpperCase()}`);

    // to close the dropdown on click
    dropdownElement?.classList.remove('dropdown-open');
    if (document.activeElement instanceof HTMLElement) {
      document.activeElement.blur();
    }
  }
</script>

<div class="dropdown dropdown-bottom" bind:this={dropdownElement}>
  <label
    tabindex="0"
    class="flex items-center justify-center hover:cursor-pointer"
  >
    <svelte:component this={$token.logoComponent} />
    <p class="px-2 text-sm">{$token.symbol.toUpperCase()}</p>
    <ChevronDown size='20' />
  </label>
  <ul
    tabindex="0"
    class="dropdown-content menu my-2 shadow-xl bg-dark-2 rounded-box p-2"
  >
    {#each tokens as t}
      <li class="cursor-pointer w-full hover:bg-dark-5 px-4 py-4">
        <button on:click={async () => await select(t)} class="flex hover:bg-dark-5">
          <svelte:component this={t.logoComponent} height={22} width={22} />
          <span class="text-sm font-medium bg-transparent px-2"
            >{t.symbol.toUpperCase()}</span
          >
        </button>
      </li>
    {/each}
  </ul>
</div>
