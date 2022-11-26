<script>
  import Connect from "./buttons/Connect.svelte";
  import Logo from "./icons/Logo.svelte";
  import { signer } from "../store/signer";
  import AddressDropdown from "./AddressDropdown.svelte";
</script>

<div class="navbar bg-base-100">
  <div class="flex-1">
    <Logo />
  </div>
  <div class="flex-none">
    {#if $signer}
      <AddressDropdown />
    {:else}
      <Connect />
    {/if}
  </div>
</div>
