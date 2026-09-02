<script lang="ts">
  import { destNetwork as destChain, importDone, selectedNFTs } from '$components/Bridge/state';
  import { ImportMethod } from '$components/Bridge/types';
  import { ChainSelector, ChainSelectorType } from '$components/ChainSelectors';
  import { OnAccount } from '$components/OnAccount';
  import { fetchNFTs } from '$libs/bridge/fetchNFTs';
  import { type Account, account } from '$stores/account';
  import { connectedSourceChain as srcChain } from '$stores/network';

  import ImportActions from './ImportActions.svelte';
  import ManualImport from './ManualImport.svelte';
  import ScannedImport from './ScannedImport.svelte';
  import { foundNFTs, selectedImportMethod } from './state';

  //  States
  let scanning = false;
  let canProceed = false;

  /**
   * Bumped whenever the scan results stop being wanted: a wallet or chain change resets the
   * step, a switch to manual import leaves the scanned view, and a newer scan replaces the
   * older one. A scan still in flight at that point used to resume and publish anyway -
   * handing wallet B wallet A's NFTs as selectable, or unmounting the manual form the user
   * had just opened to put the scanned view back.
   */
  let scanGeneration = 0;

  /** @dev Retires whatever scan is in flight; its result is discarded when it arrives. */
  const abandonScans = () => {
    scanGeneration++;
    scanning = false;
  };

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
    const countBefore = $foundNFTs.length;
    // Another page adds to what is already on screen, so a selection made on an earlier
    // page still describes an NFT the user can see and bridge
    const scanRan = await scanForNFTs(false, { keepSelection: true });
    // A scan that never ran - a wallet disconnected while the scanned view stayed mounted,
    // say - says nothing about whether more pages exist. Reporting it as "nothing arrived"
    // retires the "load more" button for good over a condition that can come back
    if (!scanRan) return true;
    return $foundNFTs.length > countBefore;
  };

  /**
   * @returns whether a scan actually ran. Missing prerequisites resolve as `false`
   * rather than throwing: nothing failed, so an error toast would be wrong, but the
   * caller must not read the resolved promise as "the wallet holds no NFTs" either.
   */
  const scanForNFTs = async (refresh: boolean, { keepSelection = false } = {}): Promise<boolean> => {
    const generation = ++scanGeneration;
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

      // Retired while it ran: nothing here describes what is on screen any more. Reported
      // as "did not run" so a page load does not read it as "nothing more to load".
      if (generation !== scanGeneration) return false;

      if (nftsFromAPIs.error) {
        // Keep the pages already on screen and let the caller decide: overwriting with the
        // empty result would both lose them and read as "there are no more NFTs"
        throw nftsFromAPIs.error;
      }

      $foundNFTs = nftsFromAPIs.nfts;

      if ($foundNFTs.length > 0) {
        $selectedImportMethod = ImportMethod.SCAN;
      }
      return true;
    } finally {
      // A retired scan has already been marked as not running; a newer one owns the flag
      if (generation === scanGeneration) scanning = false;
    }
  };

  const reset = () => {
    abandonScans();
    $foundNFTs = [];
    $selectedNFTs = [];
    $selectedImportMethod = ImportMethod.NONE;
  };

  const onAccountChange = (newAccount: Account, oldAccount?: Account) => {
    // OnAccount subscribes on mount and fires immediately with no previous account. That
    // is not a change, and treating it as one wiped the scan results and the selection on
    // every return to this step - which is what removing the onMount reset alone did not
    // fix, because this ran in its place.
    if (!oldAccount || newAccount?.address === oldAccount?.address) return;
    reset();
  };

  // A scan lists what the wallet holds on one chain; the same list against another chain
  // describes tokens the user does not own there. OnAccount covers the wallet changing,
  // nothing covered the chain changing, and the scanned view stays mounted through it.
  let previousSrcChainId: Maybe<number> = undefined;
  $: {
    const srcChainId = $srcChain?.id;
    if (previousSrcChainId !== undefined && srcChainId !== previousSrcChainId) {
      reset();
    }
    previousSrcChainId = srcChainId;
  }

  // The user has left the scanned view for the manual form; a page still loading must not
  // bring it back
  $: if ($selectedImportMethod === ImportMethod.MANUAL) abandonScans();

  $: canImport = ($account?.isConnected && $srcChain?.id && $destChain && !scanning) || false;

  $: {
    if (canProceed) {
      $importDone = true;
    } else {
      $importDone = false;
    }
  }
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
    foundNFTs={$foundNFTs}
    bind:canProceed />
{:else}
  <!--
    refresh: a scan started from this panel is the user asking the server to look again.
    The repository marks a wallet fully fetched as soon as Moralis returns no cursor -
    which an empty wallet does on its first page - and then serves that cached answer
    indefinitely, so "Scan again" could never discover a newly minted NFT. Cursor
    continuity only matters for nextPage.
  -->
  <ImportActions bind:scanning {canImport} scanForNFTs={() => scanForNFTs(true)} />
{/if}

<OnAccount change={onAccountChange} />
