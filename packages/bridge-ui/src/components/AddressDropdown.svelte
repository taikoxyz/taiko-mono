<script lang="ts">
  import { disconnect as wagmiDisconnect } from '@wagmi/core'
  import { onMount } from "svelte";
  import { _ } from "svelte-i18n";
  import { addressSubsection } from "../utils/addressSubsection";
  import { signer } from "../store/signer";
  import { pendingTransactions } from "../store/transactions";
  import { getAddressAvatarFromIdenticon } from "../utils/addressAvatar";
  import { LottiePlayer } from "@lottiefiles/svelte-lottie-player";
  import { ethers, Signer } from "ethers";
  import { errorToast, successToast } from "../utils/toast";
  import { ClipboardDocument, Power } from "svelte-heros-v2";
  import { slide } from "svelte/transition";
  import { fromChain } from "../store/chain";
  import { truncateString } from "../utils/truncateString";
  import { ChevronDown } from "svelte-heros-v2";

  let address: string = "";
  let addressAvatarImgData: string = "";
  let tokenBalance: string = "";

  onMount(() => {
    (async () => {
      await setAddress($signer);
    })();
  });

  $: getUserBalance($signer);

  $: setAddress($signer);

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
    successToast('Address copied to clipboard');
  }

  async function disconnect() {
    try {
      await wagmiDisconnect();
      signer.set(null);
    } catch (e) {
      console.error(e);
      errorToast($_("toast.errorDisconnecting"));
    }
  }
</script>

<div class="dropdown dropdown-bottom dropdown-end">
  <label tabindex="0" class="btn btn-md justify-around">
    <span class="font-normal flex-1 text-left flex items-center">
      {#if $pendingTransactions && $pendingTransactions.length}
        <span>{$pendingTransactions.length} Pending</span>
        <div class="inline-block ml-2">
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

        <span class="hidden md:inline-block mr-2">
          {addressSubsection(address)}
        </span>
      {/if}
    </span>
    <ChevronDown size='20' />
  </label>
  <ul
    tabindex="0"
    class="dropdown-content address-dropdown-content menu shadow bg-dark-2 rounded-sm w-48 mt-2 pb-2 text-sm"
  >
    <div class="p-5 pb-0 flex flex-col items-center" transition:slide>
      {#if $fromChain && $signer}
        <svelte:component this={$fromChain.icon} />
        <div class="text-lg mt-2">
          {tokenBalance.length > 10
            ? `${truncateString(tokenBalance)}...`
            : tokenBalance} ETH
        </div>
      {:else}
      <div class="text-lg mt-2">
        -- ETH
      </div>
      {/if}
    </div>
    <div class="divider" />
    <div class="flex hover:bg-dark-5 items-center py-2 px-4 mx-2 rounded-md">
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
      class="cursor-pointer flex hover:bg-dark-5 items-center py-2 px-4 mx-2 rounded-md"
      on:click={async () => await copyToClipboard(address)}
    >
      <ClipboardDocument class="mr-2" />
      Copy Address
    </div>
    <div
      class="cursor-pointer flex hover:bg-dark-5 items-center py-2 px-4 mx-2 rounded-md"
      on:click={async () => await disconnect()}
    >
      <Power class="mr-2" /> Disconnect
    </div>
  </ul>
</div>
