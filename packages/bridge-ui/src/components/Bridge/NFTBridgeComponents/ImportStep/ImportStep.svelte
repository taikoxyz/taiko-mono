<script lang="ts">
  import { onMount } from 'svelte';

  import { destNetwork as destChain, importDone, selectedNFTs } from '$components/Bridge/state';
  import { ImportMethod } from '$components/Bridge/types';
  import { ChainSelector, ChainSelectorType } from '$components/ChainSelectors';
  import { OnAccount } from '$components/OnAccount';
  import { fetchNFTs } from '$libs/bridge/fetchNFTs';
  import type { NFT } from '$libs/token';
  import { account } from '$stores/account';
  import { connectedSourceChain as srcChain } from '$stores/network';

  import ImportActions from './ImportActions.svelte';
  import ManualImport from './ManualImport.svelte';
  import ScannedImport from './ScannedImport.svelte';
  import { selectedImportMethod } from './state';

  let foundNFTs: NFT[] = [];
  let canProceed = false;

  export let validating = false;

  const scanForNFTs = async () => {
    scanning = true;
    $selectedNFTs = [];
    const accountAddress = $account?.address;
    const srcChainId = $srcChain?.id;
    const destChainId = $destChain?.id;
    if (!accountAddress || !srcChainId || !destChainId) return;
    const nftsFromAPIs = await fetchNFTs(accountAddress, srcChainId);
    foundNFTs = nftsFromAPIs.nfts;

    scanning = false;

    if (foundNFTs.length > 0) {
      $selectedImportMethod = ImportMethod.SCAN;
    }
  };

  const reset = () => {
    foundNFTs = [];
    $selectedNFTs = [];
    $selectedImportMethod = ImportMethod.NONE;
  };

  const onAccountChange = () => {
    reset();
  };

  //  States
  let scanning = false;

  $: canImport = ($account?.isConnected && $srcChain?.id && $destChain && !scanning) || false;

  $: {
    if (canProceed) {
      $importDone = true;
    } else {
      $importDone = false;
    }
  }

  onMount(() => {
    reset();
  });
</script>

<div class="f-between-center gap-[16px] mt-[30px]">
  <ChainSelector type={ChainSelectorType.COMBINED} />
</div>

<div class="h-sep" />

{#if $selectedImportMethod === ImportMethod.MANUAL}
  <ManualImport bind:validating />
{:else if $selectedImportMethod === ImportMethod.SCAN}
  <ScannedImport {scanForNFTs} bind:foundNFTs bind:canProceed />
{:else}
  <ImportActions bind:scanning {canImport} {scanForNFTs} />
{/if}

<OnAccount change={onAccountChange} />
