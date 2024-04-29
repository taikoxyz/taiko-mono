<script lang="ts">
  import { classNames } from '$lib/util/classNames';
</script>

<div class={classNames('text-content-secondary', 'text-h4', $$props.class)}>
  <slot />
</div>
