<script lang="ts">
  import { classNames } from '$libs/util/classNames';

  const styles = `
      md:card 
      w-full 
      md:rounded-xl 
      md:border 
      md:border-gray-700 
      md:bg-gradient-to-r from-glass-gradient-from to-glass-gradient-to 
      backdrop-blur-sm
      md:bg-gray-800/30`;

  export let title: string;
  export let text = '';

  $: classes = classNames(styles, $$props.class);
</script>

<div class={classes}>
  <div class="card-body body-regular p-0 md:p-[50px]">
    <h2 class="card-title title-screen-bold">{title}</h2>
    {#if text}
      <p>{text}</p>
    {/if}
    <div class="f-col mt-[35px]">
      <slot />
    </div>
  </div>
</div>
