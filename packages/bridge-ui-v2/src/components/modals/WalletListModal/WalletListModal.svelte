<script>
  import { Modal } from '../Modal'

  let open = false

  export function show() {
    open = true
  }

  export function hide() {
    open = false
  }
</script>

<Modal closeable bind:open>TODO: List of wallets</Modal>
