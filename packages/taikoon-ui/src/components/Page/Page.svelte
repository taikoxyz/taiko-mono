<script lang="ts">
  import { classNames } from '../../lib/util/classNames';
</script>

<div class={classNames('w-full', 'h-full', 'flex', 'flex-col', 'items-center', 'justify-center', $$props.class)}>
  <slot />
</div>
