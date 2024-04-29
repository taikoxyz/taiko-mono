<script lang="ts">
  import { classNames } from '$lib/util/classNames';

  import { CommonTextClasses } from './common';
</script>

<div class={classNames(CommonTextClasses, 'font-medium', 'text-h0', $$props.class)}>
  <slot />
</div>
