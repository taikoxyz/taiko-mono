"use client";

// React port of
// src/components/Dialogs/ClaimDialog/ClaimDialog.svelte.
//
// COMPONENT CONVENTION mapping:
//   - `export let dialogOpen` (two-way `bind:dialogOpen`) -> controlled
//     `dialogOpen` prop + `onDialogOpenChange(open)`. `closeDialog()` reports
//     `false` up (Svelte `dialogOpen = false`).
//   - `export let loading` (bound, READ-only here) -> `loading` prop.
//   - `export let nft / bridgeTx / directClaim` -> props.
//   - `export let activeStep` (two-way `bind:activeStep`) -> controlled
//     `activeStep` prop + `onActiveStepChange`. The component also mutates it
//     internally (reset()/step navigation), so it is mirrored into local state
//     seeded from the prop and every change is reported up.
//   - `export const handleClaimClick` (PUBLIC method) -> exposed via
//     `useImperativeHandle` on a forwarded ref (`ClaimDialogHandle`), AND wired
//     internally as the `onClaim` handler of `ClaimConfirmStep` (mirroring the
//     original `on:claim={handleClaimClick}`).
//   - `bind:this={ClaimComponent}` (calling `ClaimComponent.claim(...)`) -> a
//     ref to the `Claim` component exposing an imperative `claim()` method
//     (`ClaimHandle`). `Claim` is a sibling unit (not in this scope) and is
//     assumed to follow the COMPONENT CONVENTION + expose this handle.
//   - `createEventDispatcher` events:
//       dispatch('claimingDone')               -> onClaimingDone()
//       dispatch('insufficientFunds', { tx })   -> onInsufficientFunds({ tx })
//   - Child `bind:` props (canContinue, hideContinueButton, txHash, claiming,
//     claimingDone, canClaim) -> local state controlled into the children with
//     paired `onXChange` callbacks.
//   - `use:closeOnEscapeOrOutsideClick` -> useCloseOnEscapeOrOutsideClick hook.
//   - `<DesktopOrLarger bind:is={isDesktopOrLarger} />` -> useDesktopOrLarger().
//   - svelte-i18n `$t(key, { values })` -> react-i18next `t(key, { ... })`
//     (the `values` wrapper is dropped per the i18n migration).
//   - `$connectedSourceChain` -> useConnectedSourceChain().
//   - `pendingTransactions.add(...)` -> imperative vanilla store add (preserved).
//
// DOM / class strings preserved verbatim for pixel parity.

import {
  forwardRef,
  useEffect,
  useId,
  useImperativeHandle,
  useRef,
  useState,
} from "react";
import {
  ContractFunctionExecutionError,
  type Hash,
  UserRejectedRequestError,
} from "viem";

import { chainConfig } from "$chainConfig";
import { CloseButton } from "@/components/Button";
import { useDesktopOrLarger } from "@/components/DesktopOrLarger";
import Claim, { type ClaimHandle } from "@/components/Dialogs/Claim";
import {
  errorToast,
  infoToast,
  successToast,
  warningToast,
} from "@/components/NotificationToast";
import { OnAccount } from "@/components/OnAccount";
import type { BridgeTransaction } from "@/libs/bridge/types";
import { useCloseOnEscapeOrOutsideClick } from "@/libs/customActions";
import {
  InsufficientBalanceError,
  InvalidProofError,
  NotConnectedError,
  ProcessMessageError,
  RetryError,
} from "@/libs/error";
import type { NFT } from "@/libs/token";
import { getLogger } from "@/libs/util/logger";
import { useConnectedSourceChain } from "@/stores/network";
import { pendingTransactions } from "@/stores/pendingTransactions";
import { useTranslation } from "@/i18n/useTranslation";
import { cn } from "@/lib/utils";

import { ClaimConfirmStep, ReviewStep } from "../Shared";
import ClaimPreCheck from "../Shared/ClaimPreCheck";
import { ClaimAction } from "../Shared/types";
import { DialogStep, DialogStepper } from "../Stepper";
import ClaimStepNavigation from "./ClaimStepNavigation";
import { isMessageNotReceivedError } from "./error";
import { type ClaimDialogMode, shouldSkipMessageStatusCheck } from "./mode";
import { claimWithQuotaGuard, showQuotaToastForClaimError } from "./quota";
import { ClaimSteps, INITIAL_STEP } from "./types";

const log = getLogger("ClaimDialog");

export interface ClaimDialogHandle {
  /** Public method (Svelte `export const handleClaimClick`). */
  handleClaimClick: () => Promise<void>;
}

