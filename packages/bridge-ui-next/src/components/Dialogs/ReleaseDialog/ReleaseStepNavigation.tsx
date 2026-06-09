"use client";

// React port of
// src/components/Dialogs/ReleaseDialog/ReleaseStepNavigation.svelte.
//
// COMPONENT CONVENTION mapping:
//   - `export let activeStep` (two-way `bind:activeStep`) -> controlled
//     `activeStep` prop + `onActiveStepChange(step)` callback. The parent owns
//     the value; `handleNextStep`/`handlePreviousStep` report the new step up.
//   - `export let loading/canContinue/releasingDone/releasing` -> read-only
//     props. (The original `bind:`s these from the parent, but this component
//     only READS them — it never writes them back — so plain props are faithful.)
//   - `export let hideContinueButton` -> read-only prop.
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

import { INITIAL_STEP, ReleaseSteps } from "./types";

export interface ReleaseStepNavigationProps {
  /** Controlled active step (Svelte two-way `bind:activeStep`). */
  activeStep: ReleaseSteps;
  /** Fired when navigation changes the active step (Svelte `bind:activeStep` write). */
  onActiveStepChange?: (step: ReleaseSteps) => void;
  loading?: boolean;
  canContinue?: boolean;
  releasingDone?: boolean;
  releasing?: boolean;
  hideContinueButton: boolean;
  /** Svelte `on:closeDialog`. */
  onCloseDialog?: () => void;
}

export default function ReleaseStepNavigation({
  activeStep,
  onActiveStepChange,
  loading = false,
  canContinue = false,
  releasingDone = false,
  releasing = false,
  hideContinueButton,
  onCloseDialog,
}: ReleaseStepNavigationProps) {
  const { t } = useTranslation();

  const getNextStepText = (step: ReleaseSteps) => {
    if (step === ReleaseSteps.REVIEW) {
      return t("common.confirm");
    }
    if (step === ReleaseSteps.CONFIRM) {
      return t("common.ok");
    } else {
      return t("common.continue");
    }
  };

  const getPrevStepText = (step: ReleaseSteps) => {
    if (step === INITIAL_STEP) {
      return t("common.cancel");
    }
    return t("common.back");
  };

  const handleNextStep = () => {
    if (activeStep === INITIAL_STEP) {
      onActiveStepChange?.(ReleaseSteps.REVIEW);
    } else if (activeStep === ReleaseSteps.REVIEW) {
      onActiveStepChange?.(ReleaseSteps.CONFIRM);
    } else if (activeStep === ReleaseSteps.CONFIRM) {
      onCloseDialog?.();
    }
  };

  const handlePreviousStep = () => {
    if (activeStep === INITIAL_STEP) {
      onCloseDialog?.();
    }
    if (activeStep === ReleaseSteps.REVIEW) {
      onActiveStepChange?.(ReleaseSteps.CHECK);
    } else if (activeStep === ReleaseSteps.CONFIRM) {
      onActiveStepChange?.(ReleaseSteps.REVIEW);
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

  const isNextStepDisabled =
    loading ||
    (activeStep === ReleaseSteps.CHECK && !canContinue) ||
    (activeStep === ReleaseSteps.CONFIRM && !releasingDone);

  return (
    <>
      {(activeStep !== ReleaseSteps.CONFIRM || releasingDone) &&
        (activeStep !== ReleaseSteps.CHECK || canContinue) &&
        !hideContinueButton && (
          <>
            <div className="h-sep" />
            <ActionButton
              onPopup
              priority="primary"
              disabled={isNextStepDisabled}
              loading={loading}
              onClick={handleNextStep}
            >
              {nextStepButtonText}
            </ActionButton>
          </>
        )}
      {!releasingDone && !releasing && (
        <StepBack onClick={handlePreviousStep}>{prevStepButtonText}</StepBack>
      )}
    </>
  );
}
