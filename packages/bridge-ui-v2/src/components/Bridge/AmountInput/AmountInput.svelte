<script lang="ts">
  import type { FetchBalanceResult } from '@wagmi/core';
  import { t } from 'svelte-i18n';
  import { formatEther, parseUnits } from 'viem';

  import { InputBox } from '$components/InputBox';
  import { getMaxToBridge } from '$libs/bridge/getMaxToBridge';
  import { uid } from '$libs/util/uid';
  import { account } from '$stores/account';
  import { network } from '$stores/network';

  import { destNetwork, enteredAmount, processingFee, selectedToken } from '../state';
  import Balance from './Balance.svelte';
  import { warningToast } from '$components/NotificationToast';
  import { debounce } from '$libs/util/debounce';
  import Icon from '$components/Icon/Icon.svelte';

  let inputId = `input-${uid()}`;
  let tokenBalance: FetchBalanceResult;
  let inputBox: InputBox;

  let computingMaxAmount = false;
  let errorAmount = false;

  async function checkEnteredAmount() {
    if (
      !$selectedToken ||
      !$network ||
      !$account?.address ||
      $enteredAmount === BigInt(0) // why to even bother, right?
    ) {
      errorAmount = false;
      return;
    }

    try {
      const maxAmount = await getMaxToBridge({
        token: $selectedToken,
        balance: tokenBalance.value,
        processingFee: $processingFee,
        srcChainId: $network.id,
        destChainId: $destNetwork?.id,
        userAddress: $account.address,
        amount: $enteredAmount,
      });

      if ($enteredAmount > maxAmount) {
        errorAmount = true;
      }
    } catch (err) {
      console.error(err);

      // Viem might throw an error that contains the following message, indicating
      // that the user won't have enough to pay the transaction
      if (`${err}`.toLocaleLowerCase().match('transaction exceeds the balance')) {
        errorAmount = true;
      }
    }
  }

  // We want to debounce this function for input events
  const debouncedCheckEnteredAmount = debounce(checkEnteredAmount, 300);

  function updateAmount(event: Event) {
    errorAmount = false;

    if (!$selectedToken) return;

    const target = event.target as HTMLInputElement;

    try {
      $enteredAmount = parseUnits(target.value, $selectedToken?.decimals);

      debouncedCheckEnteredAmount();
    } catch (err) {
      $enteredAmount = BigInt(0);
    }
  }

  function setETHAmount(amount: bigint) {
    inputBox.setValue(formatEther(amount));
    $enteredAmount = amount;
  }

  async function useMaxAmount() {
    if (!$selectedToken || !$network || !$account?.address) return;

    computingMaxAmount = true;

    try {
      const maxAmount = await getMaxToBridge({
        token: $selectedToken,
        balance: tokenBalance.value,
        processingFee: $processingFee,
        srcChainId: $network.id,
        destChainId: $destNetwork?.id,
        userAddress: $account.address,
      });

      setETHAmount(maxAmount);
      checkEnteredAmount();
    } catch (err) {
      console.error(err);
      warningToast($t('amount_input.button.failed_max'));
    } finally {
      computingMaxAmount = false;
    }
  }

  // Let's also trigger the check when either the processingFee or
  // the selectedToken change and debounce it, just in case
  $: $processingFee && $selectedToken && debouncedCheckEnteredAmount();
</script>

<div class="AmountInput f-col space-y-2">
  <div class="f-between-center text-secondary-content">
    <label class="body-regular" for={inputId}>{$t('amount_input.label')}</label>
    <Balance bind:value={tokenBalance} />
  </div>

  <div class="relative f-items-center">
    <InputBox
      id="{inputId}x"
      type="number"
      placeholder="0.01"
      min="0"
      loading={computingMaxAmount}
      error={errorAmount}
      on:input={updateAmount}
      bind:this={inputBox}
      class="w-full input-box outline-none py-6 pr-16 px-[26px] title-subsection-bold placeholder:text-tertiary-content" />
    <button
      class="absolute right-6 uppercase"
      disabled={!$selectedToken || !$network || computingMaxAmount}
      on:click={useMaxAmount}>
      {$t('amount_input.button.max')}
    </button>
  </div>

  {#if errorAmount}
    <!-- TODO: should we make another component for flat error messages? -->
    <div class="f-items-center space-x-1 mt-3">
      <Icon type="exclamation-circle" fillClass="fill-negative-sentiment" />
      <div class="body-small-regular text-negative-sentiment">
        {$t('amount_input.error.insufficient_balance')}
      </div>
    </div>
  {/if}
</div>
