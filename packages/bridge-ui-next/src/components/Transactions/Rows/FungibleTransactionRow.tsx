"use client";

// React port of
// src/components/Transactions/Rows/FungibleTransactionRow.svelte.
//
// COMPONENT CONVENTION mapping:
//   - `export let bridgeTx / loading / bridgeTxStatus` -> typed props.
//   - `export let handleTransactionRemoved: (event: CustomEvent) => void` ->
//     `handleTransactionRemoved` callback prop. The original Status dispatches a
//     `BridgeTransaction` as the event detail; here `onTransactionRemoved` of the
//     ported `Status` forwards that detail and we re-wrap it so the parent's
//     `(event: CustomEvent) => void` signature is preserved verbatim.
//   - `bind:bridgeTxStatus` (two-way) -> controlled `bridgeTxStatus` prop +
//     `onBridgeTxStatusChange`. The original mutates it via `handleClaimingDone`
//     / `handleStatusChange`; both are mirrored into local state seeded from the
//     prop and reported up.
//   - Reactive `$:` blocks -> useMemo.
//   - Store `$account` -> `useAccount` hook over the ported vanilla account store.
//   - Store `$isDesktop/$isTablet/$isMobile` -> `useResponsive()` hook.
//   - svelte-i18n `$t(key)` -> react-i18next `t(key)`.
//   - `on:click` -> `onClick`. Dynamic `{...attrs}` (role=button on non-desktop)
//     preserved.
//   - Child dialogs (`InsufficientFunds`, `DesktopDetailsDialog`,
//     `MobileDetailsDialog`, `RetryDialog`, `ReleaseDialog`, `ClaimDialog`) and
//     `Status` / `ChainSymbol` are sibling units (some not yet written) assumed
//     to follow the COMPONENT CONVENTION: `bind:x` -> `x` + `onXChange`,
//     `on:event` -> `onEvent` callbacks, `bind:dialogOpen` ->
//     `dialogOpen`/`onDialogOpenChange`, etc.
//   - The `<style>` block (.dashed-border / .before-circle / .after-circle) is
//     scoped CSS in svelte; ported to a co-located CSS module imported below so
//     the exact `--primary-border-dark` driven pseudo-elements render identically.
//
// DOM / Tailwind class strings preserved verbatim for pixel parity.

import { memo, useEffect, useMemo, useState } from "react";
import { formatEther, formatUnits, hexToBigInt } from "viem";

import { ClaimDialog, ReleaseDialog, RetryDialog } from "@/components/Dialogs";
import { Spinner } from "@/components/Spinner";
import { DesktopDetailsDialog } from "@/components/Transactions/Dialogs";
import type { BridgeTransaction, MessageStatus } from "@/libs/bridge";
import { getMessageStatusForMsgHash } from "@/libs/bridge/getMessageStatusForMsgHash";
import { TokenType } from "@/libs/token";
import { classNames } from "@/libs/util/classNames";
import { formatTimestamp } from "@/libs/util/formatTimestamp";
import { geBlockTimestamp } from "@/libs/util/getBlockTimestamp";
import { shortenAddress } from "@/libs/util/shortenAddress";
import { useResponsive } from "@/hooks/useResponsive";
import { useTranslation } from "@/i18n/useTranslation";
import { useAccount } from "@/stores/account";

import ChainSymbol from "../ChainSymbol";
import MobileDetailsDialog from "../Dialogs/MobileDetailsDialog";
import InsufficientFunds from "../InsufficientFunds";
import { Status } from "../Status";

import styles from "./TransactionRow.module.css";

export interface FungibleTransactionRowProps {
  bridgeTx: BridgeTransaction;
  loading?: boolean;
  handleTransactionRemoved: (event: CustomEvent) => void;
  /** Two-way `bind:bridgeTxStatus`. */
  bridgeTxStatus: Maybe<MessageStatus>;
  onBridgeTxStatusChange?: (status: Maybe<MessageStatus>) => void;
}

