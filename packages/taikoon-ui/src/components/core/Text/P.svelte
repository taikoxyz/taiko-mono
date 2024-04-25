<script lang="ts">
  import { classNames } from '$lib/util/classNames';

  let classes: string = null;
  export { classes as class };
</script>

<p class={classNames('font-sans', 'text-content-secondary', classes)}>
  <slot />
</p>
