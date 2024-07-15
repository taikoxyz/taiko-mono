<script lang="ts">
  import { classNames } from '../../lib/util/classNames';
  const wrapperClasses = classNames(
    'w-full',
    'h-full',
    'flex',
    'flex-col',
    'items-center',
    'justify-center',
    $$props.class,
  );
</script>

<div class={wrapperClasses}>
  <slot />
</div>
