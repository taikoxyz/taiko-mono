<script lang="ts">
  import { classNames } from '$lib/util/classNames';

  import { CommonTextClasses } from './common';
</script>

<div class={classNames(CommonTextClasses, 'text-4xl', 'font-bold', $$props.class)}>
  <slot />
</div>
