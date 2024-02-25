<script lang="ts">
  import { t } from 'svelte-i18n';

  import { enteredAmount, selectedNFTs } from '$components/Bridge/state';
  import TokenAmountInput from '$components/Bridge/TokenAmountInput.svelte';
  import { ImportMethod } from '$components/Bridge/types';
  import { ActionButton, Button } from '$components/Button';
  import { IconFlipper } from '$components/Icon';
  import RotatingIcon from '$components/Icon/RotatingIcon.svelte';
  import { NFTDisplay } from '$components/NFTs';
  import { NFTView } from '$components/NFTs/types';
  import type { NFT } from '$libs/token';

  import { selectedImportMethod } from './state';

  export let scanForNFTs: () => Promise<void>;

  export let foundNFTs: NFT[] = [];

  export let canProceed = false;

  let nftView: NFTView = NFTView.LIST;
  let scanning = false;

  let amountComponent: TokenAmountInput;

  function onScanClick() {
    scanning = true;
    scanForNFTs().finally(() => {
      scanning = false;
    });
  }

  const changeNFTView = () => {
    if (nftView === NFTView.CARDS) {
      nftView = NFTView.LIST;
    } else {
      nftView = NFTView.CARDS;
    }
  };

  function onManualImportClick() {
    $selectedImportMethod = ImportMethod.MANUAL;
  }
  $: isERC1155 = $selectedNFTs ? $selectedNFTs.some((nft) => nft.type === 'ERC1155') : false;
  $: nftHasAmount = hasSelectedNFT && isERC1155;

  $: validBalance = nftHasAmount && $enteredAmount > 0;

  $: hasSelectedNFT = $selectedNFTs && $selectedNFTs?.length > 0;

  $: if (nftHasAmount && hasSelectedNFT) {
    if (validBalance) {
      canProceed = true;
    } else {
      canProceed = false;
    }
  } else if (!nftHasAmount && hasSelectedNFT) {
    canProceed = true;
  } else {
    canProceed = false;
  }
</script>

{$selectedNFTs?.length} <br />
validBalance {validBalance} <br />
$enteredAmount gt 0 {$enteredAmount > 0} <br />
has amount {nftHasAmount} <br />
(nftHasAmount ? $enteredAmount gt 0 : true) {nftHasAmount ? $enteredAmount > 0 : true} <br />
{hasSelectedNFT && (nftHasAmount ? $enteredAmount > 0 : true)}
<!-- {JSON.stringify($selectedNFTs, (key, value) => (typeof value === 'bigint' ? Number(value) : value))} -->
<div class="f-col w-full gap-4">
  <section class="space-y-2">
    <div class="flex justify-between items-center w-full">
      <p class="text-primary-content font-bold">
        {$t('bridge.nft.step.import.scan_screen.title', { values: { number: foundNFTs.length } })}
      </p>
      <div class="flex gap-2">
        <Button
          type="neutral"
          shape="circle"
          class="bg-neutral rounded-full w-[28px] h-[28px] border-none"
          on:click={onScanClick}>
          <RotatingIcon loading={scanning} type="refresh" size={13} />
        </Button>

        <IconFlipper
          type="swap-rotate"
          iconType1="list"
          iconType2="cards"
          selectedDefault="cards"
          class="bg-neutral w-[28px] h-[28px] rounded-full"
          size={20}
          on:labelclick={changeNFTView} />
      </div>
    </div>
    <div>
      <NFTDisplay loading={scanning} nfts={foundNFTs} {nftView} />
    </div>
  </section>
  {#if nftHasAmount}
    <section>
      <TokenAmountInput bind:this={amountComponent} />
    </section>
  {/if}

  <div class="flex items-center justify-between space-x-2">
    <p class="text-secondary-content">{$t('bridge.nft.step.import.scan_screen.description')}</p>
    <ActionButton priority="secondary" on:click={onManualImportClick}>
      {$t('common.add')}
    </ActionButton>
  </div>
</div>
