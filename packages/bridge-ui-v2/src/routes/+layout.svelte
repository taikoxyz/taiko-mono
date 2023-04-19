<!-- Entry point component -->
<script lang="ts">
  import { writable } from 'svelte/store'
  import '../app.css'

  import { Footer } from '../components/Footer'
  import { Header } from '../components/Header'
  import { WalletListModal } from '../components/WalletListModal'
  import { setContext } from 'svelte'

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
