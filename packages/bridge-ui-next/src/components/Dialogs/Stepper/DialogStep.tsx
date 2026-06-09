import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

import styles from "./DialogStep.module.css";

export interface DialogStepProps {
  /** Whether this step is the currently active one (Svelte `isActive`). */
  isActive?: boolean;
  /** Zero-based index of this step (Svelte `stepIndex`). */
  stepIndex: number;
  /** Index of the currently active step (Svelte `currentStepIndex`). */
  currentStepIndex: number;
  /** Default slot content (the step label). */
  children?: ReactNode;
}

/**
 * React port of `components/Dialogs/Stepper/DialogStep.svelte`.
 *
 * Renders a daisyUI `<li class="step ...">`. The global daisyUI classes
 * (`step`/`step-primary`/`step-previous`) drive layout + base coloring; the
 * CSS-module classes reproduce the component-scoped `::before` connector-bar
 * overrides from the original <style> block (see DialogStep.module.css).
 *
 * DOM/class strings are kept identical to the source for pixel parity.
 */
export default function DialogStep({
  isActive = false,
  stepIndex,
  currentStepIndex,
  children,
}: DialogStepProps) {
  const isPrevious = stepIndex < currentStepIndex && !isActive;

  return (
    <li
      data-content=""
      className={cn(
        "step",
        styles.step,
        isActive && "step-primary",
        isActive && styles["step-primary"],
        isPrevious && "step-previous",
        isPrevious && styles["step-previous"],
      )}
    >
      {children}
    </li>
  );
}
