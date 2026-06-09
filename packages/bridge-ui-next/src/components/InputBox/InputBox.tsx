"use client";

import {
  forwardRef,
  useEffect,
  useImperativeHandle,
  useRef,
  type ComponentPropsWithoutRef,
  type FocusEvent as ReactFocusEvent,
  type FormEvent,
} from "react";

import { cn } from "@/lib/utils";

/**
 * Imperative handle mirroring the original Svelte component's public API
 * (`export const setValue/getValue/clear/focus`). Callers grab these via a ref
 * (Svelte `bind:this`). These mutate the underlying input element directly,
 * exactly like the source.
 */
export interface InputBoxHandle {
  setValue: (value: string) => void;
  getValue: () => string;
  clear: () => void;
  focus: () => void;
}

export interface InputBoxProps
  // Spread of remaining native input attributes ($$restProps in Svelte).
  // We override value/onInput/onBlur/className with our own typed props below.
  extends Omit<
    ComponentPropsWithoutRef<"input">,
    "value" | "onInput" | "onBlur" | "className"
  > {
  /** Toggles the `.error` validation ring (Svelte `class:error`). */
  error?: boolean;
  /**
   * Two-way bound value (Svelte `bind:value`). The input is uncontrolled (kept
   * in the DOM) so the imperative `setValue`/`clear` API still works; this prop
   * seeds the initial value and re-syncs the DOM when the parent changes it.
   */
  value?: string | number | number[];
  /** Two-way binding write-back (Svelte `bind:value`). */
  onValueChange?: (value: string) => void;
  /** Forwarded `on:input`. */
  onInput?: (event: FormEvent<HTMLInputElement>) => void;
  /** Forwarded `on:blur`. */
  onBlur?: (event: ReactFocusEvent<HTMLInputElement>) => void;
  /** Maps Svelte's `$$props.class`. */
  className?: string;
}

const toStringValue = (value: string | number | number[]): string => {
  if (Array.isArray(value)) return value.join(",");
  return String(value);
};

const InputBox = forwardRef<InputBoxHandle, InputBoxProps>(function InputBox(
  {
    error = false,
    value = "",
    onValueChange,
    onInput,
    onBlur,
    disabled = false,
    className,
    ...restProps
  },
  ref,
) {
  const inputRef = useRef<HTMLInputElement>(null);

  // Public API — identical to the Svelte `export const` methods, which mutated
  // the underlying input element directly (bypassing React's render cycle).
  useImperativeHandle(
    ref,
    () => ({
      setValue: (next: string) => {
        if (inputRef.current) inputRef.current.value = next;
      },
      getValue: () => inputRef.current?.value ?? "",
      clear: () => {
        if (inputRef.current) inputRef.current.value = "";
      },
      focus: () => inputRef.current?.focus(),
    }),
    [],
  );

  // Mirror Svelte `bind:value`: when the parent's bound variable changes from
  // the outside, push it into the (uncontrolled) DOM input. Skip writes that
  // already match so we never clobber the caret during typing.
  const stringValue = toStringValue(value);
  useEffect(() => {
    if (inputRef.current && inputRef.current.value !== stringValue) {
      inputRef.current.value = stringValue;
    }
  }, [stringValue]);

  const classes = cn(
    "w-full input-box bg-neutral-background placeholder:text-tertiary-content font-bold",
    disabled ? "cursor-not-allowed " : "cursor-pointer",
    className,
    error && "error",
  );

  const handleInput = (event: FormEvent<HTMLInputElement>) => {
    // Write-back for `bind:value`.
    onValueChange?.(event.currentTarget.value);
    // Forwarded `on:input`.
    onInput?.(event);
  };

  return (
    <input
      ref={inputRef}
      defaultValue={stringValue}
      onInput={handleInput}
      onBlur={onBlur}
      disabled={disabled}
      className={classes}
      {...restProps}
    />
  );
});

export default InputBox;
