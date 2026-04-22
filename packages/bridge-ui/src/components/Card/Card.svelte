<script lang="ts">
  import DesktopOrLarger from '$components/DesktopOrLarger/DesktopOrLarger.svelte';
  import { classNames } from '$libs/util/classNames';

  const styles = `
    w-full 
    md:card 
    md:rounded-[20px] 
    md:border 
    md:border-divider-border
    md:glassy-gradient-card
    dark:md:dark-glass-background-gradient
    light:md:light-glass-background-gradient
    `;

  export let title: string = '';
  export let text = '';

  let isDesktopOrLarger = false;
  $: dynamicAttrs = isDesktopOrLarger ? { 'data-glow-border': true } : {};

  $: classes = classNames(styles, $$props.class);
</script>

<div class={classes}>
  <div {...dynamicAttrs} class="card-body body-regular px-4 md:p-[50px] gap-0 py-0 md:mt-[0px] mt-[40px]">
    {#if title}
      <h2 class="card-title title-screen-bold">{title}</h2>
    {/if}
    {#if text}
      <p class="text-secondary-content">{text}</p>
    {/if}
    <div class="f-col">
      <slot />
    </div>
  </div>
</div>

<DesktopOrLarger bind:is={isDesktopOrLarger} />
