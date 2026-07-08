"use client";

// React port of
// src/components/Dialogs/ReleaseDialog/ReleaseDialog.svelte.
//
// COMPONENT CONVENTION mapping:
//   - `export let dialogOpen` (two-way `bind:dialogOpen`) -> controlled
//     `dialogOpen` prop + `onDialogOpenChange(open)` callback. `closeDialog`
//     reports `false` up (the original wrote `dialogOpen = false` then `reset()`).
//   - `export let bridgeTx` -> `bridgeTx` prop.
//   - `dispatch('claimingDone')` -> `onClaimingDone()` callback.
//   - `dispatch('insufficientFunds', { tx })` -> `onInsufficientFunds({ tx })`.
//   - Local Svelte `let`s -> `useState`. Reactive `$: loading = releasing` ->
//     derived value. (The source's `$: releasing = false;` reactive assignment
//     is a no-op/quirk — `releasing` is also driven imperatively; see NOTE below.)
//   - `<DesktopOrLarger bind:is>` -> the `useDesktopOrLarger()` hook.
//   - `bind:this={ClaimComponent}` + `ClaimComponent.claim(...)` -> a ref to the
//     `Claim` component's imperative handle (`ClaimHandle.claim`).
//   - Child two-way `bind:`s (canContinue / hideContinueButton / activeStep /
//     txHash / releasing / releasingDone / canClaim) -> controlled value +
//     `on*Change` callbacks that write the corresponding local state.
//
// NOTE on `$: releasing = false;` (source line 150): in Svelte this reactive
// statement re-asserts `releasing = false` on each reactive run, fighting the
// imperative `releasing = true` writes in the handlers. In practice the handlers
// run their async work and reset `releasing` themselves, so the observable
// behaviour is "releasing is briefly true during an action, false otherwise".
// We model `releasing` as plain state written by the handlers and DO NOT add an
// effect that force-resets it, preserving the effective behaviour without the
// reactive-loop quirk.
//
// DOM / class strings preserved verbatim for pixel parity.

import { useId, useRef, useState } from "react";
import {
  ContractFunctionExecutionError,
  type Hash,
  UserRejectedRequestError,
} from "viem";

import { CloseButton } from "@/components/Button";
import { useDesktopOrLarger } from "@/components/DesktopOrLarger";
import Claim, {
  type ClaimErrorDetail,
  type ClaimHandle,
  type ClaimTxSentDetail,
} from "@/components/Dialogs/Claim";
import { ClaimConfirmStep, ReviewStep } from "@/components/Dialogs/Shared";
import { ClaimAction } from "@/components/Dialogs/Shared/types";
import { DialogStep, DialogStepper } from "@/components/Dialogs/Stepper";
import {
  errorToast,
  infoToast,
  successToast,
  warningToast,
} from "@/components/NotificationToast";
import { OnAccount } from "@/components/OnAccount";
import { chainConfig } from "@/config/generated/chainConfig";
import { useTranslation } from "@/i18n/useTranslation";
import type { BridgeTransaction } from "@/libs/bridge";
import {
  InsufficientBalanceError,
  InvalidProofError,
  NotConnectedError,
  ProcessMessageError,
  RetryError,
} from "@/libs/error";
import { getLogger } from "@/libs/util/logger";
import { cn } from "@/lib/utils";
import { connectedSourceChain } from "@/stores/network";
import { pendingTransactions } from "@/stores/pendingTransactions";

import ReleaseStepNavigation from "./ReleaseStepNavigation";
import ReleasePreCheck from "./ReleaseSteps/ReleasePreCheck";
import { INITIAL_STEP, ReleaseSteps } from "./types";

const log = getLogger("ReleaseDialog");

export interface ReleaseDialogProps {
  bridgeTx: BridgeTransaction;
  /** Two-way bound in the original (`bind:dialogOpen`). */
  dialogOpen?: boolean;
  onDialogOpenChange?: (open: boolean) => void;
  /** Svelte `dispatch('claimingDone')`. */
  onClaimingDone?: () => void;
  /** Svelte `dispatch('insufficientFunds', { tx })`. */
  onInsufficientFunds?: (detail: { tx: BridgeTransaction }) => void;
}

