<script lang="ts">
  import { erc20ABI, getNetwork, readContract } from '@wagmi/core';
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';
  import { formatUnits } from 'viem';

  import { FlatAlert } from '$components/Alert';
  import AddressInput from '$components/Bridge/AddressInput/AddressInput.svelte';
  import { Button } from '$components/Button';
  import { CloseButton } from '$components/CloseButton';
  import { Icon } from '$components/Icon';
  import Erc20 from '$components/Icon/ERC20.svelte';
  import { Spinner } from '$components/Spinner';
  import { tokenService } from '$libs/storage/services';
  import type { GetCrossChainAddressArgs, Token } from '$libs/token';
  import { getCrossChainAddress } from '$libs/token/getCrossChainAddress';
  import { getTokenWithInfoFromAddress } from '$libs/token/getTokenWithInfoFromAddress';
  import { getLogger } from '$libs/util/logger';
  import { uid } from '$libs/util/uid';
  import { account } from '$stores/account';

  import { destNetwork } from '../Bridge/state';

  const dispatch = createEventDispatcher();

  const log = getLogger('component:AddCustomERC20');
  const dialogId = `dialog-${uid()}`;

  export let modalOpen = false;
  export let loadingTokenDetails = false;

  let addressInputComponent: AddressInput;
  let tokenError = '';
  let tokenAddress: Address | string = '';
  let customTokens: Token[] = [];
  let customToken: Token | null = null;
  let customTokenWithDetails: Token | null = null;
  let disabled = true;
  let isValidEthereumAddress = false;

  const addCustomErc20Token = async () => {
    if (customToken) {
      tokenService.storeToken(customToken, $account?.address as Address);
      customTokens = tokenService.getTokens($account?.address as Address);

      const { chain: srcChain } = getNetwork();
      const destChain = $destNetwork;

      if (!srcChain || !destChain) return;

      // let's check if this token has already been bridged
      const bridgedAddress = await getCrossChainAddress({
        token: customToken,
        srcChainId: srcChain.id,
        destChainId: destChain.id,
      } as GetCrossChainAddressArgs);

      // only update the token if we actually have a bridged address
      if (bridgedAddress && bridgedAddress !== customToken.addresses[destChain.id]) {
        customToken.addresses[destChain.id] = bridgedAddress as Address;
        tokenService.updateToken(customToken, $account?.address as Address);
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
    tokenError = '';
    isValidEthereumAddress = false;
    if (addressInputComponent) addressInputComponent.clearAddress();
  };

  const remove = async (token: Token) => {
    log('remove token', token);
    const address = $account.address;
    tokenService.removeToken(token, address as Address);
    customTokens = tokenService.getTokens(address as Address);
    dispatch('tokenRemoved', { token });
  };

  const onAddressValidation = async (event: { detail: { isValidEthereumAddress: boolean } }) => {
    log('triggered onAddressValidation');

    isValidEthereumAddress = event.detail.isValidEthereumAddress;
    if (isValidEthereumAddress) {
      await onAddressChange(tokenAddress);
    } else {
      resetForm();
    }
  };

  const onAddressChange = async (tokenAddress: string) => {
    if (!tokenAddress) return;
    loadingTokenDetails = true;
    log('Fetching token details for address "%s"…', tokenAddress);
    tokenError = 'unchecked';
    const { chain: srcChain } = getNetwork();
    if (!srcChain) return;
    try {
      const token = await getTokenWithInfoFromAddress({
        contractAddress: tokenAddress as Address,
        srcChainId: srcChain.id,
      });
      if (!token) return;
      const balance = await readContract({
        address: tokenAddress as Address,
        abi: erc20ABI,
        functionName: 'balanceOf',
        args: [$account?.address as Address],
      });
      customTokenWithDetails = { ...token, balance };
      const { chain } = getNetwork();
      if (!chain) throw new Error('Chain not found');
      customToken = customTokenWithDetails;
      tokenError = '';
    } catch (error) {
      tokenError = 'Error fetching token details';
      log('Failed to fetch token: ', error);
    }
    loadingTokenDetails = false;
  };

  $: formattedBalance =
    customTokenWithDetails?.balance && customTokenWithDetails?.decimals
      ? formatUnits(customTokenWithDetails.balance, customTokenWithDetails.decimals)
      : 0;

  $: if (isValidEthereumAddress) {
    onAddressChange(tokenAddress);
  } else {
    resetForm();
  }

  $: customTokens = tokenService.getTokens($account?.address as Address);

  $: disabled = tokenError !== '' || tokenAddress === '' || tokenAddress.length !== 42;

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
  <div class="modal-box relative px-6 py-[35px] md:rounded-[20px] bg-neutral-background">
    <CloseButton onClick={closeModal} />

    <h3 class="title-body-bold mb-7">{$t('token_dropdown.custom_token.title')}</h3>

    <p class="body-regular text-secondary-content mb-3">{$t('token_dropdown.custom_token.description')}</p>
    <div class="mt-4 mb-2 w-full">
      <AddressInput
        bind:this={addressInputComponent}
        bind:ethereumAddress={tokenAddress}
        on:addressvalidation={onAddressValidation} />
      <div class="w-full flex items-center justify-between mt-4">
        {#if customTokenWithDetails}
          <span>{$t('common.name')}: {customTokenWithDetails.symbol}</span>
          <span>{$t('common.balance')}: {formattedBalance}</span>
        {:else if tokenError !== '' && tokenAddress !== '' && isValidEthereumAddress && !loadingTokenDetails}
          <FlatAlert
            type="error"
            message={$t('bridge.errors.custom_token.not_found') + ' ' + $t('bridge.errors.custom_token.description')} />
        {:else if loadingTokenDetails}
          <Spinner />
        {:else}
          <div class="min-h-[25px]" />
        {/if}
      </div>
    </div>

    <Button
      type="primary"
      hasBorder={true}
      class="px-[28px] py-[14px] rounded-full flex-1 w-full"
      {disabled}
      on:click={addCustomErc20Token}>
      {$t('token_dropdown.custom_token.button')}
    </Button>

    {#if customTokens.length > 0}
      <div class="flex h-full w-full flex-col justify-between mt-6">
        <h3 class="title-body-bold mb-7">Your imported tokens:</h3>
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
  <!-- We catch key events aboe -->
  <!-- svelte-ignore a11y-click-events-have-key-events -->
  <div role="button" tabindex="0" class="overlay-backdrop" on:click={closeModalIfClickedOutside} />
</dialog>
