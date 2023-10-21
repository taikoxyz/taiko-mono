<script lang="ts">
  import { onMount } from 'svelte';

  import { Icon } from '$components/Icon';

  let theme: 'dark' | 'light' = (localStorage.getItem('theme') as 'dark' | 'light') || 'dark';
  $: isDarkTheme = theme === 'dark';

  function switchTheme() {
    const currentTheme = localStorage.getItem('theme')?.toLocaleLowerCase() || 'dark';
    theme = currentTheme === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('theme', theme);
  }

  onMount(() => {
    const current = localStorage.getItem('theme');
    if (!current || (current !== 'dark' && current !== 'light')) {
      theme = 'dark';
    } else {
      theme = current as 'dark' | 'light';
    }
  });
</script>

<label class="swap swap-rotate">
  <input type="checkbox" class="border-none" bind:checked={isDarkTheme} on:change={switchTheme} />
  <Icon type="sun" class="fill-primary-icon swap-on" width={25} height={25} vHeight={25} vWidth={25} />
  <Icon type="moon" class="fill-primary-icon swap-off" width={25} height={25} vHeight={25} vWidth={25} />
</label>
