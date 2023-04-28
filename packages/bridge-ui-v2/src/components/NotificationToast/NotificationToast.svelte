<script lang="ts">
  import type { ToastProps } from 'flowbite-svelte/dist/toasts/Toast.svelte'
  import { Toast } from 'flowbite-svelte'

  export let color: ToastProps['color'] = 'gray'
  export let simple = true
  export let position: ToastProps['position'] = 'top-right'
  export let autohideTimeout = 6000

  let toastProps: ToastProps = {
    color,
    simple,
    position,
    open: false,
  }

  let message: string = ''

  export function hide() {
    toastProps = {
      ...toastProps,
      open: false,
    }
  }

  export function show(msg: string, _toastProps: ToastProps) {
    message = msg
    toastProps = {
      ..._toastProps,
      open: true,
    }
  }

  function autohide() {
    setTimeout(() => hide(), autohideTimeout)
  }

  export function showWithAutohide(msg: string, _toastProps: ToastProps) {
    show(msg, _toastProps)
    autohide()
  }

  export function success(msg: string) {
    showWithAutohide(msg, { ...toastProps, color: 'green' })
  }

  export function error(msg: string) {
    show(msg, {
      ...toastProps,
      color: 'red',
      simple: false, // user will have to close it manually
    })
  }

  export function warning(msg: string) {
    showWithAutohide(msg, { ...toastProps, color: 'yellow' })
  }
</script>

<Toast {...toastProps}>{message}</Toast>
