<script lang="ts">
  import '../app.css';
  import '../i18n';

  import { ResponsiveController } from '@taiko/ui-lib';
  import { onDestroy, onMount } from 'svelte';
  import { setContext } from 'svelte';
  import { zeroAddress } from 'viem';

  import { MintConfirmationModal, PostMintModal, TaikoonDetailModal } from '$components/modals';
  import { mint } from '$stores/mint';
  import { taikoonDetail } from '$stores/taikoonDetail';

  import { AccountConnectionToast } from '../components/AccountConnectionToast';
  import { Toast } from '../components/core/Toast';
  import { Header } from '../components/Header';
  import { SwitchChainModal } from '../components/SwitchChainModal';
  import { classNames } from '../lib/util/classNames';
  import { startWatching, stopWatching } from '../lib/wagmi';

  const mintState = mint;

  $: mintState.set({
    isModalOpen: false,
    isMinting: false,
    tokenIds: [],
    address: zeroAddress,
    totalMintCount: 0,
    txHash: '',
  });

  const taikoonDetailState = taikoonDetail;
  $: taikoonDetailState.set({
    tokenId: -1,
    isModalOpen: false,
  });

  setContext('mint', mintState);
  setContext('taikoonDetail', taikoonDetailState);
  const containerClasses = classNames(
    'z-0',
    'w-full',
    'h-full',
    'flex',
    'flex-col',
    'relative',
    'items-center',
    'justify-evenly',
  );

  let windowSize: 'sm' | 'md' | 'lg' = 'md';

  onMount(async () => {
    await startWatching();
  });

  onDestroy(() => {
    stopWatching();
  });
</script>

<div class={containerClasses}>
  <slot />

  <Header />
</div>

<Toast />

<AccountConnectionToast />

<SwitchChainModal />

<MintConfirmationModal />

<PostMintModal />

{#if windowSize === 'sm'}
  <TaikoonDetailModal />
{/if}

<ResponsiveController bind:windowSize />
