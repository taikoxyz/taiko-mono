<script lang="ts">
  import { Contract, ethers } from 'ethers';
  import { Trash } from 'svelte-heros-v2';
  import { getProvider } from 'wagmi/actions';

  import { erc20ABI } from '../../constants/abi';
  import type { Token, TokenDetails } from '../../domain/token';
  import { tokenService } from '../../storage/services';
  import { signer } from '../../store/signer';
  import { token as tokenStore } from '../../store/token';
  import { userTokens } from '../../store/userToken';
  import { ETHToken } from '../../token/tokens';
  import { getLogger } from '../../utils/logger';
  import Erc20 from '../icons/ERC20.svelte';
  import Loading from '../Loading.svelte';
  import Modal from '../Modal.svelte';
  import { errorToast } from '../NotificationToast.svelte';

  const log = getLogger('component:AddCustomERC20');

  export let showAddressField: boolean = false;
  export let addERC20: (event: SubmitEvent) => Promise<void>;
  export let loading: boolean = false;
  export let loadingTokenDetails: boolean = false;

  let tokenDetails: TokenDetails = null;
  let tokenError: string = '';
  let tokenAddress: string;
  let customTokens: Token[] = [];

  userTokens.subscribe((tokens) => (customTokens = tokens));

  async function remove(token: Token) {
    const address = await $signer.getAddress();
    const updatedTokensList = tokenService.removeToken(token, address);
    userTokens.set(updatedTokensList);
    tokenStore.set(ETHToken); // select ETH token
  }

  async function onAddressChange(tokenAddress: string) {
    tokenError = '';

    if (ethers.utils.isAddress(tokenAddress)) {
      loadingTokenDetails = true;

      try {
        log('Fetching token details for address "%s"…', tokenAddress);

        const provider = getProvider();
        const tokenContract = new Contract(tokenAddress, erc20ABI, provider);
        const userAddress = await $signer.getAddress();

        const [symbol, decimals, userBalance] = await Promise.all([
          tokenContract.symbol(),
          tokenContract.decimals(),
          tokenContract.balanceOf(userAddress),
        ]);

        const formatedBalance = ethers.utils.formatUnits(userBalance, decimals);

        tokenDetails = {
          address: tokenAddress,
          decimals,
          symbol,
          balance: formatedBalance,
        };

        log('Token details', tokenAddress);
      } catch (error) {
        console.error(error);

        tokenError = 'Could not fetch token details.';
        errorToast(tokenError);
      } finally {
        loadingTokenDetails = false;
      }
    } else {
      tokenError = tokenAddress ? 'Invalid token address.' : '';
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
        class="input input-primary bg-dark-2 input-md md:input-lg w-full focus:ring-0 border-dark-2 rounded-md"
        name="customTokenAddress"
        bind:value={tokenAddress} />

      {#if tokenDetails}
        <div class="bg-dark-2 w-full flex items-center justify-between">
          <span class="bg-dark-2">{tokenDetails.symbol}</span>
          <span class="bg-dark-2">Balance: {tokenDetails.balance}</span>
        </div>
      {:else if loadingTokenDetails}
        <Loading />
      {:else if tokenError}
        <div class="min-h-[25px] text-error text-sm">
          <!-- TODO: translations? -->
          ⚠ {tokenError}
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
      <button class="btn" type="submit" disabled={Boolean(tokenError)}>
        Add
      </button>
    {/if}
  </form>

  {#if customTokens.length > 0}
    <div class="flex h-full w-full flex-col justify-between bg-none mt-6">
      <h3>Tokens already added</h3>
      {#each customTokens as customToken (customToken.symbol)}
        <div class="flex items-center justify-between">
          <div class="flex items-center">
            <Erc20 />
            <span class="bg-transparent">{customToken.symbol}</span>
          </div>
          <button class="btn btn-sm" on:click={() => remove(customToken)}>
            <Trash />
          </button>
        </div>
      {/each}
    </div>
  {/if}
</Modal>
