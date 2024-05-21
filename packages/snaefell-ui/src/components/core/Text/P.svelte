<script lang="ts">
  import { classNames } from '$lib/util/classNames';
</script>

<p class={classNames('font-sans', 'text-content-secondary', $$props.class)}>
  <slot />
</p>
