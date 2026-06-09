"use client";

import type { MouseEventHandler, ReactNode } from "react";

export interface StepBackProps {
  /** Forwarded click handler (Svelte forwarded `on:click` -> `onClick`). */
  onClick?: MouseEventHandler<HTMLButtonElement>;
  /** Default slot content. */
  children?: ReactNode;
}

/**
 * React port of `components/Stepper/StepBack.svelte`.
 *
 * The source simply forwarded `on:click` on a `link`-styled button. DOM and
 * class string preserved verbatim for pixel parity.
 */
export default function StepBack({ onClick, children }: StepBackProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex justify-center link"
    >
      {children}
    </button>
  );
}
