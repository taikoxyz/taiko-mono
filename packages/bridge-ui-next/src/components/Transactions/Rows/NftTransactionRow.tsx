"use client";

// React port of
// src/components/Transactions/Rows/NftTransactionRow.svelte.
//
// COMPONENT CONVENTION mapping (same as FungibleTransactionRow plus NFT bits):
//   - `export let bridgeTx / loading / bridgeTxStatus` -> typed props.
//   - `export let handleTransactionRemoved: (event: CustomEvent) => void` ->
//     callback prop; the ported `Status`'s `onTransactionRemoved(detail)` is
//     re-wrapped into a `CustomEvent` to preserve the parent signature.
//   - `bind:bridgeTxStatus` -> controlled `bridgeTxStatus` + `onBridgeTxStatusChange`.
//   - `bind:loading` -> local `loading` state (mutated by `analyzeTransactionInput`),
//     reported up via `onLoadingChange` and consumed by the dialogs.
//   - `let token: NFT` (resolved async) -> local state.
//   - Reactive `$:` -> useMemo / useEffect.
//   - Stores `$account` / `$isDesktop|$isTablet|$isMobile` -> hooks.
//   - svelte-i18n `$t(key)` -> react-i18next `t(key)`.
//   - Sibling/child units (Status, ChainSymbol, dialogs) assumed to follow the
//     COMPONENT CONVENTION.
//   - Scoped `<style>` ported to the shared `TransactionRow.module.css`.
//
// DOM / Tailwind class strings preserved verbatim for pixel parity.

import { memo, useEffect, useMemo, useState } from "react";
import { hexToBigInt } from "viem";

import { ClaimDialog, ReleaseDialog, RetryDialog } from "@/components/Dialogs";
import { Spinner } from "@/components/Spinner";
import { DesktopDetailsDialog } from "@/components/Transactions/Dialogs";
import type { BridgeTransaction, MessageStatus } from "@/libs/bridge";
import { getMessageStatusForMsgHash } from "@/libs/bridge/getMessageStatusForMsgHash";
import { type NFT, TokenType } from "@/libs/token";
import { fetchNFTImageUrl } from "@/libs/token/fetchNFTImageUrl";
import { mapTransactionHashToNFT } from "@/libs/token/mapTransactionHashToNFT";
import { classNames } from "@/libs/util/classNames";
import { formatTimestamp } from "@/libs/util/formatTimestamp";
import { geBlockTimestamp } from "@/libs/util/getBlockTimestamp";
import { shortenAddress } from "@/libs/util/shortenAddress";
import { truncateString } from "@/libs/util/truncateString";
import { useResponsive } from "@/hooks/useResponsive";
import { useTranslation } from "@/i18n/useTranslation";
import { useAccount } from "@/stores/account";

import ChainSymbol from "../ChainSymbol";
import MobileDetailsDialog from "../Dialogs/MobileDetailsDialog";
import InsufficientFunds from "../InsufficientFunds";
import { Status } from "../Status";

import styles from "./TransactionRow.module.css";

const placeholderUrl = "/placeholder.svg";

export interface NftTransactionRowProps {
  bridgeTx: BridgeTransaction;
  loading?: boolean;
  handleTransactionRemoved: (event: CustomEvent) => void;
  /** Two-way `bind:bridgeTxStatus`. */
  bridgeTxStatus: Maybe<MessageStatus>;
  onBridgeTxStatusChange?: (status: Maybe<MessageStatus>) => void;
  /** Two-way `bind:loading`. */
  onLoadingChange?: (loading: boolean) => void;
}

