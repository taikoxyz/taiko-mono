<script lang="ts">
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { Alert } from '$components/Alert';
  import { Button } from '$components/Button';
  import { Card } from '$components/Card';
  import { ChainSelector } from '$components/ChainSelector';
  import { Icon } from '$components/Icon';
  import { detectContractType, fetchERC721Images, fetchERC1155Images } from '$libs/token';
  import { network } from '$stores/network';
  import { contractTypeStore, errorIdStore, tokenIdStore } from '$stores/nfts';

  import AddressInput from './AddressInput.svelte';
  import NftIdInput from './NFTIdInput.svelte';
  import { ProcessingFee } from './ProcessingFee';

  let isAddressValid = false;

  let contractAddress = '';
  let imageUrls = Array<string>();

  $: tokenIds = $tokenIdStore;
  $: isButtonDisabled = !($tokenIdStore?.length ?? 0);

  const handleAddressValidation = (event: { detail: { isValidEthereumAddress: boolean; ethereumAddress: string } }) => {
    isAddressValid = event.detail.isValidEthereumAddress;
    contractAddress = event.detail.ethereumAddress;
  };

  const handleIdValidation = (event: { detail: { tokenIds: number[] } }) => {
    tokenIdStore.set(event.detail.tokenIds);
  };

  //Todo: figure out a better way to do this?
  onMount(() => {
    resetAllStates();
  });

  function resetAllStates() {
    // TODO: change to $store format
    isAddressValid = false;
    contractTypeStore.set('');
    tokenIdStore.set([]);
    contractAddress = '';
    imageUrls = [];
  }

  async function handleImport() {
    contractTypeStore.set(await detectContractType(contractAddress, tokenIds[0]));
    let result = null;
    // TODO: use TokenType enum
    if ($contractTypeStore === 'ERC721') {
      result = await fetchERC721Images(contractAddress, tokenIds);
    } else if ($contractTypeStore === 'ERC1155') {
      result = await fetchERC1155Images(contractAddress, tokenIds);
    }
    if (result) {
      errorIdStore.set(result.errors);
      imageUrls = result.images.map((image) => Object.values(image)[0]);
    }
  }
</script>

<Card class="md:w-[524px]" title={$t('bridge.title.nft')} text={$t('bridge.description')}>
  <div class="space-y-[35px]">
    <div class="space-y-4">
      <div class="space-y-2">
        <ChainSelector label={$t('chain.from')} value={$network} switchWallet />
      </div>
      <AddressInput on:addressvalidation={handleAddressValidation} />
      {#if isAddressValid}
        <NftIdInput on:tokenIdUpdate={handleIdValidation} />
        <Button type="primary" disabled={isButtonDisabled} class="px-[28px] py-[14px]  w-full" on:click={handleImport}
          >{$t('bridge.button.import')}</Button>
      {/if}
      <!-- NFT images -->
      {#if imageUrls.length > 0}
        <p>Contract Type: {$contractTypeStore}</p>
        {#if imageUrls.length === 1}
          <div class="grid grid-cols-1">
            <div>
              <img class="object-cover h-full w-full" src={imageUrls[0]} alt="NFT" />
            </div>
          </div>
        {:else if imageUrls.length > 1 && imageUrls.length <= 3}
          <div class="flex justify-between">
            {#each imageUrls as imageUrl, index (imageUrl)}
              <div class="w-1/3">
                <img class="object-cover h-full w-full" src={imageUrl} alt={`Nft ${index}`} />
              </div>
            {/each}
          </div>
        {:else}
          <div class="grid grid-cols-3 gap-4">
            {#each imageUrls as imageUrl, index (imageUrl)}
              <div>
                <img class="object-cover h-full w-full" src={imageUrl} alt={`Nft ${index}`} />
              </div>
            {/each}
          </div>
        {/if}
      {/if}

      {#if $errorIdStore.length !== 0}
        <Alert type="error" forceColumnFlow>
          <p class="font-bold">Import failed</p>
          <p>Are you sure all token exist and that you are the owner?</p>
          <p>Token with id(s) {$errorIdStore} threw errors.</p>
          <br />
          <p>Check our guide if you need help!</p>
        </Alert>
      {/if}

      <div class="f-justify-center">
        <button class="f-center rounded-full bg-secondary-icon w-[30px] h-[30px]">
          <Icon type="up-down" />
        </button>
      </div>

      <div class="space-y-2" />
    </div>

    <ProcessingFee />

    <div class="h-sep" />

    <Button type="primary" class="px-[28px] py-[14px]  w-full">
      <span class="body-bold">{$t('bridge.button.bridge')}</span>
    </Button>
  </div>
</Card>
