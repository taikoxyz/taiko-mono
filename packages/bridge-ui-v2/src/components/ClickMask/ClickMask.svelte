<script lang="ts">
  import { onMount } from 'svelte';
  import { noop, onDestroy } from 'svelte/internal';

  export let active = false;
  export let fn = noop;

  let mask: HTMLDivElement;

  onMount(() => {
    mask?.addEventListener('click', fn);
  });

  onDestroy(() => {
    mask?.removeEventListener('click', fn);
  });

  $: displayClass = active ? 'block' : 'hidden';
</script>

<div class="{displayClass} fixed top-0 right-0 bottom-0 left-0" bind:this={mask} />
