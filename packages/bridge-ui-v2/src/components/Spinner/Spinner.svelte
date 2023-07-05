<script lang="ts">
  import { classNames } from '$libs/util/classNames';

  const classes = classNames(
    'w-6 h-6',
    'animate-spin',
    'box-border inline-block',
    'border-[3px] border-b-transparent rounded-full',
    $$props.class,
  );
</script>

<span class={classes} />
