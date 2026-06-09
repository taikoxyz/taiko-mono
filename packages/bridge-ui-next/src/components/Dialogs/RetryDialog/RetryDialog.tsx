"use client";

// React port of
// src/components/Dialogs/RetryDialog/RetryDialog.svelte.
//
// COMPONENT CONVENTION mapping:
//   - `export let dialogOpen` (two-way `bind:dialogOpen`) -> controlled
//     `dialogOpen` prop + `onDialogOpenChange(open)`. `closeDialog()` reports
//     `false` up (Svelte `dialogOpen = false`).
//   - `export let bridgeTx` -> prop.
//   - `export let loading` (bound, READ-only here) -> `loading` prop.
//   - `export let activeStep` (two-way `bind:activeStep`) -> controlled
//     `activeStep` prop + `onActiveStepChange`. The component also mutates it
//     internally (reset()/step navigation), so it is mirrored into local state
//     seeded from the prop and every change is reported up.
//   - `export const handleClaimClick` (PUBLIC method) -> exposed via
//     `useImperativeHandle` on a forwarded ref (`RetryDialogHandle`), AND wired
//     internally as the `onClaim` handler of `ClaimConfirmStep` (mirroring the
//     original `on:claim={handleClaimClick}`).
//   - `bind:this={ClaimComponent}` (calling `ClaimComponent.claim(...)`) -> a
//     ref to the shared `Claim` component exposing an imperative `claim()`
//     method (`ClaimHandle`). `Claim` is a sibling unit (Dialogs/Claim) and is
//     assumed to follow the COMPONENT CONVENTION + expose this handle.
//   - `createEventDispatcher` events:
//       dispatch('retryDone') -> onRetryDone()
//   - Child `bind:` props (canContinue, hideContinueButton, txHash, claiming
//     [`retrying`], retryDone) -> local state controlled into the children with
//     paired `onXChange` callbacks.
//   - `use:closeOnEscapeOrOutsideClick` -> useCloseOnEscapeOrOutsideClick hook.
//   - `<DesktopOrLarger bind:is={isDesktopOrLarger} />` -> useDesktopOrLarger().
//   - svelte-i18n `$t(key, { values })` -> react-i18next `t(key, { ... })`
//     (the `values` wrapper is dropped per the i18n migration).
//   - `$selectedRetryMethod = RETRY_OPTION.CONTINUE` -> selectedRetryMethod
//     vanilla store `.setState(...)` (imperative reset).
//   - `pendingTransactions.add(...)` -> imperative vanilla store add (preserved).
//
// DOM / class strings preserved verbatim for pixel parity.

import {
  forwardRef,
  useEffect,
  useImperativeHandle,
  useRef,
  useState,
} from "react";
import type { Hash } from "viem";

import { chainConfig } from "$chainConfig";
import { CloseButton } from "@/components/Button";
import { useDesktopOrLarger } from "@/components/DesktopOrLarger";
import Claim, { type ClaimHandle } from "@/components/Dialogs/Claim";
import { infoToast, successToast } from "@/components/NotificationToast";
import { OnAccount } from "@/components/OnAccount";
import type { BridgeTransaction } from "@/libs/bridge";
import { useCloseOnEscapeOrOutsideClick } from "@/libs/customActions";
import { getLogger } from "@/libs/util/logger";
import { useTranslation } from "@/i18n/useTranslation";
import { cn } from "@/lib/utils";
import { pendingTransactions } from "@/stores/pendingTransactions";

import ClaimConfirmStep from "../Shared/ClaimConfirmStep";
import ClaimPreCheck from "../Shared/ClaimPreCheck";
import ReviewStep from "../Shared/ReviewStep";
import { ClaimAction } from "../Shared/types";
import DialogStep from "../Stepper/DialogStep";
import DialogStepper from "../Stepper/DialogStepper";
import RetryStepNavigation from "./RetryStepNavigation";
import RetryOptionStep from "./RetrySteps/RetryOptionStep";
import { selectedRetryMethod } from "./state";
import { INITIAL_STEP, RETRY_OPTION, RetrySteps } from "./types";

