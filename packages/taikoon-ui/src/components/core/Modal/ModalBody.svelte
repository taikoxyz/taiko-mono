<script lang="ts">
  import { classNames } from '$lib/util/classNames';
</script>

<div
  class={classNames(
    'px-4',
    'w-full',
    'h-full',

    'flex',
    'flex-col',
    $$props.class,
  )}>
  <slot />
</div>
