<script lang="ts">
  import {
    error as notifyError,
    success as notifySuccess,
    warning as notifyWarning,
  } from '../components/NotificationToast'
</script>

<h1>Bridge UI</h1>

<button on:click={() => notifySuccess('Success message')}>Success</button>
<button on:click={() => notifyWarning('Warning message')}>Warning</button>
<button on:click={() => notifyError('Error message')}>Error</button>
