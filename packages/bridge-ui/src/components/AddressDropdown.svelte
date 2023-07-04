<script lang="ts">
  import * as Sentry from '@sentry/svelte';
  import { ethers, type Signer } from 'ethers';
  import { onMount } from 'svelte';
  import { slide } from 'svelte/transition';
  import { ClipboardDocument, Power } from 'svelte-heros-v2';
  import { ChevronDown } from 'svelte-heros-v2';
  import { _ } from 'svelte-i18n';
  import { RpcError } from 'wagmi';
  import { disconnect as wagmiDisconnect } from 'wagmi/actions';

  import { srcChain } from '../store/chain';
  import { signer } from '../store/signer';
  import { pendingTransactions } from '../store/transaction';
  import { getAddressAvatarFromIdenticon } from '../utils/addressAvatar';
  import { addressSubsection } from '../utils/addressSubsection';
  import { truncateString } from '../utils/truncateString';
  import Loading from './Loading.svelte';
  import { errorToast, successToast } from './NotificationToast.svelte';

  let address: string = '';
  let addressAvatarImgData: string = '';
  let tokenBalance: string = '';

  async function setUserBalance(signer: Signer) {
    if (signer) {
      const userBalance = await signer.getBalance('latest');
      tokenBalance = ethers.utils.formatEther(userBalance);
    }
  }

  async function setAddress(signer: Signer) {
    if (!signer) {
      address = '';
      addressAvatarImgData = '';
      return;
    }

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
      successToast('You are disconnected.');
    } catch (e) {
      console.error(e);
      errorToast($_('toast.errorDisconnecting'));
    }
  }

  $: setUserBalance($signer).catch((error) => {
    console.error(error);

    if (error instanceof RpcError) {
      errorToast(
        'Cannot communicate with the network. Please try again later or contact support.',
      );
    } else {
      Sentry.captureException(error, {
        extra: { srcChain: $srcChain?.id },
      });

      errorToast('There was an error getting your balance.');
    }
  });

  $: setAddress($signer).catch((e) => console.error(e));

  $: pendingTx = $pendingTransactions && $pendingTransactions.length > 0;

  onMount(() => {
    (async () => {
      await setAddress($signer);
    })();
  });
</script>

<!-- Makes no sense to render anything here without signer  -->
{#if $signer}
  <div class="dropdown dropdown-bottom dropdown-end">
    <button class="btn justify-around">
      <span class="font-normal flex-1 text-left flex items-center">
        {#if pendingTx}
          <div class="inline-block ml-2">
            <Loading text="Pending tx…" />
          </div>
        {:else}
          <img
            width="26"
            height="26"
            src="data:image/png;base64,{addressAvatarImgData}"
            class="rounded-full mr-2 inline-block"
            alt="avatar" />

          <span class="hidden md:inline-block mr-2">
            {addressSubsection(address)}
          </span>
        {/if}
      </span>
      <ChevronDown size="20" />
    </button>
    <ul
      role="listbox"
      tabindex="0"
      class="dropdown-content rounded-box menu shadow bg-dark-2 w-48 mt-2 pb-2 text-sm">
      <div class="p-5 pb-0 flex flex-col items-center" transition:slide>
        {#if $srcChain && $signer}
          <svelte:component this={$srcChain.icon} />
          <div class="text-lg mt-2">
            {tokenBalance.length > 10
              ? `${truncateString(tokenBalance)}…`
              : tokenBalance} ETH
          </div>
        {:else}
          <div class="text-lg mt-2">-- ETH</div>
        {/if}
      </div>
      <div class="divider" />
      <div class="flex hover:bg-dark-5 items-center py-2 px-4 mx-2 rounded-sm">
        <img
          width="24"
          height="24"
          src="data:image/png;base64,{addressAvatarImgData}"
          class="rounded-full mr-2 inline-block"
          alt="avatar" />
        {addressSubsection(address)}
      </div>
      <button
        class="cursor-pointer flex hover:bg-dark-5 items-center py-2 px-4 mx-2 rounded-sm"
        on:click={async () => await copyToClipboard(address)}>
        <ClipboardDocument class="mr-2" />
        Copy Address
      </button>
      <button
        class="cursor-pointer flex hover:bg-dark-5 items-center py-2 px-4 mx-2 rounded-sm"
        on:click={async () => await disconnect()}>
        <Power class="mr-2" /> Disconnect
      </button>
    </ul>
  </div>
{/if}
