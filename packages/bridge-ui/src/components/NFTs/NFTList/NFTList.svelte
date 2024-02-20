<script lang="ts">
  import { t } from 'svelte-i18n';

  import { selectedNFTs, selectedToken } from '$components/Bridge/state';
  import { PUBLIC_NFT_BATCH_TRANSFERS_ENABLED } from '$env/static/public';
  import type { NFT } from '$libs/token';
  import { groupNFTByCollection } from '$libs/util/groupNFTByCollection';

  import NftListItem from './NFTListItem.svelte';

  export let nfts: NFT[];
  export let chainId: number | undefined;
  export let viewOnly = false;

  const multiSelectEnabled = (PUBLIC_NFT_BATCH_TRANSFERS_ENABLED || 'false') === 'true';

  let allChecked = false;
  let checkedAddresses: Map<string, boolean> = new Map();

  const toggleAllAddresses = () => {
    nfts.forEach((nft) => {
      if (!chainId) return;

      const address = nft.addresses[chainId];
      if (address) {
        checkedAddresses.set(address, allChecked);
      }
    });
    checkedAddresses = new Map(checkedAddresses);
  };

  const toggleAddressCheckBox = (collectionAddress: string) => {
    if (!collectionAddress) return;
    checkedAddresses.set(collectionAddress, !checkedAddresses.get(collectionAddress));
    checkedAddresses = new Map(checkedAddresses);
    checkAllCheckboxes();
  };

  const selectNFT = (nft: NFT) => {
    if (!selectedNFTs || !chainId || !nft) return;
    const currentChainId = chainId;
    const address = nft.addresses[currentChainId];
    const foundNFT = nfts.find((n) => n.addresses[currentChainId] === address && nft.tokenId === n.tokenId);
    $selectedNFTs = foundNFT ? [foundNFT] : null;

    if ($selectedNFTs) $selectedToken = $selectedNFTs[0];
  };

  const checkAllCheckboxes = () => {
    allChecked = nfts.every((nft) => {
      if (!chainId) return;
      const collectionAddress = nft.addresses[chainId];
      return collectionAddress && checkedAddresses.get(collectionAddress);
    });
  };

  $: collections = groupNFTByCollection(nfts);
</script>

{#if nfts.length > 0}
  <div class="flex flex-col">
    {#if multiSelectEnabled && !viewOnly}
      <div class="form-control">
        <label class="cursor-pointer label">
          <span class="label-text">{$t('bridge.nft.step.import.select_all')}</span>
          <input
            type="checkbox"
            bind:checked={allChecked}
            class="checkbox checkbox-secondary mr-[23px]"
            on:change={toggleAllAddresses} />
        </label>
      </div>
    {/if}
    {#if !chainId}
      Select a chain
    {:else}
      {#each Object.entries(collections) as [address, nftsGroup] (address)}
        <div>
          {#if nftsGroup.length > 0}
            <div class="collection-header">
              <span class="font-bold text-primary-content">
                {nftsGroup[0].name}
              </span>
              <span class="badge badge-primary badge-outline badge-xs px-[10px] h-[24px] ml-[10px]"
                ><span class="text-xs">{nftsGroup[0].type}</span></span>
            </div>
            <div class="token-ids my-[16px]">
              {#each nftsGroup as nft}
                {@const collectionAddress = nft.addresses[chainId]}
                {#if collectionAddress === undefined}
                  <div>TODO: Address for {nft.name} is undefined</div>
                {:else}
                  <NftListItem
                    {nft}
                    {multiSelectEnabled}
                    {checkedAddresses}
                    {collectionAddress}
                    {toggleAddressCheckBox}
                    {selectNFT}
                    bind:viewOnly />
                {/if}
              {/each}
            </div>
            {#if Object.keys(collections).length > 1 || nfts.length > 3}
              <div class="h-sep my-[30px]" />
            {/if}
          {/if}
        </div>
      {/each}
    {/if}
  </div>
{/if}
