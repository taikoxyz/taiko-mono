<script lang="ts">
  import { onMount } from 'svelte';

  import { Button } from '$components/Button';
  import { Icon } from '$components/Icon';

  function switchTheme() {
    let darkTheme = localStorage.getItem('theme')?.toLocaleLowerCase() === 'dark';
    if (typeof darkTheme === 'undefined') return;

    const newTheme = darkTheme ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', newTheme);
    localStorage.setItem('theme', newTheme);
  }

  onMount(() => {
    darkTheme = localStorage.getItem('theme')?.toLocaleLowerCase() === 'dark';
  });

</script>

<div class="flex items-center">
  <Button class="bg-transparent hover:bg-transparent bg-primary-base-background rounded-none ml-[8px] pl-[8px] pr-[0px] border-l-2 border-gray-800/10 hover:border-gray-800/10" on:click={switchTheme}>
    <Icon type="heroicons" />
  </Button>
</div>