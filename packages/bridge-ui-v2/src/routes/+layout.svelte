<!-- Root component and entry point -->
<script lang="ts">
  import '../app.css'

  import { setContext } from 'svelte'
  import { writable } from 'svelte/store'

  import { Footer } from '../components/Footer'
  import { Header } from '../components/Header'
  import { WalletListModal } from '../components/WalletListModal'
  import { NotificationToast } from '../components/NotificationToast'

  // We should be able to open this modal from anywhere.
  // Let's make the modal instance available to all the children
  // via context.

  const walletListModal = writable<WalletListModal>()
  setContext(WalletListModal.name, walletListModal)

  const notificationToast = writable<NotificationToast>()
  setContext(NotificationToast.name, notificationToast)
</script>

<div class="container h-full mx-auto px-4 flex flex-col justify-between relative">
  <Header />
  <main class="flex-1">
    <slot />
  </main>
  <Footer />

  <WalletListModal bind:this={$walletListModal} />
  <NotificationToast bind:this={$notificationToast} />
</div>
