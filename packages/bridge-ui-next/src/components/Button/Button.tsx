"use client";

import type { ButtonHTMLAttributes, ReactNode } from "react";
import { useMemo } from "react";

import { Spinner } from "@/components/Spinner";
import { classNames } from "@/libs/util/classNames";

type ButtonType =
  | "neutral"
  | "primary"
  | "secondary"
  | "accent"
  | "info"
  | "success"
  | "warning"
  | "error"
  | "ghost"
  | "link";
type ButtonShape = "circle" | "square";

export interface ButtonProps
  extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, "type"> {
  // `type` is the daisyUI color variant here (mirrors the Svelte `export let type`),
  // not the native button `type` attribute, hence the Omit above.
  type?: Maybe<ButtonType>;
  shape?: Maybe<ButtonShape>;
  loading?: boolean;
  outline?: boolean;
  block?: boolean;
  wide?: boolean;
  hasBorder?: boolean;
  children?: ReactNode;
}

// Remember, with Tailwind's classes you cannot use string interpolation: `btn-${type}`.
// The whole class name must appear in the code in order for Tailwind compiler to know
// it must be included during build-time.
// https://tailwindcss.com/docs/content-configuration#dynamic-class-names
const typeMap: Record<ButtonType, string> = {
  neutral: "btn-neutral",
  primary: "btn-primary",
  secondary: "btn-secondary",
  accent: "btn-accent",
  info: "btn-info",
  success: "btn-success",
  warning: "btn-warning",
  error: "btn-error",
  ghost: "btn-ghost",
  link: "btn-link",
};

const shapeMap: Record<ButtonShape, string> = {
  circle: "btn-circle",
  square: "btn-square",
};

export default function Button({
  type = null,
  shape = null,
  loading = false,
  outline = false,
  block = false,
  wide = false,
  hasBorder = false,
  className,
  children,
  disabled,
  ...restProps
}: ButtonProps) {
  const borderClasses = hasBorder
    ? "border-1 border-primary-border"
    : "border-0";

  // Make sure to disable the button if we're in loading state
  const isDisabled = disabled || loading;

  const classes = useMemo(
    () =>
      classNames(
        "btn h-auto min-h-fit ",

        type === "primary" ? "body-bold" : "body-regular",

        type ? typeMap[type] : null,
        shape ? shapeMap[shape] : null,

        outline ? "btn-outline" : null,
        block ? "btn-block" : null,
        wide ? "btn-wide" : null,

        // For loading state we want to see well the content,
        // since we're showing some important information.
        loading ? "btn-disabled !text-primary-content" : null,

        isDisabled ? borderClasses : "",

        className,
      ),
    [
      type,
      shape,
      outline,
      block,
      wide,
      loading,
      isDisabled,
      borderClasses,
      className,
    ],
  );

  return (
    <button {...restProps} disabled={isDisabled} className={classes}>
      {loading ? <Spinner /> : null}

      {children}
    </button>
  );
}
