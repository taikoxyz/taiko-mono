import { toast } from '@zerodevx/svelte-toast'

export function success(message: string) {
  toast.push(message, {
    theme: {
      '--toastBackground': '#4caf50',
    },
  })
}

export function warning(message: string) {
  toast.push(message, {
    theme: {
      '--toastBackground': '#ff9800',
    },
  })
}

export function error(message: string) {
  toast.push(message, {
    theme: {
      '--toastBarHeight': '0',
      '--toastBackground': '#f44336',
    },
    initial: 0,
  })
}
