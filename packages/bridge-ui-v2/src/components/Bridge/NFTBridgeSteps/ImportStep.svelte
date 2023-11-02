<script lang="ts">
  import type { Address } from '@wagmi/core';
  import { isAddress } from 'ethereum-address';
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { FlatAlert } from '$components/Alert';
  import Alert from '$components/Alert/Alert.svelte';
  import AddressInput from '$components/Bridge/AddressInput/AddressInput.svelte';
  import { AddressInputState } from '$components/Bridge/AddressInput/state';
  import Amount from '$components/Bridge/Amount.svelte';
  import IdInput from '$components/Bridge/IDInput/IDInput.svelte';
  import { IDInputState } from '$components/Bridge/IDInput/state';
  import {
    destNetwork as destinationChain,
    enteredAmount,
    insufficientBalance,
    selectedNFTs,
    selectedToken,
    tokenBalance,
  } from '$components/Bridge/state';
  import { ImportMethod } from '$components/Bridge/types';
  import { Button } from '$components/Button';
  import { ChainSelectorWrapper } from '$components/ChainSelector';
  import { IconFlipper } from '$components/Icon';
  import RotatingIcon from '$components/Icon/RotatingIcon.svelte';
  import { NFTDisplay } from '$components/NFTs';
  import { NFTView } from '$components/NFTs/types';
  import { fetchNFTs } from '$libs/bridge/fetchNFTs';
  import { detectContractType, type NFT, TokenType } from '$libs/token';
  import { checkOwnership } from '$libs/token/checkOwnership';
  import { getTokenWithInfoFromAddress } from '$libs/token/getTokenWithInfoFromAddress';
  import { noop } from '$libs/util/noop';
  import { account } from '$stores/account';
  import { network } from '$stores/network';

  export let nftIdArray: number[] = [];
  export let canProceed: boolean = false;
  export let scanned: boolean;
  export let importMethod: ImportMethod = ImportMethod.SCAN;
  export let foundNFTs: NFT[] = [];
  export let validating: boolean = false;
  export let contractAddress: Address | string = '';

  export const prefetchImage = () => noop();

  let enteredIds: string = '';
  let scanning: boolean;

  let addressInputComponent: AddressInput;
  let addressInputState: AddressInputState = AddressInputState.DEFAULT;

  let idInputState: IDInputState = IDInputState.DEFAULT;

  let invalidToken: boolean = true;
  let isOwnerOfAllToken: boolean = false;

  let detectedTokenType: TokenType | null = null;
  let interfaceSupported: boolean = true;

  let nftIdInputComponent: IdInput;
  let amountComponent: Amount;

  let nftView: NFTView = NFTView.LIST;

  const reset = () => {
    nftView = NFTView.LIST;
    enteredIds = '';
    invalidToken = true;
    isOwnerOfAllToken = false;
    detectedTokenType = null;
    amountComponent?.clearAmount();
  };

  const changeNFTView = () => {
    if (nftView === NFTView.CARDS) {
      nftView = NFTView.LIST;
    } else {
      nftView = NFTView.CARDS;
    }
  };

  const scanForNFTs = async () => {
    scanning = true;
    $selectedNFTs = [];
    const accountAddress = $account?.address;
    const srcChainId = $network?.id;
    if (!accountAddress || !srcChainId) return;
    const nftsFromAPIs = await fetchNFTs(accountAddress, BigInt(srcChainId));
    foundNFTs = nftsFromAPIs.nfts;
    scanning = false;
    scanned = true;
  };

  const changeImportMethod = () => {
    if (addressInputComponent) addressInputComponent.clearAddress();

    importMethod = importMethod === ImportMethod.MANUAL ? ImportMethod.SCAN : ImportMethod.MANUAL;
    scanned = false;
    $selectedNFTs = [];
    $selectedToken = null;
  };

  async function onAddressValidation(event: CustomEvent<{ isValidEthereumAddress: boolean; addr: Address }>) {
    const { isValidEthereumAddress, addr } = event.detail;
    invalidToken = false;
    interfaceSupported = true;
    addressInputState = AddressInputState.VALIDATING;

    if (isValidEthereumAddress && typeof addr === 'string') {
      contractAddress = addr;
      try {
        detectedTokenType = await detectContractType(addr);
      } catch {
        invalidToken = true;
        addressInputState = AddressInputState.INVALID;
      }

      if (!$network?.id) throw new Error('network not found');
      if (detectedTokenType !== TokenType.ERC721 && detectedTokenType !== TokenType.ERC1155) {
        addressInputState = AddressInputState.INVALID;
        return;
      }

      //TODO: not working as expected yet

      // interfaceSupported = await isSupportedNFTInterface(addr, detectedTokenType);
      // if (!interfaceSupported) {
      //   addressInputState = AddressInputState.INVALID;
      // } else {
      //   addressInputState = AddressInputState.VALID;
      // }
      addressInputState = AddressInputState.VALID;
    } else {
      detectedTokenType = null;
      addressInputState = AddressInputState.INVALID;
    }
    return;
  }

  const onIdInput = async () => {
    idInputState = IDInputState.VALIDATING;
    validating = true;
    const srcChainId = $network?.id;
    if (isAddress(contractAddress) && srcChainId && $account?.address && nftIdArray.length > 0) {
      const tokenId = nftIdArray[0]; //TODO: wont work with multiple token
      // If we have a valid address, we generate a token object for the $selectedToken store
      checkOwnership(contractAddress as Address, detectedTokenType, nftIdArray, $account?.address, srcChainId).then(
        async (result) => {
          isOwnerOfAllToken = result.every((value) => value.isOwner === true);
          if (isOwnerOfAllToken) {
            getTokenWithInfoFromAddress({
              contractAddress: contractAddress as Address,
              srcChainId: srcChainId,
              tokenId,
              owner: $account?.address,
            })
              .then(async (token) => {
                if (!token) throw new Error('no token with info');
                detectedTokenType = token.type;
                idInputState = IDInputState.VALID;
                $selectedToken = token;
                $selectedNFTs = [token as NFT];
                await prefetchImage();
              })
              .catch((err) => {
                console.error(err);
                detectedTokenType = null;
                idInputState = IDInputState.INVALID;
                invalidToken = true;
              });
            idInputState = IDInputState.VALID;
          } else {
            idInputState = IDInputState.INVALID;
          }
        },
      );
    }
    idInputState = IDInputState.DEFAULT;
    validating = false;
  };

  onMount(() => {
    reset();
  });

  $: canImport = $account?.isConnected && $network?.id && $destinationChain && !scanning;

  // Handles the next step button status
  $: {
    const hasSelectedNFTs = $selectedNFTs !== null && $selectedNFTs !== undefined && $selectedNFTs.length > 0;
    if (!hasSelectedNFTs) canProceed = false;

    const isValidManualERC721 =
      detectedTokenType === TokenType.ERC721 &&
      addressInputState === AddressInputState.VALID &&
      idInputState === IDInputState.VALID &&
      isOwnerOfAllToken;

    const isValidManualERC1155 =
      detectedTokenType === TokenType.ERC1155 &&
      addressInputState === AddressInputState.VALID &&
      idInputState === IDInputState.VALID &&
      $enteredAmount > BigInt(0) &&
      isOwnerOfAllToken;

    const isManualImportValid = importMethod === ImportMethod.MANUAL && (isValidManualERC721 || isValidManualERC1155);

    const isValidScanERC1155 =
      hasSelectedNFTs &&
      $selectedNFTs![0].type === TokenType.ERC1155 &&
      $enteredAmount > BigInt(0) &&
      typeof $tokenBalance === 'bigint' &&
      $enteredAmount <= $tokenBalance &&
      !$insufficientBalance;

    const isValidScanERC721 = hasSelectedNFTs && $selectedNFTs![0].type === TokenType.ERC721;

    const isScanImportValid =
      importMethod === ImportMethod.SCAN &&
      hasSelectedNFTs &&
      $destinationChain !== undefined && // Assuming undefined is invalid
      scanned &&
      (isValidScanERC1155 || isValidScanERC721);

    canProceed = isManualImportValid || isScanImportValid;
  }

  $: isDisabled = idInputState !== IDInputState.VALID || addressInputState !== AddressInputState.VALID;
