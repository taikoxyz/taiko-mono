<script lang="ts">
  import { readContract } from '@wagmi/core';
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import { type Address, formatUnits } from 'viem';

  import { erc20Abi } from '$abi';
  import { FlatAlert } from '$components/Alert';
  import AddressInput from '$components/Bridge/SharedBridgeComponents/AddressInput/AddressInput.svelte';
  import { AddressInputState } from '$components/Bridge/SharedBridgeComponents/AddressInput/state';
  import { ActionButton, CloseButton } from '$components/Button';
  import { Icon } from '$components/Icon';
  import Erc20 from '$components/Icon/ERC20.svelte';
  import { Spinner } from '$components/Spinner';
  import { tokenService } from '$libs/storage/services';
  import { detectContractType, type GetTokenInfo, type Token, TokenType } from '$libs/token';
  import { getTokenAddresses } from '$libs/token/getTokenAddresses';
  import { getTokenWithInfoFromAddress } from '$libs/token/getTokenWithInfoFromAddress';
  import { tokenIdentityKey } from '$libs/token/tokenIdentity';
  import { getLogger } from '$libs/util/logger';
  import { config } from '$libs/wagmi';
  import { account } from '$stores/account';
  import { connectedSourceChain } from '$stores/network';

  import { destNetwork } from '../Bridge/state';

  const dispatch = createEventDispatcher();

  const log = getLogger('component:AddCustomERC20');
  const dialogId = `dialog-${crypto.randomUUID()}`;

  export let modalOpen = false;
  export let loadingTokenDetails = false;
  export let customTokens: Token[] = [];

  let addressInputComponent: AddressInput;
  let tokenAddress: Address | string = '';
  let customToken: Token | null = null;
  let customTokenWithDetails: Token | null = null;
  let disabled = true;
  let isValidEthereumAddress = false;

  let state = AddressInputState.DEFAULT;

  const addCustomErc20Token = async () => {
    if (customToken) {
      tokenService.storeToken(customToken, $account?.address as Address);
      customTokens = tokenService.getTokens($account?.address as Address);

      const srcChain = $connectedSourceChain;
      const destChain = $destNetwork;

      if (!srcChain || !destChain) return;

      // let's check if this token has already been bridged and store the info
      const tokenInfo = await getTokenAddresses({
        token: customToken,
        srcChainId: srcChain.id,
        destChainId: destChain.id,
      } as GetTokenInfo);

      if (tokenInfo && tokenInfo.bridged) {
        const { address: bridgedAddress, chainId: bridgedChainId } = tokenInfo.bridged;
        // only update the token if we actually have a bridged address
        if (bridgedAddress) {
          customToken.addresses[bridgedChainId] = bridgedAddress as Address;
          tokenService.updateToken(customToken, $account?.address as Address);
        }
      }
    }

    tokenAddress = '';
    customTokenWithDetails = null;
    resetForm();
  };

  const closeModal = () => {
    modalOpen = false;
    resetForm();
  };

  const resetForm = () => {
    // A lookup still in flight belongs to the form being cleared; without this its result
    // would repopulate the token and the loading flag after the reset
    discardLookup();
    isValidEthereumAddress = false;
    state = AddressInputState.DEFAULT;
    if (addressInputComponent) addressInputComponent.clearAddress();
  };

  const remove = async (token: Token) => {
    dispatch('tokenRemoved', { token });
  };

  async function onAddressValidation(event: CustomEvent<{ isValidEthereumAddress: boolean; addr: Address }>) {
    const { isValidEthereumAddress, addr } = event.detail;
    tokenAddress = addr;
    if (isValidEthereumAddress) {
      await onAddressChange(tokenAddress as Address);
    } else {
      // Invalid or cleared input also invalidates any in-flight lookup so its stale
      // token cannot publish into the form
      discardLookup();
    }
  }

  // Lookups for a previously typed address can resolve after a newer one;
  // only the latest may publish its result
  let lookupGeneration = 0;

  /** The address a token lookup is currently in flight for, if any */
  let pendingTokenLookup: Maybe<string> = null;

  /** The address the currently offered token was resolved for, if any */
  let resolvedTokenAddress: Maybe<string> = null;

  /** The source chain the in-flight or resolved lookup belongs to */
  let lookupChainId: Maybe<number> = null;

  /**
   * AddressInput dispatches nothing for a cleared field or text without a `0x` prefix, so
   * an edit can leave no event behind. The two-way bound draft is then the only signal
   * that a lookup still running describes an address no longer on screen.
   */
  function syncTokenAddressDraft(draft: Maybe<string>) {
    // Whichever address the form is currently offering something for: a lookup still
    // running, or one that already finished. A finished lookup leaves pendingTokenLookup
    // null, so keying only off that let a cleared field keep showing the resolved token
    const shownFor = pendingTokenLookup ?? resolvedTokenAddress;
    if (!shownFor) return;
    if (shownFor.toLowerCase() === (draft ?? '').toLowerCase()) return;

    discardLookup();
  }

  /**
   * @dev Drops whatever the form is offering and supersedes any lookup still in flight.
   *
   *      Deliberately leaves `state` alone. It is two-way bound to AddressInput, which
   *      writes VALID/INVALID as the user types, and resetting it from a path that also
   *      runs on an invalid address would erase the field's own verdict.
   */
  function discardLookup() {
    lookupGeneration++;
    pendingTokenLookup = null;
    resolvedTokenAddress = null;
    lookupChainId = null;
    loadingTokenDetails = false;
    customTokenWithDetails = null;
    customToken = null;
  }

  const onAddressChange = async (tokenAddress: Address) => {
    const generation = ++lookupGeneration;
    // Drop the previous token up front: if this lookup fails or the address is not an
    // ERC20, the form must not keep offering the token from the last address
    customTokenWithDetails = null;
    customToken = null;
    resolvedTokenAddress = null;
    if (!tokenAddress) {
      pendingTokenLookup = null;
      lookupChainId = null;
      loadingTokenDetails = false;
      return;
    }
    // The whole lookup is pinned to the chain it started on. The same address is a
    // different contract on a different chain, so detecting the type against one chain
    // and then reading the token info off another describes no contract that exists
    const srcChainId = $connectedSourceChain?.id;
    if (!srcChainId) {
      // Guard, not a fix for a reachable path: a lookup can only be in flight if the chain
      // was set when it started, and losing it since then runs onSourceChainChanged, which
      // discards the lookup and clears this. Leaving a return that sets no state is still
      // the wrong shape for a function whose other exits all clean up after themselves.
      pendingTokenLookup = null;
      lookupChainId = null;
      loadingTokenDetails = false;
      return;
    }
    pendingTokenLookup = tokenAddress;
    lookupChainId = srcChainId;
    loadingTokenDetails = true;
    log('Fetching token details for address "%s"…', tokenAddress);

    const superseded = () => generation !== lookupGeneration || $connectedSourceChain?.id !== srcChainId;

    try {
      let type: TokenType;
      try {
        type = await detectContractType(tokenAddress, srcChainId);
      } catch (error) {
        if (superseded()) return;
        log('Failed to detect contract type: ', error);
        state = AddressInputState.NOT_ERC20;
        return;
      }
      if (superseded()) return;

      if (type !== TokenType.ERC20) {
        state = AddressInputState.NOT_ERC20;
        return;
      }

      try {
        const token = await getTokenWithInfoFromAddress({
          contractAddress: tokenAddress as Address,
          srcChainId,
        });
        if (superseded()) return;
        if (!token) return;
        const balance = await readContract(config, {
          address: tokenAddress as Address,
          abi: erc20Abi,
          functionName: 'balanceOf',
          args: [$account?.address as Address],
        });
        if (superseded()) return;
        customTokenWithDetails = { ...token, balance } as Token;

        customToken = customTokenWithDetails;
        resolvedTokenAddress = tokenAddress;
      } catch (error) {
        if (superseded()) return;
        state = AddressInputState.INVALID;
        log('Failed to fetch token: ', error);
      }
    } finally {
      // Every exit path clears the flag while this lookup is still the latest
      if (generation === lookupGeneration) {
        pendingTokenLookup = null;
        loadingTokenDetails = false;
      }
    }
  };

  $: syncTokenAddressDraft(tokenAddress);
  $: onSourceChainChanged($connectedSourceChain?.id);

  /**
   * @dev A token resolved against the previous chain says nothing about the current one,
   *      and a lookup still running against it must not publish either.
   */
  function onSourceChainChanged(chainId: Maybe<number>) {
    if (lookupChainId === null || lookupChainId === chainId) return;
    discardLookup();
    // Safe to reset here, unlike in discardLookup: no validation is racing a chain switch,
    // and an address accepted against the previous chain says nothing about this one
    state = AddressInputState.DEFAULT;
  }

  $: formattedBalance =
    customTokenWithDetails?.balance && customTokenWithDetails?.decimals
      ? formatUnits(customTokenWithDetails.balance, customTokenWithDetails.decimals)
      : 0;

  // A resolved token is required: the address passing validation says nothing about the
  // lookup having finished, so Add was clickable while details were still loading or absent
  $: disabled =
    state !== AddressInputState.VALID ||
    tokenAddress === '' ||
    tokenAddress.length !== 42 ||
    loadingTokenDetails ||
    !customToken;

  const closeModalIfClickedOutside = (e: MouseEvent) => {
    if (e.target === e.currentTarget) {
      closeModal();
    }
  };
  const closeModalIfKeyDown = (e: KeyboardEvent) => {
    if (e.key === 'Escape') {
      closeModal();
    }
  };
