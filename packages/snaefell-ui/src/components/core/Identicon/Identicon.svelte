<script lang="ts">
  import { minidenticon } from 'minidenticons';

  import { classNames } from '$lib/util/classNames';
  export let seed: string;
  export let size: 'full' | 'xs' | 'sm' | 'md' | 'lg' = 'full';

  $: imgClasses = classNames(
    size === 'full' ? 'w-full ' : null,
    size === 'xs' ? 'w-16 p-2' : null,
    size === 'sm' ? 'w-32 ' : null,
    size === 'md' ? 'w-64 ' : null,
    size === 'lg' ? 'w-80 ' : null,
    'object-cover',
    'object-center',
    'rounded-full',
    'bg-overlay-background',
    $$props.class,
  );
</script>

<img
  alt={`identicon-${seed}`}
  class={imgClasses}
  src={'data:image/svg+xml;utf8,' + encodeURIComponent(minidenticon(seed))} />
