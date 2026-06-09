"use client";

import { useEffect, useId, useRef, useState } from "react";
import { formatUnits, parseUnits } from "viem/utils";

import { FlatAlert } from "@/components/Alert";
import { ProcessingFee } from "@/components/Bridge/SharedBridgeComponents";
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
  useBridgeState,
  validatingAmount,
} from "@/components/Bridge/state";
import { Icon } from "@/components/Icon";
import { InputBox, type InputBoxHandle } from "@/components/InputBox";
import { LoadingText } from "@/components/LoadingText";
import OnAccount from "@/components/OnAccount/OnAccount";
import { TokenDropdown } from "@/components/TokenDropdown";
import { useTranslation } from "@/i18n/useTranslation";
import { getMaxAmountToBridge } from "@/libs/bridge";
import { fetchBalance, tokens } from "@/libs/token";
import { isToken } from "@/libs/token/isToken";
import { refreshUserBalance, renderBalance } from "@/libs/util/balance";
import { debounce } from "@/libs/util/debounce";
import { getLogger } from "@/libs/util/logger";
import { truncateDecimal } from "@/libs/util/truncateDecimal";
import { type Account, account } from "@/stores/account";
import { ethBalance, useEthBalanceStore } from "@/stores/balance";
import { connectedSourceChain } from "@/stores/network";
import { cn } from "@/lib/utils";

import styles from "./TokenInput.module.css";

const log = getLogger("TokenInput");

export interface TokenInputProps {
  /** Two-way bound (Svelte `bind:validInput`) — write-back via `onValidInputChange`. */
  validInput?: boolean;
  onValidInputChange?: (valid: boolean) => void;
  /** Two-way bound (Svelte `bind:hasEnoughEth`) — write-back via `onHasEnoughEthChange`. */
  hasEnoughEth?: boolean;
  onHasEnoughEthChange?: (value: boolean) => void;
  /** Maps Svelte's `$$props.class` forwarded onto the InputBox. */
  className?: string;
}

