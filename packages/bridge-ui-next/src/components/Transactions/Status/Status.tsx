"use client";

// React port of
// components/Transactions/Status/Status.svelte.
//
// COMPONENT CONVENTION mapping:
//   - `export let bridgeTx / bridgeTxStatus / textOnly` -> typed props.
//   - `bind:bridgeTxStatus` (two-way) -> controlled `bridgeTxStatus` prop +
//     `onBridgeTxStatusChange`. The original mutates `bridgeTxStatus` inside
//     `onStatusChange` and `onMount`; both are mirrored into local state seeded
//     from the prop and reported up.
//   - `dispatch('statusChange', status)`     -> `onStatusChange(status)`.
//   - `dispatch('openModal', detail)`        -> `onOpenModal(detail)`.
//   - `dispatch('transactionRemoved', tx)`   -> `onTransactionRemoved(tx)`.
//   - `onInsufficientFunds` is accepted (callers pass it) but, like the original
//     Svelte component, is never invoked here — kept optional for API parity.
//   - Reactive `$: showManualClaimEntry = ...`            -> useMemo.
//   - Reactive `$: if (hasError && $account.address) {...}` -> useEffect.
//   - `onMount`/`onDestroy` (start/stop polling)          -> useEffect + cleanup.
//   - Store `$account`               -> `useAccount` hook over the vanilla account store.
//   - Store `$connectedSourceChain`  -> `useConnectedSourceChain` hook.
//   - svelte-i18n `$t(key)`          -> react-i18next `t(key)`.
//   - `on:click`                     -> `onClick`.
//
// DOM / Tailwind class strings preserved verbatim for pixel parity.

import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { Spinner } from "@/components/Spinner";
import { StatusDot } from "@/components/StatusDot";
import { type BridgeTransaction, MessageStatus } from "@/libs/bridge";
import { isTransactionProcessable } from "@/libs/bridge/isTransactionProcessable";
import { PollingEvent, startPolling } from "@/libs/polling/messageStatusPoller";
import { bridgeTxService } from "@/libs/storage";
import { isBridgePaused } from "@/libs/util/checkForPausedContracts";
import { useTranslation } from "@/i18n/useTranslation";
import { useAccount } from "@/stores/account";
import { useConnectedSourceChain } from "@/stores/network";

import {
  assertBridgeNotPaused,
  shouldShowManualClaimEntry,
} from "./statusHelpers";

export interface StatusProps {
  bridgeTx: BridgeTransaction;
  /** Two-way `bind:bridgeTxStatus`. */
  bridgeTxStatus: Maybe<MessageStatus>;
  onBridgeTxStatusChange?: (status: Maybe<MessageStatus>) => void;
  textOnly?: boolean;
  /** Svelte `dispatch('statusChange', status)`. */
  onStatusChange?: (status: MessageStatus) => void;
  /** Svelte `dispatch('openModal', detail)`. */
  onOpenModal?: (detail: string) => void;
  /** Svelte `dispatch('transactionRemoved', bridgeTx)`. */
  onTransactionRemoved?: (bridgeTx: BridgeTransaction) => void;
  /** Accepted for caller API parity; unused (matches original Svelte). */
  onInsufficientFunds?: () => void;
}

