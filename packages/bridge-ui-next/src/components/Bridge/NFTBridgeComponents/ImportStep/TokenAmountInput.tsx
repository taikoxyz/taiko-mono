"use client";

import type { GetBalanceReturnType } from "@wagmi/core";
import {
  forwardRef,
  useEffect,
  useId,
  useImperativeHandle,
  useMemo,
  useRef,
  useState,
  type FormEvent,
} from "react";

import { FlatAlert } from "@/components/Alert";
import InputBox, { type InputBoxHandle } from "@/components/InputBox/InputBox";
import { LoadingText } from "@/components/LoadingText";
import { warningToast } from "@/components/NotificationToast";
import { useTranslation } from "@/i18n/useTranslation";
import {
  InvalidParametersProvidedError,
  UnknownTokenTypeError,
} from "@/libs/error";
import {
  ETHToken,
  fetchBalance,
  fetchBalance as getTokenBalance,
  TokenType,
} from "@/libs/token";
import type { Token } from "@/libs/token";
import { debounce } from "@/libs/util/debounce";
import { getLogger } from "@/libs/util/logger";
import { account } from "@/stores/account";
import { ethBalance } from "@/stores/balance";
import { connectedSourceChain } from "@/stores/network";

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
  useBridgeState,
  validatingAmount,
} from "../../state";

const log = getLogger("component:Amount");

/**
 * Imperative handle mirroring the original Svelte component's public API
 * (`export function clearAmount/validateAmount/updateBalance/determineBalance`),
 * grabbed by the parent via `bind:this`.
 */
export interface TokenAmountInputHandle {
  clearAmount: () => void;
  validateAmount: (token?: Maybe<Token>) => Promise<void>;
  updateBalance: (
    token?: Maybe<Token>,
    userAddress?: `0x${string}`,
    srcChainId?: number,
    destChainId?: number,
  ) => Promise<void>;
  determineBalance: () => Promise<void>;
}

export interface TokenAmountInputProps {
  disabled?: boolean;
  /** Maps Svelte's `$$props.class`. */
  className?: string;
}

const TokenAmountInput = forwardRef<
  TokenAmountInputHandle,
  TokenAmountInputProps
