<script lang="ts" context="module">
  import { toast } from '@zerodevx/svelte-toast';

  // Toast component exposes the following API:

  export const errorToast = (msg: string) => {
    toast.push(msg, {
      theme: {
        '--toastBackground': '#FF0000',
        '--toastColor': '#e3e3e3',
      },
    });
  };

  export const successToast = (msg: string) => {
    toast.push(msg, {
      theme: {
        '--toastBarBackground': '#fc0fc0',
        '--toastBackground': '#4d4d4d',
        '--toastColor': '#e3e3e3',
      },
    });
  };
</script>

<script lang="ts">
  import { SvelteToast, type SvelteToastOptions } from '@zerodevx/svelte-toast';

  const toastOptions: SvelteToastOptions = {
    dismissable: false,
    duration: 4000,
    pausable: false,
  };
</script>

<div class="toast">
  <SvelteToast options={toastOptions} />
</div>

<style>
  /* TODO: Small devices. We need design!! */
  .toast {
    --toastContainerRight: 0.5rem;
    --toastContainerBottom: auto;
    --toastContainerLeft: 0.5rem;
    --toastWidth: 100%;
    --toastMinHeight: 2rem;
    --toastPadding: 0 0.5rem;
    --toastBorderRadius: 0.4rem;
  }

  /* 
    TODO: decides at which breakpoint we are no longer
          in small screens. Design!!
   */
  @media (min-width: 640px) {
    .toast {
      --toastContainerRight: auto;
      --toastContainerLeft: calc(50vw - 8rem);
      --toastWidth: 16rem;
    }
  }
</style>
