<script lang="ts">
  import { onMount } from "svelte";
  import { _ } from "svelte-i18n";

  import { addressSubsection } from "../utils/addressSubsection";
  import { signer } from "../store/signer";
  import ChevDown from "./icons/ChevDown.svelte";
  import { getAddressAvatarFromIdenticon } from "../utils/addressAvatar";
  import { LottiePlayer } from "@lottiefiles/svelte-lottie-player";
  import { ethers, Signer } from "ethers";
  import { errorToast } from "../utils/toast";
  import CopyIcon from "./icons/Copy.svelte";
  import DisconnectIcon from "./icons/Disconnect.svelte";
  import TransactionsIcon from "./icons/Transactions.svelte";
  import { slide } from "svelte/transition";
  import { fromChain } from "../store/chain";
  import { truncateString } from "../utils/truncateString";
  import Transactions from "./Transactions.svelte";
  import { transactions } from "../store/transactions";
  import { MessageStatus } from "../domain/message";

  let showTransactions = false;

  let address: string;
  let addressAvatarImgData: string;
  let tokenBalance: string = "";

  onMount(async () => {
    await setAddress($signer);
  });

  $: getUserBalance($signer);

  async function getUserBalance(signer) {
    if (signer) {
      const userBalance = await signer.getBalance("latest");
      tokenBalance = ethers.utils.formatEther(userBalance);
    }
  }

  $: setAddress($signer).catch((e) => console.error(e));

  async function setAddress(signer: Signer) {
    address = await signer.getAddress();
    addressAvatarImgData = getAddressAvatarFromIdenticon(address);
  }

  async function copyToClipboard(clip: string) {
    await navigator.clipboard.writeText(clip);
  }

  async function disconnect() {
    try {
      signer.set(null);
    } catch (e) {
      console.error(e);
      errorToast($_("toast.errorDisconnecting"));
    }
  }
</script>

<div class="dropdown dropdown-bottom dropdown-end">
  <button tabindex="0" class="btn btn-md md:btn-wide justify-around">
    <span class="font-normal flex-1 text-left">
      {#if $transactions && $transactions.filter((t) => t.status === MessageStatus.New).length}
        {$transactions.filter((t) => t.status === MessageStatus.New).length} Pending
        <div class="inline-block">
          <LottiePlayer
            src="/lottie/loader.json"
            autoplay={true}
            loop={true}
            controls={false}
            renderer="svg"
            background="transparent"
            height={26}
            width={26}
            controlsLayout={[]}
          />
        </div>
      {:else}
        <img
          width="26"
          height="26"
          src="data:image/png;base64,{addressAvatarImgData}"
          class="rounded-full mr-2 inline-block"
          alt="avatar"
        />

        <span class="hidden md:inline-block">
          {addressSubsection(address)}
        </span>
      {/if}
    </span>

    <ChevDown />
  </button>
  <div
    tabindex="0"
    class="dropdown-content address-dropdown-content menu shadow bg-dark-3 rounded-sm w-64 mt-2 pb-2"
  >
    {#if !showTransactions}
      <div class="p-5 pb-0 flex flex-col items-center" transition:slide>
        {#if $fromChain && $signer}
          <svelte:component this={$fromChain.icon} />
          <div class="text-lg mt-2">
            {tokenBalance.length > 10
              ? `${truncateString(tokenBalance)}...`
              : tokenBalance} ETH
          </div>
        {/if}
      </div>
      <div class="divider" />
      <div class="flex hover:bg-dark-5 items-center py-2 px-2">
        <img
          width="24"
          height="24"
          src="data:image/png;base64,{addressAvatarImgData}"
          class="rounded-full mr-2 inline-block"
          alt="avatar"
        />
        {addressSubsection(address)}
      </div>
      <div
        class="cursor-pointer flex hover:bg-dark-5 items-center py-2 px-2"
        on:click={async () => await copyToClipboard(address)}
      >
        <CopyIcon />
        Copy Address
      </div>
      <div
        class="cursor-pointer flex hover:bg-dark-5 items-center py-2 px-2"
        on:click={async () => await disconnect()}
      >
        <DisconnectIcon /> Disconnect
      </div>
      {#if $transactions && $transactions.length}
        <div
          class="cursor-pointer flex hover:bg-dark-5 items-center py-2 px-2"
          on:click={() => (showTransactions = true)}
        >
          <TransactionsIcon />
          {$transactions.length} Transactions
        </div>
      {/if}
    {:else}
      <div class="" transition:slide>
        <Transactions bind:showTransactions />
      </div>
    {/if}
  </div>
</div>
