<script lang="ts">
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';
  import { formatUnits, parseUnits } from 'viem/utils';

  import { FlatAlert } from '$components/Alert';
  import { ProcessingFee } from '$components/Bridge/SharedBridgeComponents';
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
  } from '$components/Bridge/state';
  import { Icon } from '$components/Icon';
  import { InputBox } from '$components/InputBox';
  import { LoadingText } from '$components/LoadingText';
  import OnAccount from '$components/OnAccount/OnAccount.svelte';
  import { OnNetwork } from '$components/OnNetwork';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { getMaxAmountToBridge } from '$libs/bridge';
  import { fetchBalance, tokens } from '$libs/token';
  import { refreshUserBalance, renderBalance } from '$libs/util/balance';
  import { debounce } from '$libs/util/debounce';
  import { getLogger } from '$libs/util/logger';
  import { truncateDecimal } from '$libs/util/truncateDecimal';
  import { uid } from '$libs/util/uid';
  import { account } from '$stores/account';
  import { ethBalance } from '$stores/balance';
  import { connectedSourceChain } from '$stores/network';

  const log = getLogger('TokenInput');

  export let validInput = false;
  export let hasEnoughEth: boolean = false;

  let inputId = `input-${uid()}`;
  let inputBox: InputBox;

  let value = '';

  async function validateAmount(token = $selectedToken) {
    // During validation, we disable all the actions
    const user = $account?.address;
    if (!$connectedSourceChain?.id || !user) return;
    $validatingAmount = true;
    $insufficientBalance = false;
    $insufficientAllowance = false;
    $computingBalance = true;

    if (skipValidate) {
      log('skipped validation');
      $validatingAmount = false;
      $computingBalance = false;
      return;
    }

    const to = $recipientAddress || $account?.address;

    if (!to || !token) {
      $validatingAmount = false;
      $computingBalance = false;
      return;
    }

    $validatingAmount = false;
    $computingBalance = false;
  }

  const debouncedValidateAmount = debounce(validateAmount, 300);

  const handleAmountInputChange = (value: string) => {
    if (!$selectedToken) return;
    $validatingAmount = true;
    $errorComputingBalance = false;

    $enteredAmount = parseUnits(value, $selectedToken.decimals);
    debouncedValidateAmount();
  };

  const useMaxAmount = async () => {
    log('useMaxAmount');
    if (!$selectedToken || !$connectedSourceChain || !$destNetwork || !$tokenBalance || !$account?.address) return;
    try {
      let maxAmount;
      if ($tokenBalance) {
        maxAmount = await getMaxAmountToBridge({
          to: $account.address,
          token: $selectedToken,
          balance: $tokenBalance.value,
          srcChainId: $connectedSourceChain.id,
          destChainId: $destNetwork.id,
          fee: $processingFee,
        });

        // Update state
        $enteredAmount = maxAmount;
        value = formatUnits(maxAmount, $selectedToken.decimals);

        value = truncateDecimal(parseFloat(value), 12).toString();
        validateAmount();
      }
    } catch (err) {
      log('Error getting max amount: ', err);
    }
  };

  const reset = async () => {
    log('reset');
    $computingBalance = true;
    value = '';
    $enteredAmount = 0n;
    if ($account && $account.address && $account?.isConnected && $selectedToken) {
      validateAmount($selectedToken);
      refreshUserBalance();
      $tokenBalance = await fetchBalance({
        userAddress: $account.address,
        token: $selectedToken,
        srcChainId: $connectedSourceChain?.id,
      });
      previousSelectedToken = $selectedToken;
    } else {
      balance = '0.00';
    }
    $computingBalance = false;
  };

  let previousSelectedToken = $selectedToken;

  $: if ($selectedToken !== previousSelectedToken) {
    log('selectedToken changed, resetting value', $enteredAmount);
    reset();
  }

  $: disabled = !$account || !$account.isConnected;

  $: validAmount = $enteredAmount > BigInt(0);

  $: skipValidate =
    !$connectedSourceChain ||
    !$destNetwork ||
    !$tokenBalance ||
    !$selectedToken ||
    !($ethBalance !== null && $ethBalance > BigInt(0)) ||
    !validAmount;

  let invalidInput: boolean;
  $: {
    if ($enteredAmount !== 0n) {
      invalidInput = $errorComputingBalance || $insufficientBalance || $insufficientAllowance;
    } else {
      invalidInput = false;
    }
  }

  $: showInsufficientBalanceAlert = $insufficientBalance && !$errorComputingBalance && !$computingBalance;

  $: showInvalidTokenAlert = $errorComputingBalance && !$computingBalance;

  $: validInput =
    $enteredAmount > 0n &&
    $tokenBalance !== null &&
    $tokenBalance !== undefined &&
    $enteredAmount <= $tokenBalance?.value;

  $: displayFeeMsg = !showInsufficientBalanceAlert && !showInvalidTokenAlert;

  let balance = $t('common.not_available_short');

  $: {
    if ($tokenBalance && $account.isConnected && !$errorComputingBalance && !$computingBalance) {
      balance = renderBalance($tokenBalance);
    } else {
      balance = $t('common.not_available_short');
    }
  }

  onMount(async () => {
    $enteredAmount = 0n;
    const user = $account?.address;
    const token = $selectedToken;
    if (!user || !token) return;
  });
