"use client";

import {
  forwardRef,
  useEffect,
  useImperativeHandle,
  useMemo,
  useRef,
  type FormEvent,
} from "react";

import { Icon } from "@/components/Icon";
import InputBox from "@/components/InputBox/InputBox";
import { useTranslation } from "@/i18n/useTranslation";

import { IDInputState as State } from "./state";

/**
 * Imperative handle mirroring the original Svelte `export const clearIds`,
 * grabbed by the parent via `bind:this`.
 */
export interface IDInputHandle {
  clearIds: () => void;
}

export interface IDInputProps {
  /** Two-way bound `validIdNumbers` (Svelte `bind:validIdNumbers`). */
  validIdNumbers?: number[];
  onValidIdNumbersChange?: (value: number[]) => void;
  isDisabled?: boolean;
  /** Two-way bound `enteredIds` (Svelte `bind:enteredIds`). */
  enteredIds?: number[];
  onEnteredIdsChange?: (value: number[]) => void;
  limit?: number;
  /** Two-way bound `state` (Svelte `bind:state`). */
  state?: State;
  onStateChange?: (value: State) => void;
  /** Svelte `dispatch('inputValidation')` -> callback prop. */
  onInputValidation?: () => void;
  /** Maps Svelte's `$$props.class`. */
  className?: string;
}

const IDInput = forwardRef<IDInputHandle, IDInputProps>(function IDInput(
  {
    // `validIdNumbers` is accepted for API parity (Svelte `bind:validIdNumbers`)
    // but is write-only here — the body only emits via `onValidIdNumbersChange`,
    // mirroring the source which never reads it internally.
    onValidIdNumbersChange,
    isDisabled = false,
    enteredIds = [],
    onEnteredIdsChange,
    limit = 1,
    state = State.DEFAULT,
    onStateChange,
    onInputValidation,
    className,
  },
  ref,
) {
  const { t } = useTranslation();

  // `let inputId = `input-${crypto.randomUUID()}`` — stable for the component's lifetime.
  const inputId = useMemo(() => `input-${crypto.randomUUID()}`, []);

  // Keep latest callbacks in refs so the unmount cleanup (onDestroy -> clearIds)
  // can stay stable without re-running.
  const callbacksRef = useRef({
    onValidIdNumbersChange,
    onEnteredIdsChange,
    onInputValidation,
  });
  callbacksRef.current = {
    onValidIdNumbersChange,
    onEnteredIdsChange,
    onInputValidation,
  };

  // Public API — mirrors the Svelte `export const clearIds`.
  const clearIds = () => {
    callbacksRef.current.onEnteredIdsChange?.([]);
    callbacksRef.current.onValidIdNumbersChange?.([]);
    callbacksRef.current.onInputValidation?.();
  };

  useImperativeHandle(ref, () => ({ clearIds }), []);

  function validateInput(idInput: EventTarget | number[] | null = null) {
    onStateChange?.(State.VALIDATING);

    let ids: number[] = [];
    if (idInput && idInput instanceof EventTarget) {
      ids = (idInput as HTMLInputElement).value
        .split(",")
        .map((item) => parseInt(item))
        .filter((num) => !isNaN(num));
    } else if (Array.isArray(idInput)) {
      ids = idInput;
    }

    if (ids.length > limit) {
      ids = ids.slice(0, limit);
    }
    onEnteredIdsChange?.(ids);
    const isValid = ids.every((num) => Number.isInteger(num));
    onValidIdNumbersChange?.(isValid ? ids : []);
    onStateChange?.(isValid ? State.VALID : State.INVALID);
    onInputValidation?.();
  }

  // onDestroy(() => clearIds());
  useEffect(() => {
    return () => clearIds();
  }, []);

  // $: typeClass = state === State.INVALID ? 'error' : '';
  const typeClass = state === State.INVALID ? "error" : "";

  const handleInput = (e: FormEvent<HTMLInputElement>) =>
    validateInput(e.currentTarget);

  return (
    <div className="f-col space-y-2">
      <div className="f-between-center text-secondary-content">
        <label className="body-regular" htmlFor={inputId}>
          {t("inputs.token_id_input.label")}
        </label>
      </div>
      <div className="relative f-items-center">
        <InputBox
          id={inputId}
          type="number"
          placeholder={t("inputs.token_id_input.placeholder")}
          disabled={isDisabled}
          value={enteredIds}
          onInput={handleInput}
          className={`withValidation w-full input-box py-6 pr-16 px-[26px] ${typeClass} ${className ?? ""}`}
        />
        {enteredIds && enteredIds.length > 0 && (
          <button
            type="button"
            className="absolute right-6 uppercase body-bold text-secondary-content"
            onClick={clearIds}
          >
            <Icon
              type="x-close-circle"
              fillClass="fill-primary-icon"
              size={24}
            />
          </button>
        )}
      </div>
    </div>
  );
});

export default IDInput;
