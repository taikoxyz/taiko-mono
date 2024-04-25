<script lang="ts">
  import { t } from 'svelte-i18n';
  import { type Address, isAddress } from 'viem';

  import { FlatAlert } from '$components/Alert';
  import IdInput from '$components/Bridge/NFTBridgeComponents/IDInput/IDInput.svelte';
  import { IDInputState } from '$components/Bridge/NFTBridgeComponents/IDInput/state';
  import TokenAmountInput from '$components/Bridge/NFTBridgeComponents/ImportStep/TokenAmountInput.svelte';
  import AddressInput from '$components/Bridge/SharedBridgeComponents/AddressInput/AddressInput.svelte';
  import { AddressInputState } from '$components/Bridge/SharedBridgeComponents/AddressInput/state';
  import { enteredAmount, selectedNFTs, selectedToken, tokenBalance } from '$components/Bridge/state';
  import { importDone } from '$components/Bridge/state';
  1;
  import { detectContractType, type NFT, TokenType } from '$libs/token';
  import { checkOwnership } from '$libs/token/checkOwnership';
  import { getTokenWithInfoFromAddress } from '$libs/token/getTokenWithInfoFromAddress';
  import { account } from '$stores/account';
  import { connectedSourceChain } from '$stores/network';

  export let contractAddress: Address | string = '';
  export let nftIdsToImport: number[] = [];
  export let validating: boolean = false;

  let addressInputState: AddressInputState = AddressInputState.DEFAULT;

  let addressInputComponent: AddressInput;
  let amountComponent: TokenAmountInput;
  let nftIdInputComponent: IdInput;

  let idInputState: IDInputState = IDInputState.DEFAULT;

  let enteredIds: number[] = [];

  let detectedTokenType: TokenType | null = null;

  $: isOwnerOfAllToken = false;

  async function onAddressValidation(event: CustomEvent<{ isValidEthereumAddress: boolean; addr: Address }>) {
    const { isValidEthereumAddress, addr } = event.detail;
    // interfaceSupported = true;
    addressInputState = AddressInputState.VALIDATING;

    const srcChainId = $connectedSourceChain?.id;
    if (!srcChainId) return;

    if (isValidEthereumAddress && typeof addr === 'string') {
      contractAddress = addr;
      try {
        detectedTokenType = await detectContractType(addr, srcChainId);
      } catch {
        addressInputState = AddressInputState.INVALID;
      }
      if (!$connectedSourceChain?.id) throw new Error('network not found');
      if (detectedTokenType !== TokenType.ERC721 && detectedTokenType !== TokenType.ERC1155) {
        addressInputState = AddressInputState.NOT_NFT;
        return;
      }

      addressInputState = AddressInputState.VALID;
    } else {
      detectedTokenType = null;
      addressInputState = AddressInputState.INVALID;
    }
    return;
  }

  async function onIdInput(): Promise<void> {
    idInputState = IDInputState.VALIDATING;
    validating = true;

    try {
      if (canValidateIdInput && enteredIds && enteredIds.length > 0) {
        const tokenId = nftIdsToImport[0]; // Handle multiple tokens if needed

        const ownershipResults = await checkOwnership(
          contractAddress as Address,
          detectedTokenType,
          nftIdsToImport,
          // Ignore as we check this in canValidateIdInput
          // eslint-disable-next-line @typescript-eslint/no-non-null-asserted-optional-chain
          $account?.address!,
          // Ignore as we check this in canValidateIdInput
          // eslint-disable-next-line @typescript-eslint/no-non-null-asserted-optional-chain
          $connectedSourceChain?.id!,
        );

        isOwnerOfAllToken = ownershipResults.every((value) => value.isOwner === true);

        if (!isOwnerOfAllToken) {
          idInputState = IDInputState.INVALID;
          throw new Error('Not owner of all tokens');
        }
        const token = await getTokenWithInfoFromAddress({
          contractAddress: contractAddress as Address,
          // Ignore as we check this in canValidateIdInput
          // eslint-disable-next-line @typescript-eslint/no-non-null-asserted-optional-chain
          srcChainId: $connectedSourceChain?.id!,
          tokenId,
          owner: $account?.address,
        });

        if (!token) {
          throw new Error('No token with info');
        }

        detectedTokenType = token.type;
        $selectedNFTs = [token as NFT];
        $selectedToken = token;
        idInputState = IDInputState.VALID;
      } else {
        idInputState = IDInputState.INVALID;
      }
    } catch (err) {
      console.error(err);
      detectedTokenType = null;
      idInputState = IDInputState.INVALID;
    } finally {
      if (idInputState !== IDInputState.VALID) {
        idInputState = IDInputState.DEFAULT;
      }
    }
    validating = false;
  }

  $: displayOwnershipError =
    contractAddress && enteredIds && !isOwnerOfAllToken && nftIdsToImport?.length > 0 && !validating;

  $: canValidateIdInput = isAddress(contractAddress) && $connectedSourceChain?.id && $account?.address ? true : false;

  $: isERC1155 = detectedTokenType === TokenType.ERC1155;

  $: nftHasAmount = hasSelectedNFT && isERC1155;

  $: validBalance = $tokenBalance && $enteredAmount > 0 && $enteredAmount <= $tokenBalance.value;

  $: hasEnteredIds = enteredIds && enteredIds.length > 0;
  $: hasSelectedNFT = $selectedNFTs && $selectedNFTs?.length > 0 && hasEnteredIds;

  $: commonChecks =
    enteredIds && enteredIds.length > 0 && !validating && idInputState === IDInputState.VALID && isOwnerOfAllToken;

  $: ERC1155Checks = commonChecks && nftHasAmount !== null && hasSelectedNFT !== null && validBalance;

  $: canProceed = isERC1155 ? ERC1155Checks : commonChecks;

  $: if (canProceed) {
    $importDone = true;
  } else {
    $importDone = false;
  }

  $: showNFTAmountInput = nftHasAmount && isOwnerOfAllToken;

  $: isDisabled = idInputState !== IDInputState.VALID || addressInputState !== AddressInputState.VALID;
</script>

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
  <!-- TODO: currently hard limited to 1 -->
  <IdInput
    isDisabled={addressInputState !== AddressInputState.VALID}
    bind:this={nftIdInputComponent}
    bind:enteredIds
    bind:validIdNumbers={nftIdsToImport}
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
{#if showNFTAmountInput && !isDisabled}
  <TokenAmountInput bind:this={amountComponent} class="!mt-0" />
{/if}
<div class="h-sep" />
