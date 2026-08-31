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

  /**
   * Everything downstream of the contract address (detected type, validated ids, the
   * selected NFT) describes the address that was validated. A new address invalidates all
   * of it, including any id validation still in flight.
   */
  function discardSelectionForNewAddress() {
    addressValidationGeneration++;
    idValidationGeneration++;
    validating = false;
    detectedTokenType = null;
    idInputState = IDInputState.DEFAULT;
    isOwnerOfAllToken = false;
    $selectedNFTs = null;
  }

  // A contract-type lookup describes one address on one chain. Without this, a lookup
  // for an address typed earlier can resolve after a newer one and re-enable the id
  // field with the wrong type for the address actually on screen.
  let addressValidationGeneration = 0;

  async function onAddressValidation(event: CustomEvent<{ isValidEthereumAddress: boolean; addr: Address }>) {
    const { isValidEthereumAddress, addr } = event.detail;
    // interfaceSupported = true;
    addressInputState = AddressInputState.VALIDATING;
    discardSelectionForNewAddress();
    const generation = addressValidationGeneration;

    const srcChainId = $connectedSourceChain?.id;
    if (!srcChainId) {
      addressInputState = AddressInputState.INVALID;
      return;
    }

    if (isValidEthereumAddress && typeof addr === 'string') {
      contractAddress = addr;
      pendingAddressLookup = addr;

      let type: TokenType | null;
      try {
        type = await detectContractType(addr, srcChainId);
      } catch {
        if (generation !== addressValidationGeneration) return;
        pendingAddressLookup = null;
        // Without a return the stale type from a previous address would decide the
        // check below and could mark this failed lookup VALID
        addressInputState = AddressInputState.INVALID;
        return;
      }

      // A newer address, a cleared field, or a source-chain change supersedes this answer
      if (generation !== addressValidationGeneration) return;
      if (srcChainId !== $connectedSourceChain?.id) return;
      pendingAddressLookup = null;

      detectedTokenType = type;
      if (type !== TokenType.ERC721 && type !== TokenType.ERC1155) {
        addressInputState = AddressInputState.NOT_NFT;
        return;
      }

      lastValidatedAddress = addr;
      addressInputState = AddressInputState.VALID;
    } else {
      addressInputState = AddressInputState.INVALID;
    }
    return;
  }

  /**
   * AddressInput dispatches nothing for a cleared field or text without a `0x` prefix, so
   * the two-way bound draft is the only signal that an in-flight lookup no longer
   * describes what is on screen.
   */
  function syncContractAddressDraft(draft: Maybe<string>) {
    const current = (draft ?? '').toLowerCase();
    const stale = (address: Maybe<string>) => !!address && address.toLowerCase() !== current;

    if (stale(pendingAddressLookup) || stale(lastValidatedAddress)) {
      pendingAddressLookup = null;
      lastValidatedAddress = null;
      discardSelectionForNewAddress();
      addressInputState = draft ? AddressInputState.INVALID : AddressInputState.DEFAULT;
    }
  }

  /** The address a contract-type lookup is currently in flight for, if any */
  let pendingAddressLookup: Maybe<string> = null;
  let lastValidatedAddress: Maybe<string> = null;

  // Guards against out-of-order async validations: only the latest entered ID may
  // publish its result into the shared stores
  let idValidationGeneration = 0;

  async function onIdInput(): Promise<void> {
    const generation = ++idValidationGeneration;
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

        if (generation !== idValidationGeneration) return;

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

        if (generation !== idValidationGeneration) return;

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
      if (generation !== idValidationGeneration) return;
      console.error(err);
      detectedTokenType = null;
      idInputState = IDInputState.INVALID;
    } finally {
      if (generation === idValidationGeneration) {
        if (idInputState !== IDInputState.VALID) {
          idInputState = IDInputState.DEFAULT;
        }
        validating = false;
      }
    }
  }

  $: syncContractAddressDraft(contractAddress);

  $: displayOwnershipError =
    contractAddress && enteredIds && !isOwnerOfAllToken && nftIdsToImport?.length > 0 && !validating;

  $: canValidateIdInput = isAddress(contractAddress) && $connectedSourceChain?.id && $account?.address ? true : false;

  $: isERC1155 = detectedTokenType === TokenType.ERC1155;

  $: nftHasAmount = hasSelectedNFT && isERC1155;

  $: validBalance = $tokenBalance && $enteredAmount > 0 && $enteredAmount <= $tokenBalance.value;

  $: hasEnteredIds = enteredIds && enteredIds.length > 0;
  $: hasSelectedNFT = $selectedNFTs && $selectedNFTs?.length > 0 && hasEnteredIds;

  // The address itself has to still be valid: editing it after an id was validated would
  // otherwise leave Continue enabled for the NFT belonging to the previous address
  $: commonChecks =
    addressInputState === AddressInputState.VALID &&
    enteredIds &&
    enteredIds.length > 0 &&
    !validating &&
    idInputState === IDInputState.VALID &&
    isOwnerOfAllToken;

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
