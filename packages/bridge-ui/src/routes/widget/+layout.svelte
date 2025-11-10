<script lang="ts">
  import '../../app.css';
  import '../../i18n';

  import { onDestroy, onMount } from 'svelte';

  import { browser } from '$app/environment';
  import { page } from '$app/stores';
  import { SwitchChainModal } from '$components/SwitchChainModal';
  import { startWatching, stopWatching } from '$libs/wagmi';
  import { bridgePausedModal } from '$stores/modal';

  // Allowed DaisyUI themes
  const ALLOWED_THEMES = [
    'light',
    'dark',
    'cupcake',
    'bumblebee',
    'emerald',
    'corporate',
    'synthwave',
    'retro',
    'cyberpunk',
    'valentine',
    'halloween',
    'garden',
    'forest',
    'aqua',
    'lofi',
    'pastel',
    'fantasy',
    'wireframe',
    'black',
    'luxury',
    'dracula',
    'cmyk',
    'autumn',
    'business',
    'acid',
    'lemonade',
    'night',
    'coffee',
    'winter',
    'dim',
    'nord',
    'sunset',
  ];

  // Get theme from URL query parameter (defaults to null), validate against allowed themes
  $: {
    const themeParam = $page.url.searchParams.get('theme');
    theme = themeParam && ALLOWED_THEMES.includes(themeParam) ? themeParam : null;
  }

  let theme: string | null = null;

  onMount(async () => {
    // Disable the bridge paused modal for widget
    bridgePausedModal.set(false);

    await startWatching();

    // Apply DaisyUI theme to html element
    if (browser && theme) {
      document.documentElement.setAttribute('data-theme', theme);
    }
  });

  onDestroy(() => {
    stopWatching();
  });
</script>

<!-- Minimal widget layout without header/sidebar -->
<main class="h-screen flex items-start justify-center p-0 bg-base-100">
  <slot />
</main>

<!-- Global modals (no toasts or BridgePausedModal for widget) -->
<SwitchChainModal />

<style>
  /* Override all responsive styling in widget - force mobile appearance */
  :global(.steps) {
    background: transparent !important;
    background-image: none !important;
    border: none !important;
    border-radius: 0 !important;
  }

  /* Prevent background image flash on page load and disable scrolling */
  :global(body) {
    background: hsl(var(--b1)) !important;
    background-color: hsl(var(--b1)) !important;
    background-image: none !important;
    overflow: hidden !important;
  }

  :global(html) {
    background: hsl(var(--b1)) !important;
    background-color: hsl(var(--b1)) !important;
    background-image: none !important;
    overflow: hidden !important;
  }

  :global(body::before),
  :global(body::after) {
    display: none !important;
  }

  /* Disable glow effects on all elements */
  :global(*),
  :global(*:hover),
  :global(*::before),
  :global(*::after),
  :global(.steps),
  :global(.steps:hover),
  :global(.steps::before),
  :global(.steps::after),
  :global([data-glow-border]),
  :global([data-glow-border]:hover),
  :global([data-glow-border]::before),
  :global([data-glow-border]::after),
  :global(.card),
  :global(.card:hover),
  :global(.card::before),
  :global(.card::after) {
    box-shadow: none !important;
    filter: none !important;
    text-shadow: none !important;
  }

  main {
    overflow: hidden !important;
  }
</style>
