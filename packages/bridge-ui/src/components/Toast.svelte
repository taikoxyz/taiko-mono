<script lang="ts" context="module">
  import { toast } from '@zerodevx/svelte-toast';

  // Toast component exposes the following API:

  export const errorToast = (msg: string) => {
    toast.push(msg, {
      theme: {
        '--toastBackground': '#D32F2F',
      },
    });
  };

  export const successToast = (msg: string) => {
    toast.push(msg, {
      theme: {
        '--toastBarBackground': '#FC0FC0',
        '--toastBackground': '#4d4d4d',
      },
    });
  };
</script>

<script lang="ts">
  import { SvelteToast, type SvelteToastOptions } from '@zerodevx/svelte-toast';

  // TODO: props
  const toastOptions: SvelteToastOptions = {
    dismissable: false,
    duration: 4000,
    pausable: false,
  };

  // TODO: props to control its position:
  //       top, bottom, left, right...
</script>

<div class="toast">
  <SvelteToast options={toastOptions} />
</div>

<style>
  /* TODO: Small devices. We need design!! */
  .toast {
    --toastContainerRight: 1rem;
    --toastContainerBottom: auto;
    --toastContainerTop: 5rem;
    --toastWidth: 100%;
    --toastMinHeight: 2rem;
    --toastPadding: 0 0.5rem;
    --toastBorderRadius: 0.4rem;
    --toastColor: #e3e3e3;
  }

  /* 
    TODO: decides at which breakpoint we are no longer
          in small screens. Design!!
   */
  @media (min-width: 640px) {
    .toast {
      --toastWidth: 16rem;
    }
  }
</style>
