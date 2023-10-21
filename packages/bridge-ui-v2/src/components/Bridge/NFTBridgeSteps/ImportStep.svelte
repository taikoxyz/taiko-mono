<script lang="ts">
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import { FlatAlert } from '$components/Alert';
  import AddressInput from '$components/Bridge/AddressInput/AddressInput.svelte';
  import { AddressInputState } from '$components/Bridge/AddressInput/state';
  import IdInput from '$components/Bridge/IDInput/IDInput.svelte';
  import { IDInputState } from '$components/Bridge/IDInput/state';
  import { destNetwork as destinationChain, selectedToken } from '$components/Bridge/state';
  import { Button } from '$components/Button';
  import { ChainSelectorWrapper } from '$components/ChainSelector';
  import { IconFlipper } from '$components/Icon';
  import RotatingIcon from '$components/Icon/RotatingIcon.svelte';
  import { LoadingMask } from '$components/LoadingMask';
  import { NFTCard } from '$components/NFTCard';
  import { NFTList } from '$components/NFTList';
  import { type NFT, TokenType } from '$libs/token';
  import { checkOwnership } from '$libs/token/checkOwnership';
  import { getTokenWithInfoFromAddress } from '$libs/token/getTokenWithInfoFromAddress';
  import { noop } from '$libs/util/noop';
  import { account } from '$stores/account';
  import { network } from '$stores/network';

  export let scanForNFTs: () => Promise<void> = async () => {};

  export let selectedNFT: NFT[];
  export let nftIdArray: number[];
  export let contractAddress: Address | '';
  export let canProceed: boolean;
  export let scanned: boolean;
  export let scanning: boolean;

  export let importMethod: 'scan' | 'manual';

  enum NFTView {
    CARDS,
    LIST,
  }
  let nftView: NFTView = NFTView.LIST;

  const changeNFTView = () => {
    if (nftView === NFTView.CARDS) {
      nftView = NFTView.LIST;
    } else {
      nftView = NFTView.CARDS;
    }
  };

  let validating: boolean = false;
  let enteredIds: string = '';
  //   let manualNFTInput: boolean = false;
  let addressInputState: AddressInputState = AddressInputState.Default;

  let isOwnerOfAllToken: boolean = false;
  let detectedTokenType: TokenType | null = null;
  export let foundNFTs: NFT[] = [];

  $: canScan = $account?.isConnected && $network?.id && $destinationChain && !scanning;

  let addressInputComponent: AddressInput;
  let nftIdInputComponent: IdInput;

  const changeImportMethod = () => {
    if (addressInputComponent) addressInputComponent.clearAddress();

    importMethod = importMethod === 'manual' ? 'scan' : 'manual';
    scanned = false;
    selectedNFT = [];
    $selectedToken = null;
  };

  function onAddressValidation(event: CustomEvent<{ isValidEthereumAddress: boolean; addr: Address }>) {
    const { isValidEthereumAddress, addr } = event.detail;
    addressInputState = AddressInputState.Validating;

    if (isValidEthereumAddress && typeof addr === 'string') {
      if (!$network?.id) throw new Error('network not found');
      const srcChainId = $network?.id;
      // If we have a valid address, we generate a token object for the $selectedToken store
      getTokenWithInfoFromAddress({ contractAddress: addr, srcChainId: srcChainId, owner: $account?.address })
        .then((token) => {
          if (!token) throw new Error('no token with info');
          detectedTokenType = token.type;
          addressInputState = AddressInputState.Valid;
          $selectedToken = token;
        })
        .catch((err) => {
          console.error(err);
          detectedTokenType = null;
          addressInputState = AddressInputState.Invalid;
        });
    } else {
      detectedTokenType = null;
      addressInputState = AddressInputState.Invalid;
    }
  }

  // Update ID input state based on the current state of the form
  let idInputState: IDInputState;
  $: {
    if (isOwnerOfAllToken && nftIdArray?.length > 0) {
      idInputState = IDInputState.VALID;
    } else if (!isOwnerOfAllToken && nftIdArray?.length > 0) {
      idInputState = IDInputState.INVALID;
    } else {
      idInputState = IDInputState.DEFAULT;
    }
  }

  let previousSelectedToken: typeof $selectedToken | null = null;
  $: {
    if (
      (selectedNFT.length > 0 &&
        $selectedToken !== selectedNFT[0] &&
        selectedNFT.length > 0 &&
        $network?.id &&
        (previousSelectedToken !== $selectedToken || !previousSelectedToken)) ||
      (nftIdArray && nftIdArray.length > 0)
    ) {
      previousSelectedToken = $selectedToken;
      if (!scanned) {
        if (addressInputState !== AddressInputState.Valid) () => noop();
        if (contractAddress === '') () => noop();
      } else {
        //eslint-disable-next-line @typescript-eslint/no-non-null-asserted-optional-chain
        contractAddress = selectedNFT[0].addresses[$network?.id!];
      }

      if ($account?.address && $network?.id && contractAddress)
        checkOwnership(contractAddress, detectedTokenType, nftIdArray, $account?.address, $network?.id).then(
          (result) => {
            result;
            isOwnerOfAllToken = result.every((value) => value.isOwner === true);
          },
        );

      //TODO: this needs changing if we do batch transfers in the future:
      // Update either selectedToken store to handle arrays or the actions to access a different store for NFTs
      $selectedToken = selectedNFT[0];
    }
  }

  // Handles the next step button status
  $: if (
    importMethod === 'manual'
      ? addressInputState === AddressInputState.Valid &&
        nftIdArray.length > 0 &&
        contractAddress &&
        $destinationChain &&
        isOwnerOfAllToken
      : selectedNFT.length > 0 && $destinationChain && scanned
  ) {
    canProceed = true;
  }
