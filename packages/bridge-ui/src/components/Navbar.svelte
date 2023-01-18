<script lang="ts">
  import Connect from "./buttons/Connect.svelte";
  import TaikoLogo from "./icons/TaikoLogo.svelte";
  import TaikoLight from "./icons/TaikoLight.svelte";
  import { signer } from "../store/signer";
  import AddressDropdown from "./AddressDropdown.svelte";
  import ChainDropdown from "./ChainDropdown.svelte";
  import TaikoLogoFluo from "./icons/TaikoLogoFluo.svelte";
  import { Sun, Moon } from "svelte-heros-v2";
  import { fly } from 'svelte/transition';

  let isDarkMode = localStorage.getItem('theme') === 'dark';

  function switchToLightMode() {
    if (!document) {
      return;
    }
    document.documentElement.setAttribute("data-theme", "light")
    localStorage.setItem('theme', 'light');
    isDarkMode = false;
  }

  function switchToDarkMode() {
    if (!document) {
      return;
    }
    document.documentElement.setAttribute("data-theme", "dark")
    localStorage.setItem('theme', 'dark');
    isDarkMode = true;
  }
</script>

<div class="navbar bg-base-100">
  <div class="flex-1">
    <span class="taiko-light-logo">
      <TaikoLight width={120} />
    </span>
    <span class="taiko-logo">
      <TaikoLogo width={120} />
    </span>
    <span class="md:hidden">
      <TaikoLogoFluo width={50} />
    </span>
  </div>
  <div class="flex-none">
    {#if $signer}
      <ChainDropdown />
      <AddressDropdown />
    {:else}
      <Connect />
    {/if}

    <div class="ml-2">
      {#if isDarkMode}
        <button in:fly="{{ y: 10, duration: 500 }}" class="btn btn-sm btn-circle">
          <Moon on:click={switchToLightMode} />
        </button>
      {:else}
        <button in:fly="{{ y: 10, duration: 500 }}" class="btn btn-sm btn-circle bg-base-100 hover:bg-base-100 text-neutral border-none">
          <Sun on:click={switchToDarkMode} class="text-gray-800" />
        </button>
      {/if}
    </div>
  </div>
</div>
