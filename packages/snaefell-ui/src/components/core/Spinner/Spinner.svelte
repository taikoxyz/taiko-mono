<script lang="ts">
  import { classNames } from '../../../lib/util/classNames';
  export let size: 'xs' | 'sm' | 'md' | 'lg' | number = 'md';

  const classes = classNames(
    size === 'xs' ? 'w-4 h-4' : null,
    size === 'sm' ? 'w-6 h-6' : null,
    size === 'md' ? 'w-12 h-12' : null,
    size === 'lg' ? 'w-32 h-32' : null,

    'loading loading-spinner',
    $$props.class,
  );
</script>

<span class={classes} />
