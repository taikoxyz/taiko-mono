"use client";

import { memo, useState } from "react";

import { selectedNFTs, useBridgeState } from "@/components/Bridge/state";
import { Icon } from "@/components/Icon";
import NFTInfoDialog from "@/components/NFTs/NFTInfoDialog";
import type { NFT } from "@/libs/token";

export interface NFTCardProps {
  nft: NFT;
  selectNFT: (nft: NFT) => void;
  viewOnly: boolean;
}

const placeholderUrl = "/placeholder.svg";

function NFTCard({ nft, selectNFT, viewOnly }: NFTCardProps) {
  const $selectedNFTs = useBridgeState(selectedNFTs);

  const [modalOpen, setModalOpen] = useState(false);

  const handleDialogSelection = () => {
    selectNFT(nft);
    setModalOpen(false);
  };

  const handleImageClick = () => {
    if (viewOnly) return;
    selectNFT(nft);
  };

  const [imageLoaded, setImageLoaded] = useState(false);

  function handleImageLoad() {
    setImageLoaded(true);
  }

  const imageUrl = nft.metadata?.image || placeholderUrl;

  const isChecked = $selectedNFTs
    ? $selectedNFTs.some(
        (selected) =>
          selected.tokenId === nft.tokenId &&
          selected.addresses === nft.addresses,
      )
    : false;

  return (
    <>
      <div className="rounded-[10px] w-[120px] bg-white max-h-[160px] min-h-[160px] relative">
        <label htmlFor="nft-radio" className="cursor-pointer">
          {!viewOnly && (
            <>
              <input
                type="radio"
                className="hidden"
                name="nft-radio"
                checked={isChecked}
                onChange={() => selectNFT(nft)}
              />
              {isChecked && (
                <div
                  className="selected-overlay rounded-[10px]"
                  style={{
                    position: "absolute",
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    backgroundColor:
                      "rgba(11, 16, 27, 0.7)" /* Gray-900 0.7 opacity */,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    border: "3px solid var(--primary-brand)",
                  }}
                  role="button"
                  tabIndex={0}
                  onClick={handleImageClick}
                  onKeyDown={handleImageClick}
                >
                  <Icon
                    type="check-circle"
                    className="f-center "
                    fillClass="fill-primary-brand"
                    width={40}
                    height={40}
                  />
                </div>
              )}
            </>
          )}
          <div
            role="button"
            tabIndex={0}
            className="h-[124px]"
            onClick={handleImageClick}
            onKeyDown={handleImageClick}
          >
            {!imageLoaded && (
              // eslint-disable-next-line @next/next/no-img-element
              <img alt="placeholder" src={placeholderUrl} className="rounded" />
            )}
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              alt={nft.name}
              src={imageUrl || ""}
              className=" rounded-t-[10px] h-[125px]"
              onLoad={handleImageLoad}
            />
          </div>
        </label>
        <button
          name="nftInfoDialog"
          className="px-[10px] py-[8px] h-[36px] f-between-center w-full"
          onClick={() => setModalOpen(true)}
        >
          <span className="font-bold text-black">{nft.tokenId} </span>
          <Icon type="option-dots" fillClass="fill-grey-500" />
        </button>
      </div>

      <NFTInfoDialog
        nft={nft}
        modalOpen={modalOpen}
        onModalOpenChange={setModalOpen}
        onSelected={() => handleDialogSelection()}
        viewOnly={viewOnly}
      />
    </>
  );
}

// Memoized: rendered in a grid (one card per NFT), each loading its own image.
// With a stable `selectNFT` from NFTCardGrid, this prevents re-rendering every
// card when an unrelated card toggles its info dialog or selection changes.
export default memo(NFTCard);
