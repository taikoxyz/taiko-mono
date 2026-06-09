"use client";

import {
  calculatingProcessingFee,
  importDone,
  useBridgeState,
} from "@/components/Bridge/state";
import {
  BridgeSteps,
  BridgingStatus,
  ImportMethod,
} from "@/components/Bridge/types";
import { ActionButton } from "@/components/Button";
import { StepBack } from "@/components/Stepper";
import { useTranslation } from "@/i18n/useTranslation";

import {
  selectedImportMethod,
  useSelectedImportMethod,
} from "../ImportStep/state";

export interface StepNavigationProps {
  /** Two-way bound `activeStep` (Svelte `bind:activeStep`). */
  activeStep?: BridgeSteps;
  onActiveStepChange?: (value: BridgeSteps) => void;
  validatingImport?: boolean;
  disabled?: boolean;
  bridgingStatus: BridgingStatus;
}

export default function StepNavigation({
  activeStep = BridgeSteps.IMPORT,
  onActiveStepChange,
  validatingImport = false,
  disabled = false,
  bridgingStatus,
}: StepNavigationProps) {
  const { t } = useTranslation();

  const $selectedImportMethod = useSelectedImportMethod();
  const $importDone = useBridgeState(importDone);
  const $calculatingProcessingFee = useBridgeState(calculatingProcessingFee);

  const getStepText = () => {
    if (activeStep === BridgeSteps.REVIEW) {
      return t("common.confirm");
    }
    if (activeStep === BridgeSteps.CONFIRM) {
      return t("common.ok");
    } else {
      return t("common.continue");
    }
  };

  const handleNextStep = () => {
    if (activeStep === BridgeSteps.IMPORT) {
      onActiveStepChange?.(BridgeSteps.REVIEW);
    } else if (activeStep === BridgeSteps.REVIEW) {
      onActiveStepChange?.(BridgeSteps.CONFIRM);
    } else if (activeStep === BridgeSteps.RECIPIENT) {
      onActiveStepChange?.(BridgeSteps.REVIEW);
    } else if (activeStep === BridgeSteps.CONFIRM) {
      onActiveStepChange?.(BridgeSteps.IMPORT);
    }
  };

  const handlePreviousStep = () => {
    if (activeStep === BridgeSteps.REVIEW) {
      onActiveStepChange?.(BridgeSteps.IMPORT);
    } else if (activeStep === BridgeSteps.CONFIRM) {
      onActiveStepChange?.(BridgeSteps.REVIEW);
    }
  };

  // $: showStepNavigation = $selectedImportMethod !== ImportMethod.NONE;
  const showStepNavigation = $selectedImportMethod !== ImportMethod.NONE;

  // $: { nextStepButtonText = getStepText(); }
  const nextStepButtonText = getStepText();

  // {#if showStepNavigation} ... {/if} — wrapper preserved as a conditional render
  // (rather than an early return) so the inner redundant `!== NONE` re-check, which
  // the source keeps verbatim, isn't narrowed away by control flow analysis.
  if (!showStepNavigation) return null;

  return (
    <div className="f-col w-full justify-content-center gap-4">
      {activeStep === BridgeSteps.IMPORT &&
        (selectedImportMethod.getState() as ImportMethod) !==
          ImportMethod.NONE && (
          <>
            <ActionButton
              priority="primary"
              disabled={!$importDone}
              loading={validatingImport}
              onClick={() => handleNextStep()}
            >
              <span className="body-bold">{nextStepButtonText}</span>
            </ActionButton>

            <StepBack
              onClick={() => selectedImportMethod.setState(ImportMethod.NONE)}
            >
              {t("common.back")}
            </StepBack>
          </>
        )}
      {activeStep === BridgeSteps.REVIEW && (
        <>
          <ActionButton
            priority="primary"
            disabled={$calculatingProcessingFee}
            onClick={() => handleNextStep()}
          >
            <span className="body-bold">{nextStepButtonText}</span>
          </ActionButton>

          <StepBack onClick={() => handlePreviousStep()}>
            {t("common.back")}
          </StepBack>
        </>
      )}

      {activeStep === BridgeSteps.RECIPIENT && (
        <ActionButton priority="primary" onClick={() => handleNextStep()}>
          <span className="body-bold">{nextStepButtonText}</span>
        </ActionButton>
      )}

      {activeStep === BridgeSteps.CONFIRM &&
        (bridgingStatus === BridgingStatus.DONE ? (
          <ActionButton
            disabled={disabled}
            priority="primary"
            onClick={() => handleNextStep()}
          >
            <span className="body-bold">{nextStepButtonText}</span>
          </ActionButton>
        ) : (
          <StepBack onClick={() => handlePreviousStep()}>
            {t("common.back")}
          </StepBack>
        ))}
    </div>
  );
}
