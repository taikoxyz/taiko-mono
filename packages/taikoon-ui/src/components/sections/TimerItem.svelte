<script lang="ts">
  import { classNames } from '$lib/util/classNames';

  export let count: number = 0;
  export let label: string = 'Label';

  const containerClasses = classNames(
    'w-[15vw]',
    'h-full',
    'flex',
    'flex-col',
    'gap-4',
    'items-center',
    'justify-center',
    'z-10',
  );
</script>

<div class={containerClasses}>
  <div class={classNames('font-clash-grotesk', 'font-medium', 'md:text-h0', 'text-5xl')}>
    {count}
  </div>
  <div class={classNames('text-content-secondary', 'md:text-h4', 'text-sm')}>{label}</div>
</div>
