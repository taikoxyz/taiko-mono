<!--
  TODO: this is a PoC. The idea would be to have a button component that can be
  styled based on props following daisyUI classes.
-->
<script lang="ts">
  import type { SizeButton, TypeButton } from '../../domain/button';

  export let type: TypeButton = '';
  export let size: SizeButton = 'md';

  const classes = `btn ${`btn-${type}`} ${`btn-${size}`} ${
    $$restProps.class ?? ''
  }`;

  const { class: _, ...restProps } = $$restProps; // remove class from rest of props
</script>

<!--
  TODO: theme daisyUI and then use btn-${type}
-->
<button class={classes} {...restProps}>
  <slot />
</button>

<style>
  /* TODO: design needed. We're using daisyUI, how about theming? */
</style>