function FungibleTransactionRow({
  bridgeTx,
  loading = false,
  handleTransactionRemoved,
  bridgeTxStatus: bridgeTxStatusProp,
  onBridgeTxStatusChange,
}: FungibleTransactionRowProps) {
  const { t } = useTranslation();

  const { isDesktop, isTablet, isMobile } = useResponsive();
  const isConnected = useAccount((a) => a?.isConnected ?? false);

  // Two-way `bind:bridgeTxStatus`.
  const [bridgeTxStatus, setBridgeTxStatusState] =
    useState<Maybe<MessageStatus>>(bridgeTxStatusProp);
  const setBridgeTxStatus = (status: Maybe<MessageStatus>) => {
    setBridgeTxStatusState(status);
    onBridgeTxStatusChange?.(status);
  };
  useEffect(() => {
    setBridgeTxStatusState(bridgeTxStatusProp);
  }, [bridgeTxStatusProp]);

  const [insufficientModal, setInsufficientModal] = useState(false);
  const [mobileDetailsOpen, setMobileDetailsOpen] = useState(false);
  const [desktopDetailsOpen, setDesktopDetailsOpen] = useState(false);
  const [directClaim, setDirectClaim] = useState(false);

  const [timestamp, setTimestamp] = useState<string>();

  // Modal states (originally `$: claimModalOpen = false` etc.)
  const [claimModalOpen, setClaimModalOpen] = useState(false);
  const [retryModalOpen, setRetryModalOpen] = useState(false);
  const [releaseModalOpen, setReleaseModalOpen] = useState(false);
  const interactiveDialogsOpen =
    claimModalOpen || retryModalOpen || releaseModalOpen;

  const getDate = async () => {
    if (!bridgeTx.blockNumber) return;
    const blockTimestamp = await geBlockTimestamp(
      BigInt(bridgeTx.srcChainId),
      hexToBigInt(bridgeTx.blockNumber),
    );
    setTimestamp(formatTimestamp(Number(blockTimestamp)));
  };

  const handleOpenClaimModal = (detail: string) => {
    if (detail === "retry") {
      setRetryModalOpen(true);
    } else if (detail === "release") {
      setReleaseModalOpen(true);
    } else if (detail === "claim") {
      setDirectClaim(false);
      setClaimModalOpen(true);
    } else if (detail === "try_claim") {
      setDirectClaim(true);
      setClaimModalOpen(true);
    }
  };

  const handleInsufficientFunds = () => {
    setInsufficientModal(true);
  };

  async function handleClaimingDone() {
    // Keeping model and UI in sync
    bridgeTx.msgStatus = await getMessageStatusForMsgHash({
      msgHash: bridgeTx.msgHash,
      srcChainId: Number(bridgeTx.srcChainId),
      destChainId: Number(bridgeTx.destChainId),
    });
    setBridgeTxStatus(bridgeTx.msgStatus);
  }

  const openDetails = () => {
    if (isMobile && !interactiveDialogsOpen) {
      setMobileDetailsOpen(true);
    } else if ((isTablet || isDesktop) && !interactiveDialogsOpen) {
      setDesktopDetailsOpen(true);
    }
  };

  const handleStatusChange = (status: MessageStatus) => {
    setBridgeTxStatus(status);
  };

  const closeDetails = () => {
    setMobileDetailsOpen(false);
    setDesktopDetailsOpen(false);
  };

  // Dynamic attributes based on screen size
  const attrs = isDesktop ? {} : { role: "button" as const };

  // get tx timestamp
  useEffect(() => {
    if (isConnected) getDate();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isConnected, bridgeTx.blockNumber, bridgeTx.srcChainId]);

  // Dynamic classes
  const containerClasses = useMemo(() => {
    const commonContainerClasses = classNames(
      "flex text-primary-content md:h-[80px] h-[70px] w-full my-[5px] md:my-[0px] hover:bg-[#C8047D]/10 px-[14px] py-[10px] rounded-[10px]",
    );
    const desktopContainerClasses = classNames(
      commonContainerClasses,
      "items-center",
    );
    const tabletContainerClasses = classNames(
      commonContainerClasses,
      "cursor-pointer",
    );
    const mobileContainerClasses = classNames(
      commonContainerClasses,
      "cursor-pointer",
      styles["dashed-border"],
    );

    return isDesktop
      ? desktopContainerClasses
      : isTablet
        ? tabletContainerClasses
        : mobileContainerClasses;
  }, [isDesktop, isTablet]);

  const columnClasses = useMemo(() => {
    const commonColumnClasses = classNames(" relative items-end");
    const desktopColumnClasses = classNames(
      commonColumnClasses,
      "w-1/6 f-row justify-center md:justify-start items-center",
    );
    const tabletColumnClasses = classNames(
      commonColumnClasses,
      "w-1/4 f-row  text-left start items-center text-sm space-y-[10px]",
    );
    const mobileColumnClasses = classNames(
      commonColumnClasses,
      "w-1/3 justify-center f-col text-sm space-y-[10px]",
    );

    return isDesktop
      ? desktopColumnClasses
      : isTablet
        ? tabletColumnClasses
        : mobileColumnClasses;
  }, [isDesktop, isTablet]);

  return (
    <>
      {/* svelte-ignore a11y-no-static-element-interactions */}
      <div className={containerClasses} onClick={openDetails} {...attrs}>
        {/* Mobile */}
        {isMobile ? (
          <>
            <div className={styles["before-circle"]}></div>
            <div className={styles["after-circle"]}></div>
            <div className={`${columnClasses} !items-start pl-[10px]`}>
              <div className="f-row md:hidden">
                <ChainSymbol
                  className="min-w-[24px]"
                  chainId={bridgeTx.srcChainId}
                />
                {shortenAddress(bridgeTx.message?.from, 4, 3)}
              </div>
              <div className="f-row md:hidden">
                <ChainSymbol
                  className="min-w-[24px]"
                  chainId={bridgeTx.destChainId}
                />
                {shortenAddress(bridgeTx.message?.to, 4, 3)}
              </div>
            </div>
          </>
        ) : isDesktop || isTablet ? (
          <>
            {/* Desktop */}
            <div className={`${columnClasses}`}>
              <ChainSymbol
                className="min-w-[24px]"
                chainId={bridgeTx.srcChainId}
              />
              {shortenAddress(bridgeTx.message?.from)}
            </div>
            <div className={`${columnClasses} `}>
              <ChainSymbol
                className="min-w-[24px]"
                chainId={bridgeTx.destChainId}
              />
              {shortenAddress(bridgeTx.message?.to)}
            </div>
          </>
        ) : null}

        <div className={`${columnClasses} items-center`}>
          {bridgeTx.tokenType === TokenType.ERC20
            ? formatUnits(
                bridgeTx.amount ? bridgeTx.amount : BigInt(0),
                bridgeTx.decimals ?? 0,
              )
            : bridgeTx.tokenType === TokenType.ETH
              ? formatEther(bridgeTx.amount ? bridgeTx.amount : BigInt(0))
              : null}{" "}
          {bridgeTx.symbol}
        </div>

        <div className={`${columnClasses}`}>
          <Status
            bridgeTx={bridgeTx}
            onTransactionRemoved={(tx: BridgeTransaction) =>
              handleTransactionRemoved(
                new CustomEvent("transactionRemoved", { detail: tx }),
              )
            }
            bridgeTxStatus={bridgeTxStatus}
            onBridgeTxStatusChange={setBridgeTxStatus}
            onOpenModal={handleOpenClaimModal}
            onInsufficientFunds={handleInsufficientFunds}
            onStatusChange={handleStatusChange}
          />
        </div>

        {isDesktop ? (
          <>
            <div className={`${columnClasses}  `}>
              {/* Original passed `<Spinner size={12} />`; the svelte Spinner ignored
                  `size` (only consumed `$$props.class`), so it rendered at the default
                  w-6/h-6. The ported Spinner exposes no `size` prop, so it is dropped
                  here with no visual change. */}
              {timestamp ? timestamp : <Spinner />}
            </div>

            <div className="flex w-1/6 py-2 flex flex-col justify-center">
              <button
                className="flex justify-end pr-[24px] py-3 link"
                onClick={openDetails}
              >
                {t("transactions.link.view")}
              </button>
            </div>
          </>
        ) : null}
      </div>

      <InsufficientFunds
        modalOpen={insufficientModal}
        onModalOpenChange={setInsufficientModal}
      />

      {/* The original Svelte parent attached `on:insufficientFunds` to these two
          detail dialogs, but neither dialog ever dispatches that event (no
          `createEventDispatcher`), so it was a no-op listener. Dropped here. */}
      <DesktopDetailsDialog
        detailsOpen={desktopDetailsOpen}
        token={null}
        closeDetails={closeDetails}
        bridgeTx={bridgeTx}
      />

      <MobileDetailsDialog
        detailsOpen={mobileDetailsOpen}
        token={null}
        closeDetails={closeDetails}
        bridgeTx={bridgeTx}
      />

      <RetryDialog
        bridgeTx={bridgeTx}
        dialogOpen={retryModalOpen}
        onDialogOpenChange={setRetryModalOpen}
      />

      <ReleaseDialog
        bridgeTx={bridgeTx}
        dialogOpen={releaseModalOpen}
        onDialogOpenChange={setReleaseModalOpen}
      />

      <ClaimDialog
        bridgeTx={bridgeTx}
        directClaim={directClaim}
        loading={loading}
        dialogOpen={claimModalOpen}
        onDialogOpenChange={setClaimModalOpen}
        onClaimingDone={() => handleClaimingDone()}
      />
    </>
  );
}

// Memoized: rows live in the paginated Transactions list and each runs its own
// status polling. With stable `bridgeTx` (from the memoized page slice) and a
// stable `handleTransactionRemoved` callback, this avoids re-rendering every
// visible row whenever the parent Transactions view re-renders.
export default memo(FungibleTransactionRow);
