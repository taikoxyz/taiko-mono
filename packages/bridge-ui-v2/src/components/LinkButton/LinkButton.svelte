<script lang="ts">
  import { Icon } from '$components/Icon';
  import { classNames } from '$libs/util/classNames';

  export let active = false;
  export let href = '/';
  export let external = false;

  $: activeClass = active
    ? 'body-bold bg-primary-interactive hover:bg-primary-interactive-hover'
    : 'body-regular hover:bg-secondary-interactive-hover';
</script>

<a
  {href}
  target={external ? '_blank' : null}
  class={classNames('p-3 rounded-full flex justify-start content-center', activeClass, $$props.class)}>
  <slot />
  {#if external}
    <Icon type="arrow-top-right" flillClass="fill-white" />
  {/if}
</a>
