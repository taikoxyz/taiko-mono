<script>
  import '../app.css'
  import Header from '../components/Header'
  import Footer from '../components/Footer'
</script>

<div class="layout">
  <Header />
  <main>
    <slot />
  </main>
  <Footer />
</div>
