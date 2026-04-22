<script lang="ts">
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { Alert } from '$components/Alert';
  import { ImportMethod } from '$components/Bridge/types';
  import { ActionButton } from '$components/Button';

  import { selectedImportMethod } from './state';

  export let canImport = false;
  export let scanning = false;

  export let scanForNFTs: () => Promise<void>;

  let firstScan = false;

  function onScanClick() {
    scanning = true;
    scanForNFTs().finally(() => {
      firstScan = false;
      scanning = false;
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
      on:click={() =>
        (async () => {
          await scanForNFTs();
        })()}>
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
