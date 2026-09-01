<!--
  Stands in for ImportStep in NFTBridge component tests: the same public API the parent
  calls into, without the chain config and NFT scanning the real one drags in.
-->
<script lang="ts">
  export let validating = false;

  export const resetManualImport = () => {};
  export const revalidate = () => {};

  $: validating = false;
</script>

<span data-testid="stub" />
