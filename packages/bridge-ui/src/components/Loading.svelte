<script lang="ts">
  import { LottiePlayer } from '@lottiefiles/svelte-lottie-player';

  export let width = 26;
  export let height = 26;
  export let text = '';

  const lottieProps = {
    height,
    width,
    loop: true,
    autoplay: true,
    controls: false,
    renderer: 'svg',
    controlsLayout: [],
    background: 'transparent',
    src: '/lottie/loader.json',
  };
</script>

<div class="flex space-x-1 items-center">
  <!-- TODO: hmmm, why do we even use lottie? -->
  <LottiePlayer {...lottieProps} />

  {#if text}
    <span>{text}</span>
  {/if}
</div>
