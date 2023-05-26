<script lang="ts">
  import { getProvider } from '@wagmi/core';
  import { Contract, ethers } from 'ethers';
  import { ChevronDown, PlusCircle } from 'svelte-heros-v2';

  import { erc20ABI } from '../../constants/abi';
  import { BridgeType } from '../../domain/bridge';
  import type { HTMLBridgeForm } from '../../domain/dom';
  import type { Token } from '../../domain/token';
  import { tokenService } from '../../storage/services';
  import { bridgeType } from '../../store/bridge';
  import { fromChain, toChain } from '../../store/chain';
  import { signer } from '../../store/signer';
  import { token } from '../../store/token';
  import { userTokens } from '../../store/userToken';
  import { isETH, tokens } from '../../token/tokens';
  import { selectToken } from '../../utils/selectToken';
  import Erc20 from '../icons/ERC20.svelte';
  import { errorToast, successToast } from '../NotificationToast.svelte';
  import AddCustomErc20 from './AddCustomERC20.svelte';

  let dropdownElement: HTMLDivElement;
  let showAddressField = false;
  let loading = false;

  function closeDropdown() {
    dropdownElement?.classList.remove('dropdown-open');
    if (document.activeElement instanceof HTMLElement) {
      document.activeElement.blur();
    }
  }

  function selectTokenAndCloseDropdown(selectedToken: Token) {
    selectToken(selectedToken);
    closeDropdown();
  }

  async function addERC20(event: SubmitEvent) {
    loading = true;

    try {
      const eventTarget = event.target as HTMLBridgeForm;
      const { customTokenAddress } = eventTarget;
      const tokenAddress = customTokenAddress.value;

      if (!ethers.utils.isAddress(tokenAddress)) {
        throw new Error('not a valid ERC20 address', { cause: tokenAddress });
      }

      const provider = getProvider();
      const contract = new Contract(tokenAddress, erc20ABI, provider);

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

      const updateTokensList = tokenService.storeToken(token, userAddress);

      selectToken(token);

      userTokens.set(updateTokensList);
      eventTarget.reset();

      showAddressField = false;

      successToast(`Token "${tokenName}" added successfully.`);
    } catch (error) {
      console.error(error);

      // TODO: what if something else happens within the try block?
      errorToast('Not a valid ERC20 address.');
    } finally {
      loading = false;
    }
  }
</script>

<div class="dropdown dropdown-bottom dropdown-end" bind:this={dropdownElement}>
  <button class="flex items-center justify-center hover:cursor-pointer">
    {#if $token.logoComponent}
      <svelte:component this={$token.logoComponent} />
    {:else}
      <Erc20 />
    {/if}
    <p class="px-2 text-sm">{$token.symbol.toUpperCase()}</p>
    <ChevronDown size="20" />
  </button>

  <ul
    role="listbox"
    tabindex="0"
    class="dropdown-content menu my-2 bg-dark-2 rounded-box p-2">
    {#each tokens as _token (_token.symbol)}
      <li>
        <button
          on:click={() => selectTokenAndCloseDropdown(_token)}
          class="flex items-center px-2 py-4 hover:bg-dark-5 rounded-sm">
          <svelte:component
            this={_token.logoComponent}
            height={22}
            width={22} />
          <span class="text-sm font-medium bg-transparent px-2">
            {_token.symbol.toUpperCase()}
          </span>
        </button>
      </li>
    {/each}

    {#each $userTokens as _token (_token.symbol)}
      <li>
        <button
          on:click={() => selectTokenAndCloseDropdown(_token)}
          class="flex items-center px-2 py-4 hover:bg-dark-5 rounded-sm">
          <Erc20 height={22} width={22} />
          <span class="text-sm font-medium bg-transparent px-2"
            >{_token.symbol.toUpperCase()}</span>
        </button>
      </li>
    {/each}

    <li class="divider h-[1px] m-0" />

    <li>
      <button
        on:click={() => (showAddressField = true)}
        class="flex hover:bg-dark-5 justify-between items-center p-4 rounded-sm">
        <PlusCircle size="25" />
        <span
          class="
            text-sm 
            font-medium 
            bg-transparent 
            flex-1 
            w-[100px] 
            px-0 
            pl-2">
          Add Custom
        </span>
      </button>
    </li>
  </ul>

  {#if showAddressField}
    <AddCustomErc20 bind:showAddressField {addERC20} bind:loading />
  {/if}
</div>
