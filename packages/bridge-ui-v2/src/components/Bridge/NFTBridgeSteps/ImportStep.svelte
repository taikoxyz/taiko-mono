<script lang="ts">
  import type { Address } from '@wagmi/core';
  import { isAddress } from 'ethereum-address';
  import { onDestroy } from 'svelte';
  import { t } from 'svelte-i18n';

  import { chainConfig } from '$chainConfig';
  import { FlatAlert } from '$components/Alert';
  import Alert from '$components/Alert/Alert.svelte';
  import AddressInput from '$components/Bridge/AddressInput/AddressInput.svelte';
  import { AddressInputState } from '$components/Bridge/AddressInput/state';
  import Amount from '$components/Bridge/Amount.svelte';
  import IdInput from '$components/Bridge/IDInput/IDInput.svelte';
  import { IDInputState } from '$components/Bridge/IDInput/state';
  import {
    destNetwork as destinationChain,
    destNetwork,
    enteredAmount,
    insufficientBalance,
    selectedNFTs,
    selectedToken,
    tokenBalance,
  } from '$components/Bridge/state';
  import { ImportMethod } from '$components/Bridge/types';
  import { Button } from '$components/Button';
  import ActionButton from '$components/Button/ActionButton.svelte';
  import { ChainSelectorWrapper } from '$components/ChainSelector';
  import { IconFlipper } from '$components/Icon';
  import RotatingIcon from '$components/Icon/RotatingIcon.svelte';
  import { NFTDisplay } from '$components/NFTs';
  import { NFTView } from '$components/NFTs/types';
  import { PUBLIC_SLOW_L1_BRIDGING } from '$env/static/public';
  import { fetchNFTs } from '$libs/bridge/fetchNFTs';
  import { LayerType } from '$libs/chain';
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

  let isOwnerOfAllToken: boolean = false;

  let detectedTokenType: TokenType | null = null;
  let interfaceSupported: boolean = true;

  let nftIdInputComponent: IdInput;
  let amountComponent: Amount;

  let nftView: NFTView = NFTView.LIST;

  let slowL1Warning = PUBLIC_SLOW_L1_BRIDGING || false;

  const reset = () => {
    nftView = NFTView.LIST;
    enteredIds = '';
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
    const destChainId = $destNetwork?.id;
    if (!accountAddress || !srcChainId || !destChainId) return;
    const nftsFromAPIs = await fetchNFTs(accountAddress, srcChainId, destChainId);
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
    interfaceSupported = true;
    addressInputState = AddressInputState.VALIDATING;

    if (isValidEthereumAddress && typeof addr === 'string') {
      contractAddress = addr;
      try {
        detectedTokenType = await detectContractType(addr);
      } catch {
        addressInputState = AddressInputState.INVALID;
      }

      if (!$network?.id) throw new Error('network not found');
      if (detectedTokenType !== TokenType.ERC721 && detectedTokenType !== TokenType.ERC1155) {
        addressInputState = AddressInputState.NOT_NFT;
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

  onDestroy(() => {
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

  $: nothingFound = scanned && foundNFTs.length === 0;

  $: displayOwnershipError =
    contractAddress && enteredIds && !isOwnerOfAllToken && nftIdArray?.length > 0 && !validating;

  $: displayL1Warning =
    slowL1Warning && $destinationChain?.id && chainConfig[$destinationChain.id].type === LayerType.L1;
</script>

<div class="f-between-center gap-[16px] mt-[30px]">
  <ChainSelectorWrapper />
</div>

{#if displayL1Warning}
  <Alert type="warning">{$t('bridge.alerts.slow_bridging')}</Alert>
{/if}
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
      labelText={$t('inputs.address_input.label.contract')} />

    <!-- {#if !interfaceSupported}
      <Alert type="error">TODO: token interface is not supported (link to docs?)</Alert>
    {/if} -->
    <div class="min-h-[20px] mt-[30px]">
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
        {#if displayOwnershipError}
          <FlatAlert type="error" forceColumnFlow message={$t('bridge.errors.not_the_owner_of_all')} />
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
  {#if !scanned || nothingFound}
    <div class="h-sep" />

    <div class="f-col w-full gap-4">
      {#if scanned}
        <ActionButton
          priority="secondary"
          disabled={!canImport}
          loading={scanning}
          on:click={() =>
            (async () => {
              await scanForNFTs();
            })()}>
          {$t('bridge.actions.nft_scan_again')}
        </ActionButton>

        <ActionButton priority="primary" disabled={!canImport} on:click={() => changeImportMethod()}>
          {$t('bridge.actions.nft_manual')}
        </ActionButton>

        <Alert type="warning" forceColumnFlow class="mt-[16px]">
          <p>{$t('bridge.nft.step.import.no_nft_found')}</p>
        </Alert>
      {:else}
        <ActionButton
          priority="primary"
          disabled={!canImport}
          loading={scanning}
          on:click={() =>
            (async () => {
              await scanForNFTs();
            })()}>
          {$t('bridge.actions.nft_scan')}
        </ActionButton>

        <ActionButton priority="secondary" disabled={!canImport} on:click={() => changeImportMethod()}>
          {$t('bridge.actions.nft_manual')}
        </ActionButton>{/if}
    </div>
  {/if}
  {#if scanned && foundNFTs.length > 0}
    <div class="f-col w-full gap-4">
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
              type="swap-rotate"
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
        <ActionButton priority="secondary" on:click={() => changeImportMethod()}>
          {$t('common.add')}
        </ActionButton>
      </div>
    </div>
  {/if}
{/if}
