"use client";

// Ported from components/Bridge/NFTBridge.svelte.
//
// The NFT bridge flow: a 3-tab stepper (Import / Review / Confirm) plus a hidden
// RECIPIENT sub-step, rendered inside a Card, with renderless OnNetwork / OnAccount
// listeners that reset the form on network/account changes.
//
// Migration notes:
// - `export let` / local `let` reactive vars -> useState / useRef.
// - Svelte `tick()` (flush pending state updates, microtask) -> `Promise.resolve().then()`.
// - The reactive statements become useEffect:
//     `$: $activeBridge && (resetForm(), activeStep = IMPORT)` -> effect keyed on activeBridge.
//        NB: BridgeTypes.FUNGIBLE === 0 is falsy, NFT === 1 is truthy — preserved verbatim.
//     `$: activeStep === BridgeSteps.IMPORT && resetForm()` -> effect keyed on activeStep.
//     `$: { nftStepTitle / nftStepDescription }` -> useMemo.
//     `$: validatingImport = false` -> local state default false (reactive init).
// - `onDestroy(() => resetForm())` -> effect cleanup on unmount.
// - PARITY: `processingFeeComponent`, `addressInputComponent`, `nftIdInputComponent`,
//   and `importMethod` are declared in the source but NEVER bound/assigned (only
//   `recipientStepComponent` has `bind:this`). Their `if (xComponent)` guards therefore
//   never fire and `importMethod === MANUAL` is always false, so `updateForm()` always
//   calls `resetForm()`. This dead-but-present logic is reproduced faithfully (the refs
//   stay null / importMethod stays undefined).
// - Two-way `bind:` on children -> controlled prop + `onXChange` callback per convention.

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { Chain } from "viem";

import { BridgingStatus, ImportMethod } from "@/components/Bridge/types";
import Card from "@/components/Card";
import OnAccount from "@/components/OnAccount";
import OnNetwork from "@/components/OnNetwork";
import { Step, Stepper } from "@/components/Stepper";
import { hasBridge } from "@/libs/bridge/bridges";
import { BridgePausedError } from "@/libs/error";
import { ETHToken } from "@/libs/token";
import { isBridgePaused } from "@/libs/util/checkForPausedContracts";
import { type Account, account } from "@/stores/account";
import { useTranslation } from "@/i18n/useTranslation";

import { ImportStep, ReviewStep, StepNavigation } from "./NFTBridgeComponents";
import type { IDInputHandle } from "./NFTBridgeComponents";
import {
  ConfirmationStep,
  RecipientStep,
  type RecipientStepHandle,
} from "./SharedBridgeComponents";
import type { AddressInputHandle } from "./SharedBridgeComponents";
import type { ProcessingFeeHandle } from "./SharedBridgeComponents";
import {
  activeBridge,
  destNetwork as destinationChain,
  destOwnerAddress,
  importDone,
  recipientAddress,
  selectedNFTs,
  selectedToken,
  useBridgeState,
} from "./state";
import { BridgeSteps } from "./types";

