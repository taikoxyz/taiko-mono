<script lang="ts">
  import type { FetchBalanceResult, GetAccountResult, PublicClient } from '@wagmi/core';
  import { t } from 'svelte-i18n';

  import LoadingText from '$components/LoadingText/LoadingText.svelte';
  import { getBalance as getTokenBalance, type Token } from '$libs/token';
  import { truncateString } from '$libs/util/truncateString';
  import { account } from '$stores/account';
  import { destChain, srcChain } from '$stores/network';
  import { selectedToken } from '../selectedToken';

  let tokenBalance: Maybe<FetchBalanceResult>;
  let computingTokenBalance = false;

  async function updateTokenBalance(
    token?: Token,
    account?: GetAccountResult<PublicClient>,
    srcChainId?: number,
    destChainId?: number,
  ) {
    if (!token || !account || !account.address) return;

    computingTokenBalance = true;

    try {
      tokenBalance = await getTokenBalance(token, account.address, srcChainId, destChainId);
    } catch (error) {
      console.error(error);
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
      <LoadingText mask="0.0000" class="text-white" />
      <LoadingText mask="XXX" class="text-white" />
    {:else}
      {renderTokenBalance(tokenBalance)}
    {/if}
  </span>
</div>
