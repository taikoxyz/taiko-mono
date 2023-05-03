<script lang="ts">
  import { SvelteToast, type SvelteToastOptions } from '@zerodevx/svelte-toast'

  export let options: SvelteToastOptions = {
    dismissable: true,
    duration: 4000,
    pausable: false,
  }
</script>

<SvelteToast {options} />