</script>

<div class="f-between-center gap-4">
  <ChainSelectorWrapper />
</div>
<div class="h-sep" />

<!-- 
Manual NFT Input 
-->
{#if importMethod === 'manual'}
  <AddressInput
    bind:this={addressInputComponent}
    bind:ethereumAddress={contractAddress}
    bind:state={addressInputState}
    class="bg-neutral-background border-0 h-[56px]"
    on:addressvalidation={onAddressValidation}
    labelText={$t('inputs.address_input.label.contract')}
    quiet />
  <div class="min-h-[20px] !mt-3">
    {#if detectedTokenType === TokenType.ERC721 && contractAddress}
      <FlatAlert type="success" forceColumnFlow message="todo: valid erc721" />
    {:else if detectedTokenType === TokenType.ERC1155 && contractAddress}
      <FlatAlert type="success" forceColumnFlow message="todo: valid erc1155" />
    {/if}

    <!-- TODO: add limit to config -->
    <IdInput
      bind:this={nftIdInputComponent}
      bind:enteredIds
      bind:numbersArray={nftIdArray}
      bind:state={idInputState}
      limit={1}
      class="bg-neutral-background border-0 h-[56px]" />
    <div class="min-h-[20px] !mt-3">
      {#if !isOwnerOfAllToken && nftIdArray?.length > 0 && !validating}
        <FlatAlert type="error" forceColumnFlow message="todo: must be owner of all token" />
      {/if}
    </div>
  </div>
{:else}
  <!-- 
Automatic NFT Input 
-->
  {#if !scanned}
    <div class="f-col w-full gap-4">
      <Button
        disabled={!canScan}
        loading={scanning}
        type={scanned ? 'neutral' : 'primary'}
        class="px-[28px] py-[14px] rounded-full flex-1 text-white"
        on:click={() =>
          (async () => {
            await scanForNFTs();
          })()}>
        {$t('bridge.actions.nft_scan')}
      </Button>

      <Button
        type="neutral"
        class="px-[28px] py-[14px] bg-transparent !border border-primary-brand rounded-full hover:border-primary-interactive-hover "
        on:click={() => changeImportMethod()}>
        {$t('bridge.actions.nft_manual')}
      </Button>
    </div>
  {/if}

  <div class="f-col w-full gap-4">
    {#if scanned}
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
              on:click={() =>
                (async () => {
                  await scanForNFTs();
                })()}>
              <RotatingIcon loading={scanning} type="refresh" size={28} viewBox={'-6 -5 24 24'} />
            </Button>

            <IconFlipper
              iconType1="list"
              iconType2="cards"
              selectedDefault="cards"
              class="bg-neutral w-[28px] h-[28px] rounded-full"
              on:labelclick={changeNFTView} />
          </div>
        </div>
        <div>
          <div class="relative max-h-[200px] min-h-[200px] bg-neutral rounded-[20px] pl-2 overflow-hidden">
            <div class="max-h-[200px] min-h-[200px] overflow-y-auto py-2">
              {#if scanning}
                <LoadingMask spinnerClass="border-white" text={$t('messages.bridge.nft_scanning')} />
              {:else if nftView === NFTView.LIST}
                <NFTList bind:nfts={foundNFTs} chainId={$network?.id} bind:selectedNFT />
              {:else if nftView === NFTView.CARDS}
                {#each foundNFTs as nft}
                  <NFTCard {nft} />
                {/each}
              {/if}
            </div>
          </div>
        </div>
      </section>

      <div class="flex items-center justify-between space-x-2">
        <p class="text-secondary-content">{$t('bridge.nft.step.import.scan_screen.description')}</p>
        <Button
          type="neutral"
          class="rounded-full py-[8px] px-[20px] bg-transparent !border border-primary-brand hover:border-primary-interactive-hover "
          on:click={() => changeImportMethod()}>
          {$t('common.add')}
        </Button>
      </div>
    {/if}
  </div>
{/if}
