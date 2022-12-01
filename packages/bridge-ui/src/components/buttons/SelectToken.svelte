<script lang="ts">
  import { token } from "../../store/token";
  import { bridgeType } from "../../store/bridge";
  import { ETH, tokens } from "../../domain/token";
  import type { Token } from "../../domain/token";
  import { toast } from "@zerodevx/svelte-toast";
  import { BridgeType } from "../../domain/bridge";
  import ChevDown from "../icons/ChevDown.svelte";

  async function select(t: Token) {
    if (t === $token) return;
    token.set(t);
    if (t.symbol.toLowerCase() == ETH.symbol.toLowerCase()) {
      bridgeType.set(BridgeType.ETH);
    } else {
      bridgeType.set(BridgeType.ERC20);
    }
    toast.push(`Token changed to ${t.symbol.toUpperCase()}`);
  }
</script>

<div class="dropdown dropdown-bottom">
  <button tabindex="0" class="btn btn-token-select m-1">
    <svelte:component this={$token.logoComponent} />
    <span class="px-2 font-medium">{$token.symbol.toUpperCase()}</span>
    <ChevDown />
  </button>
  <ul class="dropdown-content menu py-2 shadow-xl bg-base-100 rounded-box">
    {#each tokens as t}
      <li class="cursor-pointer w-full hover:bg-dark-3 px-9 py-3">
        <button
          on:click={async () => await select(t)}
          class="flex items-center"
        >
          <svelte:component this={t.logoComponent} height={16} width={16} />
          <span class="text-sm font-medium mx-2">{t.symbol.toUpperCase()}</span>
        </button>
      </li>
    {/each}
  </ul>
</div>