>(function TokenAmountInput({ disabled = false, className }, ref) {
  const { t } = useTranslation();

  // SSR-safe per-instance id (replaces Svelte `crypto.randomUUID()`).
  const inputId = `input-${useId()}`;
  const inputBoxRef = useRef<InputBoxHandle>(null);

  const [computingMaxAmount, setComputingMaxAmount] = useState(false);
  const [invalidInput, setInvalidInput] = useState(false);
  // `let value = ''` — the InputBox bind:value target. It only changes via the
  // reactive `inputBox.setValue(sanitizedValue)` sync below (never bound back).
  const value = "";
  const sanitizedValueRef = useRef("");

  // Reactive store reads (svelte `$store`).
  const $selectedToken = useBridgeState(selectedToken);
  const $tokenBalance = useBridgeState(tokenBalance);
  const $insufficientBalance = useBridgeState(insufficientBalance);
  const $errorComputingBalance = useBridgeState(errorComputingBalance);
  const $computingBalance = useBridgeState(computingBalance);

  // Public API — identical bodies to the Svelte `export function`s.
  function clearAmount() {
    inputBoxRef.current?.clear();
    enteredAmount.setState(BigInt(0));
  }

  async function validateAmount(
    token: Maybe<Token> = selectedToken.getState() as Maybe<Token>,
  ) {
    if (!connectedSourceChain.getState()?.id) return;
    validatingAmount.setState(true); // During validation, we disable all the actions
    insufficientBalance.setState(false);
    insufficientAllowance.setState(false);

    const to = recipientAddress.getState() || account.getState()?.address;

    const balanceForGasCalculation = ethBalance.getState();

    // We need all these guys to validate
    if (
      !to ||
      !token ||
      !connectedSourceChain.getState() ||
      !destNetwork.getState() ||
      !tokenBalance.getState() ||
      !selectedToken.getState() ||
      !(balanceForGasCalculation && balanceForGasCalculation > BigInt(0)) ||
      enteredAmount.getState() === BigInt(0) // no need to check if the amount is 0
    ) {
      validatingAmount.setState(false);
      return;
    }

    insufficientBalance.setState(
      (tokenBalance.getState() as GetBalanceReturnType).value <
        enteredAmount.getState(),
    );
    validatingAmount.setState(false);
  }

  async function updateBalance(
    token: Maybe<Token> = selectedToken.getState() as Maybe<Token>,
    userAddress = account.getState()?.address,
    srcChainId = connectedSourceChain.getState()?.id,
    destChainId = destNetwork.getState()?.id,
  ) {
    if (!token || !srcChainId || !userAddress) return;
    computingBalance.setState(true);

    try {
      if (token.type === TokenType.ETH) {
        tokenBalance.setState(
          await getTokenBalance({
            token: ETHToken,
            srcChainId,
            destChainId,
            userAddress,
          }),
        );
      } else {
        tokenBalance.setState(
          await getTokenBalance({
            token,
            srcChainId,
            destChainId,
            userAddress,
          }),
        );
      }
    } catch (err) {
      log("Error updating balance: ", err);
      clearAmount();
    } finally {
      computingBalance.setState(false);
    }
  }

  // We want to debounce this function for input events.
  // Could happen as the user enters an amount
  const debouncedValidateAmount = useMemo(
    () => debounce(validateAmount, 300),
    [],
  );

  function inputAmount(event: FormEvent<HTMLInputElement>) {
    setInvalidInput(false);
    validatingAmount.setState(true); // During validation, we disable all the actions
    const token = selectedToken.getState();
    if (!token) return;
    const target = event.currentTarget;
    const inputValue = target.value;

    if (token.type === TokenType.ERC1155) {
      // For ERC1155, no decimals are allowed
      if (/[.,]/.test(inputValue)) {
        setInvalidInput(true);
        return;
      }
    } else {
      validatingAmount.setState(false);
      throw new UnknownTokenTypeError(token.type);
    }

    sanitizedValueRef.current = inputValue;

    enteredAmount.setState(BigInt(sanitizedValueRef.current));
    validatingAmount.setState(false);

    debouncedValidateAmount();
  }

  // "MAX" button handler
  async function useMaxAmount() {
    const token = selectedToken.getState();
    // We cannot calculate the max amount without these guys
    if (
      !token ||
      !connectedSourceChain.getState() ||
      !destNetwork.getState() ||
      !tokenBalance.getState() ||
      !account.getState()?.address
    )
      return;
    setInvalidInput(false);
    setComputingMaxAmount(true);

    try {
      if (token.type === TokenType.ERC721 || token.type === TokenType.ERC1155) {
        const balance = (tokenBalance.getState() as GetBalanceReturnType).value;
        inputBoxRef.current?.setValue(balance.toString());
        enteredAmount.setState(balance);
        validateAmount();
      } else {
        throw new InvalidParametersProvidedError(
          "token type not supported for this component",
        );
      }
    } catch (err) {
      console.error(err);
      warningToast({ title: t("amount.errors.failed_max") });
    } finally {
      setComputingMaxAmount(false);
    }
  }

  async function determineBalance() {
    const userAddress = account.getState()?.address;
    const token = selectedToken.getState();
    if (!userAddress || !token) return;
    tokenBalance.setState(
      await fetchBalance({
        userAddress,
        token,
        srcChainId: connectedSourceChain.getState()?.id,
        destChainId: destNetwork.getState()?.id,
      }),
    );
  }

  useImperativeHandle(
    ref,
    () => ({ clearAmount, validateAmount, updateBalance, determineBalance }),
    [],
  );

  // $: if (inputBox && sanitizedValue !== value) inputBox.setValue(sanitizedValue)
  useEffect(() => {
    if (inputBoxRef.current && sanitizedValueRef.current !== value) {
      inputBoxRef.current.setValue(sanitizedValueRef.current);
    }
  });

  // $: hasBalance = $tokenBalance && $tokenBalance?.value > 0n;
  const hasBalance = Boolean($tokenBalance && $tokenBalance.value > 0n);

  // There is no reason to show any error/warning message if we are computing the balance
  // or there is an issue computing it
  const showInsufficientBalanceAlert =
    $insufficientBalance && !$errorComputingBalance && !$computingBalance;

  const noDecimalsAllowedAlert = invalidInput;

  const inputDisabled =
    computingMaxAmount ||
    disabled ||
    !$selectedToken ||
    !connectedSourceChain.getState() ||
    $errorComputingBalance ||
    !hasBalance;

  const maxButtonEnabled = hasBalance && !disabled && !$errorComputingBalance;

  // onMount
  useEffect(() => {
    enteredAmount.setState(BigInt(0));
    determineBalance();
    insufficientBalance.setState(false);
  }, []);

  return (
    <div className={`Amount f-col space-y-2 ${className ?? ""}`}>
      <div className="f-between-center text-secondary-content">
        <label className="body-regular" htmlFor={inputId}>
          {t("inputs.amount.label")}
        </label>
        <div className="body-small-regular">
          {$errorComputingBalance ? (
            <FlatAlert
              type="error"
              message={t("bridge.errors.cannot_fetch_balance")}
            />
          ) : (
            <>
              <span>{t("inputs.amount.balance")}:</span>
              <span>
                {computingMaxAmount ? (
                  <LoadingText mask={$tokenBalance?.toString() || "100"} />
                ) : null}
                {/* {renderBalance($tokenBalance)} */}
              </span>
            </>
          )}
        </div>
      </div>
      <div className="relative">
        <div className="relative f-items-center">
          <InputBox
            id={inputId}
            type="number"
            placeholder="42"
            min="0"
            disabled={inputDisabled}
            error={$insufficientBalance || invalidInput}
            value={value}
            onInput={inputAmount}
            ref={inputBoxRef}
            className={`py-6 pr-16 px-[26px] title-subsection-bold border-0  ${className ?? ""}`}
          />
          {maxButtonEnabled && (
            <button
              type="button"
              className="absolute right-6 uppercase hover:font-bold"
              onClick={useMaxAmount}
            >
              {t("inputs.amount.button.max")}
            </button>
          )}
        </div>
        <div className="flex mt-[8px] min-h-[24px]">
          {showInsufficientBalanceAlert ? (
            <FlatAlert
              type="error"
              message={t("bridge.errors.insufficient_balance.title")}
              className="relative "
            />
          ) : noDecimalsAllowedAlert ? (
            <FlatAlert
              type="error"
              message={t("bridge.errors.no_decimals_allowed")}
              className="relative"
            />
          ) : null}
        </div>
      </div>
    </div>
  );
});

export default TokenAmountInput;