function NftTransactionRow({
  bridgeTx,
  loading: loadingProp = false,
  handleTransactionRemoved,
  bridgeTxStatus: bridgeTxStatusProp,
  onBridgeTxStatusChange,
  onLoadingChange,
}: NftTransactionRowProps) {
  const { t } = useTranslation();

  const { isDesktop, isTablet, isMobile } = useResponsive();
  const isConnected = useAccount((a) => a?.isConnected ?? false);

  // `bind:loading` -> local state, reported up.
  const [loading, setLoadingState] = useState(loadingProp);
  const setLoading = (value: boolean) => {
    setLoadingState(value);
    onLoadingChange?.(value);
  };
  useEffect(() => {
    setLoadingState(loadingProp);
  }, [loadingProp]);

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
  const [token, setToken] = useState<NFT>();
  const [directClaim, setDirectClaim] = useState(false);

  const [timestamp, setTimestamp] = useState<string>();

  // Modal states.
  const [claimModalOpen, setClaimModalOpen] = useState(false);
  const [retryModalOpen, setRetryModalOpen] = useState(false);
  const [releaseModalOpen, setReleaseModalOpen] = useState(false);
  const interactiveDialogsOpen =
    claimModalOpen || retryModalOpen || releaseModalOpen;

  const isNFT =
    bridgeTx.tokenType === TokenType.ERC721 ||
    bridgeTx.tokenType === TokenType.ERC1155;

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

  const analyzeTransactionInput = async (): Promise<void> => {
    setLoading(true);
    try {
      let nextToken = await mapTransactionHashToNFT({
        hash: bridgeTx.srcTxHash,
        srcChainId: Number(bridgeTx.srcChainId),
        type: bridgeTx.tokenType,
      });
      nextToken = await fetchNFTImageUrl(nextToken);
      setToken(nextToken);
      await getDate();
    } catch (error) {
      console.error(error);
    }
    setLoading(false);
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

  // resolve NFT metadata + image
  useEffect(() => {
    if (isConnected && isNFT) analyzeTransactionInput();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isConnected, isNFT]);

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
      "w-1/6 f-row justify-center items-center",
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

  const imgUrl = token?.metadata?.image || placeholderUrl;

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

            <div className={`${columnClasses} items-center`}>
              {loading ? (
                <Spinner className="size-[24px]" />
              ) : (
                <img
                  src={imgUrl}
                  alt="NFT"
                  className="w-[46px] h-[46px] rounded-[10px]"
                />
              )}
            </div>
          </>
        ) : isDesktop ? (
          <>
            {/* Desktop */}
            <div className={`${columnClasses} !justify-start  gap-[10px]`}>
              <img
                src={imgUrl}
                alt="NFT"
                className="w-[46px] h-[46px] rounded-[10px]"
              />
              <div className="f-col items-start">
                <span>
                  {token?.name
                    ? truncateString(token?.name, 8)
                    : t("common.not_available_short")}
                </span>
                <span className="text-secondary-content text-sm">
                  #{token?.tokenId}
                </span>
              </div>
            </div>

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
        ) : isTablet ? (
          <>
            {/* Tablet */}
            <div className={`${columnClasses} items-center`}>
              <img
                src={imgUrl}
                alt="NFT"
                className="w-[40px] h-[40px] rounded-[10px]"
              />
            </div>

            <div className={`${columnClasses}`}>
              <ChainSymbol
                className="min-w-[24px]"
                chainId={bridgeTx.srcChainId}
              />
              {shortenAddress(bridgeTx.message?.from, 5, 1)}
            </div>
            <div className={`${columnClasses} `}>
              <ChainSymbol
                className="min-w-[24px]"
                chainId={bridgeTx.destChainId}
              />
              {shortenAddress(bridgeTx.message?.to, 5, 1)}
            </div>
          </>
        ) : null}

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
            <div className={`${columnClasses} w-2/6 `}>
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

      {/* The original Svelte `DesktopDetailsDialog`/`MobileDetailsDialog` never
          dispatched `insufficientFunds`, so `on:insufficientFunds` was a no-op
          listener Svelte silently dropped. The ported dialogs expose no such
          prop; omitting it preserves behavior exactly. The `Status` row above
          is the sole source of `onInsufficientFunds`. */}
      <DesktopDetailsDialog
        detailsOpen={desktopDetailsOpen}
        token={token}
        closeDetails={closeDetails}
        bridgeTx={bridgeTx}
      />

      <MobileDetailsDialog
        detailsOpen={mobileDetailsOpen}
        token={token}
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

// Memoized for the same reason as FungibleTransactionRow: NFT rows resolve
// images + run status polling, so avoid re-rendering each visible row on every
// parent Transactions re-render. Props (`bridgeTx`, `handleTransactionRemoved`)
// are stable from the parent.
export default memo(NftTransactionRow);
