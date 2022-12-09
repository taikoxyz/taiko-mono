<script lang="ts">
  import { token } from "../../store/token";
  import { bridgeType } from "../../store/bridge";
  import { ETH, tokens } from "../../domain/token";
  import type { Token } from "../../domain/token";
  import { BridgeType } from "../../domain/bridge";
  import ChevDown from "../icons/ChevDown.svelte";
  import { successToast } from "../../utils/toast";

  async function select(t: Token) {
    if (t === $token) return;
    token.set(t);
    if (t.symbol.toLowerCase() == ETH.symbol.toLowerCase()) {
      bridgeType.set(BridgeType.ETH);
    } else {
      bridgeType.set(BridgeType.ERC20);
    }
    successToast(`Token changed to ${t.symbol.toUpperCase()}`);
  }
</script>

<div class="dropdown dropdown-bottom">
  <button tabindex="0" class="flex items-center justify-center">
    <svelte:component this={$token.logoComponent} class="inline-block" />
    <p class="px-2 text-sm">{$token.symbol.toUpperCase()}</p>
    <ChevDown />
  </button>
  <ul class="dropdown-content menu py-2 shadow-xl bg-base-100 rounded-box">
    {#each tokens as t}
      <li class="cursor-pointer w-full hover:bg-dark-3 px-7 py-3">
        <button
          on:click={async () => await select(t)}
          class="flex items-center justify-center"
        >
          <svelte:component this={t.logoComponent} height={22} width={22} />
          <span class="text-sm font-medium bg-base-100 px-2"
            >{t.symbol.toUpperCase()}</span
          >
        </button>
      </li>
    {/each}
  </ul>
</div>
