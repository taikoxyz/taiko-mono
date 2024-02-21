<script lang="ts">
  import { onDestroy, onMount } from 'svelte';

  // This component will help us to programmatically do the same as
  // CSS media queries. We can use it to show/hide elements or render
  // different components based on whether or not the size is desktop
  // or larger
  const mediaQuery = window.matchMedia('(min-width: 768px)');
  export let is: boolean;

  function mediaQueryHandler(event: MediaQueryListEvent) {
    is = event.matches;
  }

  onMount(() => {
    is = mediaQuery.matches;
    mediaQuery.addEventListener('change', mediaQueryHandler);
  });

  onDestroy(() => {
    mediaQuery.removeEventListener('change', mediaQueryHandler);
  });

  // TODO: maybe we want something more general purpose than just `md`?
</script>
