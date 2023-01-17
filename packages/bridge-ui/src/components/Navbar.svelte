<script lang="ts">
  import Connect from "./buttons/Connect.svelte";
  import TaikoLogo from "./icons/TaikoLogo.svelte";
  import TaikoLight from "./icons/TaikoLight.svelte";
  import { signer } from "../store/signer";
  import AddressDropdown from "./AddressDropdown.svelte";
  import ChainDropdown from "./ChainDropdown.svelte";
  import TaikoLogoFluo from "./icons/TaikoLogoFluo.svelte";
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
  </div>
</div>
