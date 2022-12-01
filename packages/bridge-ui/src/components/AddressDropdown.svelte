<script lang="ts">
  import { onMount } from "svelte";
  import { _ } from "svelte-i18n";
  import { toast } from "@zerodevx/svelte-toast";

  import { addressSubsection } from "../utils/addressSubsection";
  import { signer } from "../store/signer";
  import { pendingTransactions } from "../store/transactions";
  import ChevDown from "./icons/ChevDown.svelte";
  import { getAddressAvatarFromIdenticon } from "../utils/addressAvatar";
  import Loader from "./icons/Loader.svelte";
  import type { BridgeTransaction } from "src/domain/transactions";

  export let transactions: BridgeTransaction[] = [];

  let address: string;
  let addressAvatarImgData: string;
  onMount(async () => {
    address = await $signer.getAddress();
    addressAvatarImgData = getAddressAvatarFromIdenticon(address);
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

<div class="dropdown dropdown-bottom">
  <button tabindex="0" class="btn btn-wide justify-around">
    <span class="font-normal flex-1 text-left">
      {#if $pendingTransactions && $pendingTransactions.length}
        {$pendingTransactions.length} Pending <Loader />
      {:else}
        <img
          width="26"
          height="26"
          src="data:image/png;base64,{addressAvatarImgData}"
          class="rounded-full mr-2"
          alt="avatar"
        />

        {addressSubsection(address)}
      {/if}
    </span>

    <ChevDown />
  </button>
  <ul
    tabindex="0"
    class="dropdown-content menu p-2 shadow bg-dark-3 rounded-box w-[194px]"
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
    {#if transactions && transactions.length}
      <li>
        <span class="cursor-pointer"> {transactions.length} Transactions</span>
      </li>
    {/if}
  </ul>
</div>
