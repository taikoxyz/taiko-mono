<script lang="ts">
  import type { FetchBalanceResult, GetAccountResult, PublicClient } from '@wagmi/core';
  import { t } from 'svelte-i18n';

  import { InputBox } from '$components/InputBox';
  import LoadingText from '$components/LoadingText/LoadingText.svelte';
  import { getBalance as getTokenBalance, type Token } from '$libs/token';
  import { getLogger } from '$libs/util/logger';
  import { truncateString } from '$libs/util/truncateString';
  import { uid } from '$libs/util/uid';
  import { account } from '$stores/account';
  import { destChain, srcChain } from '$stores/network';

  const log = getLogger('AmountInput');

  export let token: Token;

  let inputId = `input-${uid()}`;

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

      log('Token balance', tokenBalance);
    } catch (error) {
      console.error(error);

      throw Error(`failed to get balance for ${token.symbol}`, { cause: error });
    } finally {
      computingTokenBalance = false;
    }
  }

  export function renderTokenBalance(balance: Maybe<FetchBalanceResult>) {
    if (!balance) return '0.00';
    return `${truncateString(balance.formatted, 6)} ${balance.symbol}`;
  }

  $: updateTokenBalance(token, $account, $srcChain?.id, $destChain?.id);
</script>

<div class="f-col space-y-2">
  <div class="f-between-center text-secondary-content">
    <label class="body-regular" for={inputId}>{$t('amount_input.label')}</label>
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
  </div>
  <div class="relative f-items-center">
    <InputBox
      id={inputId}
      type="number"
      placeholder="0.01"
      min="0"
      class="w-full input-box outline-none py-6 pr-16 px-[26px] title-subsection-bold placeholder:text-tertiary-content" />
    <button class="absolute right-6 uppercase">{$t('amount_input.button.max')}</button>
  </div>
</div>
