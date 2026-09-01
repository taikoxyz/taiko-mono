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

  /**
   * @returns whether the page actually added anything. ScannedImport used to answer that
   * by reading its own bound `foundNFTs` after awaiting this, which is the parent's array
   * arriving through a prop update - a value that has not necessarily been flushed to the
   * child yet. Reading it here, where it is owned, removes the ordering question, and
   * getting this wrong retires the "load more" button for good.
   */
  const nextPage = async (): Promise<boolean> => {
    const countBefore = foundNFTs.length;
    // Another page adds to what is already on screen, so a selection made on an earlier
    // page still describes an NFT the user can see and bridge
    await scanForNFTs(false, { keepSelection: true });
    return foundNFTs.length > countBefore;
  };

  /**
   * @returns whether a scan actually ran. Missing prerequisites resolve as `false`
   * rather than throwing: nothing failed, so an error toast would be wrong, but the
   * caller must not read the resolved promise as "the wallet holds no NFTs" either.
   */
  const scanForNFTs = async (refresh: boolean, { keepSelection = false } = {}): Promise<boolean> => {
    scanning = true;
    try {
      // A fresh scan replaces the list, so the selection goes with it. Pagination does
      // not, and clearing there dropped the user's selection on every "load more" - and
      // on a failed page fetch, which keeps the earlier pages on screen deliberately
      if (!keepSelection) $selectedNFTs = [];
      const accountAddress = $account?.address;
      const srcChainId = $srcChain?.id;
      const destChainId = $destChain?.id;
      if (!accountAddress || !srcChainId || !destChainId) return false;
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
      return true;
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
  <ScannedImport
    refresh={async () => {
      await scanForNFTs(true);
    }}
    {nextPage}
    bind:foundNFTs
    bind:canProceed />
{:else}
  <ImportActions bind:scanning {canImport} scanForNFTs={() => scanForNFTs(false)} />
{/if}

<OnAccount change={onAccountChange} />
