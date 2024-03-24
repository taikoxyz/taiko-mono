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
  import { getLogger } from '$libs/util/logger';
  import { uid } from '$libs/util/uid';
  import { config } from '$libs/wagmi';
  import { account } from '$stores/account';
  import { connectedSourceChain } from '$stores/network';

  import { destNetwork } from '../Bridge/state';

  const dispatch = createEventDispatcher();

  const log = getLogger('component:AddCustomERC20');
  const dialogId = `dialog-${uid()}`;

  export let modalOpen = false;
  export let loadingTokenDetails = false;

  let addressInputComponent: AddressInput;
  let tokenAddress: Address | string = '';
  let customTokens: Token[] = [];
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
    customToken = null;
    customTokenWithDetails = null;
    isValidEthereumAddress = false;
    state = AddressInputState.DEFAULT;
    if (addressInputComponent) addressInputComponent.clearAddress();
  };

  const remove = async (token: Token) => {
    log('remove token', token);
    const address = $account.address;
    tokenService.removeToken(token, address as Address);
    customTokens = tokenService.getTokens(address as Address);
    dispatch('tokenRemoved', { token });
  };

  async function onAddressValidation(event: CustomEvent<{ isValidEthereumAddress: boolean; addr: Address }>) {
    const { isValidEthereumAddress, addr } = event.detail;
    tokenAddress = addr;
    if (isValidEthereumAddress) {
      await onAddressChange(tokenAddress as Address);
    } else {
      tokenAddress = addr;
    }
  }

  const onAddressChange = async (tokenAddress: Address) => {
    if (!tokenAddress) return;
    loadingTokenDetails = true;
    log('Fetching token details for address "%s"…', tokenAddress);

    let type: TokenType;
    try {
      type = await detectContractType(tokenAddress, $connectedSourceChain?.id as number);
    } catch (error) {
      log('Failed to detect contract type: ', error);
      loadingTokenDetails = false;
      state = AddressInputState.NOT_ERC20;
      return;
    }

    if (type !== TokenType.ERC20) {
      loadingTokenDetails = false;
      state = AddressInputState.NOT_ERC20;
      return;
    }

    const srcChain = $connectedSourceChain;
    if (!srcChain) return;
    try {
      const token = await getTokenWithInfoFromAddress({
        contractAddress: tokenAddress as Address,
        srcChainId: srcChain.id,
      });
      if (!token) return;
      const balance = await readContract(config, {
        address: tokenAddress as Address,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: [$account?.address as Address],
      });
      customTokenWithDetails = { ...token, balance };

      customToken = customTokenWithDetails;
    } catch (error) {
      state = AddressInputState.INVALID;
      log('Failed to fetch token: ', error);
    }
    loadingTokenDetails = false;
  };

  $: formattedBalance =
    customTokenWithDetails?.balance && customTokenWithDetails?.decimals
      ? formatUnits(customTokenWithDetails.balance, customTokenWithDetails.decimals)
      : 0;

  $: customTokens = tokenService.getTokens($account?.address as Address);

  $: disabled = state !== AddressInputState.VALID || tokenAddress === '' || tokenAddress.length !== 42;

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
      <div class="w-full flex items-center justify-between mt-4">
        {#if customTokenWithDetails}
          <span>{$t('common.name')}: {customTokenWithDetails.symbol}</span>
          <span>{$t('common.balance')}: {formattedBalance}</span>
        {:else if state === AddressInputState.INVALID && tokenAddress !== '' && isValidEthereumAddress && !loadingTokenDetails}
          <FlatAlert type="error" message={$t('bridge.errors.custom_token.not_found.message')} />
        {:else if loadingTokenDetails}
          <Spinner />
        {:else}
          <div class="min-h-[25px]" />
        {/if}
      </div>
    </div>

    <ActionButton priority="primary" {disabled} on:click={addCustomErc20Token} onPopup>
      {$t('token_dropdown.custom_token.button')}
    </ActionButton>

    {#if customTokens.length > 0}
      <div class="flex h-full w-full flex-col justify-between mt-6">
        <h3 class="title-body-bold mb-7">{$t('token_dropdown.imported_tokens')}</h3>
        {#each customTokens as ct (ct.symbol)}
          <div class="flex items-center justify-between">
            <div class="flex items-center m-2 space-x-2">
              <Erc20 />
              <span>{ct.symbol}</span>
            </div>
            <button class="btn btn-sm btn-ghost flex justify-center items-center" on:click={() => remove(ct)}>
              <Icon type="trash" fillClass="fill-primary-icon" size={24} />
            </button>
          </div>
          <div class="h-sep" />
        {/each}
      </div>
    {/if}
  </div>
  <!-- We catch key events above -->
  <!-- svelte-ignore a11y-click-events-have-key-events -->
  <div role="button" tabindex="0" class="overlay-backdrop" on:click={closeModalIfClickedOutside} />
</dialog>
