<script lang="ts">
  import { writable } from 'svelte/store';
  import { t } from 'svelte-i18n';

  import { Alert } from '$components/Alert';
  import AddressInput from '$components/Bridge/AddressInput/AddressInput.svelte';
  import NftIdInput from '$components/Bridge/NftIdInput/NftIdInput.svelte';
  import { Button } from '$components/Button';
  import { Card } from '$components/Card';
  import { ChainSelector } from '$components/ChainSelector';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { chains } from '$libs/chain';
  import { detectContractType, ETHToken, fetchERC721Images, fetchERC1155Images, type Token, tokens } from '$libs/token';
  import type { Account } from '$stores/account';
  import { activeTab } from '$stores/bridgetabs';
  import { destChain } from '$stores/network';
  import { type Network, network } from '$stores/network';

  import { AmountInput } from './AmountInput';
  import { ProcessingFee } from './ProcessingFee';
  import { RecipientInput } from './RecipientInput';
  import { destNetwork, selectedToken } from './state';
  import SwitchChainsButton from './SwitchChainsButton.svelte';

  let isAddressValid = false;
  let importSuccess = false;
  let activeTabName: string;
  let contractTypeStore = writable('');
  let tokenIdStore = writable<Array<number>>([]);
  let errorIdStore = writable<Array<number>>([]);
  let contractAddress = '';
  let imageUrls = Array<any>();

  $: activeTabName = $activeTab;
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
  $: if (activeTabName === 'nft_tab') {
    resetAllStates();
  }

  function resetAllStates() {
    isAddressValid = false;
    importSuccess = false;
    contractTypeStore.set('');
    tokenIdStore.set([]);
    contractAddress = '';
    imageUrls = [];
  }

  async function handleImport() {
    contractTypeStore.set(await detectContractType(contractAddress));
    let result = null;
    if ($contractTypeStore === 'ERC721') {
      result = await fetchERC721Images(contractAddress, tokenIds);
    } else if ($contractTypeStore === 'ERC1155') {
      result = await fetchERC1155Images(contractAddress, tokenIds);
    }
    if (result) {
      importSuccess = true;
      errorIdStore.set(result.errors);
      imageUrls = result.images;
    } else {
      importSuccess = false;
    }
  }

  function onNetworkChange(network: Network) {
    if (network && chains.length === 2) {
      // If there are only two chains, the destination chain will be the other one
      const otherChain = chains.find((chain) => chain.id !== network.id);

      if (otherChain) destNetwork.set(otherChain);
    }
  }

  function onAccountChange(account: Account) {
    if (account && account.isConnected && !$selectedToken) {
      $selectedToken = ETHToken;
    } else if (account && account.isDisconnected) {
      $selectedToken = null;
      $destNetwork = null;
    }
  }
</script>

{#if activeTabName === 'erc20_tab'}
  <Card class="md:w-[524px]" title={$t('bridge.title')} text={$t('bridge.subtitle')}>
    <div class="space-y-[35px]">
      <div class="space-y-4">
        <div class="space-y-2">
          <ChainSelector label={$t('chain.from')} value={$network} switchWallet />
          <TokenDropdown {tokens} bind:value={$selectedToken} />
        </div>

        <AmountInput />

        <div class="f-justify-center">
          <SwitchChainsButton />
        </div>

        <div class="space-y-2">
          <ChainSelector label={$t('chain.to')} value={$destNetwork} readOnly />
          <RecipientInput />
        </div>
      </div>

      <ProcessingFee />

      <div class="h-sep" />

      <Button type="primary" class="px-[28px] py-[14px]">
        <span class="body-bold">{$t('bridge.button.bridge')}</span>
      </Button>
    </div>
  </Card>
{:else if activeTabName === 'nft_tab'}
  <Card class="md:w-[524px]" title={$t('bridge.nft.title')} text={$t('bridge.subtitle')}>
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
                <img class="object-cover h-full w-full" src={Object.values(imageUrls[0])[0]} alt="NFT" />
              </div>
            </div>
          {:else if imageUrls.length > 1 && imageUrls.length <= 3}
            <div class="flex justify-between">
              {#each imageUrls as image, index (image)}
                {#each Object.values(image) as imageUrl}
                  <div class="w-1/3">
                    <img class="object-cover h-full w-full" src={imageUrl} alt="Nft {index}" />
                  </div>
                {/each}
              {/each}
            </div>
          {:else}
            <div class="grid grid-cols-3 gap-4">
              {#each imageUrls as image, index (image)}
                {#each Object.values(image) as imageUrl}
                  <div>
                    <img class="object-cover h-full w-full" src={imageUrl} alt="Nft {index}" />
                  </div>
                {/each}
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

        <!-- if address valid show next input -->
        <div class="f-justify-center">
          <button class="f-center rounded-full bg-secondary-icon w-[30px] h-[30px]">
            <Icon type="up-down" />
          </button>
        </div>

        <div class="space-y-2">
          <ChainSelector label={$t('chain.to')} value={$destChain} />
          <!-- <RecipientInput /> -->
        </div>
      </div>

      <ProcessingFee />

      <div class="h-sep" />

      <Button type="primary" class="px-[28px] py-[14px]  w-full">
        <span class="body-bold">{$t('bridge.button.bridge')}</span>
      </Button>
    </div>
  </Card>
{/if}
