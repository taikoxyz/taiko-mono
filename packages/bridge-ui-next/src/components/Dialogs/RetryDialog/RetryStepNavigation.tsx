"use client";

// React port of
// src/components/Dialogs/RetryDialog/RetryStepNavigation.svelte.
//
// COMPONENT CONVENTION mapping:
//   - `export let activeStep` (two-way `bind:activeStep`) -> controlled
//     `activeStep` prop + `onActiveStepChange(step)` callback. The parent owns
//     the value; `handleNextStep`/`handlePreviousStep` report the new step up.
//   - `export let loading/canContinue/retryDone/retrying` -> read-only props.
//     (The original `bind:`s these from the parent, but this component only
//     READS them — it never writes them back — so plain props are faithful.)
//   - `dispatch('closeDialog')` -> `onCloseDialog()` callback prop.
//   - Reactive `$:` derivations -> `useMemo`. (The original's redundant
//     `$: if (activeStep) { getPrevStepText(activeStep); getNextStepText(...) }`
//     block was a no-op recompute with discarded results; it is intentionally
//     dropped — the `useMemo`s already recompute on `activeStep` change.)
//
// DOM / class strings preserved verbatim for pixel parity.

import { useMemo } from "react";

import { ActionButton } from "@/components/Button";
import { StepBack } from "@/components/Stepper";
import { useTranslation } from "@/i18n/useTranslation";

import { INITIAL_STEP, RetrySteps } from "./types";

export interface RetryStepNavigationProps {
  /** Controlled active step (Svelte two-way `bind:activeStep`). */
  activeStep: RetrySteps;
  /** Fired when navigation changes the active step (Svelte `bind:activeStep` write). */
  onActiveStepChange?: (step: RetrySteps) => void;
  loading?: boolean;
  canContinue?: boolean;
  retryDone?: boolean;
  retrying?: boolean;
  /** Svelte `on:closeDialog`. */
  onCloseDialog?: () => void;
}

export default function RetryStepNavigation({
  activeStep,
  onActiveStepChange,
  loading = false,
  canContinue = false,
  retryDone = false,
  retrying = false,
  onCloseDialog,
}: RetryStepNavigationProps) {
  const { t } = useTranslation();

  const getNextStepText = (step: RetrySteps) => {
    if (step === RetrySteps.REVIEW) {
      return t("common.confirm");
    }
    if (step === RetrySteps.CONFIRM) {
      return t("common.ok");
    } else {
      return t("common.continue");
    }
  };

  const getPrevStepText = (step: RetrySteps) => {
    if (step === INITIAL_STEP) {
      return t("common.cancel");
    }
    return t("common.back");
  };

  const handleNextStep = () => {
    if (activeStep === INITIAL_STEP) {
      onActiveStepChange?.(RetrySteps.SELECT);
    } else if (activeStep === RetrySteps.SELECT) {
      onActiveStepChange?.(RetrySteps.REVIEW);
    } else if (activeStep === RetrySteps.REVIEW) {
      onActiveStepChange?.(RetrySteps.CONFIRM);
    } else if (activeStep === RetrySteps.CONFIRM) {
      onCloseDialog?.();
    }
  };

  const handlePreviousStep = () => {
    if (activeStep === INITIAL_STEP) {
      onCloseDialog?.();
    }
    if (activeStep === RetrySteps.REVIEW) {
      onActiveStepChange?.(RetrySteps.SELECT);
    } else if (activeStep === RetrySteps.SELECT) {
      onActiveStepChange?.(RetrySteps.CHECK);
    } else if (activeStep === RetrySteps.CONFIRM) {
      onActiveStepChange?.(RetrySteps.REVIEW);
    }
  };

  const nextStepButtonText = useMemo(
    () => getNextStepText(activeStep),
    [activeStep, t],
  );

  const prevStepButtonText = useMemo(
    () => getPrevStepText(activeStep),
    [activeStep, t],
  );

  // $: isNextStepEnabled = !canContinue || loading || (activeStep === RetrySteps.CONFIRM && !retryDone);
  // (Despite the name, this is the button's DISABLED condition — preserved verbatim.)
  const isNextStepEnabled =
    !canContinue ||
    loading ||
    (activeStep === RetrySteps.CONFIRM && !retryDone);

  return (
    <>
      {activeStep !== RetrySteps.CONFIRM ? (
        <>
          <div className="h-sep" />
          <ActionButton
            onPopup
            priority="primary"
            disabled={isNextStepEnabled}
            loading={loading}
            onClick={handleNextStep}
          >
            {nextStepButtonText}
          </ActionButton>
        </>
      ) : activeStep === RetrySteps.CONFIRM && retryDone ? (
        <ActionButton
          onPopup
          priority="primary"
          disabled={isNextStepEnabled}
          loading={loading}
          onClick={handleNextStep}
        >
          {nextStepButtonText}
        </ActionButton>
      ) : null}
      {!retryDone && !retrying && (
        <StepBack onClick={handlePreviousStep}>{prevStepButtonText}</StepBack>
      )}
    </>
  );
}
