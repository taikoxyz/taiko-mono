<script lang="ts">
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';
  import { formatUnits, parseUnits } from 'viem';

  import { FlatAlert } from '$components/Alert';
  import { InputBox } from '$components/InputBox';
  import { LoadingText } from '$components/LoadingText';
  import { warningToast } from '$components/NotificationToast';
  import { checkBalanceToBridge, getMaxAmountToBridge } from '$libs/bridge';
  import {
    InsufficientAllowanceError,
    InsufficientBalanceError,
    RevertedWithFailedError,
    RevertedWithoutMessageError,
    UnknownTokenTypeError,
  } from '$libs/error';
  import { ETHToken, getBalance as getTokenBalance, type NFT, TokenType } from '$libs/token';
  import { renderBalance } from '$libs/util/balance';
  import { debounce } from '$libs/util/debounce';
  import { getLogger } from '$libs/util/logger';
  import { uid } from '$libs/util/uid';
  import { account } from '$stores/account';
  import { ethBalance } from '$stores/balance';
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
  let invalidInput = false;

  // Public API
  export function clearAmount() {
    inputBox?.clear();
    $enteredAmount = BigInt(0);
  }

  export let disabled = false;

  export let doAllowanceCheck = true;

  export async function validateAmount(token = $selectedToken, fee = $processingFee) {
    if (!$network?.id) return;
    $validatingAmount = true; // During validation, we disable all the actions
    $insufficientBalance = false;
    $insufficientAllowance = false;

    const to = $recipientAddress || $account?.address;

    let balanceForGasCalculation = $ethBalance;

    // We need all these guys to validate
    if (
      !to ||
      !token ||
      !$network ||
      !$destNetwork ||
      !$tokenBalance ||
      !$selectedToken ||
      !(balanceForGasCalculation && balanceForGasCalculation > BigInt(0)) ||
      $enteredAmount === BigInt(0) // no need to check if the amount is 0
    ) {
      $validatingAmount = false;
      return;
    }

    if (doAllowanceCheck) {
      try {
        await checkBalanceToBridge({
          to,
          token,
          amount: $enteredAmount,
          fee,
          balance: balanceForGasCalculation,
          srcChainId: $network.id,
          destChainId: $destNetwork.id,
          tokenIds:
            $selectedToken.type === TokenType.ERC721 || $selectedToken.type === TokenType.ERC1155
              ? [BigInt((token as NFT).tokenId)]
              : [],
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
            warningToast({
              title: $t('bridge.errors.send_message_error.title'),
              message: $t('bridge.errors.send_message_error.message'),
            });
            break;
          case err instanceof RevertedWithoutMessageError:
            warningToast({
              title: $t('bridge.errors.unknown_error.title'),
              message: $t('bridge.errors.unknown_error.message'),
            });
            break;
          default:
            invalidInput = true;
            break;
        }
      }
    } else {
      if (typeof $tokenBalance === 'bigint') {
        $insufficientBalance = $tokenBalance < $enteredAmount;
      }
    }
    $validatingAmount = false;
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
      if (token.type === TokenType.ERC20) {
        $tokenBalance = await getTokenBalance({
          token,
          srcChainId,
          destChainId,
          userAddress,
        });
      } else if (token.type === TokenType.ETH) {
        $tokenBalance = await getTokenBalance({
          token: ETHToken,
          srcChainId,
          destChainId,
          userAddress,
        });
      } else {
        $tokenBalance = token.balance;
      }
    } catch (err) {
      log('Error updating balance: ', err);
      //most likely we have a custom token that is not bridged yet
      $errorComputingBalance = true;
      clearAmount();
    }
    $computingBalance = false;
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
    } else if ($selectedToken.type === TokenType.ERC20 || $selectedToken.type === TokenType.ETH) {
      // For ERC20 or ETH, replace commas with dots
      value = value.replace(/[,]/g, '.');
    } else {
      throw new UnknownTokenTypeError($selectedToken.type);
    }

    sanitizedValue = value;

    if ($selectedToken.type === TokenType.ERC1155 || !$selectedToken.decimals) {
      $enteredAmount = BigInt(sanitizedValue);
    } else {
      $enteredAmount = parseUnits(sanitizedValue, $selectedToken.decimals);
    }
    debouncedValidateAmount();
  }

  // "MAX" button handler
  async function useMaxAmount() {
    // We cannot calculate the max amount without these guys
    if (!$selectedToken || !$network || !$destNetwork || !$tokenBalance || !$account?.address) return;

    computingMaxAmount = true;

    const balance = determineBalance();

    try {
      let maxAmount;

      if ($selectedToken.type === TokenType.ERC721 || $selectedToken.type === TokenType.ERC1155) {
        $enteredAmount = $tokenBalance as bigint;
        inputBox.setValue($enteredAmount.toString());
      } else {
        maxAmount = await getMaxAmountToBridge({
          to: $recipientAddress || $account.address,
          token: $selectedToken,
          balance,
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
      }

      // Check validity
      validateAmount();
    } catch (err) {
      console.error(err);
      warningToast({ title: $t('amount.errors.failed_max') });
    } finally {
      computingMaxAmount = false;
    }
  }

  const determineBalance = () => {
    $computingBalance = true;
    let balance = 0n;
    if (!$selectedToken) return balance;
    const type = $selectedToken.type;
    switch (type) {
      case TokenType.ERC20:
        if (typeof $tokenBalance === 'bigint') break;
        if ($tokenBalance?.value) balance = $tokenBalance.value;
        break;
      case TokenType.ETH:
        balance = $ethBalance;
        break;
      case TokenType.ERC721:
      case TokenType.ERC1155:
        if (typeof $tokenBalance === 'bigint') balance = $tokenBalance;
        break;
      default:
        break;
    }
    $computingBalance = false;
    return balance;
  };

  $: if (inputBox && sanitizedValue !== inputBox.getValue()) {
    inputBox.setValue(sanitizedValue); // Update InputBox value if sanitizedValue changes
  }

  $: updateBalance($selectedToken, $account?.address, $network?.id, $destNetwork?.id);

  $: validateAmount($selectedToken, $processingFee);

  // There is no reason to show any error/warning message if we are computing the balance
  // or there is an issue computing it
  $: showInsufficientBalanceAlert = $insufficientBalance && !$errorComputingBalance && !$computingBalance;

  $: noDecimalsAllowedAlert = invalidInput;

  $: inputDisabled = computingMaxAmount || disabled || !$selectedToken || !$network || $errorComputingBalance;

  // TODO: Disabled for now, potentially confusing users
  // $: showInsiffucientAllowanceAlert = $insufficientAllowance && !$errorComputingBalance && !$computingBalance;

  onMount(() => {
    $computingBalance = true;
    $enteredAmount = BigInt(0);
    determineBalance();
    $computingBalance = false;
  });
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
        disabled={inputDisabled}
        error={$insufficientBalance || invalidInput}
        on:input={inputAmount}
        bind:this={inputBox}
        class="py-6 pr-16 px-[26px] title-subsection-bold border-0  {$$props.class}" />
      <!-- TODO: talk to Jane about the MAX button and its styling -->
      {#if !disabled}
        <button class="absolute right-6 uppercase hover:font-bold" on:click={useMaxAmount}>
          {$t('inputs.amount.button.max')}
        </button>
      {/if}
    </div>
    <div class="flex mt-[8px] min-h-[24px]">
      {#if showInsufficientBalanceAlert}
        <FlatAlert type="error" message={$t('bridge.errors.insufficient_balance.title')} class="relative" />
        <!-- TODO: Disabled for now, potentially confusing users -->

        <!-- {:else if showInsiffucientAllowanceAlert}
        <FlatAlert type="warning" message={$t('bridge.errors.insufficient_allowance')} class="absolute" /> -->
      {:else if noDecimalsAllowedAlert}
        <FlatAlert type="error" message={$t('bridge.errors.no_decimals_allowed')} class="relative" />
      {/if}
    </div>
  </div>
</div>
