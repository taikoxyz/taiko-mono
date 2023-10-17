<script lang="ts">
  import { onDestroy } from 'svelte';
  import { t } from 'svelte-i18n';
  import { formatUnits, parseUnits } from 'viem';

  import { FlatAlert } from '$components/Alert';
  import { InputBox } from '$components/InputBox';
  import { LoadingText } from '$components/LoadingText';
  import { warningToast } from '$components/NotificationToast';
  import { checkBalanceToBridge, getMaxAmountToBridge } from '$libs/bridge';
  import { InsufficientAllowanceError, InsufficientBalanceError, RevertedWithFailedError } from '$libs/error';
  import { ETHToken, getBalance as getTokenBalance, TokenType } from '$libs/token';
  import { renderBalance } from '$libs/util/balance';
  import { debounce } from '$libs/util/debounce';
  import { getLogger } from '$libs/util/logger';
  import { uid } from '$libs/util/uid';
  import { account } from '$stores/account';
  import { network } from '$stores/network';

  import {
    computingBalance,
    destNetwork,
    enteredAmount,
    errorComputingBalance,
    insufficientAllowance,
    insufficientBalance,
    processingFee,
    recipientAddress,
    selectedToken,
    tokenBalance,
    validatingAmount,
  } from './state';

  const log = getLogger('component:Amount');

  let inputId = `input-${uid()}`;
  let inputBox: InputBox;
  let computingMaxAmount = false;

  onDestroy(() => {
    clearAmount();
  });

  // Public API
  export function clearAmount() {
    inputBox?.clear();
    $enteredAmount = BigInt(0);
  }

  export async function validateAmount(token = $selectedToken, fee = $processingFee) {
    $insufficientBalance = false;
    $insufficientAllowance = false;
    $validatingAmount = true; // During validation, we disable all the actions

    const to = $recipientAddress || $account?.address;

    // We need all these guys to validate
    if (
      !to ||
      !token ||
      !$network ||
      !$destNetwork ||
      !$tokenBalance ||
      !$selectedToken ||
      $enteredAmount === BigInt(0) // no need to check if the amount is 0
    )
      return;

    try {
      await checkBalanceToBridge({
        to,
        token,
        amount: $enteredAmount,
        fee,
        balance: $tokenBalance.value,
        srcChainId: $network.id,
        destChainId: $destNetwork.id,
      });
    } catch (err) {
      switch (true) {
        case err instanceof InsufficientBalanceError:
          $insufficientBalance = true;
          break;
        case err instanceof InsufficientAllowanceError:
          $insufficientAllowance = true;
          break;
        case err instanceof RevertedWithFailedError:
          warningToast({title: $t('messages.network.rejected')});
          break;
      }
    } finally {
      $validatingAmount = false;
    }
  }

  export async function updateBalance(
    token = $selectedToken,
    userAddress = $account?.address,
    srcChainId = $network?.id,
    destChainId = $destNetwork?.id,
  ) {
    if (!token || !srcChainId || !userAddress) return;

    $computingBalance = true;
    $errorComputingBalance = false;

    try {
      if (token.type !== TokenType.ETH) {
        $tokenBalance = await getTokenBalance({
          token,
          srcChainId,
          destChainId,
          userAddress,
        });
      } else {
        $tokenBalance = await getTokenBalance({
          token: ETHToken,
          srcChainId,
          destChainId,
          userAddress,
        });
      }
    } catch (err) {
      log('Error updating balance: ', err);
      //most likely we have a custom token that is not bridged yet
      $errorComputingBalance = true;
      clearAmount();
    } finally {
      $computingBalance = false;
    }
  }

  // We want to debounce this function for input events.
  // Could happen as the user enters an amount
  const debouncedValidateAmount = debounce(validateAmount, 300);

  // Will trigger on input events. We update the entered amount
  // and check it's validity
  function inputAmount(event: Event) {
    if (!$selectedToken) return;

    const { value } = event.target as HTMLInputElement;
    $enteredAmount = parseUnits(value, $selectedToken.decimals);

    debouncedValidateAmount();
  }

  // "MAX" button handler
  async function useMaxAmount() {
    // We cannot calculate the max amount without these guys
    if (!$selectedToken || !$network || !$destNetwork || !$tokenBalance || !$account?.address) return;

    computingMaxAmount = true;

    try {
      const maxAmount = await getMaxAmountToBridge({
        to: $recipientAddress || $account.address,
        token: $selectedToken,
        balance: $tokenBalance.value,
        fee: $processingFee,
        srcChainId: $network.id,
        destChainId: $destNetwork.id,
        amount: BigInt(1), // whatever amount to estimate the cost
      });

      // Update UI
      // Note: triggering the event manually does not always work, specially
      // in other browsers (looking at you, Safari!!)
      inputBox.setValue(formatUnits(maxAmount, $selectedToken.decimals));

      // Update state
      $enteredAmount = maxAmount;

      // Check validity
      validateAmount();
    } catch (err) {
      console.error(err);
      warningToast({title: $t('amount.errors.failed_max')});
    } finally {
      computingMaxAmount = false;
    }
  }

  $: updateBalance($selectedToken, $account?.address, $network?.id, $destNetwork?.id);

  $: validateAmount($selectedToken, $processingFee);

  // There is no reason to show any error/warning message if we are computing the balance
  // or there is an issue computing it
  $: showInsufficientBalanceAlert = $insufficientBalance && !$errorComputingBalance && !$computingBalance;

  // TODO: Disabled for now, potentially confusing users
  // $: showInsiffucientAllowanceAlert = $insufficientAllowance && !$errorComputingBalance && !$computingBalance;
</script>

<div class="Amount f-col space-y-2">
  <div class="f-between-center text-secondary-content">
    <label class="body-regular" for={inputId}>{$t('inputs.amount.label')}</label>
    <div class="body-small-regular">
      {#if $errorComputingBalance}
        <FlatAlert type="error" message={$t('bridge.errors.cannot_fetch_balance')} />
      {:else}
        <span>{$t('inputs.amount.balance')}:</span>
        <span>
          {#if $computingBalance}
            <LoadingText mask="0.0000" />
            <LoadingText mask="XXX" />
          {:else}
            {renderBalance($tokenBalance)}
          {/if}
        </span>
      {/if}
    </div>
  </div>

  <div class="relative">
    <div class="relative f-items-center">
      <InputBox
        id={inputId}
        type="number"
        placeholder="0.01"
        min="0"
        disabled={$errorComputingBalance || computingMaxAmount}
        error={$insufficientBalance}
        on:input={inputAmount}
        bind:this={inputBox}
        class="py-6 pr-16 px-[26px] title-subsection-bold border-0" />
      <!-- TODO: talk to Jane about the MAX button and its styling -->
      <button
        class="absolute right-6 uppercase hover:font-bold"
        disabled={!$selectedToken || !$network || computingMaxAmount || $errorComputingBalance}
        on:click={useMaxAmount}>
        {$t('inputs.amount.button.max')}
      </button>
    </div>
    <div class="flex mt-[8px] min-h-[24px]">
      {#if showInsufficientBalanceAlert}
        <FlatAlert type="error" message={$t('bridge.errors.insufficient_balance')} class="relative" />
        <!-- TODO: Disabled for now, potentially confusing users -->

        <!-- {:else if showInsiffucientAllowanceAlert}
        <FlatAlert type="warning" message={$t('bridge.errors.insufficient_allowance')} class="absolute" /> -->
      {/if}
    </div>
  </div>
</div>
