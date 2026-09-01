<!--
  Stands in for RecommendedFee in component tests. The real one polls the chain on an
  interval and pushes the answer up through `bind:amount`; this exposes that push as a
  writable store the test can drive, so a fee refresh landing at a chosen moment is
  reproducible.
-->
<script lang="ts" context="module">
  import { writable } from 'svelte/store';

  export const stubRecommendedAmount = writable<bigint>(BigInt(0));
</script>

<script lang="ts">
  export let amount: bigint = BigInt(0);
  export let error: boolean = false;

  $: amount = $stubRecommendedAmount;
  $: error = false;
</script>

<span data-testid="recommended-fee-stub" />
