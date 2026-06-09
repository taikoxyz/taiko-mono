"use client";

import type { MouseEventHandler, ReactNode } from "react";

import { StepBack } from "@/components/Stepper";
import { classNames } from "@/libs/util/classNames";

/** Slot props the original `<slot {activeStep} />` exposed to its default slot. */
export interface DialogStepperSlotProps {
  activeStep: number;
}

export interface DialogStepperProps {
  /** Index of the active step, forwarded to the slot (Svelte `activeStep`). */
  activeStep?: number;
  /** Pass-through className merged onto the outer wrapper (Svelte `$$props.class`). */
  className?: string;
  /** Svelte forwarded `<StepBack on:click />` -> forwarded `onClick`. */
  onClick?: MouseEventHandler<HTMLButtonElement>;
  /**
   * Default slot content. The original slot received `{ activeStep }`, so this
   * accepts either plain children or a render-prop `(slotProps) => ReactNode`
   * (mirroring `<slot let:activeStep>` usage).
   */
  children?: ReactNode | ((slotProps: DialogStepperSlotProps) => ReactNode);
}

// The original `styles` constant was an empty string; preserved verbatim.
const styles = ``;

/**
 * React port of `components/Dialogs/Stepper/DialogStepper.svelte`.
 *
 * Mirrors the original DOM structure exactly: a wrapper div, a card body, the
 * daisyUI `steps` list, then a forwarded `<StepBack>`. DOM/class strings are
 * kept identical to the source for pixel parity.
 */
export default function DialogStepper({
  activeStep = 0,
  className,
  onClick,
  children,
}: DialogStepperProps) {
  const classes = classNames(styles, className);

  const slotContent =
    typeof children === "function" ? children({ activeStep }) : children;

  return (
    <>
      <div className={classes}>
        <div className="card-body body-regular gap-0 p-0">
          <ul className="steps md:mb-[30px] mt-[30px]">{slotContent}</ul>
        </div>
      </div>

      <StepBack onClick={onClick} />
    </>
  );
}
