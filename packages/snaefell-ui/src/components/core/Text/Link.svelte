<script lang="ts">
  import { classNames } from '$lib/util/classNames';

  export let href = '#';
  export let target = '_self';
</script>

<a {href} {target} class={classNames('font-sans', 'underline', 'font-bold', $$props.class)}>
  <slot />
</a>
