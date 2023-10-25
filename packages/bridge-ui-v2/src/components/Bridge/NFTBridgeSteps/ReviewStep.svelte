<script lang="ts">
  import { t } from 'svelte-i18n';

  import { chainConfig } from '$chainConfig';
  import { ProcessingFee } from '$components/Bridge/ProcessingFee';
  import Recipient from '$components/Bridge/Recipient.svelte';
  import { destNetwork as destinationChain, selectedNFTs } from '$components/Bridge/state';
  import { ChainSelector } from '$components/ChainSelector';
  import { Icon, IconFlipper } from '$components/Icon';
  import { NFTDisplay } from '$components/NFTs';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { network } from '$stores/network';

  let recipientComponent: Recipient;
  let processingFeeComponent: ProcessingFee;

  $: nftsToDisplay = $selectedNFTs ? $selectedNFTs : [];

  enum NFTView {
    CARDS,
    LIST,
  }
  let nftView: NFTView = NFTView.CARDS;

  const changeNFTView = () => {
    if (nftView === NFTView.CARDS) {
      nftView = NFTView.LIST;
    } else {
      nftView = NFTView.CARDS;
    }
  };
</script>

<div class="container mx-auto inline-block align-middle space-y-[25px]">
  <div class="flex justify-between mb-2 items-center">
    <div class="font-bold">{$t('common.destination')}</div>
    <div><ChainSelector small value={$destinationChain} readOnly /></div>
  </div>
  <div class="flex justify-between mb-2">
    <div class="font-bold">{$t('common.contract_address')}</div>
    <div class="text-secondary-content">
      <ul>
        {#each nftsToDisplay as nft}
          {@const currentChain = $network?.id}
          {#if currentChain && $destinationChain?.id}
            <li>
              <a
                class="flex justify-start link"
                href={`${chainConfig[$destinationChain?.id].urls.explorer}`}
                target="_blank">
                {shortenAddress(nft.addresses[currentChain], 8, 12)}
                <Icon type="arrow-top-right" fillClass="fill-primary-link" />
              </a>
            </li>
          {/if}
        {/each}
      </ul>
    </div>
  </div>

  <div class="flex justify-between">
    <div class="font-bold">{$t('inputs.token_id_input.label')}</div>
    <div class="break-words text-right text-secondary-content">
      <ul>
        {#each nftsToDisplay as nft}
          <li>{nft.tokenId}</li>
        {/each}
      </ul>
    </div>
  </div>
</div>

<div class="h-sep" />
<!-- 
  Recipient & Processing Fee
  -->
<div class="space-y-[16px]">
  <Recipient bind:this={recipientComponent} />
  <ProcessingFee bind:this={processingFeeComponent} />
</div>

<div class="h-sep" />
<!-- 
NFT List or Card View
-->
<section class="space-y-2">
  <div class="flex justify-between items-center w-full">
    <div class="flex items-center gap-2">
      <span>{$t('bridge.nft.step.review.your_tokens')}</span>
      <ChainSelector small value={$network} readOnly />
    </div>
    <div class="flex gap-2">
      <IconFlipper
        iconType1="list"
        iconType2="cards"
        selectedDefault="list"
        class="bg-neutral w-9 h-9 rounded-full"
        on:labelclick={changeNFTView} />
      <!-- <Icon type="list" fillClass="fill-primary-icon" size={24} vWidth={24} vHeight={24} /> -->
    </div>
  </div>
  <NFTDisplay loading={false} nfts={$selectedNFTs} {nftView} viewOnly />
</section>
