"use client";

// React port of
// src/components/Dialogs/ClaimDialog/ClaimStepNavigation.svelte.
//
// COMPONENT CONVENTION mapping:
//   - `export let activeStep` (two-way `bind:activeStep`) -> controlled
//     `activeStep` prop + `onActiveStepChange(step)` callback. The parent owns
//     the value; `handleNextStep`/`handlePreviousStep` report the new step up.
//   - `export let loading/canContinue/claimingDone/claiming` -> read-only props.
//     (The original `bind:`s these from the parent, but this component only
//     READS them — it never writes them back — so plain props are faithful.)
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

import { ClaimSteps } from "./types";

export interface ClaimStepNavigationProps {
  /** Controlled active step (Svelte two-way `bind:activeStep`). */
  activeStep: ClaimSteps;
  /** Fired when navigation changes the active step (Svelte `bind:activeStep` write). */
  onActiveStepChange?: (step: ClaimSteps) => void;
  loading?: boolean;
  canContinue?: boolean;
  claimingDone?: boolean;
  claiming?: boolean;
  hideContinueButton: boolean;
  /** Svelte `on:closeDialog`. */
  onCloseDialog?: () => void;
}

const INITIAL_STEP = ClaimSteps.CHECK;

export default function ClaimStepNavigation({
  activeStep,
  onActiveStepChange,
  loading = false,
  canContinue = false,
  claimingDone = false,
  claiming = false,
  hideContinueButton,
  onCloseDialog,
}: ClaimStepNavigationProps) {
  const { t } = useTranslation();

  const getNextStepText = (step: ClaimSteps) => {
    if (step === ClaimSteps.REVIEW) {
      return t("common.confirm");
    }
    if (step === ClaimSteps.CONFIRM) {
      return t("common.ok");
    } else {
      return t("common.continue");
    }
  };

  const getPrevStepText = (step: ClaimSteps) => {
    if (step === INITIAL_STEP) {
      return t("common.cancel");
    }
    return t("common.back");
  };

  const handleNextStep = () => {
    if (activeStep === INITIAL_STEP) {
      onActiveStepChange?.(ClaimSteps.REVIEW);
    } else if (activeStep === ClaimSteps.REVIEW) {
      onActiveStepChange?.(ClaimSteps.CONFIRM);
    } else if (activeStep === ClaimSteps.CONFIRM) {
      onCloseDialog?.();
    }
  };

  const handlePreviousStep = () => {
    if (activeStep === INITIAL_STEP) {
      onCloseDialog?.();
    }
    if (activeStep === ClaimSteps.REVIEW) {
      onActiveStepChange?.(ClaimSteps.CHECK);
    } else if (activeStep === ClaimSteps.CONFIRM) {
      onActiveStepChange?.(ClaimSteps.REVIEW);
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
    (activeStep === ClaimSteps.CHECK && !canContinue) ||
    (activeStep === ClaimSteps.CONFIRM && !claimingDone);

  return (
    <>
      {(activeStep !== ClaimSteps.CONFIRM || claimingDone) &&
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
      {!claimingDone && !claiming && (
        <StepBack onClick={handlePreviousStep}>{prevStepButtonText}</StepBack>
      )}
    </>
  );
}
