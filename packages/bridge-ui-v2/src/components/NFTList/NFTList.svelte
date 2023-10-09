<script lang="ts">
  import type { Address } from 'viem';

  import { PUBLIC_NFT_BATCH_TRANSFERS_ENABLED } from '$env/static/public';
  import { type NFT, TokenType } from '$libs/token';
  import { fetchNFTImage } from '$libs/token/fetchNFTImage';

  export let nfts: NFT[];
  export let chainId: number | undefined;
  export let selectedNFT: NFT[] | null = [];

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

  const toggleAddressCheckBox = (address: string) => {
    if (!address) return;
    checkedAddresses.set(address, !checkedAddresses.get(address));
    checkedAddresses = new Map(checkedAddresses);
    checkAllCheckboxes();
  };

  const selectNFT = (address: Address) => {
    if (!selectedNFT || !chainId) return;
    const currentChainId = chainId;
    const foundNFT = nfts.find((nft) => nft.addresses[currentChainId] === address);
    selectedNFT = foundNFT ? [foundNFT] : null;
  };

  const checkAllCheckboxes = () => {
    allChecked = nfts.every((nft) => {
      if (!chainId) return;
      const address = nft.addresses[chainId];
      return address && checkedAddresses.get(address);
    });
  };
</script>

{#if nfts.length > 0}
  <div class="flex flex-col">
    {#if multiSelectEnabled}
      <div class="form-control">
        <label class="cursor-pointer label">
          <span class="label-text">Select all NFTs</span>
          <input
            type="checkbox"
            bind:checked={allChecked}
            class="checkbox checkbox-secondary mr-[23px]"
            on:change={toggleAllAddresses} />
        </label>
      </div>
    {/if}
    <div class="max-h-[200px] min-h-[150px] overflow-y-scroll bg-neutral rounded p-2">
      {#if !chainId}
        Select a chain
      {:else}
        {#each nfts as nft (nft.addresses[chainId])}
          {@const address = nft.addresses[chainId]}
          {@const tokenImage = fetchNFTImage(nft)}

          {#if address === undefined}
            <div>Address for {nft.name} is undefined</div>
          {:else}
            <div class="form-control flex">
              <label class="cursor-pointer label">
                <div class="mr-2">
                  {#if tokenImage}
                    {tokenImage}
                  {:else}
                    <img alt="placeholder nft" src="/chains/taiko.svg" class="w-[40px] h-[40px] rounded" />
                  {/if}
                </div>
                <div class="f-col grow">
                  <span class="font-bold">
                    {nft.name}
                    <span class="badge badge-primary badge-outline badge-xs p-2">{nft.type}</span></span>
                  <span class=" text-xs text-neutral-content">ID: {nft.tokenId}</span>
                  {#if nft.type === TokenType.ERC1155}
                    <span class=" text-xs text-neutral-content">Balance: {nft.balance}</span>
                  {/if}
                  <!-- <span class=" text-xs text-neutral-content">{truncateString(nft.addresses[chainId], 18)}</span> -->
                </div>
                {#if multiSelectEnabled}
                  <input
                    type="checkbox"
                    class="checkbox checkbox-secondary"
                    checked={checkedAddresses.get(address) || false}
                    on:change={() => toggleAddressCheckBox(address)} />
                {:else}
                  <input
                    type="radio"
                    name="nft-radio"
                    class="flex-none radio radio-secondary"
                    on:change={() => selectNFT(address)} />
                {/if}
              </label>
            </div>
          {/if}
        {/each}
      {/if}
    </div>
  </div>
{/if}
