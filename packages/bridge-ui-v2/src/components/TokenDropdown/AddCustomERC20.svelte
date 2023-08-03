<script lang="ts">
  import AddressInput from '$components/Bridge/AddressInput.svelte';
  import type { Address } from 'viem';
  import { erc20ABI, readContract, getNetwork } from '@wagmi/core';
  import { formatUnits } from 'viem';
  import { t } from 'svelte-i18n';
  import { Icon } from '$components/Icon';
  import Erc20 from '$components/Icon/ERC20.svelte';
  import { fetchToken } from '@wagmi/core';

  import { Spinner } from '$components/Spinner';
  import { TokenType, type Token, type TokenEnv } from '$libs/token';
  import { getLogger } from '$libs/util/logger';
  import { uid } from '$libs/util/uid';
  import { account } from '$stores/account';
  import { tokenService } from '$libs/storage/services';
  import { Alert } from '$components/Alert';

  const log = getLogger('component:AddCustomERC20');

  let dialogId = `dialog-${uid()}`;

  export let modalOpen: boolean = false;
  export let loading: boolean = false;
  export let loadingTokenDetails: boolean = false;

  let tokenDetails: (TokenEnv & { balance: bigint; decimals: number }) | null;
  let tokenError: string = '';
  let tokenAddress: Address | string = '0x6A08CDA7dde383BBc8267f079d20E1ad3C270fff';
  let customTokens: Token[] = [];
  let customToken: Token | null = null;
  let disabled = true;

  const addCustomErc20Token = () => {
    if (customToken) {
      tokenService.storeToken(customToken, $account?.address as Address);
      customTokens = tokenService.getTokens($account?.address as Address);
    }
    tokenAddress = '';
  };

  const closeModal = () => {
    modalOpen = false;
    resetForm();
  };

  const resetForm = () => {
    customToken = null;
    tokenDetails = null;
    tokenError = '';
    isValidEthereumAddress = false;
  };

  const openModal = () => {
    modalOpen = true;
    customTokens = tokenService.getTokens($account?.address as Address);
    log('customTokens', customTokens);
  };

  const remove = async (token: Token) => {
    log('remove token', token);
    const address = $account.address;
    tokenService.removeToken(token, address as Address);
    customTokens = tokenService.getTokens(address as Address);
  };

  let isValidEthereumAddress = false;

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
    log('Fetching token details for address "%s"…', tokenAddress);

    try {
      const tokenInfo = await fetchToken({ address: tokenAddress as Address });
      const balance = await readContract({
        address: tokenAddress as Address,
        abi: erc20ABI,
        functionName: 'balanceOf',
        args: [$account?.address as Address],
      });

      log({ balance });

      tokenDetails = { ...tokenInfo, balance };
      const { chain } = getNetwork();

      if ($account.address && chain) {
        customToken = {
          name: tokenDetails.name,
          addresses: {
            [chain?.id]: tokenDetails.address,
          },
          decimals: tokenDetails.decimals,
          symbol: tokenDetails.symbol,
          logoComponent: null,
          type: TokenType.ERC20,
        } as Token;
        log({ customToken });
      }
    } catch (error) {
      tokenError = 'Error fetching token details';
      console.error('Failed to fetch token: ', error);
    }
  };

  $: {
    if (modalOpen) openModal();

    resetForm();
    if (isValidEthereumAddress) {
      onAddressChange(tokenAddress);
    }
  }

  $: customTokens = tokenService.getTokens($account?.address as Address);

  $: disabled = tokenError !== '';

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
  <div
    class="modal-box relative px-6 py-[35px] md:py-[20px] bg-primary-base-background text-primary-base-content text-center">
    <button class="absolute right-6 top-[35px] md:top-[20px]" on:click={closeModal}>
      <Icon type="x-close" fillClass="fill-secondary-icon" size={24} />
    </button>
    <div class="mt-4 mb-2">
      <AddressInput bind:ethereumAddress={tokenAddress} on:addressvalidation={onAddressValidation} />
      {#if tokenDetails}
        <div class="w-full flex items-center justify-between">
          <span>Name: {tokenDetails.symbol}</span>
          <span>Balance: {formatUnits(tokenDetails.balance, tokenDetails.decimals)}</span>
        </div>
      {:else if loadingTokenDetails}
        <Spinner />
      {:else if tokenError !== '' && tokenAddress !== ''}
        <Alert type="error" forceColumnFlow>
          <p class="font-bold">{$t('bridge.errors.custom_token.not_found')}</p>
          <p>{$t('bridge.errors.custom_token.description')}</p>
        </Alert>
      {:else}
        <div class="min-h-[25px]" />
      {/if}
    </div>
    {#if loading}
      <Spinner />
    {:else}
      <button class="btn btn-primary" disabled={Boolean(disabled)} on:click={addCustomErc20Token}> Add </button>
    {/if}

    {#if customTokens.length > 0}
      <div class="flex h-full w-full flex-col justify-between mt-6">
        <h3>Your imported tokens:</h3>
        {#each customTokens as ct (ct.symbol)}
          <div class="flex items-center justify-between">
            <div class="flex items-center">
              <Erc20 />
              <span class="bg-transparent">{ct.symbol}</span>
            </div>
            <button class="btn btn-sm btn-ghost flex justify-center items-center" on:click={() => remove(ct)}>
              <Icon type="trash" fillClass="fill-secondary-icon" size={24} />
            </button>
          </div>
        {/each}
      </div>
    {/if}
    <!-- We catch key events aboe -->
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <div role="button" tabindex="0" class="overlay-backdrop" on:click={closeModalIfClickedOutside} />
  </div>
</dialog>
