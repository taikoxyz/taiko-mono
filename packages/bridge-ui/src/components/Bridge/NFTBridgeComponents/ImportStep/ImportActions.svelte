<script lang="ts">
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { Alert } from '$components/Alert';
  import { ImportMethod } from '$components/Bridge/types';
  import { ActionButton } from '$components/Button';
  import { errorToast } from '$components/NotificationToast';

  import { selectedImportMethod } from './state';

  export let canImport = false;
  export let scanning = false;

  /** Resolves to whether a scan actually ran; see ImportStep.scanForNFTs */
  export let scanForNFTs: () => Promise<boolean>;

  let firstScan = false;

  function onScanClick() {
    scanning = true;
    scanForNFTs()
      .then((scanned) => {
        // Only a scan that actually ran can claim there are no NFTs. A failure keeps the
        // retry button, and so does a scan skipped for missing account/chain - both would
        // otherwise render as a false "none found".
        if (scanned) firstScan = false;
      })
      .catch(reportScanFailure)
      .finally(() => {
        scanning = false;
      });
  }

  // A scan that fails now rejects rather than resolving with an empty list, so every
  // call site has to handle it or it becomes an unhandled rejection
  function reportScanFailure(error: unknown) {
    console.error('Error scanning for NFTs', error);
    errorToast({
      title: $t('bridge.errors.unknown_error.title'),
      message: $t('bridge.errors.unknown_error.message'),
    });
  }

  onMount(() => {
    firstScan = true;
  });
</script>

<div class="f-col w-full gap-4">
  {#if firstScan}
    <ActionButton priority="primary" disabled={!canImport} loading={scanning} on:click={onScanClick}>
      {$t('bridge.actions.nft_scan')}
    </ActionButton>

    <ActionButton
      priority="secondary"
      disabled={!canImport}
      on:click={() => ($selectedImportMethod = ImportMethod.MANUAL)}>
      {$t('bridge.actions.nft_manual')}
    </ActionButton>
  {:else}
    <ActionButton
      priority="secondary"
      disabled={!canImport}
      loading={scanning}
      on:click={() => {
        scanForNFTs().catch(reportScanFailure);
      }}>
      {$t('bridge.actions.nft_scan_again')}
    </ActionButton>

    <ActionButton
      priority="primary"
      disabled={!canImport}
      on:click={() => ($selectedImportMethod = ImportMethod.MANUAL)}>
      {$t('bridge.actions.nft_manual')}
    </ActionButton>

    <Alert type="warning" forceColumnFlow class="mt-[16px]">
      <p>{$t('bridge.nft.step.import.no_nft_found')}</p>
    </Alert>
  {/if}
</div>
