<script lang="ts">
  import { classNames } from '../../libs/classNames';

  type LinkTarget = '_blank' | '_self';

  export let active = false;
  export let href = '/';
  export let target: LinkTarget = '_self';

  $: activeClass = active ? 'bg-primary-interactive hover:bg-primary-interactive-hover' : '';
</script>

<a {href} {target} class={classNames('btn rounded-full body-bold flex justify-start content-center', activeClass)}>
  <slot />
</a>