</script>

<div class="TokenInput space-y-[8px]">
  <div class="f-between-center text-sm">
    <span class="text-tertiary-content">{$t('inputs.amount.label')}</span>
    <span class="text-secondary-content">
      {$t('common.balance')}:
      {#if $errorComputingBalance && !$computingBalance}
        {$t('common.not_available_short')}
      {:else if $computingBalance}
        <LoadingText mask="0.0000" />
      {:else}
        {balance}
      {/if}
    </span>
  </div>
  <div class="relative f-row h-[64px]">
    <div class="relative f-items-center w-full">
      <!-- Amount Input -->
      <InputBox
        id={inputId}
        type="number"
        placeholder="0.01"
        min="0"
        disabled={disabled || $errorComputingBalance || $computingBalance}
        error={invalidInput}
        bind:value
        on:input={() => handleAmountInputChange(value)}
        bind:this={inputBox}
        class="min-h-[64px] pl-[15px] w-full border-0 h-full !rounded-r-none z-20  {$$props.class}" />

      <!-- vertical separator -->
      <div class="border-l border-r bg-primary-border-dark border-neutral-background h-[64px] w-[3px]" />

      <!-- Max Button -->
      <button
        disabled={disabled || $errorComputingBalance || $computingBalance}
        class="max-button absolute right-6 uppercase hover:font-bold text-tertiary-content z-20"
        on:click={useMaxAmount}>
        {$t('inputs.amount.button.max')}
      </button>
    </div>

    <!-- Token Dropdown -->
    <TokenDropdown combined class="min-w-[151px] z-20 " {tokens} bind:value={$selectedToken} bind:disabled />
  </div>

  <div class="flex mt-[8px] min-h-[24px]">
    {#if displayFeeMsg}
      <div class="f-row items-center gap-1">
        <Icon type="info-circle" size={15} fillClass="fill-tertiary-content" /><span
          class="text-sm text-tertiary-content"
          >{$t('recipient.label')} <ProcessingFee textOnly class="text-tertiary-content" bind:hasEnoughEth /></span>
      </div>
    {:else if showInsufficientBalanceAlert}
      <FlatAlert type="error" message={$t('bridge.errors.insufficient_balance.title')} class="relative " />
    {:else if showInvalidTokenAlert}
      <FlatAlert type="error" message={$t('bridge.errors.custom_token.not_found.message')} class="relative " />
    {:else}
      <LoadingText mask="" class="w-1/2" />
    {/if}
  </div>
</div>

<OnNetwork change={reset} />
<OnAccount change={reset} />

<style>
  .max-button {
    font-family: 'Public Sans';
    font-size: 14px;
    font-style: normal;
    font-weight: 400;
    line-height: 20px; /* 142.857% */
    letter-spacing: 0.14px;
  }
</style>
