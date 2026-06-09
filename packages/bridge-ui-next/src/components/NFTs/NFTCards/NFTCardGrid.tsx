"use client";

import { useCallback, useEffect, useMemo, useRef } from "react";

import { selectedNFTs, selectedToken } from "@/components/Bridge/state";
import NFTCard from "@/components/NFTs/NFTCards/NFTCard";
import type { NFT } from "@/libs/token";
import { groupNFTByCollection } from "@/libs/util/groupNFTByCollection";
import {
  connectedSourceChain,
  useConnectedSourceChain,
} from "@/stores/network";

export interface NFTCardGridProps {
  /** Svelte `bind:nfts` (the parent passes it; this component never mutates it). */
  nfts?: NFT[];
  viewOnly?: boolean;
}

export default function NFTCardGrid({
  nfts = [],
  viewOnly = false,
}: NFTCardGridProps) {
  const $connectedSourceChain = useConnectedSourceChain();

  // `selectNFT` is passed to every memoized NFTCard, so keep its identity stable.
  // The selected list + chain are read from their vanilla stores at call time;
  // only `nfts` (a prop) is mirrored into a ref (synced in an effect) so the
  // callback can read the latest array without depending on it. Behavior is
  // identical to closing over the values directly — it only runs on card click.
  const nftsRef = useRef(nfts);
  useEffect(() => {
    nftsRef.current = nfts;
  }, [nfts]);

  const selectNFT = useCallback((nft: NFT) => {
    const currentChainId = connectedSourceChain.getState()?.id;

    if (!currentChainId || !nft) return;
    const currentNFTs = nftsRef.current;
    const currentSelected = selectedNFTs.getState();
    const address = nft.addresses[currentChainId];
    const foundNFT = currentNFTs.find(
      (n) =>
        n.addresses[currentChainId] === address && nft.tokenId === n.tokenId,
    );

    if (currentSelected && foundNFT && currentSelected.includes(foundNFT)) {
      // Deselect
      selectedNFTs.setState(
        currentSelected.filter((selected) => selected.tokenId !== nft.tokenId),
        true,
      );
      selectedToken.setState(null, true);
    } else {
      // Select
      const next = foundNFT ? [foundNFT] : null;
      selectedNFTs.setState(next, true);
      if (next) selectedToken.setState(next[0], true);
    }
  }, []);

  const collections = useMemo(() => groupNFTByCollection(nfts), [nfts]);

  return (
    <>
      {Object.entries(collections).map(([address, nftsGroup]) => {
        const chainId = $connectedSourceChain?.id;
        return (
          <div className="" key={address}>
            {nftsGroup.length > 0 && chainId && (
              <>
                <div className="collection-header">
                  <span className="font-bold text-primary-content">
                    {nftsGroup[0].name}
                  </span>
                  <span className="badge badge-primary badge-outline badge-xs px-[10px] h-[24px] ml-[10px]">
                    <span className="text-xs">{nftsGroup[0].type}</span>
                  </span>
                </div>
                <div className="token-ids mt-[16px] grid gap-4 md:grid-cols-3 grid-cols-2">
                  {nftsGroup.map((nft) => (
                    <NFTCard
                      key={`${nft.tokenId}`}
                      nft={nft}
                      selectNFT={selectNFT}
                      viewOnly={viewOnly}
                    />
                  ))}
                </div>
                {(Object.keys(collections).length > 1 || nfts.length > 3) && (
                  <div className="h-sep my-[30px]" />
                )}
              </>
            )}
          </div>
        );
      })}
    </>
  );
}