const log = getLogger("RetryDialog");

export interface RetryDialogHandle {
  /** Public method (Svelte `export const handleClaimClick`). */
  handleClaimClick: () => Promise<void>;
}

export interface RetryDialogProps {
  /** Two-way `bind:dialogOpen`. */
  dialogOpen?: boolean;
  onDialogOpenChange?: (open: boolean) => void;

  bridgeTx: BridgeTransaction;

  loading?: boolean;

  /** Two-way `bind:activeStep`. */
  activeStep?: RetrySteps;
  onActiveStepChange?: (step: RetrySteps) => void;

  /** dispatch('retryDone'). */
  onRetryDone?: () => void;
}

const RetryDialog = forwardRef<RetryDialogHandle, RetryDialogProps>(
  function RetryDialog(
    {
      dialogOpen = false,
      onDialogOpenChange,
      bridgeTx,
      loading = false,
      activeStep: activeStepProp = INITIAL_STEP,
      onActiveStepChange,
      onRetryDone,
    },
    ref,
  ) {
    const { t } = useTranslation();

    const dialogIdRef = useRef<string>(`dialog-${crypto.randomUUID()}`);
    const dialogId = dialogIdRef.current;

    const isDesktopOrLarger = useDesktopOrLarger();

    // Two-way `bind:activeStep` mirrored into local state seeded from the prop.
    const [activeStep, setActiveStepState] =
      useState<RetrySteps>(activeStepProp);
    const setActiveStep = (step: RetrySteps) => {
      setActiveStepState(step);
      onActiveStepChange?.(step);
    };
    // Keep local in sync if the parent pushes a new controlled value.
    useEffect(() => {
      setActiveStepState(activeStepProp);
    }, [activeStepProp]);

    const [canContinue, setCanContinue] = useState(false);
    // let retrying: boolean;
    const [retrying, setRetrying] = useState<boolean>(false);
    const [retryDone, setRetryDone] = useState(false);
    const claimComponentRef = useRef<ClaimHandle>(null);
    const [hideContinueButton, setHideContinueButton] =
      useState<boolean>(false);
    // let txHash: Hash;
    const [txHash, setTxHash] = useState<Hash>();

    const handleRetryError = () => {
      setRetrying(false);
    };

    const reset = () => {
      setActiveStep(INITIAL_STEP);
      selectedRetryMethod.setState(RETRY_OPTION.CONTINUE);
      setRetryDone(false);
    };

    const handleAccountChange = () => {
      reset();
    };

    const closeDialog = () => {
      onDialogOpenChange?.(false);
      reset();
    };

    const handleClaimClick = async () => {
      setRetrying(true);
      await claimComponentRef.current?.claim(ClaimAction.RETRY);
    };

    // Expose the public method (Svelte `export const handleClaimClick`).
    useImperativeHandle(ref, () => ({ handleClaimClick }));

    // The shared `Claim` component dispatches `claimingTxSent` with `{ txHash, action }`
    // (see ClaimDialog's `handleClaimTxSent`). The source RetryDialog only reads
    // `txHash`, so `action` is accepted but ignored to stay compatible with the
    // assumed `Claim` handle's callback signature.
    const handleRetryTxSent = async (detail: {
      txHash: Hash;
      action: ClaimAction;
    }) => {
      const { txHash: transactionHash } = detail;
      setTxHash(transactionHash);
      log("handle claim tx sent", transactionHash);
      setRetrying(true);

      const explorer = (
        chainConfig as Record<
          number,
          { blockExplorers?: { default: { url: string } } }
        >
      )[Number(bridgeTx.destChainId)]?.blockExplorers?.default.url;
      log("explorer", explorer);
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

      setRetryDone(true);

      onRetryDone?.();

      successToast({
        title: t("transactions.actions.claim.success.title"),
        // NOTE: the source reuses the `claim.tx.message` key here (not the
        // `success.message` key) and passes only `url` — preserved verbatim.
        message: t("transactions.actions.claim.tx.message", {
          url: `${explorer}/tx/${transactionHash}`,
        }),
      });
    };

    const dialogRef = useRef<HTMLDialogElement>(null);
    useCloseOnEscapeOrOutsideClick(dialogRef, {
      enabled: dialogOpen,
      callback: closeDialog,
      uuid: dialogId,
    });

    return (
      <>
        <dialog
          ref={dialogRef}
          id={dialogId}
          className={cn(
            "modal",
            isDesktopOrLarger ? "" : "modal-bottom",
            dialogOpen && "modal-open",
          )}
        >
          <div className="modal-box relative px-6 py-[35px] w-full bg-neutral-background absolute">
            <div className="w-full f-between-center">
              <CloseButton onClick={closeDialog} />
              <h3 className="title-body-bold">
                {t("transactions.retry.steps.title")}
              </h3>
            </div>
            <div className="h-sep mx-[-24px] mt-[20px]" />

            <div className="w-full h-full f-col">
              <DialogStepper>
                <DialogStep
                  stepIndex={RetrySteps.CHECK}
                  currentStepIndex={activeStep}
                  isActive={activeStep === RetrySteps.CHECK}
                >
                  {t("transactions.claim.steps.pre_check.title")}
                </DialogStep>
                <DialogStep
                  stepIndex={RetrySteps.SELECT}
                  currentStepIndex={activeStep}
                  isActive={activeStep === RetrySteps.SELECT}
                >
                  {t("transactions.retry.steps.select.title")}
                </DialogStep>
                <DialogStep
                  stepIndex={RetrySteps.REVIEW}
                  currentStepIndex={activeStep}
                  isActive={activeStep === RetrySteps.REVIEW}
                >
                  {t("common.review")}
                </DialogStep>
                <DialogStep
                  stepIndex={RetrySteps.CONFIRM}
                  currentStepIndex={activeStep}
                  isActive={activeStep === RetrySteps.CONFIRM}
                >
                  {t("common.confirm")}
                </DialogStep>
              </DialogStepper>

              {activeStep === RetrySteps.CHECK ? (
                <ClaimPreCheck
                  tx={bridgeTx}
                  canContinue={canContinue}
                  onCanContinueChange={setCanContinue}
                  hideContinueButton={hideContinueButton}
                  onHideContinueButtonChange={setHideContinueButton}
                  onCloseDialog={closeDialog}
                />
              ) : activeStep === RetrySteps.SELECT ? (
                <RetryOptionStep
                  canContinue={canContinue}
                  onCanContinueChange={setCanContinue}
                />
              ) : activeStep === RetrySteps.REVIEW ? (
                <ReviewStep tx={bridgeTx} />
              ) : activeStep === RetrySteps.CONFIRM ? (
                <ClaimConfirmStep
                  bridgeTx={bridgeTx}
                  // Original `bind:txHash` — the child only READS it, so this is a
                  // read-only prop here. `txHash` starts undefined; ClaimConfirmStep
                  // types it as required, so we forward the local value (cast to
                  // satisfy the prop) and the child guards on truthy `txHash`.
                  txHash={txHash as Hash}
                  onClaim={handleClaimClick}
                  claiming={retrying}
                  canClaim={canContinue}
                  claimingDone={retryDone}
                />
              ) : null}
              <div className="f-col text-left self-end h-full w-full">
                <div className="f-col gap-4 mt-[20px]">
                  <RetryStepNavigation
                    activeStep={activeStep}
                    onActiveStepChange={setActiveStep}
                    canContinue={canContinue}
                    loading={loading}
                    retrying={retrying}
                    onCloseDialog={closeDialog}
                    retryDone={retryDone}
                  />
                </div>
              </div>
            </div>
          </div>
          <button className="overlay-backdrop" data-modal-uuid={dialogId} />
        </dialog>

        <Claim
          ref={claimComponentRef}
          bridgeTx={bridgeTx}
          onError={handleRetryError}
          onClaimingTxSent={handleRetryTxSent}
        />

        <OnAccount change={handleAccountChange} />
      </>
    );
  },
);

export default RetryDialog;