export default function ReleaseDialog({
  bridgeTx,
  dialogOpen = false,
  onDialogOpenChange,
  onClaimingDone,
  onInsufficientFunds,
}: ReleaseDialogProps) {
  const { t } = useTranslation();

  const isDesktopOrLarger = useDesktopOrLarger();

  // SSR-safe per-instance id (replaces Svelte `crypto.randomUUID()`, which
  // differs between server render and hydration).
  const dialogId = `dialog-${useId()}`;

  const ClaimComponent = useRef<ClaimHandle>(null);

  const [canContinue, setCanContinue] = useState(false);
  const [activeStep, setActiveStep] = useState<ReleaseSteps>(INITIAL_STEP);
  const [txHash, setTxHash] = useState<Hash | undefined>(undefined);
  const [releasing, setReleasing] = useState(false);
  const [releasingDone, setReleasingDone] = useState(false);
  const [hideContinueButton, setHideContinueButton] = useState(false);

  // $: loading = releasing;
  const loading = releasing;

  const reset = () => {
    setReleasing(false);
    setActiveStep(INITIAL_STEP);
  };

  const closeDialog = () => {
    onDialogOpenChange?.(false);
    reset();
  };

  const handleAccountChange = () => {
    reset();
  };

  const handleClaimTxSent = async (detail: ClaimTxSentDetail) => {
    const { txHash: transactionHash, action } = detail;
    setTxHash(transactionHash);
    log("handle claim tx sent", transactionHash, action);
    setReleasing(true);

    const explorer =
      chainConfig[Number(bridgeTx.destChainId)]?.blockExplorers?.default.url;

    infoToast({
      title: t("transactions.actions.claim.tx.title"),
      message: t("transactions.actions.claim.tx.message", {
        token: bridgeTx.symbol,
        url: `${explorer}/tx/${transactionHash}`,
      }),
    });
    await pendingTransactions.add(
      transactionHash,
      Number(bridgeTx.destChainId),
    );

    setReleasingDone(true);

    onClaimingDone?.();

    successToast({
      title: t("transactions.actions.claim.success.title"),
      message: t("transactions.actions.claim.success.message", {
        network: connectedSourceChain.getState()?.name,
      }),
    });
  };

  const handleClaimError = (detail: ClaimErrorDetail) => {
    //TODO: update this to display info alongside toasts
    const err = detail.error;
    switch (true) {
      case err instanceof NotConnectedError:
        warningToast({ title: t("messages.account.required") });
        break;
      case err instanceof UserRejectedRequestError:
        warningToast({ title: t("transactions.actions.claim.rejected.title") });
        break;
      case err instanceof InsufficientBalanceError:
        onInsufficientFunds?.({ tx: bridgeTx });
        break;
      case err instanceof InvalidProofError:
        errorToast({
          title: t("common.error"),
          message: t("bridge.errors.invalid_proof_provided"),
        });
        break;
      case err instanceof ProcessMessageError:
        errorToast({ title: t("bridge.errors.process_message_error") });
        break;
      case err instanceof RetryError:
        errorToast({ title: t("bridge.errors.retry_error") });
        break;
      case err instanceof ContractFunctionExecutionError:
        console.error(err);
        if (err.message.includes("B_NOT_RECEIVED")) {
          errorToast({
            title: t("bridge.errors.claim.not_received.title"),
            message: t("bridge.errors.claim.not_received.message"),
          });
        } else {
          errorToast({
            title: t("bridge.errors.unknown_error.title"),
            message: t("bridge.errors.unknown_error.message"),
          });
        }
        break;
      default:
        console.error(err);
        errorToast({
          title: t("bridge.errors.unknown_error.title"),
          message: t("bridge.errors.unknown_error.message"),
        });
        break;
    }
    setReleasing(false);
  };

  const handleReleaseClick = async () => {
    setReleasing(true);
    await ClaimComponent.current?.claim(ClaimAction.RELEASE);
    setReleasing(false);
  };

  return (
    <>
      <dialog
        id={dialogId}
        className={cn(
          "modal",
          isDesktopOrLarger ? "" : "modal-bottom",
          dialogOpen && "modal-open",
        )}
      >
        <div className="modal-box relative w-full bg-neutral-background absolute">
          <div className="w-full f-between-center">
            <CloseButton onClick={closeDialog} />
            <h3 className="title-body-bold">
              {t("transactions.release.title")}
            </h3>
          </div>
          <div className="h-sep mx-[-24px] mt-[20px]" />
          <div className="w-full h-full f-col">
            <DialogStepper>
              <DialogStep
                stepIndex={ReleaseSteps.CHECK}
                currentStepIndex={activeStep}
                isActive={activeStep === ReleaseSteps.CHECK}
              >
                {t("transactions.claim.steps.pre_check.title")}
              </DialogStep>
              <DialogStep
                stepIndex={ReleaseSteps.REVIEW}
                currentStepIndex={activeStep}
                isActive={activeStep === ReleaseSteps.REVIEW}
              >
                {t("common.review")}
              </DialogStep>
              <DialogStep
                stepIndex={ReleaseSteps.CONFIRM}
                currentStepIndex={activeStep}
                isActive={activeStep === ReleaseSteps.CONFIRM}
              >
                {t("bridge.step.confirm.title")}
              </DialogStep>
            </DialogStepper>
            {activeStep === ReleaseSteps.CHECK ? (
              <ReleasePreCheck
                tx={bridgeTx}
                canContinue={canContinue}
                onCanContinueChange={setCanContinue}
                hideContinueButton={hideContinueButton}
                onHideContinueButtonChange={setHideContinueButton}
              />
            ) : activeStep === ReleaseSteps.REVIEW ? (
              <ReviewStep tx={bridgeTx} />
            ) : activeStep === ReleaseSteps.CONFIRM ? (
              <ClaimConfirmStep
                bridgeTx={bridgeTx}
                txHash={txHash as Hash}
                onClaim={handleReleaseClick}
                claiming={releasing}
                canClaim={canContinue}
                claimingDone={releasingDone}
              />
            ) : null}
            <div className="f-col text-left self-end h-full w-full">
              <div className="f-col gap-4 mt-[20px]">
                <ReleaseStepNavigation
                  activeStep={activeStep}
                  onActiveStepChange={setActiveStep}
                  canContinue={canContinue}
                  hideContinueButton={hideContinueButton}
                  loading={loading}
                  releasing={releasing}
                  releasingDone={releasingDone}
                  onCloseDialog={closeDialog}
                />
              </div>
            </div>
          </div>
        </div>
      </dialog>

      <Claim
        bridgeTx={bridgeTx}
        ref={ClaimComponent}
        onError={handleClaimError}
        onClaimingTxSent={handleClaimTxSent}
      />

      <OnAccount change={handleAccountChange} />
    </>
  );
}
