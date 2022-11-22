<script lang="ts">
  import { _ } from "svelte-i18n";
  import { addressSubsection } from "../utils/addressSubsection";
  import { onMount } from "svelte";
  import { signer } from "../store/signer";
  import ChevDown from "./icons/ChevDown.svelte";
  import { toast } from "@zerodevx/svelte-toast";

  let address: string;
  onMount(async () => {
    address = await $signer.getAddress();
  });

  async function copyToClipboard(clip: string) {
    await navigator.clipboard.writeText(clip);
  }

  async function disconnect() {
    try {
      signer.set(null);
    } catch (e) {
      console.error(e);
      toast.push($_("toast.errorDisconnecting"));
    }
  }
</script>

<div class="dropdown dropdown-end">
  <label tabindex="0" class="btn m-1">
    <span class="pr-2">{addressSubsection(address)}</span>

    <ChevDown />
  </label>
  <ul
    tabindex="0"
    class="dropdown-content menu p-2 shadow bg-base-100 rounded-box w-52"
  >
    <li>
      <span
        class="cursor-pointer"
        on:click={async () => await copyToClipboard(address)}>Copy Address</span
      >
    </li>
    <li>
      <span class="cursor-pointer" on:click={async () => await disconnect()}
        >Disconnect</span
      >
    </li>
  </ul>
</div>
