<script lang="ts">
  import { classNames } from '$libs/util/classNames';

  export let active = false;
  export let href = '/';
  export let external = false;

  $: activeClass = active
    ? 'body-bold bg-primary-interactive hover:bg-primary-interactive-hover'
    : 'body-regular hover:bg-secondary-interactive-hover';

  $: classes = classNames('p-3 rounded-full flex justify-start content-center', activeClass, $$props.class);
</script>

<a {href} target={external ? '_blank' : null} class={classes}>
  <slot />
</a>
