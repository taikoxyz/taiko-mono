"use client";

import { memo, useState } from "react";
import type { Address } from "viem";

import { selectedNFTs, useBridgeState } from "@/components/Bridge/state";
import { Icon } from "@/components/Icon";
import NFTInfoDialog from "@/components/NFTs/NFTInfoDialog";
import { useTranslation } from "@/i18n/useTranslation";
import { type NFT, TokenType } from "@/libs/token";
import { noop } from "@/libs/util/noop";

export interface NFTListItemProps {
  nft: NFT;
  collectionAddress: Address;
  multiSelectEnabled?: boolean;
  checkedAddresses?: Map<string, boolean>;
  selectNFT: (nft: NFT) => void;
  toggleAddressCheckBox?: (collectionAddress: string) => void;
  /** Svelte `bind:viewOnly` — never mutated by the child, so a plain prop. */
  viewOnly: boolean;
}

const placeholderUrl = "/placeholder.svg";

function NFTListItem({
  nft,
  collectionAddress,
  multiSelectEnabled = false,
  checkedAddresses = new Map(),
  selectNFT,
  toggleAddressCheckBox = noop,
  viewOnly,
}: NFTListItemProps) {
  const { t } = useTranslation();

  const $selectedNFTs = useBridgeState(selectedNFTs);

  const [modalOpen, setModalOpen] = useState(false);

  const handleDialogSelection = () => {
    selectNFT(nft);
    setModalOpen(false);
  };

  const [imageLoaded, setImageLoaded] = useState(false);

  function handleImageLoad() {
    setImageLoaded(true);
  }

  const imageUrl = nft.metadata?.image || placeholderUrl;

  const selected = $selectedNFTs
    ? $selectedNFTs.some(
        (sel) => sel.tokenId === nft.tokenId && sel.addresses === nft.addresses,
      )
    : false;

  return (
    <>
      <div className="form-control flex">
        <label className="cursor-pointer label my-[8px] space-x-[16px]">
          {multiSelectEnabled && !viewOnly ? (
            <input
              type="checkbox"
              className="checkbox checkbox-secondary"
              checked={checkedAddresses.get(collectionAddress) || false}
              onChange={() => toggleAddressCheckBox(collectionAddress)}
            />
          ) : !viewOnly ? (
            <input
              type="radio"
              name="nft-radio"
              checked={selected}
              className="flex-none radio radio-secondary"
              onChange={() => selectNFT(nft)}
            />
          ) : null}
          <div className="avatar h-[56px] w-[56px]">
            <div className="rounded-[10px] bg-primary-background">
              {!imageLoaded && (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  alt="placeholder"
                  src={placeholderUrl}
                  className="rounded bg-white"
                />
              )}
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                alt={nft.name}
                src={imageUrl || ""}
                className=" rounded bg-white"
                onLoad={handleImageLoad}
              />
            </div>
          </div>
          <div className="f-col grow">
            {nft.metadata?.name && (
              <span className="text-xs text-neutral-content font-bold">
                {nft.metadata?.name}
              </span>
            )}
            <span className=" text-xs text-neutral-content">
              {t("common.id")}: {nft.tokenId}
            </span>
            {nft.type === TokenType.ERC1155 && (
              <span className=" text-xs text-neutral-content">
                {t("common.balance")}: {nft.balance}
              </span>
            )}
          </div>
          <button onClick={() => setModalOpen(true)}>
            <Icon type="option-dots" />
          </button>
        </label>
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

// Memoized: rendered once per NFT in a collection list, each loading an image.
// With stable `selectNFT` / `toggleAddressCheckBox` callbacks from NFTList, only
// the items whose `checkedAddresses`/`nft` actually changed re-render.
export default memo(NFTListItem);