export default function TokenInput({
  hasEnoughEth = false,
  onValidInputChange,
  onHasEnoughEthChange,
  className,
}: TokenInputProps) {
  const { t } = useTranslation();

  // Reactive store reads (Svelte `$store`).
  const $selectedToken = useBridgeState(selectedToken);
  const $tokenBalance = useBridgeState(tokenBalance);
  const $enteredAmount = useBridgeState(enteredAmount);
  const $destNetwork = useBridgeState(destNetwork);
  const $computingBalance = useBridgeState(computingBalance);
  const $errorComputingBalance = useBridgeState(errorComputingBalance);
  const $insufficientBalance = useBridgeState(insufficientBalance);
  const $insufficientAllowance = useBridgeState(insufficientAllowance);
  const $account = useBridgeState(account);
  const $connectedSourceChain = useBridgeState(connectedSourceChain);
  const $ethBalance = useEthBalanceStore();

  // Stable per-instance input id. The Svelte original used `crypto.randomUUID()`
  // at script init, which is fine for an SPA but produces DIFFERENT ids on the
  // server vs the client under SSR -> hydration mismatch. `useId()` is the
  // SSR-consistent React equivalent.
  const inputId = useId();

  const inputBoxRef = useRef<InputBoxHandle>(null);

  // Svelte `let value = ''` — drives the InputBox `bind:value`.
  const [value, setValue] = useState("");

  // Svelte `let balance = '0.00'` only assigned when no account/token. The
  // "no balance available" state is otherwise derived (see `balance` below).
  const [noAccountBalance, setNoAccountBalance] = useState<string | null>(null);

  // Track previous selected token to mirror `$: if ($selectedToken !== previousSelectedToken)`.
  const previousSelectedTokenRef = useRef(selectedToken.getState());

  // --- Derived reactive values (Svelte `$:`) -----------------------------

  // $: disabled = !$account || !$account.isConnected;
  const disabled = !$account || !$account.isConnected;

  // $: validAmount = $enteredAmount > BigInt(0);
  const validAmount = $enteredAmount > BigInt(0);

  // $: skipValidate = ...
  const skipValidate =
    !$connectedSourceChain ||
    !$destNetwork ||
    !$tokenBalance ||
    !$selectedToken ||
    !(
      $ethBalance !== null &&
      $ethBalance !== undefined &&
      $ethBalance > BigInt(0)
    ) ||
    !validAmount;

  // $: { invalidInput = ... }
  const invalidInput =
    $enteredAmount !== 0n
      ? $errorComputingBalance || $insufficientBalance || $insufficientAllowance
      : false;

  // $: showInsufficientBalanceAlert = ...
  const showInsufficientBalanceAlert =
    $insufficientBalance && !$errorComputingBalance && !$computingBalance;

  // $: showInvalidTokenAlert = ...
  const showInvalidTokenAlert = $errorComputingBalance && !$computingBalance;

  // $: validInput = ...
  const validInput =
    $enteredAmount > 0n &&
    $tokenBalance !== null &&
    $tokenBalance !== undefined &&
    $enteredAmount <= $tokenBalance.value;

  // $: displayFeeMsg = ...
  const displayFeeMsg = !showInsufficientBalanceAlert && !showInvalidTokenAlert;

  // $: { balance = ... } — derived rendered balance string. The reactive block
  // in the source always recomputes from the live state, so we derive it during
  // render. When the primary condition is unmet, the fallback is N/A — except
  // after reset() ran with no connected account/token, where the source set
  // `balance = '0.00'` (captured here as `noAccountBalance`).
  const balance =
    $tokenBalance &&
    $account?.isConnected &&
    !$errorComputingBalance &&
    !$computingBalance
      ? renderBalance($tokenBalance)
      : (noAccountBalance ?? t("common.not_available_short"));

  // --- validation / reset logic (closures over current state) ------------

  async function validateAmount(token = selectedToken.getState()) {
    // During validation, we disable all the actions
    const user = account.getState()?.address;
    if (!connectedSourceChain.getState()?.id || !user) return;
    validatingAmount.setState(true);
    insufficientBalance.setState(false);
    insufficientAllowance.setState(false);
    computingBalance.setState(true);

    // Recompute skipValidate against the latest store state (Svelte read $-stores).
    const localSkipValidate =
      !connectedSourceChain.getState() ||
      !destNetwork.getState() ||
      !tokenBalance.getState() ||
      !selectedToken.getState() ||
      !(() => {
        const eb = ethBalance.getState();
        return eb !== null && eb !== undefined && eb > BigInt(0);
      })() ||
      !(enteredAmount.getState() > BigInt(0));

    if (localSkipValidate) {
      log("skipped validation");
      validatingAmount.setState(false);
      computingBalance.setState(false);
      return;
    }

    const to = recipientAddress.getState() || account.getState()?.address;

    if (!to || !token) {
      validatingAmount.setState(false);
      computingBalance.setState(false);
      return;
    }

    validatingAmount.setState(false);
    computingBalance.setState(false);
  }

  // Stable debounced validate (Svelte module-scope `debounce(validateAmount, 300)`).
  const debouncedValidateAmountRef = useRef(debounce(validateAmount, 300));

  const handleAmountInputChange = (nextValue: string) => {
    const token = selectedToken.getState();
    if (!isToken(token)) return;
    validatingAmount.setState(true);
    errorComputingBalance.setState(false);

    enteredAmount.setState(parseUnits(nextValue, token.decimals));
    debouncedValidateAmountRef.current();
  };

  const useMaxAmount = async () => {
    log("useMaxAmount");

    const token = selectedToken.getState();
    const srcChain = connectedSourceChain.getState();
    const dest = destNetwork.getState();
    const tb = tokenBalance.getState();
    const acct = account.getState();

    if (!isToken(token) || !srcChain || !dest || !tb || !acct?.address) return;

    try {
      let maxAmount;
      if (tb) {
        maxAmount = await getMaxAmountToBridge({
          to: acct.address,
          token,
          balance: tb.value,
          srcChainId: srcChain.id,
          destChainId: dest.id,
          fee: processingFee.getState(),
        });

        // Update state
        enteredAmount.setState(maxAmount);
        let nextValue = formatUnits(maxAmount, token.decimals);
        nextValue = truncateDecimal(parseFloat(nextValue), 12).toString();
        setValue(nextValue);
        inputBoxRef.current?.setValue(nextValue);
        validateAmount();
      }
    } catch (err) {
      log("Error getting max amount: ", err);
    }
  };

  const reset = async () => {
    log("reset");
    computingBalance.setState(true);
    setValue("");
    inputBoxRef.current?.clear();
    enteredAmount.setState(0n);
    const acct = account.getState();
    const token = selectedToken.getState();
    if (acct && acct.address && acct.isConnected && token) {
      validateAmount(token);
      refreshUserBalance();
      log("fetching on chain", connectedSourceChain.getState()?.name);
      const newBalance = await fetchBalance({
        userAddress: acct.address,
        token,
        srcChainId: connectedSourceChain.getState()?.id,
      });
      tokenBalance.setState(newBalance);
      log("tokenBalance", newBalance);
      previousSelectedTokenRef.current = token;
      setNoAccountBalance(null);
    } else {
      setNoAccountBalance("0.00");
    }
    computingBalance.setState(false);
  };

  // $: if ($selectedToken !== previousSelectedToken) { reset(); }
  useEffect(() => {
    if ($selectedToken !== previousSelectedTokenRef.current) {
      log("selectedToken changed, resetting value", enteredAmount.getState());
      reset();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [$selectedToken]);

  // $: validInput = ... ; report write-back of bound `validInput`.
  useEffect(() => {
    onValidInputChange?.(validInput);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [validInput]);

  // onMount(async () => { $enteredAmount = 0n; ... })
  useEffect(() => {
    enteredAmount.setState(0n);
    const user = account.getState()?.address;
    const token = selectedToken.getState();
    if (!user || !token) return;
  }, []);

  const onAccountChange = async (
    newAccount?: Account,
    oldAccount?: Account,
  ) => {
    log("onAccountChange", newAccount, oldAccount);
    const token = selectedToken.getState();
    if (
      newAccount?.isConnected &&
      newAccount.address &&
      newAccount.address !== oldAccount?.address
    ) {
      log("resetting input");
      reset();
    } else if (newAccount?.address && newAccount?.isConnected && token) {
      log("refreshing user balance", connectedSourceChain.getState()?.name);
      const newBalance = await fetchBalance({
        userAddress: newAccount.address,
        token,
        srcChainId: newAccount.chainId,
      });
      tokenBalance.setState(newBalance);
    } else {
      console.error("No account connected or token selected");
    }
  };

  // `skipValidate` is recomputed against the live store state inside
  // `validateAmount`; the render-scope derivation above is kept only to mirror
  // the source's reactive declaration order.
  void skipValidate;

  return (
    <>
      <div className="TokenInput space-y-[8px]">
        <div className="f-between-center text-sm">
          <span className="text-tertiary-content">
            {t("inputs.amount.label")}
          </span>
          <span className="text-secondary-content">
            {t("common.balance")}:{" "}
            {$errorComputingBalance && !$computingBalance ? (
              t("common.not_available_short")
            ) : $computingBalance ? (
              <LoadingText mask="0.0000" />
            ) : (
              balance
            )}
          </span>
        </div>
        <div className="relative f-row h-[64px]">
          <div className="relative f-items-center w-full">
            {/* Amount Input */}
            <InputBox
              ref={inputBoxRef}
              id={inputId}
              type="number"
              placeholder="0.01"
              min="0"
              disabled={disabled || $errorComputingBalance || $computingBalance}
              error={invalidInput}
              value={value}
              onValueChange={setValue}
              onInput={() => handleAmountInputChange(value)}
              className={`min-h-[64px] pl-[15px] w-full border-0 h-full !rounded-r-none z-20  ${className ?? ""}`}
            />

            {/* vertical separator */}
            <div className="border-l border-r bg-primary-border-dark border-neutral-background h-[64px] w-[3px]" />

            {/* Max Button */}
            <button
              disabled={disabled || $errorComputingBalance || $computingBalance}
              className={cn(
                styles.maxButton,
                "max-button absolute right-6 uppercase hover:font-bold text-tertiary-content z-20",
              )}
              onClick={useMaxAmount}
            >
              {t("inputs.amount.button.max")}
            </button>
          </div>

          {/* Token Dropdown */}
          <TokenDropdown
            combined
            className="min-w-[151px] z-20"
            tokens={tokens}
            value={$selectedToken}
            onValueChange={(token) => selectedToken.setState(token)}
            disabled={disabled}
          />
        </div>

        <div className="flex mt-[8px] min-h-[24px]">
          {displayFeeMsg ? (
            <div className="f-row items-center gap-1">
              <Icon
                type="info-circle"
                size={15}
                fillClass="fill-tertiary-content"
              />
              <span className="text-sm text-tertiary-content">
                {t("recipient.label")}{" "}
                <ProcessingFee
                  textOnly
                  className="text-tertiary-content"
                  hasEnoughEth={hasEnoughEth}
                  onHasEnoughEthChange={onHasEnoughEthChange}
                />
              </span>
            </div>
          ) : showInsufficientBalanceAlert ? (
            <FlatAlert
              type="error"
              message={t("bridge.errors.insufficient_balance.title")}
              className="relative"
            />
          ) : showInvalidTokenAlert ? (
            <FlatAlert
              type="error"
              message={t("bridge.errors.custom_token.not_found.message")}
              className="relative"
            />
          ) : (
            <LoadingText mask="" className="w-1/2" />
          )}
        </div>
      </div>

      <OnAccount change={onAccountChange} />
    </>
  );
}
