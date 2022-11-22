<script lang="ts">
  import { token } from "../../store/token";
  import { tokens } from "../../domain/token";

  import type { Token } from "../../domain/token";

  async function select(t: Token) {
    token.set(t);
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