export default function NFTBridge() {
  const { t } = useTranslation();

  const activeBridgeValue = useBridgeState(activeBridge);

  // `bind:this` ref — actually bound below.
  const recipientStepComponent = useRef<RecipientStepHandle>(null);

  // Declared in source but NEVER bound — kept null so the guards never fire (parity).
  const processingFeeComponent = useRef<ProcessingFeeHandle>(null);
  const addressInputComponent = useRef<AddressInputHandle>(null);
  const nftIdInputComponent = useRef<IDInputHandle>(null);
  // Declared in source but never assigned — stays undefined (parity).
  const importMethodRef = useRef<ImportMethod | undefined>(undefined);

  const [bridgingStatus, setBridgingStatus] = useState<BridgingStatus>(
    BridgingStatus.PENDING,
  );
  const [hasEnoughEth, setHasEnoughEth] = useState<boolean>(false);
  const [activeStep, setActiveStep] = useState<BridgeSteps>(BridgeSteps.IMPORT);

  // $: validatingImport = false;
  const [validatingImport, setValidatingImport] = useState<boolean>(false);

  const runValidations = useCallback(() => {
    if (addressInputComponent.current)
      addressInputComponent.current.validateAddress();
    isBridgePaused().then((paused) => {
      if (paused) {
        throw new BridgePausedError();
      }
    });
  }, []);

  const resetForm = useCallback(() => {
    // we check if these are still mounted, as the user might have left the page
    if (processingFeeComponent.current)
      processingFeeComponent.current.resetProcessingFee();
    if (addressInputComponent.current)
      addressInputComponent.current.clearAddress();

    // Update balance after bridging
    if (nftIdInputComponent.current) nftIdInputComponent.current.clearIds();

    const addr = account.getState()?.address ?? null;
    recipientAddress.setState(addr, true);
    destOwnerAddress.setState(addr, true);
    setBridgingStatus(BridgingStatus.PENDING);
    selectedToken.setState(ETHToken, true);
    importDone.setState(false, true);
    selectedNFTs.setState([], true);
    setActiveStep(BridgeSteps.IMPORT);
  }, []);

  const updateForm = useCallback(() => {
    // tick() -> flush microtask
    Promise.resolve().then(() => {
      if (importMethodRef.current === ImportMethod.MANUAL) {
        // run validations again if we are in manual mode
        runValidations();
      } else {
        resetForm();
      }
    });
  }, [runValidations, resetForm]);

  const onNetworkChange = useCallback(
    (newNetwork: Chain | undefined, oldNetwork: Chain | undefined) => {
      updateForm();
      setActiveStep(BridgeSteps.IMPORT);
      if (newNetwork) {
        const destChainId = destinationChain.getState()?.id;
        if (!destinationChain.getState()?.id) return;
        // determine if we simply swapped dest and src networks
        if (newNetwork.id === destChainId) {
          destinationChain.setState(oldNetwork ?? null, true);
          return;
        }
        // check if the new network has a bridge to the current dest network
        if (
          hasBridge(newNetwork.id, destinationChain.getState()?.id as number)
        ) {
          destinationChain.setState(oldNetwork ?? null, true);
        } else {
          // if not, set dest network to null
          destinationChain.setState(null, true);
        }
      }
    },
    [updateForm],
  );

  const onAccountChange = useCallback(
    (acc: Account | undefined) => {
      updateForm();
      if (acc && acc.isDisconnected) {
        selectedToken.setState(null, true);
        destinationChain.setState(null, true);
      }
    },
    [updateForm],
  );

  const handleTransactionDetailsClick = () =>
    setActiveStep(BridgeSteps.RECIPIENT);

  // $: $activeBridge && (resetForm(), (activeStep = BridgeSteps.IMPORT));
  // NB: BridgeTypes.FUNGIBLE === 0 (falsy), NFT === 1 (truthy) — guard preserved.
  // Faithful port of a Svelte reactive statement that re-runs (and resets the form)
  // when the bridge type changes; the synchronous setState is intentional here.
  useEffect(() => {
    if (activeBridgeValue) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      resetForm();
      setActiveStep(BridgeSteps.IMPORT);
    }
  }, [activeBridgeValue, resetForm]);

  // $: { nftStepTitle / nftStepDescription }
  const { nftStepTitle, nftStepDescription } = useMemo(() => {
    const stepKey = BridgeSteps[activeStep].toLowerCase();
    if (activeStep === BridgeSteps.CONFIRM) {
      return { nftStepTitle: "", nftStepDescription: "" };
    }
    return {
      nftStepTitle: t(`bridge.title.nft.${stepKey}`),
      nftStepDescription: t(`bridge.description.nft.${stepKey}`),
    };
  }, [activeStep, t]);

  // $: activeStep === BridgeSteps.IMPORT && resetForm();
  // Faithful port of a Svelte reactive statement; synchronous reset is intentional.
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    if (activeStep === BridgeSteps.IMPORT) resetForm();
  }, [activeStep, resetForm]);

  // onDestroy(() => resetForm());
  useEffect(() => {
    return () => {
      resetForm();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <>
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
          title={nftStepTitle}
          text={nftStepDescription}
        >
          <div className="space-y-[30px]">
            {activeStep === BridgeSteps.IMPORT ? (
              /* IMPORT STEP */
              <ImportStep
                validating={validatingImport}
                onValidatingChange={setValidatingImport}
              />
            ) : activeStep === BridgeSteps.REVIEW ? (
              /* REVIEW STEP */
              <ReviewStep
                onEditTransactionDetails={handleTransactionDetailsClick}
                hasEnoughEth={hasEnoughEth}
                onHasEnoughEthChange={setHasEnoughEth}
              />
            ) : activeStep === BridgeSteps.RECIPIENT ? (
              /* RECIPIENT STEP */
              <RecipientStep
                ref={recipientStepComponent}
                hasEnoughEth={hasEnoughEth}
                onHasEnoughEthChange={setHasEnoughEth}
              />
            ) : activeStep === BridgeSteps.CONFIRM ? (
              /* CONFIRM STEP */
              <ConfirmationStep
                bridgingStatus={bridgingStatus}
                onBridgingStatusChange={setBridgingStatus}
              />
            ) : null}
            {/* NAVIGATION */}
            <StepNavigation
              activeStep={activeStep}
              onActiveStepChange={setActiveStep}
              validatingImport={validatingImport}
              bridgingStatus={bridgingStatus}
            />
          </div>
        </Card>
      </div>

      <OnNetwork change={onNetworkChange} />
      <OnAccount change={onAccountChange} />
    </>
  );
}
