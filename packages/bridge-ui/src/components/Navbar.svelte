<script lang="ts">
  import Connect from "./buttons/Connect.svelte";
  import TaikoLogo from "./icons/TaikoLogo.svelte";
  import { signer } from "../store/signer";
  import AddressDropdown from "./AddressDropdown.svelte";
  import ChainDropdown from "./ChainDropdown.svelte";
</script>

<div class="navbar bg-base-100">
  <div class="flex-1">
    <TaikoLogo width={120} />
  </div>
  <div class="flex-none">
    {#if $signer}
      <ChainDropdown />
      <AddressDropdown />
    {:else}
      <Connect />
    {/if}
  </div>
</div>
