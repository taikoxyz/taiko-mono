<script lang="ts" context="module">
  import { toast } from '@zerodevx/svelte-toast';

  import { uid } from '$libs/util/uid';

  import ItemToast from './ItemToast.svelte';
  import type { TypeToast } from './types';

  // Public API

  export function notify(message: string, type: TypeToast = 'unknown', closeManually = false) {
    const id = Number(uid());
    const close = () => toast.pop(id);

    toast.push({
      id,
      ...(closeManually ? { initial: 0 } : {}),
      component: {
        src: ItemToast,
        props: { type, message, close },
      },
    });
  }

  export function successToast(message: string) {
    notify(message, 'success');
  }

  export function errorToast(message: string) {
    notify(message, 'error', true);
  }

  export function warningToast(message: string) {
    notify(message, 'warning');
  }
</script>

<script lang="ts">
  import { SvelteToast } from '@zerodevx/svelte-toast';
  import type { SvelteToastOptions } from '@zerodevx/svelte-toast/stores';

  const options: SvelteToastOptions = {
    duration: 5000, // TODO: config file?
    pausable: false,
  };
</script>

<div class="NotificationToast">
  <SvelteToast {options} />
</div>

<style>
  .NotificationToast {
    --toastContainerRight: auto;
    --toastContainerBottom: auto;
    --toastContainerTop: 77px;
    --toastContainerLeft: calc(50vw - 150px);
    --toastWidth: 300px;

    /*
      We need to makes the surroundings dissapear in order
      to fully customize the toast with our own component
    */
    --toastBackground: transparent;
    --toastPadding: 0;
    --toastMsgPadding: 0;
    --toastBarWidth: 0;
    --toastBarHeight: 0;
    --toastBtnWidth: 0;
    --toastBtnHeight: 0;
    --toastBtnContent: '';
  }

  /* sm */
  @media (min-width: 640px) {
    .NotificationToast {
      --toastContainerLeft: auto;
      --toastContainerRight: 1rem;
    }
  }

  /* md */
  @media (min-width: 768px) {
    .NotificationToast {
      --toastContainerRight: 2.5rem;
    }
  }
</style>
