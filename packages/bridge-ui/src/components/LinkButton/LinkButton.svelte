<script lang="ts">
  import { Icon } from '$components/Icon';
  import { classNames } from '$libs/util/classNames';

  export let active = false;
  export let href = '/';
  export let external = false;

  $: activeClass = active
    ? 'body-bold bg-primary-interactive text-grey-10 hover:!bg-primary-interactive hover:!text-grey-10'
    : 'body-regular hover:bg-primary-interactive-hover';

  $: classes = classNames('p-3 rounded-full flex justify-start content-center', activeClass, $$props.class);
</script>

<a {href} target={external ? '_blank' : null} class={classes}>
  <slot />
  {#if external}
    <div class="flex flex-grow justify-end">
      <Icon type="arrow-top-right" class="justify-self-end" />
    </div>
  {/if}
</a>
