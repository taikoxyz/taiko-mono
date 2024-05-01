<script lang="ts">
  import { classNames } from '$lib/util/classNames';
  const sectionContainerClasses = classNames('w-full', 'h-full', 'z-0', 'overflow-y-scroll', $$props.class);
</script>

<div class={sectionContainerClasses}>
  <slot />
</div>
