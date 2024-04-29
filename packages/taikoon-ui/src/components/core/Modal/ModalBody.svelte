<script lang="ts">
  import { classNames } from '$lib/util/classNames';
  const modalBodyClasses = classNames('px-4', 'w-full', 'h-full', 'flex', 'flex-col', $$props.class);
</script>

<div class={modalBodyClasses}>
  <slot />
</div>
