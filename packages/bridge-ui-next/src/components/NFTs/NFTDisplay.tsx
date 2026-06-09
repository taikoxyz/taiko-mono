"use client";

import { LoadingMask } from "@/components/LoadingMask";
import { useTranslation } from "@/i18n/useTranslation";
import type { NFT } from "@/libs/token";
import { useConnectedSourceChain } from "@/stores/network";

import { NFTCardGrid } from "./NFTCards";
import { NFTList } from "./NFTList";
import { NFTView } from "./types";

export interface NFTDisplayProps {
  loading: boolean;
  viewOnly?: boolean;
  nfts?: NFT[] | null;
  nftView?: NFTView;
}

export default function NFTDisplay({
  loading,
  viewOnly = false,
  nfts = [],
  nftView = NFTView.LIST,
}: NFTDisplayProps) {
  const { t } = useTranslation();

  const $connectedSourceChain = useConnectedSourceChain();

  const size =
    nfts?.length && nfts?.length > 2
      ? "max-h-[350px] min-h-[350px]"
      : "max-h-[249px] min-h-[249px]";

  const outerClasses =
    "relative m bg-neutral rounded-[20px] overflow-hidden " + size;
  const innerClasses = "overflow-y-auto p-[24px] " + size;

  return (
    <div className={outerClasses}>
      <div className={innerClasses}>
        {loading ? (
          <LoadingMask
            spinnerClass="border-white"
            text={t("messages.bridge.nft_scanning")}
          />
        ) : nftView === NFTView.LIST && nfts ? (
          <NFTList
            nfts={nfts}
            chainId={$connectedSourceChain?.id}
            viewOnly={viewOnly}
          />
        ) : nftView === NFTView.CARDS && nfts ? (
          <NFTCardGrid nfts={nfts} viewOnly={viewOnly} />
        ) : null}
      </div>
    </div>
  );
}
