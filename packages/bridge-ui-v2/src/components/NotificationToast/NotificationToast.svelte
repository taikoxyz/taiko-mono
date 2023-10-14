<script lang="ts" context="module">
  import { toast } from '@zerodevx/svelte-toast';

  import { uid } from '$libs/util/uid';

  import ItemToast from './ItemToast.svelte';
  import type { TypeToast } from './types';

  // Public API

  export function notify(title: string, message: string = '', type: TypeToast = 'unknown', closeManually = false) {
    const id = Number(uid());
    const close = () => toast.pop(id);

    toast.push({
      id,
      ...(closeManually ? { initial: 0 } : {}),
      component: {
        src: ItemToast,
        props: { type, title, message, close },
      },
    });
  }

  export function successToast(title: string, message: string = '', closeManually = false) {
    notify(title, message, 'success', closeManually);
  }

  export function errorToast(title: string, message: string = '', closeManually = true) {
    notify(title, message, 'error', closeManually);
  }

  export function warningToast(title: string, message: string = '', closeManually = false) {
    notify(title, message, 'warning', closeManually);
  }

  export function infoToast(title: string, message: string = '', closeManually = false) {
    notify(title, message, 'info', closeManually);
  }
</script>

<script lang="ts">
  import { SvelteToast } from '@zerodevx/svelte-toast';
  import type { SvelteToastOptions } from '@zerodevx/svelte-toast/stores';

  const options: SvelteToastOptions = {
    duration: 5000,
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
    --toastContainerLeft: calc(50vw - 160px);
    --toastBoxShadow: none;
    --toastWidth: 339px;

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
