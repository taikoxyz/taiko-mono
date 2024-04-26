<script lang="ts">
  import { pageScroll } from '$stores/pageScroll';

  let scrollTarget: HTMLElement | null = null;

  function handleScroll() {
    if (!scrollTarget) return;
    pageScroll.set(scrollTarget.scrollTop > 100);
  }
</script>

<div
  bind:this={scrollTarget}
  on:scroll={handleScroll}
  class="w-full h-full z-0 snap-y snap-mandatory overflow-y-scroll">
  <slot />
</div>
