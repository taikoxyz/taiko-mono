<script lang="ts">
  import '../app.css';
</script>

<svelte:head>
  <script>
    // On page load or when changing themes, best to add inline in `head` to avoid FOUC
    if (
      localStorage.theme === 'dark' ||
      (!('theme' in localStorage) && window.matchMedia('(prefers-color-scheme: dark)').matches)
    ) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  </script>
</svelte:head>

<div class="container">
  <header />
  <main>
    <slot />
  </main>
  <footer />
</div>
