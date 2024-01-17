<script lang="ts">
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { chainConfig } from '$chainConfig';
  import { Alert } from '$components/Alert';
  import ImportActions from '$components/Bridge/NFTBridgeSteps/ImportStep/ImportActions.svelte';
  import ManualImport from '$components/Bridge/NFTBridgeSteps/ImportStep/ManualImport.svelte';
  import ScannedImport from '$components/Bridge/NFTBridgeSteps/ImportStep/ScannedImport.svelte';
  import { destNetwork as destChain, selectedNFTs } from '$components/Bridge/state';
  import { ImportMethod } from '$components/Bridge/types';
  import { ChainSelectorWrapper } from '$components/ChainSelector';
  import { PUBLIC_SLOW_L1_BRIDGING_WARNING } from '$env/static/public';
  import { fetchNFTs } from '$libs/bridge/fetchNFTs';
  import { LayerType } from '$libs/chain';
  import type { NFT } from '$libs/token';
  import { account } from '$stores/account';
  import { network as srcChain } from '$stores/network';

  import { selectedImportMethod } from './state';

  let slowL1Warning = PUBLIC_SLOW_L1_BRIDGING_WARNING || false;

  let foundNFTs: NFT[] = [];

  export let canProceed = false;
  export let validating = false;

  const scanForNFTs = async () => {
    scanning = true;
    $selectedNFTs = [];
    const accountAddress = $account?.address;
    const srcChainId = $srcChain?.id;
    const destChainId = $destChain?.id;
    if (!accountAddress || !srcChainId || !destChainId) return;
    const nftsFromAPIs = await fetchNFTs(accountAddress, srcChainId, destChainId);
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

  //  States
  let scanning = false;

  $: canImport = ($account?.isConnected && $srcChain?.id && $destChain && !scanning) || false;

  $: displayL1Warning = slowL1Warning && $destChain?.id && chainConfig[$destChain.id].type === LayerType.L1;

  onMount(() => {
    reset();
  });
</script>

<div class="f-between-center gap-[16px] mt-[30px]">
  <ChainSelectorWrapper />
</div>

{#if displayL1Warning}
  <Alert type="warning">{$t('bridge.alerts.slow_bridging')}</Alert>
{/if}
<div class="h-sep" />
{#if $selectedImportMethod === ImportMethod.MANUAL}
  <ManualImport bind:canProceed bind:validating />
{:else if $selectedImportMethod === ImportMethod.SCAN}
  <ScannedImport {scanForNFTs} bind:foundNFTs bind:canProceed />
{:else}
  <ImportActions bind:scanning {canImport} {scanForNFTs} />
{/if}
