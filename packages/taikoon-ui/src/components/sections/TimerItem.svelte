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

  const countClasses = classNames('font-clash-grotesk', 'font-medium', 'md:text-h0', 'text-5xl');
  const labelClasses = classNames('text-content-secondary', 'md:text-h4', 'text-sm');
</script>

<div class={containerClasses}>
  <div class={countClasses}>
    {count}
  </div>
  <div class={labelClasses}>{label}</div>
</div>
