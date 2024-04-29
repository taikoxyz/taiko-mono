<script lang="ts">
  import { classNames } from '$lib/util/classNames';
  const footerClasses = classNames(
    'border-t-[1px]',
    'border-border-divider-default',
    'w-full',
    'flex',
    'px-4',
    'py-6',
    $$props.class,
  );
</script>

<div class={footerClasses}>
  <slot />
</div>
