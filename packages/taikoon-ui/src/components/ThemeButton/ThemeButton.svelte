<script lang="ts">
  import { onMount } from 'svelte';

  import { Icons } from '$ui/Icons';
  const { Moon, Sun } = Icons;

  import { classNames } from '$lib/util/classNames';

  import { web3modal } from '../../lib/connect';
  import { Theme, theme } from '../../stores/theme';

  $: isDarkTheme = $theme === Theme.DARK;

  export let size: 'sm' | 'md' | 'lg' = 'md';

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

  $: iconSize = size === 'sm' ? 16 : size === 'md' ? 20 : size === 'lg' ? 48 : 0;

  const wrapperClasses = classNames('swap swap-rotate');

  const inputClasses = classNames('border-none');
  const moonClasses = classNames('swap-off  fill-icon-primary');
  const sunClasses = classNames('swap-on fill-icon-primary');
</script>

<label class={wrapperClasses}>
  <input type="checkbox" class={inputClasses} bind:checked={isDarkTheme} on:change={switchTheme} />
  <Moon size={iconSize} class={moonClasses} />
  <Sun size={iconSize} class={sunClasses} />
</label>
