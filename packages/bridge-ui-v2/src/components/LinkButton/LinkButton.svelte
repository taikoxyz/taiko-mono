<script lang="ts">
  import { classNames } from '$libs/classNames';

  export let active = false;
  export let href = '/';
  export let external = false;

  $: activeClass = active ? 'bg-primary-interactive hover:bg-primary-interactive-hover' : '';
</script>

<a
  {href}
  target={external ? '_blank' : null}
  class={classNames('btn btn-sm md:btn-md btn-ghost p-3 rounded-full body-bold flex justify-start content-center', activeClass)}>
  <slot />
</a>
