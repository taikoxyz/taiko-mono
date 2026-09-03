<!--
  Stands in for ExplorerLink: renders what the real component would link to, so a test can read
  which address or hash a row points at. Every prop the real component takes is declared and
  rendered, so Svelte warns about neither an unknown prop nor an unused export.
-->
<script lang="ts">
  export let category: string;
  export let urlParam: string;
  export let chainId: number | undefined = undefined;
  export let linkText: string | null = null;
  export let shorten = false;
  let className = '';
  export { className as class };
</script>

<span
  data-testid="explorer-link"
  data-category={category}
  data-param={urlParam}
  data-chain={chainId}
  data-shorten={shorten}
  class={className}>{linkText ?? urlParam}</span>
