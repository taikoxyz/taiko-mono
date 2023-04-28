<script lang="ts">
  import '../app.css'

  import { Footer } from '../components/Footer'
  import { Header } from '../components/Header'
  import { NotificationToast } from '../components/NotificationToast'
  import { WalletListModal } from '../components/WalletListModal'
</script>

<div class="container h-full mx-auto px-4 flex flex-col justify-between relative">
  <Header />
  <main class="flex-1">
    <slot />
  </main>
  <Footer />

  <WalletListModal />
  <NotificationToast />
</div>
