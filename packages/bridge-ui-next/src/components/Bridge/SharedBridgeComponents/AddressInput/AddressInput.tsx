"use client";

import { isAddress } from "ethereum-address";
import {
  forwardRef,
  useEffect,
  useId,
  useImperativeHandle,
  useRef,
  useState,
  type ChangeEvent,
} from "react";
import type { Address } from "viem";

import { FlatAlert } from "@/components/Alert";
import { Icon } from "@/components/Icon";
import { useHoverAndFocusListener } from "@/libs/customActions";
import { classNames } from "@/libs/util/classNames";
import { account } from "@/stores/account";
import { useTranslation } from "@/i18n/useTranslation";

import { AddressInputState as State } from "./state";

/**
 * Imperative public API mirroring the original Svelte component's
 * `export const validateAddress / clearAddress / focus`, grabbed by callers via
 * `bind:this`. In React these are exposed through `forwardRef` +
 * `useImperativeHandle`.
 */
export interface AddressInputHandle {
  validateAddress: () => void;
  clearAddress: () => void;
  focus: () => void;
}

export interface AddressInputProps {
  /** Two-way bound value (Svelte `bind:value={ethereumAddress}`). */
  ethereumAddress?: Address | string;
  /** Write-back for the two-way `ethereumAddress` binding. */
  onEthereumAddressChange?: (value: Address | string) => void;
  /** `bind:state` controlled value. */
  state?: State;
  /** Write-back for the two-way `state` binding. */
  onStateChange?: (state: State) => void;

  labelText?: string;
  isDisabled?: boolean;
  quiet?: boolean;
  resettable?: boolean;
  onDialog?: boolean;

  /** `dispatch('input', ethereumAddress)`. */
  onInput?: (address: Address | string) => void;
  /** `dispatch('addressvalidation', { isValidEthereumAddress, addr })`. */
  onAddressValidation?: (detail: {
    isValidEthereumAddress: boolean;
    addr: Address | string;
  }) => void;
  /** `dispatch('clearInput')` — present for API parity (never fired, matching source). */
  onClearInput?: () => void;

  /** Maps Svelte's `$$props.class`. */
  className?: string;
}

