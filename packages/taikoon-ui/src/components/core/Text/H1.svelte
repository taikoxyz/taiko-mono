<script lang="ts">
  import { classNames } from '$lib/util/classNames';

  import { CommonTextClasses } from './common';
</script>

<div class={classNames(CommonTextClasses, 'text-5xl', 'font-semibold', $$props.class)}>
  <slot />
</div>
