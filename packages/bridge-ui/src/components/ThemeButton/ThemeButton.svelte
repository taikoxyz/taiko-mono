<script lang="ts">
  import { onMount } from 'svelte';

  import { Icon } from '$components/Icon';
  import { web3modal } from '$libs/connect';
  import { Theme, theme } from '$stores/theme';

  export let mobile = false;

  $: isDarkTheme = $theme === Theme.DARK;

  $: darkFill = isDarkTheme ? 'fill-grey-600' : 'fill-grey-0';
  $: lightFill = isDarkTheme ? 'fill-grey-0' : 'fill-grey-600';

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

{#if mobile}
  <label class="cursor-pointer grid place-items-center">
    <input
      type="checkbox"
      bind:checked={isDarkTheme}
      on:change={switchTheme}
      class="
                    toggle toggle-md toggle-grey-600 row-start-1 col-start-1 col-span-2 theme-controller
                      bg-grey-0 border-grey-600 [--tglbg:theme(colors.grey.600)] checked:bg-grey-0 checked:border-blue-800 checked:[--tglbg:theme(colors.grey.600)] hover:bg-grey-0
                    
                    " />
    <Icon type="moon" class="col-start-2 row-start-1" size={16} fillClass={darkFill} />
    <Icon type="sun" class="col-start-1 row-start-1" size={16} fillClass={lightFill} />
  </label>
{:else}
  <label class="swap swap-rotate">
    <input type="checkbox" class="border-none" bind:checked={isDarkTheme} on:change={switchTheme} />
    <Icon type="sun" class="fill-primary-icon swap-on " size={25} />
    <Icon type="moon" class="fill-primary-icon swap-off" size={25} />
  </label>
{/if}
