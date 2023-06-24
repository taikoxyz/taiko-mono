<script lang="ts">
  import '../app.css';

  import Header from '$components/Header';
  import SideNavigation from '$components/SideNavigation';
</script>

<SideNavigation>
  <Header />
  <main class="flex justify-center md:px-10 md:py-7 mt-8 md:mt-14">
    <slot />
  </main>
</SideNavigation>
