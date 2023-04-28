<script lang="ts">
  import { getContext } from 'svelte'
  import { NotificationToast } from '../components/NotificationToast'
  import type { Writable } from 'svelte/store'

  const notificationToast = getContext<Writable<NotificationToast>>(NotificationToast.name)
</script>

<h1>Bridge UI</h1>

<button on:click={() => $notificationToast.success('Success message')}>Success</button>
<button on:click={() => $notificationToast.warning('Warning message')}>Warning</button>
<button on:click={() => $notificationToast.error('Error message')}>Error</button>
