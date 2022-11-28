<script lang="ts">
  import { token } from "../../store/token";
  import { bridgeType } from "../../store/bridge";
  import { ETH, tokens } from "../../domain/token";

  import type { Token } from "../../domain/token";
  import { toast } from "@zerodevx/svelte-toast";
  import { BridgeType } from "../../domain/bridge";

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

<div class="dropdown">
  <label tabindex="0" class="btn m-1">
    {$token.symbol.toUpperCase()}
    <svelte:component this={$token.logoComponent} />
  </label>
  <ul
    tabindex="0"
    class="dropdown-content menu p-2 shadow bg-base-100 rounded-box"
  >
    {#each tokens as t}
      <li class="cursor-pointer">
        <a on:click={async () => await select(t)}
          >{t.symbol.toUpperCase()}
          <svelte:component this={t.logoComponent} /></a
        >
      </li>
    {/each}
  </ul>
</div>
