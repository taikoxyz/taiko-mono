"use client";

// React port of
// src/components/Transactions/Dialogs/MobileDetailsDialog.svelte.
//
// COMPONENT CONVENTION mapping:
//   - `export let detailsOpen / bridgeTx / closeDetails / token` -> typed props
//     (`closeDetails` defaults to `noop`).
//   - Local `let openStatusDialog` / `let tooltipOpen` -> `useState`.
//     `openToolTip` / `handleStatusDialog` toggle those states.
//   - Reactive `$:` derivations -> `useMemo` over `bridgeTx`/`token`.
//   - `$: bridgeTx && getInitiatedDate()` / `getClaimedDate()` -> `useEffect`s
//     keyed on `bridgeTx`.
//   - `$: $account.isConnected && checkStatus()` -> `useEffect` keyed on the
//     account-connected flag + `bridgeTx`.
//   - `use:closeOnEscapeOrOutsideClick` -> `useCloseOnEscapeOrOutsideClick`.
//     (Here the original passes `callback: closeDetails` directly — correct.)
//   - `class:modal-open={detailsOpen}` -> conditional class via `cn()`.
//   - `<StatusInfoDialog bind:modalOpen={openStatusDialog} noIcon />` ->
//     controlled `modalOpen` + `onModalOpenChange` (sibling not yet written;
//     assumed COMPONENT CONVENTION).
//   - `on:click|stopPropagation` -> `onClick` calling `e.stopPropagation()`.
//   - `<ActionButton ... on:click={closeDetails}>` -> `onClick={closeDetails}`.
//   - svelte-i18n `$t(key)` -> react-i18next `t(key)`.
//   - Sibling `ChainSymbolName`, `Status`, `StatusInfoDialog` (in ../Status)
//     assumed to follow the COMPONENT CONVENTION.
//
// DOM / Tailwind class strings preserved verbatim for pixel parity.

import { useEffect, useId, useMemo, useRef, useState } from "react";
import { formatEther, hexToBigInt } from "viem";

import { CloseButton } from "@/components/Button";
import ActionButton from "@/components/Button/ActionButton";
import ExplorerLink from "@/components/ExplorerLink/ExplorerLink";
import { Icon } from "@/components/Icon";
import { Spinner } from "@/components/Spinner";
import { useCloseOnEscapeOrOutsideClick } from "@/libs/customActions/closeOnEscapeOrOutsideClick";
import { type BridgeTransaction, MessageStatus } from "@/libs/bridge";
import { isTransactionProcessable } from "@/libs/bridge/isTransactionProcessable";
import { getChainName, isL2Chain } from "@/libs/chain";
import { type NFT, TokenType } from "@/libs/token";
import { formatTimestamp } from "@/libs/util/formatTimestamp";
import { getBlockFromTxHash } from "@/libs/util/getBlockFromTxHash";
import { geBlockTimestamp } from "@/libs/util/getBlockTimestamp";
import { getLogger } from "@/libs/util/logger";
import { noop } from "@/libs/util/noop";
import { cn } from "@/lib/utils";
import { useTranslation } from "@/i18n/useTranslation";
import { useAccount } from "@/stores/account";

import ChainSymbolName from "../ChainSymbolName";
// Original imported `Status` from `../Status/Status.svelte` (default) and
// `StatusInfoDialog` from the `../Status` barrel. In the Next app, resolving
// `../Status/Status` hits the `status.ts` helper (no default export) because TS
// prefers `.ts` over `.tsx`, so we pull both from the barrel (named exports),
// matching the already-migrated FungibleTransactionRow.
import { Status, StatusInfoDialog } from "../Status";

const log = getLogger("DesktopDetailsDialog");
const placeholderUrl = "/placeholder.svg";

export interface MobileDetailsDialogProps {
  detailsOpen?: boolean;
  bridgeTx: BridgeTransaction;
  token: Maybe<NFT>;
  closeDetails?: () => void;
}

