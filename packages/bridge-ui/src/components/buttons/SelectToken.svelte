<script lang="ts">
  import { getProvider } from '@wagmi/core';
  import { token } from '../../store/token';
  import { bridgeType } from '../../store/bridge';
  import type { Token } from '../../domain/token';
  import { BridgeType, type HTMLBridgeForm } from '../../domain/bridge';
  import { ChevronDown, PlusCircle } from 'svelte-heros-v2';
  import { ethers } from 'ethers';
  import ERC20_ABI from '../../constants/abi/ERC20';
  import { signer } from '../../store/signer';
  import { userTokens, tokenService } from '../../store/userToken';
  import { fromChain, toChain } from '../../store/chain';
  import Erc20 from '../icons/ERC20.svelte';
  import AddCustomErc20 from '../form/AddCustomERC20.svelte';
  import { ETHToken, tokens } from '../../token/tokens';
  import { errorToast, successToast } from '../Toast.svelte';

  let dropdownElement: HTMLDivElement;
  let showAddressField = false;
  let loading = false;

  function select(t: Token) {
    if (t === $token) return;

    token.set(t);

    if (t.symbol.toLowerCase() === ETHToken.symbol.toLowerCase()) {
      bridgeType.set(BridgeType.ETH);
    } else {
      bridgeType.set(BridgeType.ERC20);
    }

    successToast(`Token changed to ${t.symbol.toUpperCase()}`);

    // to close the dropdown on click
    dropdownElement?.classList.remove('dropdown-open');
    if (document.activeElement instanceof HTMLElement) {
      document.activeElement.blur();
    }
  }

  async function addERC20(event: SubmitEvent) {
    loading = true;

    try {
      const eventTarget = event.target as HTMLBridgeForm;
      const { customTokenAddress } = eventTarget;
      const tokenAddress = customTokenAddress.value;

      if (!ethers.utils.isAddress(tokenAddress)) {
        throw new Error('Not a valid ERC20 address');
      }

      const provider = getProvider();
      const contract = new ethers.Contract(tokenAddress, ERC20_ABI, provider);

      const userAddress = await $signer.getAddress();

      // This call makes sure the contract is a valid ERC20 contract,
      // otherwise it throws and gets caught informing the user
      // it's not a valid ERC20 address
      await contract.balanceOf(userAddress);

      const [tokenName, decimals, symbol] = await Promise.all([
        contract.name(),
        contract.decimals(),
        contract.symbol(),
      ]);

      const token = {
        name: tokenName,
        addresses: [
          {
            chainId: $fromChain.id,
            address: tokenAddress,
          },
          {
            chainId: $toChain.id,
            address: '0x00',
          },
        ],
        decimals: decimals,
        symbol: symbol,
        logoComponent: null,
      } as Token;

      const updateTokensList = $tokenService.storeToken(token, userAddress);

      select(token);

      userTokens.set(updateTokensList);
      eventTarget.reset();

      showAddressField = false;
    } catch (error) {
      // TODO: what if something else happens within the try block?
      errorToast('Not a valid ERC20 address');
      console.error(error);
    } finally {
      loading = false;
    }
  }
</script>

<div class="dropdown dropdown-bottom" bind:this={dropdownElement}>
  <!-- svelte-ignore a11y-label-has-associated-control -->
  <label
    role="button"
    tabindex="0"
    class="flex items-center justify-center hover:cursor-pointer">
    {#if $token.logoComponent}
      <svelte:component this={$token.logoComponent} />
    {:else}
      <Erc20 />
    {/if}
    <p class="px-2 text-sm">{$token.symbol.toUpperCase()}</p>
    <ChevronDown size="20" />
  </label>

  <ul
    role="listbox"
    tabindex="0"
    class="token-dropdown dropdown-content menu my-2 shadow-xl bg-dark-2 rounded-box p-2">
    {#each tokens as t}
      <li class="cursor-pointer w-full hover:bg-dark-5 rounded-none">
        <button on:click={() => select(t)} class="flex hover:bg-dark-5 p-4">
          <svelte:component this={t.logoComponent} height={22} width={22} />
          <span class="text-sm font-medium bg-transparent px-2"
            >{t.symbol.toUpperCase()}</span>
        </button>
      </li>
    {/each}
    {#each $userTokens as t}
      <li class="cursor-pointer w-full hover:bg-dark-5">
        <button on:click={() => select(t)} class="flex hover:bg-dark-5 p-4">
          <Erc20 height={22} width={22} />
          <span class="text-sm font-medium bg-transparent px-2"
            >{t.symbol.toUpperCase()}</span>
        </button>
      </li>
    {/each}
    <li class="cursor-pointer hover:bg-dark-5">
      <button
        on:click={() => (showAddressField = true)}
        class="flex hover:bg-dark-5 justify-between items-center p-4">
        <PlusCircle size="25" />
        <span
          class="text-sm font-medium bg-transparent flex-1 w-[100px] px-0 pl-2"
          >Add Custom</span>
      </button>
    </li>
  </ul>

  {#if showAddressField}
    <AddCustomErc20 bind:showAddressField {addERC20} bind:loading />
  {/if}
</div>
