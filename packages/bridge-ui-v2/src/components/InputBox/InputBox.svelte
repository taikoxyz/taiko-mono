<script lang="ts">
  import { classNames } from '$libs/util/classNames';

  export let classes = classNames('w-full input-box placeholder:text-tertiary-content', $$props.class);
</script>

<input class={classes} {...$$restProps} />
