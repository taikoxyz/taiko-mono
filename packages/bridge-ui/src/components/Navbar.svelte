<script lang="ts">
  import Connect from "./buttons/Connect.svelte";
  import Logo from "./icons/Logo.svelte";
  import { signer } from "../store/signer";
  import AddressDropdown from "./AddressDropdown.svelte";
  import ChainDropdown from "./ChainDropdown.svelte";
</script>

<nav class="navbar mb-4 md:h-[125px] pt-4 md:pt-0 md:px-4 w-full">
  <div class="navbar-end justify-start">
    <Logo />
  </div>
  <div class="navbar-end">
    {#if $signer}
      <ChainDropdown />
      <AddressDropdown />
    {:else}
      <Connect />
    {/if}
  </div>
</nav>