export default function Status({
  bridgeTx,
  bridgeTxStatus: bridgeTxStatusProp,
  onBridgeTxStatusChange,
  textOnly = false,
  onStatusChange,
  onOpenModal,
  onTransactionRemoved,
}: StatusProps) {
  const { t } = useTranslation();

  const $account = useAccount((a) => a);
  const $connectedSourceChain = useConnectedSourceChain();

  // Two-way `bind:bridgeTxStatus`.
  const [bridgeTxStatus, setBridgeTxStatusState] =
    useState<Maybe<MessageStatus>>(bridgeTxStatusProp);
  const setBridgeTxStatus = useCallback(
    (status: Maybe<MessageStatus>) => {
      setBridgeTxStatusState(status);
      onBridgeTxStatusChange?.(status);
    },
    [onBridgeTxStatusChange],
  );
  useEffect(() => {
    setBridgeTxStatusState(bridgeTxStatusProp);
  }, [bridgeTxStatusProp]);

  // UI state
  const [isProcessable, setIsProcessable] = useState(false); // bridge tx state to be processed: claimed/retried/released
  const pollingRef = useRef<ReturnType<typeof startPolling> | null>(null);
  const [loading] = useState<false | string>(false);
  const [hasError, setHasError] = useState(false);

  // $: showManualClaimEntry = shouldShowManualClaimEntry({...})
  const showManualClaimEntry = useMemo(
    () =>
      shouldShowManualClaimEntry({
        bridgeTxStatus,
        isProcessable,
        processingFee: bridgeTx.processingFee,
      }),
    [bridgeTxStatus, isProcessable, bridgeTx.processingFee],
  );

  const onProcessable = useCallback((isTxProcessable: boolean) => {
    setIsProcessable(isTxProcessable);
  }, []);

  const onStatusChangeHandler = useCallback(
    (status: MessageStatus) => {
      // Keeping model and UI in sync
      bridgeTx.msgStatus = status;
      setBridgeTxStatus(status);
      onStatusChange?.(status);
    },
    [bridgeTx, setBridgeTxStatus, onStatusChange],
  );

  async function handleRetryClick() {
    assertBridgeNotPaused(await isBridgePaused());
    if (!$connectedSourceChain || !$account?.address) return;
    // retryModalOpen = true;
    onOpenModal?.("retry");
  }

  async function handleReleaseClick() {
    assertBridgeNotPaused(await isBridgePaused());
    if (!$connectedSourceChain || !$account?.address) return;
    // releaseModalOpen = true;
    onOpenModal?.("release");
  }

  async function handleClaimClick() {
    assertBridgeNotPaused(await isBridgePaused());
    if (!$connectedSourceChain || !$account?.address) return;

    // claimModalOpen = true;
    onOpenModal?.("claim");
  }

  async function handleTryClaimClick() {
    assertBridgeNotPaused(await isBridgePaused());
    if (!$connectedSourceChain || !$account?.address) return;

    onOpenModal?.("try_claim");
  }

  // $: if (hasError && $account.address) { ... }
  useEffect(() => {
    if (hasError && $account?.address) {
      if (
        bridgeTxService.transactionIsStoredLocally($account.address, bridgeTx)
      ) {
        // If we can't start polling, it maybe an old/outdated transaction in the local storage, so we remove it
        bridgeTxService.removeTransactions($account.address, [bridgeTx]);
        if (
          !bridgeTxService.transactionIsStoredLocally(
            $account.address,
            bridgeTx,
          )
        ) {
          onTransactionRemoved?.(bridgeTx);
        }
      }
    }
  }, [hasError, $account?.address, bridgeTx, onTransactionRemoved]);

  // onMount: seed status, resolve processability, start polling.
  // onDestroy: stop polling.
  useEffect(() => {
    let cancelled = false;

    (async () => {
      if (bridgeTx && $account?.address) {
        setBridgeTxStatus(bridgeTx.msgStatus);

        // Can we start claiming/retrying/releasing?
        const processable = await isTransactionProcessable(bridgeTx);
        if (cancelled) return;
        setIsProcessable(processable);

        try {
          const polling = startPolling(bridgeTx);
          pollingRef.current = polling;

          // If there is no emitter, means the bridgeTx is already DONE
          // so we do nothing here
          if (polling?.emitter) {
            // The following listeners will trigger change in the UI
            polling.emitter.on(PollingEvent.PROCESSABLE, onProcessable);
            polling.emitter.on(PollingEvent.STATUS, onStatusChangeHandler);
          }
        } catch (err) {
          console.warn("Cannot start polling", err);
          setHasError(true);
        }
      }
    })();

    return () => {
      cancelled = true;
      if (pollingRef.current) {
        pollingRef.current.destroy();
        pollingRef.current = null;
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="Status f-items-center space-x-1">
      {showManualClaimEntry ? (
        textOnly ? (
          <>
            <StatusDot type="pending" />
            <span>{t("transactions.status.processing.name")}</span>
          </>
        ) : (
          <button className="status-btn" onClick={handleTryClaimClick}>
            {t("transactions.button.try_claim")}
          </button>
        )
      ) : !isProcessable ? (
        <>
          <StatusDot type="pending" />
          <span>{t("transactions.status.processing.name")}</span>
        </>
      ) : loading ? (
        <div className="f-items-center space-x-2">
          <Spinner />
          <span>{t(`transactions.status.${loading}`)}</span>
        </div>
      ) : bridgeTxStatus === MessageStatus.NEW ? (
        textOnly ? (
          <>
            <StatusDot type="pending" />
            <span>{t("transactions.status.claimable")}</span>
          </>
        ) : (
          <button className="status-btn" onClick={handleClaimClick}>
            {t("transactions.button.claim")}
          </button>
        )
      ) : bridgeTxStatus === MessageStatus.RETRIABLE ? (
        textOnly ? (
          <>
            <StatusDot type="pending" />
            <span>{t("transactions.status.retriable")}</span>
          </>
        ) : (
          <button className="status-btn" onClick={handleRetryClick}>
            {t("transactions.button.retry")}
          </button>
        )
      ) : bridgeTxStatus === MessageStatus.DONE ? (
        <>
          <StatusDot type="success" />
          <span>{t("transactions.status.claimed.name")}</span>
        </>
      ) : bridgeTxStatus === MessageStatus.FAILED ? (
        textOnly ? (
          <>
            <StatusDot type="pending" />
            <span>{t("transactions.status.releasable")}</span>
          </>
        ) : (
          <button className="status-btn" onClick={handleReleaseClick}>
            {t("transactions.button.release")}
          </button>
        )
      ) : bridgeTxStatus === MessageStatus.RECALLED ? (
        <>
          <StatusDot type="error" />
          <span>{t("transactions.status.released.name")}</span>
        </>
      ) : (
        <>
          {/* TODO: look into this possible state */}
          <StatusDot type="error" />
          <span>{t("transactions.status.error.name")}</span>
        </>
      )}
    </div>
  );
}
