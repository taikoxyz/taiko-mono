<script>
  import '../app.css'

  import { Footer } from '../components/Footer'
  import { Header } from '../components/Header'
</script>

<div class="container mx-auto px-4 flex flex-col justify-between">
  <Header />
  <main class="flex-1">
    <slot />
  </main>
  <Footer />
</div>
