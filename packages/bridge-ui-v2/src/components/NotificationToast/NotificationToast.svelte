<script lang="ts" context="module">
  import { toast } from '@zerodevx/svelte-toast';
  import ItemToast from './ItemToast.svelte';

  export function successToast(message: string) {
    toast.push({
      component: {
        src: ItemToast,
        props: {
          message,
          type: 'success',
        },
      },
    });
  }

  export function errorToast(message: string) {
    toast.push({
      component: {
        src: ItemToast,
        props: {
          message,
          type: 'error',
        },
      },
    });
  }

  export function warningToast(message: string) {
    toast.push({
      component: {
        src: ItemToast,
        props: {
          message,
          type: 'warning',
        },
      },
    });
  }
</script>

<script lang="ts">
  import { SvelteToast } from '@zerodevx/svelte-toast';
  import type { SvelteToastOptions } from '@zerodevx/svelte-toast/stores';

  const options: SvelteToastOptions = {
    duration: 100000,
    pausable: false,
    theme: {
      '--toastBackground': 'transparent',
      '--toastPadding': 0,
      '--toastBarHeight': 0, // hides progress bar
      '--toastMsgPadding': 0,
      '--toastBtnWidth': 0,
      '--toastBtnHeight': 0,
      '--toastBtnContent': '',
    },
  };
</script>

<SvelteToast {options} />
