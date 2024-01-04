<script lang="ts">
  import { onMount } from 'svelte';

  import { Icon } from '$components/Icon';
  import { web3modal } from '$libs/connect';
  import { Theme, theme } from '$stores/theme';

  $: isDarkTheme = $theme === Theme.DARK;

  function switchTheme() {
    const currentTheme = $theme;
    const newTheme = currentTheme === Theme.DARK ? Theme.LIGHT : Theme.DARK;
    document.documentElement.setAttribute('data-theme', newTheme);
    localStorage.setItem('theme', newTheme);
    web3modal.setThemeMode(newTheme);
    $theme = newTheme;
  }

  onMount(() => {
    const current = localStorage.getItem('theme');
    if (!current || (current !== Theme.DARK && current !== Theme.LIGHT)) {
      $theme = Theme.DARK;
    } else {
      $theme = current as Theme;
    }
  });
</script>

<label class="swap swap-rotate">
  <input type="checkbox" class="border-none" bind:checked={isDarkTheme} on:change={switchTheme} />
  <Icon type="sun" class="fill-primary-icon swap-on " size={25} />
  <Icon type="moon" class="fill-primary-icon swap-off" size={25} />
</label>
