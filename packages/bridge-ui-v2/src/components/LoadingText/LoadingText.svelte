<script lang="ts">
  import { classNames } from '$libs/util/classNames';

  export let mask = 'Loading';

  let classes = classNames('animate-pulse blur-sm font-bold', $$props.class);
</script>

<span class={classes}>{mask}</span>
