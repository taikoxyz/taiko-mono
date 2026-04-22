<script lang="ts">
  import { classNames } from '$lib/util/classNames';
  const chipClasses = classNames('rounded-full', 'bg-primary', 'text-white', 'px-4', 'py-1');
</script>

<span class={chipClasses}>
  <slot />
</span>
