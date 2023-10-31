<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';

  import { chainConfig } from '$chainConfig';
  import { ProcessingFee } from '$components/Bridge/ProcessingFee';
  import Recipient from '$components/Bridge/Recipient.svelte';
  import { destNetwork as destinationChain, enteredAmount, selectedNFTs } from '$components/Bridge/state';
  import { ChainSelector } from '$components/ChainSelector';
  import { IconFlipper } from '$components/Icon';
  import { NFTDisplay } from '$components/NFTs';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { network } from '$stores/network';

  let recipientComponent: Recipient;
  let processingFeeComponent: ProcessingFee;
  let hasEnoughEth: boolean;

  const dispatch = createEventDispatcher();

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

  const editTransactionDetails = () => {
    dispatch('editTransactionDetails');
  };

  // check if any of the selected NFTs are ERC1155 tokens
  $: isERC1155 = $selectedNFTs ? $selectedNFTs.some((nft) => nft.type === 'ERC1155') : false;
</script>

<div class="container mx-auto inline-block align-middle space-y-[25px] mt-[30px]">
  <div class="flex justify-between mb-2 items-center">
    <div class="font-bold text-primary-content">{$t('bridge.nft.step.review.transfer_details')}</div>
  </div>
  <div>
    <div class="flex justify-between items-center">
      <div class="text-secondary-content">{$t('common.from')}</div>
      <div class="">{$network?.name}</div>
    </div>
    <div class="flex justify-between items-center">
      <div class="text-secondary-content">{$t('common.to')}</div>
      <div class="">{$destinationChain?.name}</div>
    </div>

    <div class="flex justify-between">
      <div class="text-secondary-content">{$t('common.contract_address')}</div>
      <div class="">
        <ul>
          {#each nftsToDisplay as nft}
            {@const currentChain = $network?.id}
            {#if currentChain && $destinationChain?.id}
              <li>
                <a
                  class="flex justify-start link"
                  href={`${chainConfig[currentChain].urls.explorer}/token/${nft.addresses[currentChain]}`}
                  target="_blank">
                  {shortenAddress(nft.addresses[currentChain], 8, 12)}
                  <!-- <Icon type="arrow-top-right" fillClass="fill-primary-link" /> -->
                </a>
              </li>
            {/if}
          {/each}
        </ul>
      </div>
    </div>

    <div class="flex justify-between">
      <div class="text-secondary-content">{$t('inputs.token_id_input.label')}</div>
      <div class="break-words text-right">
        <ul>
          {#each nftsToDisplay as nft}
            <li>{nft.tokenId}</li>
          {/each}
        </ul>
      </div>
    </div>
    {#if isERC1155}
      <div class="flex justify-between">
        <div class="text-secondary-content">{$t('common.amount')}</div>
        {$enteredAmount}
      </div>
    {/if}
  </div>
</div>

<!-- 
NFT List or Card View
-->
<section class="space-y-[16px]">
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

<div class="h-sep" />
<!-- 
Recipient & Processing Fee
-->

<div class="f-col">
  <div class="f-between-center mb-[10px]">
    <div class="font-bold text-primary-content">{$t('bridge.nft.step.review.recipient_details')}</div>
    <button class="flex justify-start link" on:click={editTransactionDetails}> Edit </button>
  </div>
  <Recipient bind:this={recipientComponent} small />
  <ProcessingFee bind:this={processingFeeComponent} small bind:hasEnoughEth />
</div>

<div class="h-sep" />
