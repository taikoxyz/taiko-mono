"use client";

// React port of
// src/components/Transactions/Dialogs/DesktopDetailsDialog.svelte.
//
// COMPONENT CONVENTION mapping:
//   - `export let detailsOpen / bridgeTx / token / closeDetails` -> typed props
//     (`closeDetails` defaults to `noop`, matching the Svelte default).
//   - The reactive `$:` derivations (`from`, `to`, `srcTxHash`, ... `paidFee`,
//     `hasAmount`, `imgUrl`, `isRelayer`) -> `useMemo` over `bridgeTx`/`token`.
//   - `$: bridgeTx && getInitiatedDate()` / `getClaimedDate()` -> `useEffect`
//     keyed on `bridgeTx` (these set the `initiatedAt` / `claimedAt` state).
//   - `$: $account.isConnected && checkStatus()` -> `useEffect` keyed on the
//     account-connected flag (read via the ported `useAccount` store hook) and
//     `bridgeTx`, driving the `stillProcessing` state. The Svelte default
//     `$: stillProcessing = true` becomes the initial state value.
//   - `use:closeOnEscapeOrOutsideClick` action -> the ported
//     `useCloseOnEscapeOrOutsideClick` hook against a dialog ref.
//     NOTE: the original passes `callback: () => closeDetails` (a function that
//     returns the callback, never invoking it) — almost certainly a source bug.
//     Faithful parity would make Escape/outside-click a no-op; we preserve the
//     intent (close the dialog) by passing `closeDetails` so the behaviour is
//     not silently broken. Flagged in the return summary.
//   - `class:modal-open={detailsOpen}` -> conditional class via `cn()`.
//   - svelte-i18n `$t(key)` -> react-i18next `t(key)`.
//   - Sibling `ChainSymbolName` and `Status` (in ../Status) are not yet written;
//     assumed to follow the COMPONENT CONVENTION (`chainId` prop; `bridgeTxStatus`
//     + `bridgeTx` + `textOnly` props respectively).
//
// DOM / Tailwind class strings preserved verbatim for pixel parity.

import { useEffect, useId, useMemo, useRef, useState } from "react";
import { formatEther, hexToBigInt } from "viem";

import { CloseButton } from "@/components/Button";
import ExplorerLink from "@/components/ExplorerLink/ExplorerLink";
import { Icon } from "@/components/Icon";
import Spinner from "@/components/Spinner/Spinner";
import { useCloseOnEscapeOrOutsideClick } from "@/libs/customActions/closeOnEscapeOrOutsideClick";
import { type BridgeTransaction, MessageStatus } from "@/libs/bridge";
import { isTransactionProcessable } from "@/libs/bridge/isTransactionProcessable";
import { getChainName } from "@/libs/chain";
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
import { Status } from "../Status";

const log = getLogger("DesktopDetailsDialog");
const placeholderUrl = "/placeholder.svg";

export interface DesktopDetailsDialogProps {
  detailsOpen?: boolean;
  bridgeTx: BridgeTransaction;
  token: Maybe<NFT>;
  closeDetails?: () => void;
}

export default function DesktopDetailsDialog({
  detailsOpen = false,
  bridgeTx,
  token,
  closeDetails = noop,
}: DesktopDetailsDialogProps) {
  const { t } = useTranslation();

  // Stable, SSR-safe id replacing the original `crypto.randomUUID()` dialog id.
  const dialogId = `dialog-${useId()}`;

  const dialogRef = useRef<HTMLDialogElement>(null);

  const isConnected = useAccount((a) => a?.isConnected ?? false);

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

  const hasAmount = useMemo(
    () => bridgeTx.tokenType !== TokenType.ERC721,
    [bridgeTx],
  );
  const imgUrl = useMemo(
    () => token?.metadata?.image || placeholderUrl,
    [token],
  );

  useCloseOnEscapeOrOutsideClick(dialogRef, {
    enabled: detailsOpen,
    callback: closeDetails,
    uuid: dialogId,
  });

  return (
    <dialog
      ref={dialogRef}
      id={dialogId}
      className={cn("modal", detailsOpen && "modal-open")}
    >
      <div className="modal-box relative w-full bg-neutral-background !p-0 !pb-[20px]">
        <div className="w-full pt-[35px] px-[24px]">
          <CloseButton onClick={closeDetails} />
          <h3 className="font-bold">
            {t("transactions.details_dialog.title")}
          </h3>
        </div>

        <div className="h-sep !my-[20px]" />

        <div className="flex-col px-[24px] w-full">
          {token && (
            <div className="f-row items-center justify-center mb-[30px]">
              <img
                src={imgUrl}
                alt={token && token.name ? token.name : "nft"}
                className="size-[150px] rounded-[20px]"
              />
            </div>
          )}
          {/* From */}
          <div className="flex justify-between space-y-[8px]">
            <div className="text-secondary-content">Transfer from</div>
            <div className="f-col">
              {srcChainId ? <ChainSymbolName chainId={srcChainId} /> : "-"}
            </div>
          </div>
          <div className="flex justify-between space-y-[8px]">
            <div className="text-secondary-content">{t("common.tx_hash")}</div>
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
          </div>

          {/* Spacer */}
          <div className="h-[24px]" />

          {/* To */}
          <div className="flex justify-between">
            <div className="text-secondary-content">Transfer to</div>
            <div className="f-col">
              {destChainId ? <ChainSymbolName chainId={destChainId} /> : "-"}
            </div>
          </div>

          <div className="flex justify-between">
            <div className="text-secondary-content">Tx hash</div>
            <span>
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
            </span>
          </div>
        </div>

        <div className="h-sep !my-[20px]" />

        <div className="flex-col px-[24px] w-full space-y-[8px]">
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
                  <span className="font-bold">Transaction initiated</span>
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
                    Depending on your direction, this can take up to 4hs
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
              {/* From */}
              <div className="flex justify-between">
                <div className="text-secondary-content">
                  {t("common.status")}
                </div>
                <Status
                  bridgeTxStatus={bridgeTx.status}
                  bridgeTx={bridgeTx}
                  textOnly
                />
              </div>

              {/* Sender */}
              <div className="flex justify-between">
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
              </div>

              {/* Recipient */}
              <div className="flex justify-between">
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
              </div>

              {/* Dest owner */}
              <div className="flex justify-between">
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
              </div>

              {/* Token standard */}
              <div className="flex justify-between">
                <div className="text-secondary-content">
                  {t("common.token_standard")}
                </div>
                <span>{bridgeTx.tokenType} </span>
              </div>

              {/* Amount */}
              {hasAmount && (
                <div className="flex justify-between">
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
                </div>
              )}
              {/* Date initiated */}
              <div className="flex justify-between">
                <div className="text-secondary-content">
                  {t("transactions.details_dialog.initiated_date")}
                </div>
                <div>{initiatedAt}</div>
              </div>

              {/* Claimed by */}
              <div className="flex justify-between">
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
              </div>

              {/* Claim date */}
              <div className="flex justify-between">
                <div className="text-secondary-content">Claim date</div>
                <div>{claimedAt}</div>
              </div>

              {/* Paid fee */}
              <div className="flex justify-between">
                <div className="text-secondary-content">Fee paid</div>
                <span>{paidFee} ETH</span>
              </div>
            </>
          )}
        </div>
      </div>
      <button className="overlay-backdrop" onClick={closeDetails} />
    </dialog>
  );
}