export interface ClaimDialogProps {
  /** Two-way `bind:dialogOpen`. */
  dialogOpen?: boolean;
  onDialogOpenChange?: (open: boolean) => void;

  loading?: boolean;

  nft?: NFT | null;

  /** Two-way `bind:activeStep`. */
  activeStep?: ClaimSteps;
  onActiveStepChange?: (step: ClaimSteps) => void;

  bridgeTx: BridgeTransaction;
  directClaim?: boolean;

  /** dispatch('claimingDone'). */
  onClaimingDone?: () => void;
  /** dispatch('insufficientFunds', { tx }). */
  onInsufficientFunds?: (detail: { tx: BridgeTransaction }) => void;
}

const ClaimDialog = forwardRef<ClaimDialogHandle, ClaimDialogProps>(
  function ClaimDialog(
    {
      dialogOpen = false,
      onDialogOpenChange,
      loading = false,
      nft = null,
      activeStep: activeStepProp = INITIAL_STEP,
      onActiveStepChange,
      bridgeTx,
      directClaim = false,
      onClaimingDone,
      onInsufficientFunds,
    },
    ref,
  ) {
    const { t } = useTranslation();

    // SSR-safe per-instance id (replaces Svelte `crypto.randomUUID()`).
    const dialogId = `dialog-${useId()}`;

    // $connectedSourceChain
    const connectedSourceChain = useConnectedSourceChain();

    const isDesktopOrLarger = useDesktopOrLarger();

    // Two-way `bind:activeStep` mirrored into local state seeded from the prop.
    const [activeStep, setActiveStepState] =
      useState<ClaimSteps>(activeStepProp);
    const setActiveStep = (step: ClaimSteps) => {
      setActiveStepState(step);
      onActiveStepChange?.(step);
    };
    // Keep local in sync if the parent pushes a new controlled value.
    useEffect(() => {
      setActiveStepState(activeStepProp);
    }, [activeStepProp]);

    // Original was `let force = false` tied to the (commented-out)
    // `canForceTransaction` logic; with that disabled it never reassigns.
    const force = false;
    // let canForceTransaction = false;
    const [canContinue, setCanContinue] = useState(false);
    const [claiming, setClaiming] = useState<boolean>(false);
    const [claimingDone, setClaimingDone] = useState(false);
    const claimComponentRef = useRef<ClaimHandle>(null);
    const [txHash, setTxHash] = useState<Hash>();
    const [hideContinueButton, setHideContinueButton] =
      useState<boolean>(false);

    // $: claimMode = directClaim ? 'try_claim' : 'claim';
    const claimMode: ClaimDialogMode = directClaim ? "try_claim" : "claim";

    const showQuotaReachedToast = () => {
      errorToast({
        title: t("bridge.errors.claim.quota_reached.title"),
        message: t("bridge.errors.claim.quota_reached.message"),
      });
    };

    const showUnknownErrorToast = () => {
      errorToast({
        title: t("bridge.errors.unknown_error.title"),
        message: t("bridge.errors.unknown_error.message"),
      });
    };

    const logQuotaCheckError = (quotaError: unknown) => {
      console.error("Failed to check claim quota", quotaError);
    };

    const handleClaimClick = async () => {
      await claimWithQuotaGuard({
        bridgeTx,
        claim: async () => {
          await claimComponentRef.current?.claim(
            ClaimAction.CLAIM,
            force,
            shouldSkipMessageStatusCheck(claimMode),
          );
        },
        setClaiming,
        showQuotaReachedToast,
        onQuotaCheckError: logQuotaCheckError,
      });
    };

    // Expose the public method (Svelte `export const handleClaimClick`).
    useImperativeHandle(ref, () => ({ handleClaimClick }));

    const reset = () => {
      setActiveStep(INITIAL_STEP);
      setClaimingDone(false);
      // canForceTransaction = false;
    };

    const handleAccountChange = () => {
      reset();
    };

    const closeDialog = () => {
      onDialogOpenChange?.(false);
      reset();
    };

    const handleClaimTxSent = async (detail: {
      txHash: Hash;
      action: ClaimAction;
    }) => {
      const { txHash: transactionHash, action } = detail;
      setTxHash(transactionHash);
      log("handle claim tx sent", transactionHash, action);
      setClaiming(true);

      const explorer = (
        chainConfig as Record<
          number,
          { blockExplorers?: { default: { url: string } } }
        >
      )[Number(bridgeTx.destChainId)]?.blockExplorers?.default.url;

      if (action === ClaimAction.CLAIM) {
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
      } else {
        // Retry
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
      }

      setClaimingDone(true);

      onClaimingDone?.();

      successToast({
        title: t("transactions.actions.claim.success.title"),
        message: t("transactions.actions.claim.success.message", {
          network: connectedSourceChain?.name,
        }),
      });
    };

    const handleClaimError = async (detail: {
      error: unknown;
      action: ClaimAction;
    }) => {
      //TODO: update this to display info alongside toasts
      const err = detail.error;
      // canForceTransaction = true;
      switch (true) {
        case err instanceof NotConnectedError:
          warningToast({ title: t("messages.account.required") });
          break;
        case err instanceof UserRejectedRequestError:
          warningToast({
            title: t("transactions.actions.claim.rejected.title"),
          });
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
          if (isMessageNotReceivedError(err)) {
            errorToast({
              title: t("bridge.errors.claim.not_received.title"),
              message: t("bridge.errors.claim.not_received.message"),
            });
          } else {
            if (
              !(await showQuotaToastForClaimError(err, bridgeTx, {
                showQuotaReachedToast,
                onQuotaCheckError: logQuotaCheckError,
              }))
            ) {
              showUnknownErrorToast();
            }
          }
          break;
        default:
          console.error(err);
          showUnknownErrorToast();
          break;
      }
      setClaiming(false);
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
          <div className="modal-box relative w-full bg-neutral-background absolute md:min-h-[600px]">
            <div className="w-full f-between-center">
              <CloseButton onClick={closeDialog} />
              <h3 className="title-body-bold">
                {t("transactions.claim.steps.title")}
              </h3>
            </div>
            <div className="h-sep mx-[-24px] mt-[20px]" />
            <div className="w-full h-full f-col">
              <DialogStepper>
                <DialogStep
                  stepIndex={ClaimSteps.CHECK}
                  currentStepIndex={activeStep}
                  isActive={activeStep === ClaimSteps.CHECK}
                >
                  {t("transactions.claim.steps.pre_check.title")}
                </DialogStep>
                <DialogStep
                  stepIndex={ClaimSteps.REVIEW}
                  currentStepIndex={activeStep}
                  isActive={activeStep === ClaimSteps.REVIEW}
                >
                  {t("common.review")}
                </DialogStep>
                <DialogStep
                  stepIndex={ClaimSteps.CONFIRM}
                  currentStepIndex={activeStep}
                  isActive={activeStep === ClaimSteps.CONFIRM}
                >
                  {t("bridge.step.confirm.title")}
                </DialogStep>
              </DialogStepper>
              {activeStep === ClaimSteps.CHECK ? (
                <ClaimPreCheck
                  tx={bridgeTx}
                  canContinue={canContinue}
                  onCanContinueChange={setCanContinue}
                  hideContinueButton={hideContinueButton}
                  onHideContinueButtonChange={setHideContinueButton}
                  onCloseDialog={closeDialog}
                />
              ) : activeStep === ClaimSteps.REVIEW ? (
                <ReviewStep tx={bridgeTx} nft={nft} />
              ) : activeStep === ClaimSteps.CONFIRM ? (
                <ClaimConfirmStep
                  bridgeTx={bridgeTx}
                  // Original `bind:txHash` — the child only READS it (it is never
                  // written back), so this is a read-only prop here. `txHash`
                  // starts undefined (Svelte `let txHash: Hash`); ClaimConfirmStep
                  // types it as required, so we forward the local value (cast to
                  // satisfy the prop) and the child guards its own usage on truthy
                  // `txHash && claimingDone`.
                  txHash={txHash as Hash}
                  onClaim={handleClaimClick}
                  claiming={claiming}
                  canClaim={canContinue}
                  claimingDone={claimingDone}
                />
              ) : null}
              <div className="f-col text-left self-end h-full w-full">
                <div className="f-col gap-4 mt-[20px]">
                  <ClaimStepNavigation
                    activeStep={activeStep}
                    onActiveStepChange={setActiveStep}
                    canContinue={canContinue}
                    loading={loading}
                    claiming={claiming}
                    hideContinueButton={hideContinueButton}
                    onCloseDialog={closeDialog}
                    claimingDone={claimingDone}
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
          onError={handleClaimError}
          onClaimingTxSent={handleClaimTxSent}
        />

        <OnAccount change={handleAccountChange} />
      </>
    );
  },
);

export default ClaimDialog;
