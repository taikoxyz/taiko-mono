<script lang="ts">
  import { LottiePlayer } from '@lottiefiles/svelte-lottie-player';

  export let width = 26;
  export let height = 26;
</script>

<LottiePlayer
  src="/lottie/loader.json"
  autoplay={true}
  loop={true}
  controls={false}
  renderer="svg"
  background="transparent"
  {height}
  {width}
  controlsLayout={[]} />
