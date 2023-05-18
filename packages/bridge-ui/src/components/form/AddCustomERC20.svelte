<script lang="ts">
  import { getProvider } from '@wagmi/core';
  import { Trash } from 'svelte-heros-v2';
  import type { Token, TokenDetails } from '../../domain/token';
  import { signer } from '../../store/signer';
  import { token as tokenStore } from '../../store/token';
  import { userTokens } from '../../store/userToken';
  import Erc20 from '../icons/ERC20.svelte';
  import Modal from '../modals/Modal.svelte';
  import { ethers } from 'ethers';
  import { erc20ABI } from '../../constants/abi';
  import { ETHToken } from '../../token/tokens';
  import { errorToast } from '../Toast.svelte';
  import { tokenService } from '../../storage/services';
  import Loading from '../Loading.svelte';

  export let showAddressField: boolean = false;
  export let addERC20: (event: SubmitEvent) => Promise<void>;
  export let loading: boolean = false;
  export let loadingTokenDetails: boolean = false;

  let tokenDetails: TokenDetails = null;
  let showError: boolean = false;
  let tokenAddress: string;

  let customTokens: Token[] = [];
  userTokens.subscribe((tokens) => (customTokens = tokens));

  async function remove(token) {
    const address = await $signer.getAddress();
    const updatedTokensList = tokenService.removeToken(token, address);
    userTokens.set(updatedTokensList);
    tokenStore.set(ETHToken);
  }

  async function onAddressChange(tokenAddress: string) {
    showError = false;
    if (ethers.utils.isAddress(tokenAddress)) {
      loadingTokenDetails = true;
      try {
        const provider = getProvider();
        const contract = new ethers.Contract(tokenAddress, erc20ABI, provider);
        const userAddress = await $signer.getAddress();
        const [symbol, decimals, userBalance] = await Promise.all([
          contract.symbol(),
          contract.decimals(),
          contract.balanceOf(userAddress),
        ]);
        const userTokenBalance = ethers.utils.formatUnits(
          userBalance,
          decimals,
        );
        tokenDetails = {
          address: tokenAddress,
          decimals,
          symbol,
          userTokenBalance,
        };
      } catch (error) {
        showError = true;
        errorToast("Couldn't fetch token details");
        console.error(error);
      } finally {
        loadingTokenDetails = false;
      }
    } else {
      tokenDetails = null;
    }
  }

  $: onAddressChange(tokenAddress);
</script>

<Modal title="Add custom ERC20" bind:isOpen={showAddressField}>
  <form
    class="flex h-full min-h-tooltip-modal w-full flex-col justify-between"
    on:submit|preventDefault={addERC20}>
    <div class="mt-4 mb-2">
      <input
        type="text"
        placeholder="Enter valid ERC20 Address"
        class="input input-primary bg-dark-2 input-md md:input-lg w-full focus:ring-0"
        name="customTokenAddress"
        bind:value={tokenAddress} />
      {#if tokenDetails}
        <div class="bg-dark-2 w-full flex items-center justify-between">
          <span class="bg-dark-2">{tokenDetails.symbol}</span>
          <span class="bg-dark-2"
            >Balance: {tokenDetails.userTokenBalance}</span>
        </div>
      {:else if loadingTokenDetails}
        <Loading />
      {:else if showError}
        <div class="min-h-[25px] text-error text-sm">
          Couldn't fetch token details
        </div>
      {:else}
        <div class="min-h-[25px]" />
      {/if}
    </div>
    {#if loading}
      <button class="btn" disabled={true}>
        <Loading />
      </button>
    {:else}
      <button class="btn" type="submit">Add</button>
    {/if}
  </form>
  {#if customTokens.length > 0}
    <div class="flex h-full w-full flex-col justify-between bg-none mt-6">
      <h3>Tokens already added</h3>
      {#each customTokens as t}
        <div class="flex items-center justify-between">
          <div class="flex items-center">
            <Erc20 />
            <span class="bg-transparent">{t.symbol}</span>
          </div>
          <button class="btn btn-sm" on:click={() => remove(t)}>
            <Trash />
          </button>
        </div>
      {/each}
    </div>
  {/if}
</Modal>