export default function MobileDetailsDialog({
  detailsOpen = false,
  bridgeTx,
  token,
  closeDetails = noop,
}: MobileDetailsDialogProps) {
  const { t } = useTranslation();

  // Stable, SSR-safe id replacing the original `crypto.randomUUID()` dialog id.
  const dialogId = `dialog-${useId()}`;

  const dialogRef = useRef<HTMLDialogElement>(null);

  const isConnected = useAccount((a) => a?.isConnected ?? false);

  const [openStatusDialog, setOpenStatusDialog] = useState(false);
  // `tooltipOpen` is toggled by the status button but never read/rendered in the
  // original Svelte component — preserved verbatim (the setter is the load-bearing
  // part of the `openToolTip` handler).
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const [tooltipOpen, setTooltipOpen] = useState(false);

  const openToolTip = () => {
    setTooltipOpen((v) => !v);
  };

  const handleStatusDialog = () => {
    setOpenStatusDialog((v) => !v);
  };

  const [initiatedAt, setInitiatedAt] = useState("");
  const [claimedAt, setClaimedAt] = useState("");
  const [stillProcessing, setStillProcessing] = useState(true);

  // $: bridgeTx && getInitiatedDate();
  useEffect(() => {
    const getInitiatedDate = async () => {
      if (!bridgeTx.blockNumber) return;
      const blockTimestamp = await geBlockTimestamp(
        bridgeTx.srcChainId,
        hexToBigInt(bridgeTx.blockNumber),
      );
      setInitiatedAt(formatTimestamp(Number(blockTimestamp)));
    };
    if (bridgeTx) getInitiatedDate();
  }, [bridgeTx]);

  // $: bridgeTx && getClaimedDate();
  useEffect(() => {
    const getClaimedDate = async () => {
      if (!bridgeTx.destTxHash || !bridgeTx.destChainId) return;
      log(
        "destTxHash",
        bridgeTx.destTxHash,
        "destChainId",
        bridgeTx.destChainId,
      );
      try {
        const blockNumber = await getBlockFromTxHash(
          bridgeTx.destTxHash,
          bridgeTx.destChainId,
        );
        log("blockNumber", blockNumber);
        const blockTimestamp = await geBlockTimestamp(
          bridgeTx.destChainId,
          blockNumber,
        );
        log("blockTimestamp", blockTimestamp);
        setClaimedAt(formatTimestamp(Number(blockTimestamp)));
        log("claimedAt", formatTimestamp(Number(blockTimestamp)));
      } catch (error) {
        log("error", error);
      }
    };
    if (bridgeTx) getClaimedDate();
  }, [bridgeTx]);

  // $: $account.isConnected && checkStatus();
  useEffect(() => {
    const checkStatus = async () => {
      const isProcessable = await isTransactionProcessable(bridgeTx);
      if (
        bridgeTx.status === MessageStatus.NEW ||
        bridgeTx.status === MessageStatus.RETRIABLE
      ) {
        if (!isProcessable) {
          setStillProcessing(true);
        } else {
          setStillProcessing(false);
        }
      } else if (
        bridgeTx.status === MessageStatus.DONE ||
        bridgeTx.status === MessageStatus.FAILED ||
        bridgeTx.status === MessageStatus.RECALLED
      ) {
        setStillProcessing(false);
      }
    };
    if (isConnected) checkStatus();
  }, [isConnected, bridgeTx]);

  const from = useMemo(() => bridgeTx.message?.from || null, [bridgeTx]);
  const to = useMemo(() => bridgeTx.message?.to || null, [bridgeTx]);

  const srcTxHash = useMemo(() => bridgeTx.srcTxHash || null, [bridgeTx]);
  const destTxHash = useMemo(() => bridgeTx.destTxHash || null, [bridgeTx]);

  const srcChainId = useMemo(() => bridgeTx.srcChainId || null, [bridgeTx]);
  const destChainId = useMemo(() => bridgeTx.destChainId || null, [bridgeTx]);
  const destOwner = useMemo(
    () => bridgeTx.message?.destOwner || null,
    [bridgeTx],
  );

  const claimedBy = useMemo(() => bridgeTx.claimedBy || null, [bridgeTx]);

  const isRelayer = useMemo(
    () =>
      claimedBy !== to &&
      claimedBy !== destOwner &&
      bridgeTx.status === MessageStatus.DONE,
    [claimedBy, to, destOwner, bridgeTx],
  );

  const paidFee = useMemo(
    () => formatEther(bridgeTx.fee ? bridgeTx.fee : BigInt(0)),
    [bridgeTx],
  );

  const isBridgeToL1 = useMemo(
    () => !isL2Chain(Number(bridgeTx.destChainId)),
    [bridgeTx],
  );

  const imgUrl = useMemo(
    () => token?.metadata?.image || placeholderUrl,
    [token],
  );

  const hasAmount = useMemo(
    () => bridgeTx.tokenType !== TokenType.ERC721,
    [bridgeTx],
  );

  const title = useMemo(
    () =>
      token && token.name && token.tokenId
        ? `${token.name} #${token.tokenId}`
        : t("transactions.details_dialog.title"),
    [token, t],
  );

  useCloseOnEscapeOrOutsideClick(dialogRef, {
    enabled: detailsOpen,
    callback: closeDetails,
    uuid: dialogId,
  });

  return (
    <>
      <dialog
        ref={dialogRef}
        id={dialogId}
        className={cn("modal h-full min-h-[100%]", detailsOpen && "modal-open")}
      >
        <div className="modal-box max-w-[100%] min-h-[100%] relative f-col justify-between w-full h-full rounded-[0px] bg-neutral-background !p-0 !pb-[20px]">
          <div className="w-dvw fixed pt-[20px] px-[24px] z-40 bg-neutral-background">
            <CloseButton onClick={closeDetails} />
            <h3 className="font-bold">{title}</h3>
            <div className="h-sep mx-[-24px] mb-0" />
          </div>
          <div className="w-full py-[50px] px-[24px] overflow-y-auto flex-grow relative">
            <div className="w-full my-[50px] text-left">
              {bridgeTx && (
                <>
                  {token && (
                    <div className="f-row items-center justify-center mb-[30px]">
                      <img
                        src={imgUrl}
                        alt={token && token.name ? token.name : "nft"}
                        className="size-[150px] rounded-[20px]"
                      />
                    </div>
                  )}
                  <ul className="body-small-regular w-full">
                    {/* From */}
                    <li className="f-between-center space-y-[8px]">
                      <h4 className="text-secondary-content">
                        {t("common.from")}
                      </h4>
                      <ChainSymbolName chainId={bridgeTx.srcChainId} />
                    </li>
                    <li className="f-between-center space-y-[8px]">
                      <div className="text-secondary-content">
                        {t("common.tx_hash")}
                      </div>
                      <span>
                        {srcTxHash ? (
                          <ExplorerLink
                            className="text-secondary-content"
                            urlParam={srcTxHash}
                            category="tx"
                            chainId={Number(srcChainId)}
                            shorten
                          />
                        ) : (
                          "-"
                        )}
                      </span>
                    </li>

                    {/* Spacer */}
                    <div className="h-[24px]" />

                    {/* To */}
                    <li className="f-between-center space-y-[8px]">
                      <h4 className="text-secondary-content">
                        {t("common.to")}
                      </h4>
                      <ChainSymbolName chainId={bridgeTx.destChainId} />
                    </li>

                    <li className="f-between-center space-y-[8px]">
                      <div className="text-secondary-content">
                        {t("common.tx_hash")}
                      </div>
                      {destTxHash ? (
                        <ExplorerLink
                          className="text-secondary-content"
                          urlParam={destTxHash}
                          category="tx"
                          chainId={Number(destChainId)}
                          shorten
                        />
                      ) : (
                        "-"
                      )}
                    </li>
                  </ul>

                  <div className="h-sep my-[20px] mx-[-24px]" />

                  <ul className="space-y-[8px] body-small-regular w-full">
                    {stillProcessing ? (
                      <div className="f-row">
                        <div className="f-col min-h-full border border-dashed border-primary-border-dark mr-[20px] my-[10px]" />
                        {/* Vertical line */}
                        <div className="f-col space-y-[30px]">
                          <div className="f-col relative">
                            <span className="bg-neutral-background absolute size-[20px] flex items-center justify-center left-[-30px] mt-1">
                              <Icon
                                type="check"
                                fillClass="fill-positive-sentiment"
                                className="size-[16px]"
                              />
                            </span>
                            <span className="font-bold">
                              Transaction initiated
                            </span>
                            <span className="text-secondary-content">
                              <ExplorerLink
                                className="text-secondary-content"
                                urlParam={srcTxHash as `0x${string}`}
                                linkText={initiatedAt}
                                category="tx"
                                chainId={Number(srcChainId)}
                                shorten
                              />
                            </span>
                          </div>

                          <div className="f-col">
                            <span className="bg-neutral-background absolute size-[20px] flex items-center justify-center left-[15px] mt-1">
                              <Spinner className="bg-positive-sentiment !loading-xs " />
                            </span>

                            <span className="font-bold text-positive-sentiment">
                              Waiting for transaction to be processed
                            </span>
                            <span className="text-secondary-content">
                              {isBridgeToL1
                                ? t("bridge.alerts.slow_bridging")
                                : ""}
                            </span>
                          </div>

                          <div className="f-col">
                            <span className="bg-neutral-background absolute size-[15px] flex items-center justify-center left-[17.5px] mt-2">
                              <Icon
                                type="circle"
                                fillClass="fill-primary-border-dark "
                                className="size-[10px]"
                              />
                            </span>
                            <span className="font-bold">
                              Receiving {bridgeTx.symbol} on{" "}
                              {getChainName(Number(bridgeTx.destChainId))}
                            </span>
                          </div>
                        </div>
                      </div>
                    ) : (
                      <>
                        {/* Status */}
                        <li className="f-between-center space-y-[8px]">
                          <h4 className="text-secondary-content">
                            <div className="f-items-center space-x-1">
                              <button
                                onClick={(e) => {
                                  e.stopPropagation();
                                  openToolTip();
                                }}
                              >
                                <span>{t("transactions.header.status")}</span>
                              </button>
                              <button
                                onClick={handleStatusDialog}
                                className="flex justify-start content-center"
                              >
                                <Icon type="question-circle" />
                              </button>
                            </div>
                          </h4>
                          <div className="f-items-center space-x-1">
                            <Status
                              bridgeTxStatus={bridgeTx.status}
                              bridgeTx={bridgeTx}
                              textOnly
                            />
                          </div>
                        </li>

                        {/* Sender */}
                        <li className="f-between-center">
                          <div className="text-secondary-content">
                            {t("transactions.details_dialog.sender_address")}
                          </div>
                          {from && (
                            <div>
                              <ExplorerLink
                                category="address"
                                urlParam={from}
                                chainId={Number(srcChainId)}
                                shorten
                              />
                            </div>
                          )}
                        </li>

                        {/* Recipient */}
                        <li className="f-between-center">
                          <div className="text-secondary-content">
                            {t("transactions.details_dialog.recipient_address")}
                          </div>
                          {to && (
                            <div>
                              <ExplorerLink
                                category="address"
                                urlParam={to}
                                chainId={Number(destChainId)}
                                shorten
                              />
                            </div>
                          )}
                        </li>

                        {/* Dest owner */}
                        <li className="f-between-center">
                          <div className="text-secondary-content">
                            {t("transactions.details_dialog.destination_owner")}
                          </div>
                          {destOwner && (
                            <div>
                              <ExplorerLink
                                category="address"
                                urlParam={destOwner}
                                chainId={Number(destChainId)}
                                shorten
                              />
                            </div>
                          )}
                        </li>

                        {/* Token standard */}
                        <li className="f-between-center">
                          <div className="text-secondary-content">
                            {t("common.token_standard")}
                          </div>
                          <span>{bridgeTx.tokenType} </span>
                        </li>

                        {/* Amount */}
                        {hasAmount && (
                          <li className="f-between-center">
                            <div className="text-secondary-content">
                              {t("common.amount")}
                            </div>
                            {bridgeTx.tokenType === TokenType.ERC1155 ? (
                              <span>{String(bridgeTx.amount)} </span>
                            ) : (
                              <span>
                                {formatEther(
                                  bridgeTx.amount ? bridgeTx.amount : BigInt(0),
                                )}{" "}
                                {bridgeTx.symbol}
                              </span>
                            )}
                          </li>
                        )}
                        {/* Date initiated */}
                        <li className="f-between-center">
                          <div className="text-secondary-content">
                            {t("transactions.details_dialog.initiated_date")}
                          </div>
                          <div>{initiatedAt || "-"}</div>
                        </li>

                        {/* Claimed by */}
                        <li className="f-between-center">
                          <div className="text-secondary-content">
                            {t("transactions.details_dialog.claimed_by")}
                          </div>
                          <div>
                            {isRelayer ? (
                              <span>{t("common.relayer")}</span>
                            ) : claimedBy ? (
                              <ExplorerLink
                                category="address"
                                urlParam={claimedBy}
                                chainId={Number(destChainId)}
                                shorten
                              />
                            ) : (
                              "-"
                            )}
                          </div>
                        </li>

                        {/* Claim date */}
                        <li className="f-between-center">
                          <div className="text-secondary-content">
                            Claim date
                          </div>
                          <div>{claimedAt || "-"}</div>
                        </li>

                        {/* Paid fee */}
                        <li className="f-between-center">
                          <div className="text-secondary-content">Fee paid</div>
                          <span>{paidFee || "-"} ETH</span>
                        </li>
                      </>
                    )}
                  </ul>
                </>
              )}
            </div>
          </div>
          <div className="fixed bottom-[20px] left-0 w-full bg-neutral-background">
            <div className="h-sep mb-[20px] mt-0" />
            <div className="px-[24px] w-full max-h-[56px]">
              <ActionButton priority="primary" onClick={closeDetails}>
                {t("common.close")}
              </ActionButton>
            </div>
          </div>
        </div>
        <button className="overlay-backdrop" data-modal-uuid={dialogId} />
      </dialog>

      <StatusInfoDialog
        modalOpen={openStatusDialog}
        onModalOpenChange={setOpenStatusDialog}
        noIcon
      />
    </>
  );
}
