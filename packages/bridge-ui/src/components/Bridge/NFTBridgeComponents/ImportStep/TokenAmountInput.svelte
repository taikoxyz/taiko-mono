<script lang="ts">
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { FlatAlert } from '$components/Alert';
  import { InputBox } from '$components/InputBox';
  import { LoadingText } from '$components/LoadingText';
  import { warningToast } from '$components/NotificationToast';
  import { InvalidParametersProvidedError, UnknownTokenTypeError } from '$libs/error';
  import { ETHToken, fetchBalance, fetchBalance as getTokenBalance, TokenType } from '$libs/token';
  import { debounce } from '$libs/util/debounce';
  import { getLogger } from '$libs/util/logger';
  import { uid } from '$libs/util/uid';
  import { account } from '$stores/account';
  import { ethBalance } from '$stores/balance';
  import { connectedSourceChain } from '$stores/network';

  import {
    computingBalance,
    destNetwork,
    enteredAmount,
    errorComputingBalance,
    insufficientAllowance,
    insufficientBalance,
    recipientAddress,
    selectedToken,
    tokenBalance,
    validatingAmount,
  } from '../../state';

  const log = getLogger('component:Amount');

  let inputId = `input-${uid()}`;
  let inputBox: InputBox;
  let computingMaxAmount = false;
  let invalidInput = false;
  let value = '';

  // Public API
  export function clearAmount() {
    inputBox?.clear();
    $enteredAmount = BigInt(0);
  }

  export let disabled = false;

  export async function validateAmount(token = $selectedToken) {
    if (!$connectedSourceChain?.id) return;
    $validatingAmount = true; // During validation, we disable all the actions
    $insufficientBalance = false;
    $insufficientAllowance = false;

    const to = $recipientAddress || $account?.address;

    let balanceForGasCalculation = $ethBalance;

    // We need all these guys to validate
    if (
      !to ||
      !token ||
      !$connectedSourceChain ||
      !$destNetwork ||
      !$tokenBalance ||
      !$selectedToken ||
      !(balanceForGasCalculation && balanceForGasCalculation > BigInt(0)) ||
      $enteredAmount === BigInt(0) // no need to check if the amount is 0
    ) {
      $validatingAmount = false;
      return;
    }

    $insufficientBalance = $tokenBalance.value < $enteredAmount;
    $validatingAmount = false;
  }

  export async function updateBalance(
    token = $selectedToken,
    userAddress = $account?.address,
    srcChainId = $connectedSourceChain?.id,
    destChainId = $destNetwork?.id,
  ) {
    if (!token || !srcChainId || !userAddress) return;
    $computingBalance = true;

    try {
      if (token.type === TokenType.ETH) {
        $tokenBalance = await getTokenBalance({
          token: ETHToken,
          srcChainId,
          destChainId,
          userAddress,
        });
      } else {
        $tokenBalance = await getTokenBalance({
          token,
          srcChainId,
          destChainId,
          userAddress,
        });
      }
    } catch (err) {
      log('Error updating balance: ', err);
      clearAmount();
    } finally {
      $computingBalance = false;
    }
  }

  // We want to debounce this function for input events.
  // Could happen as the user enters an amount
  const debouncedValidateAmount = debounce(validateAmount, 300);
  let sanitizedValue = '';

  function inputAmount(event: Event) {
    invalidInput = false;
    $validatingAmount = true; // During validation, we disable all the actions
    if (!$selectedToken) return;
    const target = event.target as HTMLInputElement;
    let value = target.value;

    if ($selectedToken.type === TokenType.ERC1155) {
      // For ERC1155, no decimals are allowed
      if (/[.,]/.test(value)) {
        invalidInput = true;
        return;
      }
    } else {
      $validatingAmount = false;
      throw new UnknownTokenTypeError($selectedToken.type);
    }

    sanitizedValue = value;

    $enteredAmount = BigInt(sanitizedValue);
    $validatingAmount = false;

    debouncedValidateAmount();
  }

  // "MAX" button handler
  async function useMaxAmount() {
    // We cannot calculate the max amount without these guys
    if (!$selectedToken || !$connectedSourceChain || !$destNetwork || !$tokenBalance || !$account?.address) return;
    invalidInput = false;
    computingMaxAmount = true;

    try {
      if ($selectedToken.type === TokenType.ERC721 || $selectedToken.type === TokenType.ERC1155) {
        inputBox.setValue($tokenBalance.value.toString());
        $enteredAmount = $tokenBalance.value;
        validateAmount();
      } else {
        throw new InvalidParametersProvidedError('token type not supported for this component');
      }
    } catch (err) {
      console.error(err);
      warningToast({ title: $t('amount.errors.failed_max') });
    } finally {
      computingMaxAmount = false;
    }
  }

  export async function determineBalance() {
    if (!$account?.address || !$selectedToken) return;
    $tokenBalance = await fetchBalance({
      userAddress: $account?.address,
      token: $selectedToken,
      srcChainId: $connectedSourceChain?.id,
      destChainId: $destNetwork?.id,
    });
  }

  $: if (inputBox && sanitizedValue !== value) {
    inputBox.setValue(sanitizedValue); // Update InputBox value if sanitizedValue changes
  }

  $: hasBalance = $tokenBalance && $tokenBalance?.value > 0n;

  // There is no reason to show any error/warning message if we are computing the balance
  // or there is an issue computing it
  $: showInsufficientBalanceAlert = $insufficientBalance && !$errorComputingBalance && !$computingBalance;

  $: noDecimalsAllowedAlert = invalidInput;

  $: inputDisabled =
    computingMaxAmount ||
    disabled ||
    !$selectedToken ||
    !$connectedSourceChain ||
    $errorComputingBalance ||
    !hasBalance;

  $: maxButtonEnabled = hasBalance && !disabled && !$errorComputingBalance;

  onMount(() => {
    $enteredAmount = BigInt(0);
    determineBalance();
    $insufficientBalance = false;
  });
</script>

<div class="Amount f-col space-y-2 {$$props.class}">
  <div class="f-between-center text-secondary-content">
    <label class="body-regular" for={inputId}>{$t('inputs.amount.label')}</label>
    <div class="body-small-regular">
      {#if $errorComputingBalance}
        <FlatAlert type="error" message={$t('bridge.errors.cannot_fetch_balance')} />
      {:else}
        <span>{$t('inputs.amount.balance')}:</span>
        <span>
          {#if computingMaxAmount}
            <LoadingText mask={$tokenBalance?.toString() || '100'} />
          {:else}
            <!-- {renderBalance($tokenBalance)} -->
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
        placeholder="42"
        min="0"
        disabled={inputDisabled}
        error={$insufficientBalance || invalidInput}
        bind:value
        on:input={inputAmount}
        bind:this={inputBox}
        class="py-6 pr-16 px-[26px] title-subsection-bold border-0  {$$props.class}" />
      {#if maxButtonEnabled}
        <button class="absolute right-6 uppercase hover:font-bold" on:click={useMaxAmount}>
          {$t('inputs.amount.button.max')}
        </button>
      {/if}
    </div>
    <div class="flex mt-[8px] min-h-[24px]">
      {#if showInsufficientBalanceAlert}
        <FlatAlert type="error" message={$t('bridge.errors.insufficient_balance.title')} class="relative " />
      {:else if noDecimalsAllowedAlert}
        <FlatAlert type="error" message={$t('bridge.errors.no_decimals_allowed')} class="relative" />
      {/if}
    </div>
  </div>
</div>
