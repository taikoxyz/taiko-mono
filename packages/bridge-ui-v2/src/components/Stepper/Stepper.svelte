<script lang="ts">
  import DesktopOrLarger from '$components/DesktopOrLarger/DesktopOrLarger.svelte';
  import { classNames } from '$libs/util/classNames';
  export let activeStep: number = 0;

  const styles = `
  md:w-[524px]
    w-full 
    md:card 
    md:rounded-[20px] 
    md:border 
    md:border-divider-border
    md:glassy-gradient-card
    dark:md:dark-glass-background-gradient
    light:md:light-glass-background-gradient
    `;
  let isDesktopOrLarger = false;

  $: classes = classNames(styles, $$props.class);
  $: dynamicAttrs = isDesktopOrLarger ? { 'data-glow-border': true } : {};
</script>

<div class={classes}>
  <div {...dynamicAttrs} class="card-body body-regular gap-0 p-0">
    <ul class="steps md:mb-[30px] mt-[30px]">
      <slot {activeStep} />
    </ul>
  </div>
</div>

<DesktopOrLarger bind:is={isDesktopOrLarger} />
