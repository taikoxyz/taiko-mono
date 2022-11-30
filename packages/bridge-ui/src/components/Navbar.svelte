<script>
  import Connect from "./buttons/Connect.svelte";
  import Logo from "./icons/Logo.svelte";
  import { signer } from "../store/signer";
  import AddressDropdown from "./AddressDropdown.svelte";
</script>

<nav class="navbar h-[125px] py-8 px-32">
  <div class="navbar-end justify-start">
    <Logo />
  </div>
  <div class="navbar-end">
    {#if $signer}
      <AddressDropdown />
    {:else}
      <Connect />
    {/if}
  </div>
</nav>
