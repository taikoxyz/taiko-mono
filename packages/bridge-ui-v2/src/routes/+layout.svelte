<script>
  import '../app.css'

  import { Footer } from '../components/Footer'
  import { Header } from '../components/Header'
</script>

<div>
  <Header />
  <main>
    <slot />
  </main>
  <Footer />
</div>
