<script lang="ts">
  import { t } from 'svelte-i18n';

  import { chainConfig } from '$chainConfig';
  import Amount from '$components/Bridge/Amount.svelte';
  import { ProcessingFee } from '$components/Bridge/ProcessingFee';
  import Recipient from '$components/Bridge/Recipient.svelte';
  import { destNetwork as destinationChain, selectedToken } from '$components/Bridge/state';
  import { ChainSelector } from '$components/ChainSelector';
  import { Icon, IconFlipper } from '$components/Icon';
  import { NFTCard } from '$components/NFTCard';
  import { NFTList } from '$components/NFTList';
  import { type NFT, TokenType } from '$libs/token';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { network } from '$stores/network';

  export let selectedNFT: NFT[];

  let amountComponent: Amount;
  let recipientComponent: Recipient;
  let processingFeeComponent: ProcessingFee;

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
        {#each selectedNFT as nft}
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
    <div class="font-bold">{$t('bridge.nft.step.review.token_id')}</div>
    <div class="break-words text-right text-secondary-content">
      <ul>
        {#each selectedNFT as nft}
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
  {#if $selectedToken?.type === TokenType.ERC1155}
    <Amount bind:this={amountComponent} />
  {/if}
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
  {#if nftView === NFTView.LIST}
    <NFTList bind:nfts={selectedNFT} chainId={$network?.id} viewOnly />
  {:else if nftView === NFTView.CARDS}
    <div class="rounded-[20px] bg-neutral min-h-[200px] w-full p-2 f-center">
      {#each selectedNFT as nft}
        <NFTCard {nft} />
      {/each}
    </div>
  {/if}
</section>
