<script lang="ts" context="module">
  import { toast } from '@zerodevx/svelte-toast';

  export function successToast() {
    toast.push('Success', {
      theme: {
        '--toastBackground': 'var(--positive-background)',
        '--toastColor': 'var(--positive-sentiment)',
      },
    });
  }

  export function errorToast() {
    toast.push('Error', {
      theme: {
        '--toastBackground': 'var(--negative-background)',
        '--toastColor': 'var(--negative-sentiment)',
      },
    });
  }

  export function warningToast() {
    toast.push('Warning', {
      theme: {
        '--toastBackground': 'var(--warning-background)',
        '--toastColor': 'var(--warning-sentiment)',
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
    classes: ['callout-regular'],
    theme: {
      '--toastBorderRadius': '9999px', // rounded-full
      '--toastPadding': '12px 20px',
      '--toastBarHeight': 0, // hides progress bar
      '--toastMsgPadding': 0,
    },
  };
</script>

<SvelteToast {options} />
