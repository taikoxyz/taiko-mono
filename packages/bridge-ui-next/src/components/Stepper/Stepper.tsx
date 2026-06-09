"use client";

import type { ReactNode } from "react";

import { useMediaQuery } from "@/hooks/useResponsive";
import { cn } from "@/lib/utils";

/** Slot props the original `<slot {activeStep} />` exposed to its default slot. */
export interface StepperSlotProps {
  activeStep: number;
}

export interface StepperProps {
  /** Index of the active step, forwarded to the slot (Svelte `activeStep`). */
  activeStep?: number;
  /** Pass-through className merged onto the outer wrapper (Svelte `$$props.class`). */
  className?: string;
  /**
   * Default slot content. The original slot received `{ activeStep }`, so this
   * accepts either plain children or a render-prop `(slotProps) => ReactNode`
   * (mirroring `<slot let:activeStep>` usage in consumers).
   */
  children?: ReactNode | ((slotProps: StepperSlotProps) => ReactNode);
}

/**
 * Base class string copied verbatim from the original Stepper.svelte for pixel
 * parity.
 *
 * NOTE: the `light:md:` prefix relies on the daisyUI-generated `light:` variant
 * from the original Tailwind config, which is not (yet) wired in bridge-ui-next.
 * The string is preserved exactly so it "just works" once that variant exists
 * (same caveat as Card.tsx).
 */
const styles = `
  md:w-[524px]
    w-full
    md:card
    md:rounded-[20px]
    md:border
    md:border-divider-border
    md:glassy-gradient-card
    dark:md:dark-glass-background-gradient
    light:md:light-glass-background-gradient
    `;

/**
 * React port of `components/Stepper/Stepper.svelte`.
 *
 * Mirrors the original DOM structure exactly. The `data-glow-border` attribute
 * is applied only at desktop width (>=768px) — the original used the renderless
 * `<DesktopOrLarger bind:is />` component, replaced here by
 * `useMediaQuery('(min-width: 768px)')` (both start `false` on first paint / SSR,
 * then resolve from `window.matchMedia`).
 */
export default function Stepper({
  activeStep = 0,
  className,
  children,
}: StepperProps) {
  const isDesktopOrLarger = useMediaQuery("(min-width: 768px)");

  const dynamicAttrs = isDesktopOrLarger ? { "data-glow-border": true } : {};

  const classes = cn(styles, className);

  const slotContent =
    typeof children === "function" ? children({ activeStep }) : children;

  return (
    <div className={classes}>
      <div {...dynamicAttrs} className="card-body body-regular gap-0 p-0">
        <ul className="steps md:mb-[30px] mt-[30px]">{slotContent}</ul>
      </div>
    </div>
  );
}
