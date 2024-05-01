<script lang="ts">
  import { classNames } from '$lib/util/classNames';

  export let href = '#';
</script>

<a {href} class={classNames('font-sans', 'underline', 'font-bold', $$props.class)}>
  <slot />
</a>