</script>

<svelte:window on:keydown={closeModalIfKeyDown} />

<dialog id={dialogId} class="modal modal-bottom md:modal-middle" class:modal-open={modalOpen}>
  <div class="modal-box relative px-6 py-[35px] md:rounded-[20px] bg-dialog-background">
    <CloseButton onClick={closeModal} />
    <h3 class="title-body-bold mb-7">{$t('token_dropdown.custom_token.title')}</h3>

    <p class="body-regular text-secondary-content mb-3">{$t('token_dropdown.custom_token.description')}</p>
    <div class="mt-4 mb-2 w-full">
      <AddressInput
        bind:this={addressInputComponent}
        bind:ethereumAddress={tokenAddress}
        on:addressvalidation={onAddressValidation}
        bind:state
        onDialog />
      <div class="w-full flex items-center justify-between">
        {#if customTokenWithDetails}
          <span>{$t('common.name')}: {customTokenWithDetails.symbol}</span>
          <span>{$t('common.balance')}: {formattedBalance}</span>
        {:else if state === AddressInputState.INVALID && tokenAddress !== '' && isValidEthereumAddress && !loadingTokenDetails}
          <FlatAlert type="error" message={$t('bridge.errors.custom_token.not_found.message')} />
        {:else if loadingTokenDetails}
          <Spinner />
        {:else if state === AddressInputState.DEFAULT}
          <FlatAlert type="info" message={$t('token_dropdown.custom_token.default_message')} />
        {/if}
      </div>
    </div>
    <div class="h-sep" />
    {#if customTokens.length > 0}
      <div class="flex h-full w-full flex-col justify-between mt-6">
        <h3 class="title-body-bold mb-7">{$t('token_dropdown.imported_tokens')}</h3>
        {#each customTokens as ct (tokenIdentityKey(ct))}
          <div class="flex items-center justify-between">
            <div class="flex items-center m-2 space-x-2">
              <Erc20 />
              <span>{ct.symbol}</span>
            </div>
            <button class="btn btn-sm btn-ghost flex justify-center items-center" on:click={() => remove(ct)}>
              <Icon type="trash" fillClass="fill-primary-icon" size={24} />
            </button>
          </div>
        {/each}
      </div>
    {:else}
      <span>{$t('token_dropdown.no_imported_token')}</span>
    {/if}
    <div class="h-sep" />
    <ActionButton priority="primary" {disabled} on:click={addCustomErc20Token} onPopup>
      {$t('token_dropdown.custom_token.button')}
    </ActionButton>
  </div>
  <!-- We catch key events above -->
  <!-- svelte-ignore a11y-click-events-have-key-events -->
  <div role="button" tabindex="0" class="overlay-backdrop" on:click={closeModalIfClickedOutside} />
</dialog>
