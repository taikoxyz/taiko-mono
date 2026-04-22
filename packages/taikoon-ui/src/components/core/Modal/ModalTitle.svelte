<script lang="ts">
  import { classNames } from '$lib/util/classNames';

  const titleRowClasses = classNames(
    'flex',
    'w-full',
    'items-center',
    'justify-between',
    'gap-10',
    'md:mt-0',
    'mt-16',
    'p-4',
    'relative',
    $$props.class,
  );

  const textClasses = classNames('font-clash-grotesk', 'text-4xl', 'text-content-primary', 'font-semibold');
</script>

<div class={titleRowClasses}>
  <div class={textClasses}>
    <slot />
  </div>
</div>
