"use client";

import { useState } from "react";
import { formatEther, formatUnits } from "viem";

import ExplorerLink from "@/components/ExplorerLink/ExplorerLink";
import ChainSymbolName from "@/components/Transactions/ChainSymbolName";
import { useTranslation } from "@/i18n/useTranslation";
import type { BridgeTransaction } from "@/libs/bridge";
import { type NFT, TokenType } from "@/libs/token";
import { cn } from "@/lib/utils";

export interface ReviewStepProps {
  tx: BridgeTransaction;
  nft?: NFT | null;
}

const placeholderUrl = "/placeholder.svg";

export default function ReviewStep({ tx, nft = null }: ReviewStepProps) {
  const { t } = useTranslation();

  // $: imageUrl = nft?.metadata?.image || placeholderUrl;
  const imageUrl = nft?.metadata?.image || placeholderUrl;
  const [imageLoaded, setImageLoaded] = useState(false);

  function handleImageLoad() {
    setImageLoaded(true);
  }

  return (
    <div className="space-y-[25px] mt-[20px]">
      <div className="flex justify-between mb-2 items-center">
        <div className="font-bold text-primary-content">
          {t("transactions.claim.steps.review.title")}
        </div>
      </div>
      <div className="min-h-[150px] grid content-between">
        {nft ? (
          <div className="f-row justify-center">
            {!imageLoaded ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                alt="placeholder"
                src={placeholderUrl}
                className="rounded-[20px] bg-white max-w-[200px]"
              />
            ) : null}
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              alt="nft"
              src={imageUrl || ""}
              className={cn(
                "rounded-[20px] bg-white max-w-[200px]",
                (!imageLoaded || imageUrl === "") && "hidden",
              )}
              onLoad={handleImageLoad}
            />
          </div>
        ) : null}
        <div className="space-y-[5px]">
          <div className="flex justify-between items-center">
            <div className="text-secondary-content">{t("common.from")}</div>
            <ChainSymbolName chainId={tx.srcChainId} />
          </div>
          <div className="flex justify-between items-center">
            <div className="text-secondary-content">{t("common.to")}</div>
            <ChainSymbolName chainId={tx.destChainId} />
          </div>
          {tx.message ? (
            <>
              <div className="flex justify-between">
                <div className="text-secondary-content">
                  {t("common.sender")}
                </div>
                <ExplorerLink
                  category="address"
                  chainId={Number(tx.srcChainId)}
                  urlParam={tx.message.srcOwner}
                  shorten
                />
              </div>

              <div className="flex justify-between">
                <div className="text-secondary-content">
                  {t("common.recipient")}
                </div>
                <ExplorerLink
                  category="address"
                  chainId={Number(tx.destChainId)}
                  urlParam={tx.message.to}
                  shorten
                />
              </div>
            </>
          ) : null}
          {tx.amount !== 0n ? (
            <div className="flex justify-between">
              <div className="text-secondary-content">{t("common.amount")}</div>
              {tx.tokenType === TokenType.ERC20
                ? formatUnits(
                    tx.amount ? tx.amount : BigInt(0),
                    tx.decimals ?? 0,
                  )
                : tx.tokenType === TokenType.ETH
                  ? formatEther(tx.amount ? tx.amount : BigInt(0))
                  : tx.amount}{" "}
              {tx.symbol}
            </div>
          ) : null}
        </div>
      </div>
    </div>
  );
}
