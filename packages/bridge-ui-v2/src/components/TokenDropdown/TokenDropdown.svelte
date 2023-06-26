<script lang="ts">
  export let tokens: Token[] = [];

  let selectedToken: Token
</script>

<div class="dropdown" role="listbox">
  <button class="m-1 btn">open or close</button>
  <ul class="menu dropdown-content" role="listbox">
    {#each tokens as token (token.symbol)}
      <li role="option" aria-selected={selectedToken === token}>{token.name}</li>
    {/each}
  </ul>
</div>
