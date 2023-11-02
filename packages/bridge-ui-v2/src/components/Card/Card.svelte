<script lang="ts">
  import { classNames } from '$libs/util/classNames';

  const styles = `
    w-full 
    md:card 
    md:rounded-[20px] 
    md:border 
    md:border-divider-border
    dark:md:glassy-gradient-card
    dark:md:glass-background-gradient`;

  export let title: string = '';
  export let text = '';

  $: classes = classNames(styles, $$props.class);
</script>

<div class={classes}>
  <div class="card-body body-regular p-4 md:p-[50px] gap-0">
    {#if title}
      <h2 class="card-title title-screen-bold">{title}</h2>
    {/if}
    {#if text}
      <p>{text}</p>
    {/if}
    <div class="f-col">
      <slot />
    </div>
  </div>
</div>
