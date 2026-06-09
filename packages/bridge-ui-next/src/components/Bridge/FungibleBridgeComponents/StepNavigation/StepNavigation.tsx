"use client";

import { useState } from "react";

import {
  calculatingProcessingFee,
  importDone,
  useBridgeState,
} from "@/components/Bridge/state";
import { BridgeSteps, BridgingStatus } from "@/components/Bridge/types";
import { ActionButton } from "@/components/Button";
import { Icon } from "@/components/Icon";
import { StepBack } from "@/components/Stepper";
import { useTranslation } from "@/i18n/useTranslation";
import { account, connectedSmartContractWallet } from "@/stores/account";

export interface StepNavigationProps {
  /** Two-way bound (Svelte `bind:activeStep`). */
  activeStep?: BridgeSteps;
  onActiveStepChange?: (step: BridgeSteps) => void;
  /** Svelte `export let validatingImport = false`. */
  validatingImport?: boolean;
  /** Svelte `export let hasEnoughFundsToContinue`. */
  hasEnoughFundsToContinue: boolean;
  /** Svelte `export let needsManualReviewConfirmation`. */
  needsManualReviewConfirmation: boolean;
  /** Svelte `export let needsManualRecipientConfirmation`. */
  needsManualRecipientConfirmation: boolean;
  /** Svelte `export let bridgingStatus`. */
  bridgingStatus: BridgingStatus;
}

export default function StepNavigation({
  activeStep = BridgeSteps.IMPORT,
  onActiveStepChange,
  validatingImport = false,
  hasEnoughFundsToContinue,
  needsManualReviewConfirmation,
  needsManualRecipientConfirmation,
  bridgingStatus,
}: StepNavigationProps) {
  const { t } = useTranslation();

  // Reactive store reads (Svelte `$store`).
  const $importDone = useBridgeState(importDone);
  const $calculatingProcessingFee = useBridgeState(calculatingProcessingFee);
  const $account = useBridgeState(account);
  const $connectedSmartContractWallet = useBridgeState(
    connectedSmartContractWallet,
  );

  // Svelte `let manuallyConfirmed...Step = false`.
  const [manuallyConfirmedReviewStep, setManuallyConfirmedReviewStep] =
    useState(false);
  const [manuallyConfirmedRecipientStep, setManuallyConfirmedRecipientStep] =
    useState(false);

  // Helper mirroring `bind:activeStep` write-back.
  const setActiveStep = (step: BridgeSteps) => onActiveStepChange?.(step);

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
      if ($connectedSmartContractWallet && !manuallyConfirmedRecipientStep) {
        // If the user is connected to a smart contract wallet and hasn't confirmed the risk, we enforce the recipient step first
        setActiveStep(BridgeSteps.RECIPIENT);
      } else {
        setActiveStep(BridgeSteps.REVIEW);
      }
    } else if (activeStep === BridgeSteps.REVIEW) {
      setActiveStep(BridgeSteps.CONFIRM);
    } else if (activeStep === BridgeSteps.RECIPIENT) {
      setActiveStep(BridgeSteps.REVIEW);
    } else if (activeStep === BridgeSteps.CONFIRM) {
      setActiveStep(BridgeSteps.IMPORT);
    }
  };

  const handlePreviousStep = () => {
    if (activeStep === BridgeSteps.REVIEW) {
      setActiveStep(BridgeSteps.IMPORT);
    } else if (activeStep === BridgeSteps.CONFIRM) {
      setActiveStep(BridgeSteps.REVIEW);
    } else if (activeStep === BridgeSteps.RECIPIENT) {
      setActiveStep(BridgeSteps.REVIEW);
    }
    reset();
  };

  const reset = () => {
    setManuallyConfirmedReviewStep(false);
    setManuallyConfirmedRecipientStep(false);
  };

  // $: disabled = !$account || !$account.isConnected || $calculatingProcessingFee;
  const disabled =
    !$account || !$account.isConnected || $calculatingProcessingFee;

  // $: nextStepButtonText = getStepText();
  const nextStepButtonText = getStepText();

  // $: reviewConfirmed = !needsManualReviewConfirmation || manuallyConfirmedReviewStep;
  const reviewConfirmed =
    !needsManualReviewConfirmation || manuallyConfirmedReviewStep;

  // $: recipientConfirmed = !needsManualRecipientConfirmation || manuallyConfirmedRecipientStep;
  const recipientConfirmed =
    !needsManualRecipientConfirmation || manuallyConfirmedRecipientStep;

  return (
    <div className="f-col w-full justify-content-center gap-4">
      {activeStep === BridgeSteps.IMPORT && (
        <>
          <div className="h-sep mt-0" />
          <ActionButton
            priority="primary"
            disabled={!$importDone || disabled}
            loading={validatingImport}
            onClick={() => handleNextStep()}
          >
            <span className="body-bold">{nextStepButtonText}</span>
          </ActionButton>
        </>
      )}

      {activeStep === BridgeSteps.REVIEW && (
        <>
          {needsManualReviewConfirmation && (
            <ActionButton
              priority="primary"
              disabled={manuallyConfirmedReviewStep}
              onClick={() => setManuallyConfirmedReviewStep(true)}
            >
              {!reviewConfirmed ? (
                t("bridge.actions.acknowledge")
              ) : (
                <>
                  <Icon type="check" />
                  {t("common.confirmed")}
                </>
              )}
            </ActionButton>
          )}

          <ActionButton
            priority="primary"
            disabled={disabled || !reviewConfirmed || !hasEnoughFundsToContinue}
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
        <>
          {needsManualRecipientConfirmation && (
            <ActionButton
              priority="primary"
              disabled={recipientConfirmed}
              onClick={() => setManuallyConfirmedRecipientStep(true)}
            >
              {!recipientConfirmed ? (
                t("bridge.actions.acknowledge")
              ) : (
                <>
                  <Icon type="check" />
                  {t("common.confirmed")}
                </>
              )}
            </ActionButton>
          )}
          <ActionButton
            disabled={disabled || !recipientConfirmed}
            priority="primary"
            onClick={() => handleNextStep()}
          >
            <span className="body-bold">{nextStepButtonText}</span>
          </ActionButton>
        </>
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
