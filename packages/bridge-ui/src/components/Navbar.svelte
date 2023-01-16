<script lang="ts">
  import Connect from "./buttons/Connect.svelte";
  import TaikoLogo from "./icons/TaikoLogo.svelte";
  import TaikoLight from "./icons/TaikoLight.svelte";
  import { signer } from "../store/signer";
  import AddressDropdown from "./AddressDropdown.svelte";
  import ChainDropdown from "./ChainDropdown.svelte";
</script>

<div class="navbar bg-base-100">
  <div class="flex-1">
    <span class="inline dark:hidden">
      <TaikoLight width={120} />
    </span>
    <span class="hidden dark:inline">
      <TaikoLogo width={120} />
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
