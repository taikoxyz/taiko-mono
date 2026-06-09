"use client";

import type { ButtonHTMLAttributes, ReactNode } from "react";
import { useEffect } from "react";

import { Spinner } from "@/components/Spinner";
import { classNames } from "@/libs/util/classNames";

import { ButtonState } from "./states";
import type { ActionButtonType } from "./types";

export interface ActionButtonProps
  extends ButtonHTMLAttributes<HTMLButtonElement> {
  loading?: boolean;
  priority: ActionButtonType;
  /** Controlled `state` (Svelte `bind:state`). Pair with `onStateChange` for two-way sync. */
  state?: ButtonState;
  onStateChange?: (state: ButtonState) => void;
  onPopup?: boolean;
  children?: ReactNode;
}

export default function ActionButton({
  loading = false,
  priority,
  state = ButtonState.DEFAULT,
  onStateChange,
  onPopup = false,
  className,
  children,
  disabled,
  ...restProps
}: ActionButtonProps) {
  // $: if (loading) { state = ButtonState.LOADING } else { state = ButtonState.DEFAULT }
  // Mirrors Svelte `bind:state`: report the derived state to the parent only when it changes.
  const nextState = loading ? ButtonState.LOADING : ButtonState.DEFAULT;
  useEffect(() => {
    if (state !== nextState) {
      onStateChange?.(nextState);
    }
  }, [state, nextState, onStateChange]);

  const disabledColor =
    onPopup && disabled ? "!bg-dialog-interactive-disabled" : "";

  const commonClasses = classNames(
    "btn size-[56px] px-[28px] py-[14px] rounded-full flex-1 w-full items-center",
    disabled ? "cursor-not-allowed" : "cursor-pointer",
    disabledColor,
    className,
  );

  const primaryClasses = classNames("btn-primary text-white border-none");

  const secondaryClasses = classNames(
    disabled
      ? "border-none"
      : "border-primary-brand dark:text-white hover:bg-primary-interactive-hover btn-secondary bg-transparent light:text-black",
  );

  const priorityToClassMap = {
    primary: primaryClasses,
    secondary: secondaryClasses,
  };

  const classes = classNames(
    commonClasses,
    priorityToClassMap[priority],
    className,
  );

  return (
    <button {...restProps} disabled={disabled} className={classes}>
      {loading ? <Spinner /> : null}

      {children}
    </button>
  );
}
