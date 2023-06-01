<!--
  TODO: this is a PoC. The idea would be to have a button component that can be
  styled based on props following daisyUI classes.
-->
<script lang="ts">
  import type { SizeButton, TypeButton } from '../domain/button';

  export let type: TypeButton = '';
  export let size: SizeButton = 'md';

  const classes = `btn ${`btn-${type}`} ${`btn-${size}`} ${$$props.class}`;
</script>

<button {...$$restProps} on:click class={classes}>
  <slot />
</button>
