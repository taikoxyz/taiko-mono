<script lang="ts">
  import { onDestroy, onMount } from 'svelte';

  // This component will help us to programmatically do the same as
  // CSS media queries. We can use it to show/hide elements or render
  // different components based on whether or not the size is desktop
  // or larger
  const isLgMediaQuery = window.matchMedia('(min-width: 1024px)');
  const isMdMediaQuery = window.matchMedia('(min-width: 768px)');

  export let windowSize: 'sm' | 'md' | 'lg' = 'md';

  function isLgQueryHandler(event: MediaQueryListEvent) {
    windowSize = event.matches ? 'lg' : 'md';
  }

  function isMdQueryHandler(event: MediaQueryListEvent) {
    windowSize = event.matches ? 'md' : 'sm';
  }

  onMount(() => {
    isLgMediaQuery.addEventListener('change', isLgQueryHandler);
    isMdMediaQuery.addEventListener('change', isMdQueryHandler);
    //assign starting value
    windowSize = window.innerWidth > 1024 ? 'lg' : window.innerWidth < 768 ? 'sm' : 'md';
  });

  onDestroy(() => {
    isLgMediaQuery.removeEventListener('change', isLgQueryHandler);
    isMdMediaQuery.removeEventListener('change', isMdQueryHandler);
  });
</script>
