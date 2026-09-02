<script lang="ts">
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';
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
  import { TokenDropdown } from '$components/TokenDropdown';
  import { getMaxAmountToBridge } from '$libs/bridge';
  import { fetchBalance, tokens } from '$libs/token';
  import { isToken } from '$libs/token/isToken';
  import type { NFT, Token } from '$libs/token/types';
  import { refreshUserBalance, renderBalance } from '$libs/util/balance';
  import { debounce } from '$libs/util/debounce';
  import { getLogger } from '$libs/util/logger';
  import { parseDecimalAmount } from '$libs/util/parseDecimalAmount';
  import { truncateDecimalString } from '$libs/util/truncateDecimal';
  import { type Account, account } from '$stores/account';
  import { ethBalance } from '$stores/balance';
  import { connectedSourceChain } from '$stores/network';

  const log = getLogger('TokenInput');

  export let validInput = false;
  export let hasEnoughEth: boolean = false;

  let inputId = `input-${crypto.randomUUID()}`;
  let inputBox: InputBox;

  let value = '';
  let amountRejected = false;

  async function validateAmount(token = $selectedToken) {
    // During validation, we disable all the actions
    const user = $account?.address;
    if (!$connectedSourceChain?.id || !user) return;
    $validatingAmount = true;
    $insufficientBalance = false;
    $insufficientAllowance = false;
    // No balance is read here, so the computing flag is not touched: raising and lowering
    // it synchronously showed no spinner and, during a token switch, let the previous
    // token's balance stand in for the new one

    if (skipValidate) {
      log('skipped validation');
      $validatingAmount = false;
      return;
    }

    const to = $recipientAddress || $account?.address;

    if (!to || !token) {
      $validatingAmount = false;
      return;
    }

    // The one check this used to delegate to a helper nothing called: an amount above the
    // balance is refused here, and Actions gates Bridge on the same flag, so the Confirm
    // step cannot send more than the wallet holds. The NFT input does exactly this.
    $insufficientBalance = !!$tokenBalance && $tokenBalance.value < $enteredAmount;
    $validatingAmount = false;
  }

  const debouncedValidateAmount = debounce(validateAmount, 300);

  const handleAmountInputChange = (value: string) => {
    if (!isToken($selectedToken)) return;
    $validatingAmount = true;
    $errorComputingBalance = false;

    // parseUnits alone accepts hex ('0x10' becomes 268435456), negatives and a leading
    // plus, and rounds excess precision - every one of those bridges an amount other than
    // the one on screen
    const parsed = parseDecimalAmount(value, $selectedToken.decimals);
    if (!parsed.ok) {
      // An empty box is not an error, it is a box nobody has filled in yet. Anything else
      // needs saying out loud: the amount is now zero and Continue is disabled, and
      // without a message there is nothing on screen explaining why
      amountRejected = parsed.reason !== 'EMPTY';
      $enteredAmount = 0n;
      $validatingAmount = false;
      return;
    }
    amountRejected = false;
    $enteredAmount = parsed.value;
    debouncedValidateAmount();
  };

  const useMaxAmount = async () => {
    log('useMaxAmount');

    if (!isToken($selectedToken) || !$connectedSourceChain || !$destNetwork || !$tokenBalance || !$account?.address)
      return;

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

        // The displayed value is truncated for readability, so the entered amount is
        // re-derived from it: what the user sees is exactly what gets bridged. The
        // truncation stays on the string, since a float round-trip yields scientific
        // notation for tiny balances, which parseUnits rejects
        const exact = formatUnits(maxAmount, $selectedToken.decimals);
        const truncated = truncateDecimalString(exact, 12);
        // Below 1e-12 the truncation rounds the whole balance away, and MAX would show
        // and bridge zero. Showing every digit is better than offering nothing
        value = parseUnits(truncated, $selectedToken.decimals) > BigInt(0) ? truncated : exact;
        $enteredAmount = parseUnits(value, $selectedToken.decimals);
        amountRejected = false;
        validateAmount();
      }
    } catch (err) {
      log('Error getting max amount: ', err);
    }
  };

  // Balance reads resolve out of order: a bridged ERC20 goes through getAddress and its
  // own RPCs while ETH answers immediately, so an earlier selection's balance could land
  // against a later token - and validInput would then accept an amount the wallet does
  // not hold. Every writer of $tokenBalance goes through this.
  let balanceGeneration = 0;

  /**
   * @dev Reads the balance and publishes it only if no newer read has started meanwhile.
   * @param token The token the read belongs to
   * @param userAddress The account to read for
   * @param srcChainId The chain to read on
   * @return published_ Whether this read was still the latest when it resolved
   */
  const publishLatestBalance = async (token: Token | NFT, userAddress: Address, srcChainId?: number) => {
    const generation = ++balanceGeneration;
    let fetched: Awaited<ReturnType<typeof fetchBalance>>;
    try {
      fetched = await fetchBalance({ userAddress, token, srcChainId });
    } catch (error) {
      // A rejection here would otherwise escape as an unhandled rejection and leave the
      // computing flag raised for good. Reporting the read as settled hands the caller
      // back the job of lowering it; the balance itself is simply left as it was.
      log('Error fetching balance', error);
      // Superseded reads report nothing: a slow read failing for a token the user has
      // already replaced would otherwise raise the error flag over a balance that loaded
      // fine, which is the same staleness the generation counter exists to stop
      if (generation !== balanceGeneration) return false;
      $errorComputingBalance = true;
      return true;
    }
    if (generation !== balanceGeneration) return false;
    $errorComputingBalance = false;
    $tokenBalance = fetched;
    return true;
  };

  const reset = async () => {
    log('reset');
    const tokenForThisReset = $selectedToken;
    // Recorded here rather than after the balance read: this is selection bookkeeping, not
    // fetch-success bookkeeping. A reset superseded by a concurrent balance refresh returned
    // below without recording its token, so switching back to the previous one found
    // `$selectedToken === previousSelectedToken` and skipped the reset entirely - keeping
    // the other token's typed amount, its raw units and its balance, and validating the
    // transfer against them.
    previousSelectedToken = tokenForThisReset;
    $computingBalance = true;
    value = '';
    amountRejected = false;
    $enteredAmount = 0n;
    if ($account && $account.address && $account?.isConnected && tokenForThisReset) {
      validateAmount(tokenForThisReset);
      refreshUserBalance();
      log('fetching on chain', $connectedSourceChain?.name);
      const published = await publishLatestBalance(tokenForThisReset, $account.address, $connectedSourceChain?.id);
      // A superseded read leaves the flag to whichever read is current now - clearing it
      // here would stop the spinner while that one is still in flight. Every caller of
      // publishLatestBalance raises the flag and clears it on the winning path, so the
      // last read standing always turns it off.
      if (!published) return;
      log('tokenBalance', $tokenBalance);
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

  const onAccountChange = async (newAccount: Account, oldAccount?: Account) => {
    log('onAccountChange', newAccount, oldAccount);
    if (newAccount?.isConnected && newAccount.address && newAccount.address !== oldAccount?.address) {
      log('resetting input');
      reset();
    } else if (newAccount?.address && newAccount?.isConnected && $selectedToken) {
      log('refreshing user balance', $connectedSourceChain?.name);
      // The other writer of $tokenBalance, and it races the same way. It has to carry the
      // computing flag too: superseding a reset without owning the flag left the spinner
      // on forever, because the reset it superseded had already declined to clear it.
      $computingBalance = true;
      const published = await publishLatestBalance($selectedToken, newAccount.address, newAccount.chainId);
      if (published) $computingBalance = false;
    } else {
      console.error('No account connected or token selected');
    }
  };
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
    <TokenDropdown combined class="min-w-[151px] z-20" {tokens} bind:value={$selectedToken} bind:disabled />
  </div>

  <div class="flex mt-[8px] min-h-[24px]">
    {#if amountRejected}
      <FlatAlert type="error" message={$t('bridge.errors.invalid_amount')} class="relative" />
    {:else if displayFeeMsg}
      <div class="f-row items-center gap-1">
        <Icon type="info-circle" size={15} fillClass="fill-tertiary-content" /><span
          class="text-sm text-tertiary-content"
          >{$t('recipient.label')} <ProcessingFee textOnly class="text-tertiary-content" bind:hasEnoughEth /></span>
      </div>
    {:else if showInsufficientBalanceAlert}
      <FlatAlert type="error" message={$t('bridge.errors.insufficient_balance.title')} class="relative" />
    {:else if showInvalidTokenAlert}
      <FlatAlert type="error" message={$t('bridge.errors.custom_token.not_found.message')} class="relative" />
    {:else}
      <LoadingText mask="" class="w-1/2" />
    {/if}
  </div>
</div>

<OnAccount change={onAccountChange} />

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
