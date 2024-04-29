<script lang="ts">
  import { pageScroll } from '$stores/pageScroll';
  import { classNames } from '$lib/util/classNames';

  let scrollTarget: HTMLElement | null = null;

  function handleScroll() {
    if (!scrollTarget) return;
    pageScroll.set(scrollTarget.scrollTop > 100);
  }

  const sectionContainerClasses = classNames('w-full', 'h-full', 'z-0', 'overflow-y-scroll', $$props.class);
</script>

<div
  bind:this={scrollTarget}
  on:scroll={handleScroll}
 class={sectionContainerClasses}>
  <slot />
</div>
