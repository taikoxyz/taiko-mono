<script lang="ts">
  import { classNames } from '../../../lib/util/classNames';

  const styles = classNames(
    'w-full',
    'h-min',
    'my-7',
    //'card',
    //'rounded-[20px]',
    //'border',
    //'border-divider-border',
    //'glassy-gradient-card',
    //'shadow-card',
    //'bg-elevated-background'
    'card ',
    'rounded-[20px] ',
    'border ',
    'glassy-background-md',
  );

  export let title: string = '';
  export let text = '';

  let isDesktopOrLarger = false;
  $: dynamicAttrs = isDesktopOrLarger ? { 'data-glow-border': true } : {};

  $: classes = classNames(styles, $$props.class);
</script>

<div class={classes}>
  <div
    {...dynamicAttrs}
    class="card-body
        body-regular
        ">
    {#if title}
      <h2 class="card-title title-screen-bold">{title}</h2>
    {/if}
    {#if text}
      <p class="text-secondary-content">{text}</p>
    {/if}
    <slot />
  </div>
</div>
