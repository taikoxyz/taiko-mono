<script lang="ts">
  import { format, t } from 'svelte-i18n';

  import { InputBox } from '$components/InputBox';
  import { uid } from '$libs/util/uid';
  import { isETH, type Token } from '$libs/token';
  import { fetchBalance, type FetchBalanceResult, type GetAccountResult, type PublicClient } from '@wagmi/core';
  import { getLogger } from '$libs/util/logger';
  import { account } from '$stores/account';
  import LoadingText from '$components/LoadingText/LoadingText.svelte';
  import { truncateString } from '$libs/util/truncateString';

  const log = getLogger('AmountInput');

  export let token: Token;

  let inputId = `input-${uid()}`;

  let tokenBalance: FetchBalanceResult;
  let computingTokenBalance = false;

  async function updateTokenBalance(token: Maybe<Token>, account: Maybe<GetAccountResult<PublicClient>>) {
    if (!token || !account) return;

    computingTokenBalance = true;

    try {
      if (isETH(token)) {
        const { address } = account;

        if (address) {
          tokenBalance = await fetchBalance({ address });
          log('ETH balance:', tokenBalance);
        }
      }
    } finally {
      computingTokenBalance = false;
    }
  }

  export function renderTokenBalance(balance: Maybe<FetchBalanceResult>) {
    if (!balance) return '0.00';
    return `${truncateString(balance.formatted, 6)} ${balance.symbol}`;
  }

  $: updateTokenBalance(token, $account);
</script>

<div class="f-col space-y-2">
  <div class="f-between-center text-secondary-content">
    <label class="body-regular" for={inputId}>{$t('amount_input.label')}</label>
    <div class="body-small-regular">
      <span>{$t('amount_input.balance')}:</span>
      <span>
        {#if computingTokenBalance}
          <LoadingText mask="0.000" class="text-white" />
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
