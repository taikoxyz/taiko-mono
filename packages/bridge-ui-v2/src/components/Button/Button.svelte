<script lang="ts">
  import type { SizeButton, TypeButton } from './types'

  export let type: TypeButton
  export let size: SizeButton = 'md'

  const typeCls = type ? `btn-${type}` : ''
  const sizeCls = `btn-${size}`
  const classes = `btn ${typeCls} ${sizeCls} ${$$props.class}`
</script>

<button {...$$restProps} on:click class={classes}>
  <slot />
</button>
