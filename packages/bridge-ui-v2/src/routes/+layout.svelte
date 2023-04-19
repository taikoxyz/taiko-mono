<!-- Root component and entry point -->
<script lang="ts">
  import '../app.css'

  import { setContext } from 'svelte'
  import { writable } from 'svelte/store'

  import { Footer } from '../components/Footer'
  import { Header } from '../components/Header'
  import { WalletListModal } from '../components/modals/WalletListModal'

  // We should be able to open this modal from anywhere.
  // Let's make this context store available to all the children.
  const walletListModal = writable<WalletListModal>()
  setContext(WalletListModal.name, walletListModal)
</script>

<div class="container h-full mx-auto px-4 flex flex-col justify-between">
  <Header />
  <main class="flex-1">
    <slot />
  </main>
  <Footer />
</div>

<WalletListModal bind:this={$walletListModal} />