</script>

<div class="f-between-center gap-4 mt-[30px]">
  <ChainSelectorWrapper />
</div>
<div class="h-sep my-[30px]" />
<!-- 
Manual NFT Input 
-->
{#if importMethod === ImportMethod.MANUAL}
  <div id="manualImport">
    <AddressInput
      bind:this={addressInputComponent}
      bind:ethereumAddress={contractAddress}
      bind:state={addressInputState}
      class="bg-neutral-background border-0 h-[56px]"
      on:addressvalidation={onAddressValidation}
      labelText={$t('inputs.address_input.label.contract')}
      quiet />
    {#if addressInputState === AddressInputState.INVALID && invalidToken}
      <FlatAlert type="error" forceColumnFlow message="todo: invalid token" />
    {/if}

    {#if !interfaceSupported}
      <Alert type="error">TODO: token interface is not supported (link to docs?)</Alert>
    {/if}
    <div class="min-h-[20px] !mt-3">
      <!-- TODO: add limit to config -->
      <IdInput
        isDisabled={addressInputState !== AddressInputState.VALID}
        bind:this={nftIdInputComponent}
        bind:enteredIds
        bind:validIdNumbers={nftIdArray}
        bind:state={idInputState}
        on:inputValidation={onIdInput}
        limit={1}
        class="bg-neutral-background border-0 h-[56px]" />
      <div class="min-h-[20px] !mt-3">
        {#if !isOwnerOfAllToken && nftIdArray?.length > 0 && !validating}
          <FlatAlert type="error" forceColumnFlow message="todo: must be owner of all token" />
        {/if}
      </div>
    </div>
    {#if detectedTokenType === TokenType.ERC1155 && interfaceSupported}
      <Amount bind:this={amountComponent} class="bg-neutral-background border-0 h-[56px]" disabled={isDisabled} />
    {/if}
  </div>
{:else}
  <!-- 
Automatic NFT Input 
-->
  {#if !scanned}
    <div class="f-col w-full gap-4">
      <Button
        disabled={!canImport}
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
        disabled={!canImport}
        type="neutral"
        class="px-[28px] py-[14px] bg-transparent border-primary-brand rounded-full "
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
              <RotatingIcon loading={scanning} type="refresh" size={13} />
            </Button>

            <IconFlipper
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
      {#if $selectedNFTs && $selectedNFTs[0]?.type === TokenType.ERC1155}
        <section>
          <Amount bind:this={amountComponent} />
        </section>
      {/if}

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
