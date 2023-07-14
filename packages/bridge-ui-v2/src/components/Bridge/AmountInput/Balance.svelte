<script lang="ts">
  import type { FetchBalanceResult } from '@wagmi/core';
  import { t } from 'svelte-i18n';

  import LoadingText from '$components/LoadingText/LoadingText.svelte';
  import { getBalance as getTokenBalance, type Token } from '$libs/token';
  import { truncateString } from '$libs/util/truncateString';
  import { type Account, account } from '$stores/account';
  import { destChain, srcChain } from '$stores/network';

  import { selectedToken } from '../selectedToken';

  let tokenBalance: Maybe<FetchBalanceResult>;
  let computingTokenBalance = false;
  let errorComputingTokenBalance = false;

  async function updateTokenBalance(token?: Token, account?: Account, srcChainId?: number, destChainId?: number) {
    if (!token || !account || !account.address) return;

    computingTokenBalance = true;
    errorComputingTokenBalance = false;

    try {
      tokenBalance = await getTokenBalance({ token, userAddress: account.address, srcChainId, destChainId });
    } catch (error) {
      console.error(error);
      errorComputingTokenBalance = true;
    } finally {
      computingTokenBalance = false;
    }
  }

  export function renderTokenBalance(balance: Maybe<FetchBalanceResult>) {
    if (!balance) return '0.00';
    return `${truncateString(balance.formatted, 6)} ${balance.symbol}`;
  }

  $: updateTokenBalance($selectedToken, $account, $srcChain?.id, $destChain?.id);
</script>

<div class="body-small-regular">
  <span>{$t('amount_input.balance')}:</span>
  <span>
    {#if computingTokenBalance}
      <LoadingText mask="0.0000" />
      <LoadingText mask="XXX" />
    {:else}
      {renderTokenBalance(tokenBalance)}
    {/if}
  </span>
</div>
