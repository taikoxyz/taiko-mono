<script lang="ts">
  import { onMount } from 'svelte';

  import { Button } from '$components/Button';
  import { Icon } from '$components/Icon';

  let theme: 'dark' | 'light' = 'dark';
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

<div class="flex items-center">
  <Button class="bg-transparent hover:bg-neutral rounded-full p-[5px] rounded-full" on:click={switchTheme}>
    <Icon type={isDarkTheme ? 'moon' : 'sun'} width={25} height={25} />
  </Button>
</div>
