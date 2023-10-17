<script lang="ts" context="module">
  import { toast } from '@zerodevx/svelte-toast';

  import { toastConfig } from '$config';
  import { uid } from '$libs/util/uid';

  import ItemToast from './ItemToast.svelte';
  import type { TypeToast } from './types';

  export type NotificationType = {
    title: string;
    message?: string;
    type?: TypeToast;
    closeManually?: boolean;
  };

  export function notify(notificationType: NotificationType) {
    const id = Number(uid());
    const close = () => toast.pop(id);
    const { title, message, type = 'unknown', closeManually = false } = notificationType;

    toast.push({
      id,
      ...(closeManually ? { initial: 0 } : {}),
      component: {
        src: ItemToast,
        props: { type, title, message, close },
      },
    });
  }

  export function successToast(notificationType: NotificationType) {
    notify({
      ...notificationType,
      type: 'success',
      closeManually: false
    });
  }

  export function errorToast(notificationType: NotificationType) {
    notify({
      ...notificationType,
      type: 'error',
      closeManually: true
    });
  }

  export function warningToast(notificationType: NotificationType) {
    notify({
      ...notificationType,
      type: 'warning',
      closeManually: false
    });
  }

  export function infoToast(notificationType: NotificationType) {
    notify({
      ...notificationType,
      type: 'info',
      closeManually: false
    });
  }
</script>

<script lang="ts">
  import { SvelteToast } from '@zerodevx/svelte-toast';
  import type { SvelteToastOptions } from '@zerodevx/svelte-toast/stores';

  const options: SvelteToastOptions = {
    duration: toastConfig.duration,
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
