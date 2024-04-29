<script lang="ts">
  import { classNames } from '$lib/util/classNames';
</script>

<div
  class={classNames(
    'border-t-[1px]',
    'border-border-divider-default',
    'w-full',
    //'h-full',

    'flex',
    'px-4',
    'py-6',
    $$props.class,
  )}>
  <slot />
</div>
