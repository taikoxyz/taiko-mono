<script lang="ts">
  import { classNames } from '$libs/util/classNames';

  const classes = classNames(
    'w-6 h-6',
    'animate-spin',
    'inline-block',
    'border-[3px] border-b-transparent rounded-full',
    'border-primary-content border-b-transparent ',
    $$props.class,
  );
</script>

<span class={classes} />
