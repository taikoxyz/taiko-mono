<script lang="ts">
  import '../app.css';

  import Header from '@components/Header';
  import SideNavigation from '@components/SideNavigation';
</script>

<SideNavigation>
  <Header />
  <main class="md:px-10 md:py-7">
    <slot />
  </main>
</SideNavigation>
