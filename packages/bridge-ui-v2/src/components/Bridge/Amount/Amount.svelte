<script lang="ts">
  import type { FetchBalanceResult } from '@wagmi/core';
  import { t } from 'svelte-i18n';
  import { formatUnits, parseUnits } from 'viem';

  import Icon from '$components/Icon/Icon.svelte';
  import { InputBox } from '$components/InputBox';
  import { warningToast } from '$components/NotificationToast';
  import { checkBalanceToBridge, getMaxAmountToBridge } from '$libs/bridge';
  import { InsufficientAllowanceError, InsufficientBalanceError } from '$libs/error';
  import { debounce } from '$libs/util/debounce';
  import { uid } from '$libs/util/uid';
  import { account } from '$stores/account';
  import { network } from '$stores/network';

  import { destNetwork, enteredAmount, processingFee, selectedToken } from '../state';
  import Balance from './Balance.svelte';
  import { FlatAlert } from '$components/Alert';

  let inputId = `input-${uid()}`;
  let tokenBalance: FetchBalanceResult;
  let inputBox: InputBox;

  let computingMaxAmount = false;

  // There are two possible errors that can happen when the user
  // enters an amount:
  // 1. Insufficient balance
  // 2. Insufficient allowance
  // The first one is an error and the user cannot proceed. The second one
  // is a warning but the user must approve allowance before bridging.
  let insufficientBalance = false;
  let insufficientAllowance = false;

  async function checkEnteredAmount() {
    insufficientBalance = false;
    insufficientAllowance = false;

    if (
      !$selectedToken ||
      !$network ||
      !$destNetwork ||
      !$account?.address ||
      $enteredAmount === BigInt(0) // no need to check if the amount is 0
    )
      return;

    try {
      await checkBalanceToBridge({
        to: $account.address,
        token: $selectedToken,
        amount: $enteredAmount,
        balance: tokenBalance.value,
        srcChainId: $network.id,
        destChainId: $destNetwork.id,
        processingFee: $processingFee,
      });
    } catch (err) {
      console.error(err);

      switch (true) {
        case err instanceof InsufficientBalanceError:
          insufficientBalance = true;
          break;
        case err instanceof InsufficientAllowanceError:
          insufficientAllowance = true;
          break;
      }
    }
  }

  // We want to debounce this function for input events
  const debouncedCheckEnteredAmount = debounce(checkEnteredAmount, 300);

  // Will trigger on input events. We update the entered amount
  // and check it's validity
  function inputAmount(event: Event) {
    insufficientBalance = false;
    insufficientAllowance = false;

    if (!$selectedToken) return;

    const target = event.target as HTMLInputElement;

    try {
      $enteredAmount = parseUnits(target.value, $selectedToken.decimals);

      debouncedCheckEnteredAmount();
    } catch (err) {
      $enteredAmount = BigInt(0);
    }
  }

  // "MAX" button handler
  async function useMaxAmount() {
    insufficientBalance = false;
    insufficientAllowance = false;

    // We cannot calculate the max amount without these guys
    if (!$selectedToken || !$network || !$destNetwork || !$account?.address) return;

    computingMaxAmount = true;

    try {
      const maxAmount = await getMaxAmountToBridge({
        to: $account.address,
        token: $selectedToken,
        balance: tokenBalance.value,
        processingFee: $processingFee,
        srcChainId: $network.id,
        destChainId: $destNetwork.id,
        amount: BigInt(1), // whatever amount to estimate the cost
      });

      // Update UI
      inputBox.setValue(formatUnits(maxAmount, $selectedToken.decimals));

      // Update state
      $enteredAmount = maxAmount;

      // Check validity
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
  // TODO: better way? maybe store.subscribe(), or different component
  $: $processingFee && $selectedToken && debouncedCheckEnteredAmount();
</script>

<div class="AmountInput f-col space-y-2">
  <div class="f-between-center text-secondary-content">
    <label class="body-regular" for={inputId}>{$t('amount_input.label')}</label>
    <Balance bind:value={tokenBalance} />
  </div>

  <div class="relative">
    <div class="relative f-items-center">
      <InputBox
        id={inputId}
        type="number"
        placeholder="0.01"
        min="0"
        loading={computingMaxAmount}
        error={insufficientBalance}
        on:input={inputAmount}
        bind:this={inputBox}
        class="w-full input-box outline-none py-6 pr-16 px-[26px] title-subsection-bold placeholder:text-tertiary-content" />
      <!-- TODO: talk to Jane about the MAX button and its styling -->
      <button
        class="absolute right-6 uppercase hover:font-bold"
        disabled={!$selectedToken || !$network || computingMaxAmount}
        on:click={useMaxAmount}>
        {$t('amount_input.button.max')}
      </button>
    </div>

    {#if insufficientBalance}
      <FlatAlert type="error" message={$t('amount_input.error.insufficient_balance')} class="absolute bottom-[-26px]" />
    {/if}

    {#if insufficientAllowance}
      <FlatAlert
        type="warning"
        message={$t('amount_input.error.insufficient_allowance')}
        class="absolute bottom-[-26px]" />
    {/if}
  </div>
</div>
