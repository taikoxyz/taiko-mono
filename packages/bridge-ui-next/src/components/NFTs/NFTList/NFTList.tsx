"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { selectedNFTs, selectedToken } from "@/components/Bridge/state";
import { useTranslation } from "@/i18n/useTranslation";
import type { NFT } from "@/libs/token";
import { groupNFTByCollection } from "@/libs/util/groupNFTByCollection";
import { publicEnv } from "@/config/env";

import NFTListItem from "./NFTListItem";

export interface NFTListProps {
  /** Svelte `bind:nfts` (parent passes it; this component never mutates it). */
  nfts: NFT[];
  chainId: number | undefined;
  viewOnly?: boolean;
}

const multiSelectEnabled =
  (publicEnv.NFT_BATCH_TRANSFERS_ENABLED || "false") === "true";

export default function NFTList({
  nfts,
  chainId,
  viewOnly = false,
}: NFTListProps) {
  const { t } = useTranslation();

  const [allChecked, setAllChecked] = useState(false);
  const [checkedAddresses, setCheckedAddresses] = useState<
    Map<string, boolean>
  >(new Map());

  // Latest `nfts` / `chainId` / `checkedAddresses` for the stable callbacks
  // below — keeps callback identity stable (they are passed to every memoized
  // NFTListItem) without changing behavior. Refs are synced in an effect so we
  // never write a ref during render.
  const nftsRef = useRef(nfts);
  const chainIdRef = useRef(chainId);
  const checkedAddressesRef = useRef(checkedAddresses);
  useEffect(() => {
    nftsRef.current = nfts;
    chainIdRef.current = chainId;
    checkedAddressesRef.current = checkedAddresses;
  }, [nfts, chainId, checkedAddresses]);

  const toggleAllAddresses = (nextAllChecked: boolean) => {
    const next = new Map(checkedAddresses);
    nfts.forEach((nft) => {
      if (!chainId) return;

      const address = nft.addresses[chainId];
      if (address) {
        next.set(address, nextAllChecked);
      }
    });
    setCheckedAddresses(next);
  };

  const toggleAddressCheckBox = useCallback((collectionAddress: string) => {
    if (!collectionAddress) return;
    const next = new Map(checkedAddressesRef.current);
    next.set(collectionAddress, !next.get(collectionAddress));
    setCheckedAddresses(next);

    // Mirror the original `checkAllCheckboxes(next)` call inline.
    const currentChainId = chainIdRef.current;
    setAllChecked(
      nftsRef.current.every((nft) => {
        if (!currentChainId) return false;
        const collectionAddress = nft.addresses[currentChainId];
        return Boolean(collectionAddress && next.get(collectionAddress));
      }),
    );
  }, []);

  const selectNFT = useCallback((nft: NFT) => {
    const currentChainId = chainIdRef.current;
    if (!selectedNFTs || !currentChainId || !nft) return;
    const address = nft.addresses[currentChainId];
    const foundNFT = nftsRef.current.find(
      (n) =>
        n.addresses[currentChainId] === address && nft.tokenId === n.tokenId,
    );
    const next = foundNFT ? [foundNFT] : null;
    selectedNFTs.setState(next, true);

    if (next) selectedToken.setState(next[0], true);
  }, []);

  const collections = useMemo(() => groupNFTByCollection(nfts), [nfts]);

  if (nfts.length <= 0) return null;

  return (
    <div className="flex flex-col">
      {multiSelectEnabled && !viewOnly && (
        <div className="form-control">
          <label className="cursor-pointer label">
            <span className="label-text">
              {t("bridge.nft.step.import.select_all")}
            </span>
            <input
              type="checkbox"
              checked={allChecked}
              className="checkbox checkbox-secondary mr-[23px]"
              onChange={(e) => {
                setAllChecked(e.target.checked);
                toggleAllAddresses(e.target.checked);
              }}
            />
          </label>
        </div>
      )}
      {!chainId
        ? "Select a chain"
        : Object.entries(collections).map(([address, nftsGroup]) => (
            <div key={address}>
              {nftsGroup.length > 0 && (
                <>
                  <div className="collection-header">
                    <span className="font-bold text-primary-content">
                      {nftsGroup[0].name}
                    </span>
                    <span className="badge badge-primary badge-outline badge-xs px-[10px] h-[24px] ml-[10px]">
                      <span className="text-xs">{nftsGroup[0].type}</span>
                    </span>
                  </div>
                  <div className="token-ids my-[16px]">
                    {nftsGroup.map((nft) => {
                      const collectionAddress = nft.addresses[chainId];
                      if (collectionAddress === undefined) {
                        return (
                          <div key={`${nft.tokenId}`}>
                            TODO: Address for {nft.name} is undefined
                          </div>
                        );
                      }
                      return (
                        <NFTListItem
                          key={`${nft.tokenId}`}
                          nft={nft}
                          multiSelectEnabled={multiSelectEnabled}
                          checkedAddresses={checkedAddresses}
                          collectionAddress={collectionAddress}
                          toggleAddressCheckBox={toggleAddressCheckBox}
                          selectNFT={selectNFT}
                          viewOnly={viewOnly}
                        />
                      );
                    })}
                  </div>
                  {(Object.keys(collections).length > 1 || nfts.length > 3) && (
                    <div className="h-sep my-[30px]" />
                  )}
                </>
              )}
            </div>
          ))}
    </div>
  );
}
