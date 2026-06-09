"use client";

// Ported from components/Bridge/FungibleBridge.svelte.
//
// The ERC20/ETH bridge flow: a 3-tab stepper (Import / Review / Confirm) plus a
// hidden RECIPIENT sub-step, rendered inside a Card. Step content + the shared
// StepNavigation are swapped based on `activeStep`.
//
// Migration notes:
// - `export let` / local `let` reactive vars -> useState.
// - Svelte two-way `bind:x` on children -> controlled prop `x` + callback `onXChange`
//   (per the COMPONENT CONVENTION; child components are written by sibling agents).
// - `on:editTransactionDetails` / `on:goBack` -> `onEditTransactionDetails` / `onGoBack`.
// - `bind:this={recipientStepComponent}` -> a ref forwarded to RecipientStep. It is
//   held but never invoked by this parent (parity with the source), so it stays a
//   plain ref.
// - `$: needsManualRecipientConfirmation = $connectedSmartContractWallet` is a derived
//   value driven by the smart-contract-wallet store, NOT independent local state, so it
//   reads straight from the store hook.
// - The two reactive blocks computing the step title/description become useMemo.

import { useMemo, useRef, useState } from "react";

import Card from "@/components/Card";
import { Step, Stepper } from "@/components/Stepper";
import { useSmartContractWallet } from "@/stores/account";
import { useTranslation } from "@/i18n/useTranslation";

import {
  ImportStep,
  ReviewStep,
  StepNavigation,
} from "./FungibleBridgeComponents";
import {
  ConfirmationStep,
  RecipientStep,
  type RecipientStepHandle,
} from "./SharedBridgeComponents";
import { BridgeSteps, BridgingStatus } from "./types";

export default function FungibleBridge() {
  const { t } = useTranslation();

  const [activeStep, setActiveStep] = useState<BridgeSteps>(BridgeSteps.IMPORT);

  // `bind:this={recipientStepComponent}` — held, not invoked here (parity with source).
  const recipientStepComponent = useRef<RecipientStepHandle>(null);

  const [hasEnoughEth, setHasEnoughEth] = useState<boolean>(false);
  const [hasEnoughFundsToContinue, setHasEnoughFundsToContinue] =
    useState<boolean>(false);
  const [bridgingStatus, setBridgingStatus] = useState<BridgingStatus>(
    BridgingStatus.PENDING,
  );
  const [needsManualReviewConfirmation, setNeedsManualReviewConfirmation] =
    useState<boolean>(false);

  // $: needsManualRecipientConfirmation = $connectedSmartContractWallet;
  const needsManualRecipientConfirmation = useSmartContractWallet();

  const handleTransactionDetailsClick = () =>
    setActiveStep(BridgeSteps.RECIPIENT);
  const handleBackClick = () => setActiveStep(BridgeSteps.IMPORT);

  // $: { compute stepTitle / stepDescription from activeStep }
  const { stepTitle, stepDescription } = useMemo(() => {
    const stepKey = BridgeSteps[activeStep].toLowerCase();
    if (activeStep === BridgeSteps.CONFIRM) {
      return { stepTitle: "", stepDescription: "" };
    }
    return {
      stepTitle: t(`bridge.title.fungible.${stepKey}`),
      stepDescription: t(`bridge.description.fungible.${stepKey}`),
    };
  }, [activeStep, t]);

  return (
    <div className=" gap-0 w-full md:w-[524px]">
      <Stepper activeStep={activeStep}>
        <Step
          stepIndex={BridgeSteps.IMPORT}
          currentStepIndex={activeStep}
          isActive={activeStep === BridgeSteps.IMPORT}
        >
          {t("bridge.step.import.title")}
        </Step>
        <Step
          stepIndex={BridgeSteps.REVIEW}
          currentStepIndex={activeStep}
          isActive={activeStep === BridgeSteps.REVIEW}
        >
          {t("bridge.step.review.title")}
        </Step>
        <Step
          stepIndex={BridgeSteps.CONFIRM}
          currentStepIndex={activeStep}
          isActive={activeStep === BridgeSteps.CONFIRM}
        >
          {t("bridge.step.confirm.title")}
        </Step>
      </Stepper>

      <Card
        className="md:mt-[32px] w-full md:w-[524px]"
        title={stepTitle}
        text={stepDescription}
      >
        <div className="space-y-[30px] mt-[30px]">
          {activeStep === BridgeSteps.IMPORT ? (
            /* IMPORT STEP */
            <ImportStep
              hasEnoughEth={hasEnoughEth}
              onHasEnoughEthChange={setHasEnoughEth}
            />
          ) : activeStep === BridgeSteps.REVIEW ? (
            /* REVIEW STEP */
            <ReviewStep
              onEditTransactionDetails={handleTransactionDetailsClick}
              onGoBack={handleBackClick}
              needsManualReviewConfirmation={needsManualReviewConfirmation}
              onNeedsManualReviewConfirmationChange={
                setNeedsManualReviewConfirmation
              }
              hasEnoughEth={hasEnoughEth}
              onHasEnoughEthChange={setHasEnoughEth}
              hasEnoughFundsToContinue={hasEnoughFundsToContinue}
              onHasEnoughFundsToContinueChange={setHasEnoughFundsToContinue}
            />
          ) : activeStep === BridgeSteps.RECIPIENT ? (
            /* RECIPIENT STEP */
            <RecipientStep
              ref={recipientStepComponent}
              hasEnoughEth={hasEnoughEth}
              onHasEnoughEthChange={setHasEnoughEth}
              needsManualRecipientConfirmation={
                needsManualRecipientConfirmation
              }
            />
          ) : activeStep === BridgeSteps.CONFIRM ? (
            /* CONFIRM STEP */
            <ConfirmationStep
              bridgingStatus={bridgingStatus}
              onBridgingStatusChange={setBridgingStatus}
            />
          ) : null}
          {/* NAVIGATION */}
          {/*
            Source binds `bind:hasEnoughFundsToContinue` / `bind:needsManualReviewConfirmation`
            here, but StepNavigation only ever writes back `activeStep` — the others are
            read-only inside it — so they are passed one-way to match the child contract.
          */}
          <StepNavigation
            activeStep={activeStep}
            onActiveStepChange={setActiveStep}
            hasEnoughFundsToContinue={hasEnoughFundsToContinue}
            bridgingStatus={bridgingStatus}
            needsManualReviewConfirmation={needsManualReviewConfirmation}
            needsManualRecipientConfirmation={needsManualRecipientConfirmation}
          />
        </div>
      </Card>
    </div>
  );
}