const AddressInput = forwardRef<AddressInputHandle, AddressInputProps>(
  function AddressInput(
    {
      ethereumAddress = "",
      onEthereumAddressChange,
      state = State.DEFAULT,
      onStateChange,
      labelText,
      isDisabled = false,
      quiet = false,
      resettable = false,
      onDialog = false,
      onInput,
      onAddressValidation,
      className,
    },
    ref,
  ) {
    const { t } = useTranslation();

    const inputRef = useRef<HTMLInputElement>(null);
    const inputId = `input-${useId()}`;

    const [isElementFocused, setIsElementFocused] = useState(false);
    const [isElementHovered, setIsElementHovered] = useState(false);

    // Keep the latest props in refs so the imperative handle (created once) always
    // sees current values, matching the Svelte component reading reactive locals.
    const ethereumAddressRef = useRef(ethereumAddress);
    ethereumAddressRef.current = ethereumAddress;
    const onEthereumAddressChangeRef = useRef(onEthereumAddressChange);
    onEthereumAddressChangeRef.current = onEthereumAddressChange;
    const onStateChangeRef = useRef(onStateChange);
    onStateChangeRef.current = onStateChange;
    const onInputRef = useRef(onInput);
    onInputRef.current = onInput;
    const onAddressValidationRef = useRef(onAddressValidation);
    onAddressValidationRef.current = onAddressValidation;

    const setState = (next: State) => {
      onStateChangeRef.current?.(next);
    };

    const setAddress = (next: Address | string) => {
      onEthereumAddressChangeRef.current?.(next);
    };

    useHoverAndFocusListener(inputRef, {
      onFocusChange: setIsElementFocused,
      onHoverChange: setIsElementHovered,
    });

    // Validate the Ethereum address — operates on the current `ethereumAddress`.
    const validateAddress = (
      address: Address | string = ethereumAddressRef.current,
    ): void => {
      if (!address) {
        setState(State.DEFAULT);
        return;
      }

      if (address.length >= 2 && !address.startsWith("0x")) {
        setState(State.INVALID);
        return;
      }

      const nextState =
        address.length < 42
          ? State.TOO_SHORT
          : isAddress(address)
            ? State.VALID
            : State.INVALID;
      setState(nextState);

      onInputRef.current?.(address);
      onAddressValidationRef.current?.({
        isValidEthereumAddress: nextState === State.VALID,
        addr: address,
      });
    };

    // Clear the input field.
    const clearAddress = (): void => {
      if (inputRef.current) inputRef.current.value = "";
      setAddress("");
      setState(State.DEFAULT);
    };

    const setToCurrentAddress = (): void => {
      clearAddress();
      const next = account.getState()?.address || "";
      setAddress(next);
      validateAddress(next);
    };

    useImperativeHandle(
      ref,
      () => ({
        validateAddress: () => validateAddress(),
        clearAddress,
        focus: () => inputRef.current?.focus(),
      }),
      // eslint-disable-next-line react-hooks/exhaustive-deps
      [],
    );

    // onDestroy(() => clearAddress())
    useEffect(() => {
      return () => {
        clearAddress();
      };
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    const handleInput = (event: ChangeEvent<HTMLInputElement>) => {
      const next = event.currentTarget.value;
      setAddress(next);
      validateAddress(next);
    };

    // $: defaultBorder
    const defaultBorder = (() => {
      if (!onDialog || isElementFocused || isElementHovered) return "";
      return "neutral";
    })();

    const isWrongType = state === State.NOT_ERC20 || state === State.NOT_NFT;
    const validState = state === State.VALID;
    const invalidState = state === State.INVALID || isWrongType;

    const borderState = validState
      ? "success"
      : invalidState
        ? "error"
        : defaultBorder;

    const classes = classNames(className, borderState);

    const resolvedLabel = labelText ?? t("inputs.address_input.label.default");

    return (
      <div className="f-col space-y-2">
        {/* Input field and label */}
        <div className="f-between-center text-secondary-content">
          <label className="body-regular" htmlFor={inputId}>
            {resolvedLabel}
          </label>
          {resettable && (
            <button className="link" onClick={setToCurrentAddress}>
              {t("common.reset_to_wallet")}
            </button>
          )}
        </div>
        <div className="relative f-items-center">
          <input
            ref={inputRef}
            id={inputId}
            disabled={isDisabled}
            type="string"
            placeholder="0x1B77..."
            value={ethereumAddress}
            onChange={handleInput}
            className={`w-full input-box withValidation py-6 pr-16 px-[26px] font-bold placeholder:text-tertiary-content ${classes}  !border-primary-border-dark`}
          />
          {ethereumAddress && (
            <button
              className="absolute right-6 uppercase body-bold text-secondary-content"
              onClick={clearAddress}
            >
              <Icon
                type="x-close-circle"
                fillClass="fill-primary-icon"
                size={24}
              />
            </button>
          )}
        </div>

        {/* Conditional alerts */}
        {!quiet && (
          <div className="pt-[8px]">
            {state === State.INVALID && ethereumAddress ? (
              <FlatAlert
                type="error"
                message={t("inputs.address_input.errors.invalid")}
              />
            ) : state === State.TOO_SHORT && ethereumAddress ? (
              <FlatAlert
                type="warning"
                message={t("inputs.address_input.errors.too_short")}
              />
            ) : state === State.VALID ? (
              <FlatAlert
                type="success"
                message={t("inputs.address_input.success")}
              />
            ) : state === State.NOT_NFT ? (
              <FlatAlert
                type="error"
                message={t("inputs.address_input.errors.not_nft")}
              />
            ) : state === State.NOT_ERC20 ? (
              <FlatAlert
                type="error"
                message={t("inputs.address_input.errors.not_erc20")}
              />
            ) : null}
          </div>
        )}
      </div>
    );
  },
);

export default AddressInput;
