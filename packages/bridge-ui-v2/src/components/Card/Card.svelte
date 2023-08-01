<script lang="ts">
  import { classNames } from '$libs/util/classNames';

  const desktopStyle = `card 
      w-full 
      rounded-xl 
      md:border 
      md:border-gray-700 
      bg-gradient-to-r from-glass-gradient-from to-glass-gradient-to 
      backdrop-blur-sm
      bg-gray-800/30 `;

  const mobileStyle = 'backdrop-blur p-5';

  export let isMobile = false;

  export let title: string;
  export let text = '';

  // export let classes = classNames(isMobile ? mobileStyle : desktopStyle, $$props.class);
  $: classes = classNames(isMobile ? mobileStyle : desktopStyle, $$props.class);
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
