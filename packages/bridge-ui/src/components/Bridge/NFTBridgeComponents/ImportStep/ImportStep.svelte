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

  //  States
  let scanning = false;
  let canProceed = false;

  export let validating = false;

  let manualImportComponent: ManualImport;

  /** Re-runs the manual import's validation; a no-op when it is not mounted */
  export const revalidate = () => manualImportComponent?.revalidate();

  /** Clears the manual import form; a no-op when it is not mounted */
  export const resetManualImport = () => manualImportComponent?.reset();

  const nextPage = async () => {
    await scanForNFTs(false);
  };

  const scanForNFTs = async (refresh: boolean) => {
    scanning = true;
    try {
      $selectedNFTs = [];
      const accountAddress = $account?.address;
      const srcChainId = $srcChain?.id;
      const destChainId = $destChain?.id;
      if (!accountAddress || !srcChainId || !destChainId) return;
      const nftsFromAPIs = await fetchNFTs({ address: accountAddress, chainId: srcChainId, refresh });

      if (nftsFromAPIs.error) {
        // Keep the pages already on screen and let the caller decide: overwriting with the
        // empty result would both lose them and read as "there are no more NFTs"
        throw nftsFromAPIs.error;
      }

      foundNFTs = nftsFromAPIs.nfts;

      if (foundNFTs.length > 0) {
        $selectedImportMethod = ImportMethod.SCAN;
      }
    } finally {
      scanning = false;
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
  <ManualImport bind:this={manualImportComponent} bind:validating />
{:else if $selectedImportMethod === ImportMethod.SCAN}
  <ScannedImport refresh={() => scanForNFTs(true)} {nextPage} bind:foundNFTs bind:canProceed />
{:else}
  <ImportActions bind:scanning {canImport} scanForNFTs={() => scanForNFTs(false)} />
{/if}

<OnAccount change={onAccountChange} />
