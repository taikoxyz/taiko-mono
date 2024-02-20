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

  const closeManuallyDefaults: Record<TypeToast, boolean> = {
    // Defaults when no value was provided for closeManually
    success: false,
    error: true,
    warning: false,
    info: false,
    unknown: false,
  };

  function getDefaultCloseBehaviour(type: TypeToast): boolean {
    return closeManuallyDefaults[type];
  }

  export function notify(notificationType: NotificationType) {
    const id = Number(uid());
    const close = () => toast.pop(id);
    const { title, message, type = 'unknown', closeManually = getDefaultCloseBehaviour(type) } = notificationType;

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
    });
  }

  export function errorToast(notificationType: NotificationType) {
    notify({
      ...notificationType,
      type: 'error',
    });
  }

  export function warningToast(notificationType: NotificationType) {
    notify({
      ...notificationType,
      type: 'warning',
    });
  }

  export function infoToast(notificationType: NotificationType) {
    notify({
      ...notificationType,
      type: 'info',
    });
  }
</script>

<script lang="ts">
  import { SvelteToast } from '@zerodevx/svelte-toast';
  import type { SvelteToastOptions } from '@zerodevx/svelte-toast/stores';

  const options: SvelteToastOptions = {
    duration: toastConfig.duration,
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
      We need to makes the surroundings disappear in order
      to fully customize the toast with our own component
    */
    --toastBackground: transparent;
    --toastPadding: 0;
    --toastMsgPadding: 0;
    --toastBarWidth: 0;
    --toastBarHeight: 1;
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
