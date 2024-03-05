<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { chainConfig } from '$chainConfig';
  import { Alert } from '$components/Alert';
  import { ProcessingFee, Recipient } from '$components/Bridge/SharedBridgeComponents';
  import { destNetwork as destChain, enteredAmount, selectedNFTs, selectedToken } from '$components/Bridge/state';
  import { ChainSelector, ChainSelectorDirection, ChainSelectorType } from '$components/ChainSelectors';
  import { IconFlipper } from '$components/Icon';
  import { NFTDisplay } from '$components/NFTs';
  import { PUBLIC_SLOW_L1_BRIDGING_WARNING } from '$env/static/public';
  import { LayerType } from '$libs/chain';
  import { fetchNFTImageUrl } from '$libs/token/fetchNFTImageUrl';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { connectedSourceChain } from '$stores/network';

  export let hasEnoughEth: boolean = false;

  let recipientComponent: Recipient;
  let processingFeeComponent: ProcessingFee;
  let slowL1Warning = PUBLIC_SLOW_L1_BRIDGING_WARNING || false;

  $: displayL1Warning = slowL1Warning && $destChain?.id && chainConfig[$destChain.id].type === LayerType.L1;

  const dispatch = createEventDispatcher();

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

  const fetchImage = async () => {
    if (!$selectedNFTs || $selectedNFTs?.length === 0) return;
    const srcChainId = $connectedSourceChain?.id;
    const destChainId = $destChain?.id;
    if (!srcChainId || !destChainId) return;

    await Promise.all(
      $selectedNFTs.map(async (nft) => {
        fetchNFTImageUrl(nft).then((nftWithUrl) => {
          $selectedToken = nftWithUrl;
          $selectedNFTs = [nftWithUrl];
        });
      }),
    );
    nftsToDisplay = $selectedNFTs;
  };

  const editTransactionDetails = () => {
    dispatch('editTransactionDetails');
  };

  onMount(async () => {
    await fetchImage();
  });

  $: nftsToDisplay = $selectedNFTs ? $selectedNFTs : [];

  // check if any of the selected NFTs are ERC1155 tokens
  $: isERC1155 = $selectedNFTs ? $selectedNFTs.some((nft) => nft.type === 'ERC1155') : false;
</script>

<div class="container mx-auto inline-block align-middle space-y-[25px] w-full mt-[30px]">
  <div class="flex justify-between mb-2 items-center">
    <div class="font-bold text-primary-content">{$t('bridge.nft.step.review.transfer_details')}</div>
    <span role="button" tabindex="0" class="link" on:keydown={editTransactionDetails} on:click={editTransactionDetails}
      >{$t('common.edit')}</span>
  </div>
  <div>
    <div class="flex justify-between items-center">
      <div class="text-secondary-content">{$t('common.from')}</div>
      <div class="">{$connectedSourceChain?.name}</div>
    </div>
    <div class="flex justify-between items-center">
      <div class="text-secondary-content">{$t('common.to')}</div>
      <div class="">{$destChain?.name}</div>
    </div>

    <div class="flex justify-between">
      <div class="text-secondary-content">{$t('common.contract_address')}</div>
      <div class="">
        <ul>
          {#each nftsToDisplay as nft}
            {@const currentChain = $connectedSourceChain?.id}
            {#if currentChain && $destChain?.id}
              <li>
                <a
                  class="flex justify-start link"
                  href={`${chainConfig[currentChain]?.blockExplorers?.default.url}/token/${nft.addresses[currentChain]}`}
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

{#if displayL1Warning}
  <Alert type="warning">{$t('bridge.alerts.slow_bridging')}</Alert>
{/if}

<!-- 
NFT List or Card View
-->
<section class="space-y-[16px]">
  <div class="flex justify-between items-center w-full">
    <div class="flex items-center gap-2">
      <span></span>
      <ChainSelector
        type={ChainSelectorType.SMALL}
        direction={ChainSelectorDirection.SOURCE}
        label={$t('bridge.nft.step.review.your_tokens')} />
    </div>
    <div class="flex gap-2">
      <IconFlipper
        type="swap-rotate"
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
    <button class="flex justify-start link" on:click={editTransactionDetails}> {$t('common.edit')} </button>
  </div>
  <Recipient bind:this={recipientComponent} small />
  <ProcessingFee bind:this={processingFeeComponent} small bind:hasEnoughEth />
</div>

<div class="h-sep" />
