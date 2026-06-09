"use client";

import { useEffect, useRef, useState } from "react";

import TokenAmountInput, {
  type TokenAmountInputHandle,
} from "@/components/Bridge/NFTBridgeComponents/ImportStep/TokenAmountInput";
import {
  enteredAmount,
  selectedNFTs,
  tokenBalance,
  useBridgeState,
} from "@/components/Bridge/state";
import { ImportMethod } from "@/components/Bridge/types";
import { ActionButton, Button } from "@/components/Button";
import { Icon, IconFlipper } from "@/components/Icon";
import RotatingIcon from "@/components/Icon/RotatingIcon";
import { NFTDisplay } from "@/components/NFTs";
import { NFTView } from "@/components/NFTs/types";
import { useTranslation } from "@/i18n/useTranslation";
import type { NFT } from "@/libs/token";

import { selectedImportMethod } from "./state";

export interface ScannedImportProps {
  refresh: () => Promise<void>;
  nextPage: () => Promise<void>;
  /** Two-way bound `foundNFTs` (Svelte `bind:foundNFTs`). */
  foundNFTs?: NFT[];
  onFoundNFTsChange?: (value: NFT[]) => void;
  /** Two-way bound `canProceed` (Svelte `bind:canProceed`). */
  canProceed?: boolean;
  onCanProceedChange?: (value: boolean) => void;
}

export default function ScannedImport({
  refresh,
  nextPage,
  foundNFTs = [],
  // onFoundNFTsChange is accepted for API parity; foundNFTs is parent-driven here.
  canProceed = false,
  onCanProceedChange,
}: ScannedImportProps) {
  const { t } = useTranslation();

  const [nftView, setNftView] = useState<NFTView>(NFTView.LIST);
  const [scanning, setScanning] = useState(false);
  const [hasMoreNFTs, setHasMoreNFTs] = useState(true);

  const tokenAmountInput = useRef<TokenAmountInputHandle>(null);

  const previousNFTsRef = useRef<NFT[]>([]);

  const setCanProceed = (v: boolean) => onCanProceedChange?.(v);

  const $selectedNFTs = useBridgeState(selectedNFTs);
  const $enteredAmount = useBridgeState(enteredAmount);
  const $tokenBalance = useBridgeState(tokenBalance);

  const handleNextPage = () => {
    previousNFTsRef.current = foundNFTs;
    setScanning(true);

    nextPage().finally(() => {
      setScanning(false);
    });

    if (previousNFTsRef.current.length === foundNFTs.length) {
      setHasMoreNFTs(false);
    }
  };

  function onRefreshClick() {
    setScanning(true);
    setHasMoreNFTs(true);
    refresh().finally(() => {
      setScanning(false);
    });
  }

  const changeNFTView = () => {
    setNftView((prev) =>
      prev === NFTView.CARDS ? NFTView.LIST : NFTView.CARDS,
    );
  };

  function onManualImportClick() {
    selectedImportMethod.setState(ImportMethod.MANUAL);
  }

  // Reactive derivations ($:)
  const isERC1155 = $selectedNFTs
    ? $selectedNFTs.some((nft) => nft.type === "ERC1155")
    : false;
  const hasSelectedNFT = Boolean($selectedNFTs && $selectedNFTs.length > 0);
  const nftHasAmount = hasSelectedNFT && isERC1155;
  const validBalance = Boolean(
    nftHasAmount &&
      $enteredAmount > 0 &&
      $tokenBalance &&
      $tokenBalance.value >= $enteredAmount,
  );

  // $: if (nftHasAmount && hasSelectedNFT && $selectedNFTs) { ... } else if ... else ...
  useEffect(() => {
    if (nftHasAmount && hasSelectedNFT && $selectedNFTs) {
      tokenAmountInput.current?.determineBalance().then(() => {
        setCanProceed(validBalance ? true : false);
      });
    } else if (!nftHasAmount && hasSelectedNFT) {
      setCanProceed(true);
    } else {
      setCanProceed(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [nftHasAmount, hasSelectedNFT, $selectedNFTs, validBalance]);

  // onMount(() => { $selectedNFTs = []; });
  useEffect(() => {
    selectedNFTs.setState([]);
  }, []);

  void canProceed;

  return (
    <div className="f-col w-full gap-4">
      <section className="space-y-2">
        <div className="flex justify-between items-center w-full">
          <p className="text-primary-content font-bold">
            {t("bridge.nft.step.import.scan_screen.title", {
              number: foundNFTs.length,
            })}
          </p>
          <div className="flex gap-2">
            <Button
              type="neutral"
              shape="circle"
              className="bg-neutral rounded-full w-[28px] h-[28px] border-none"
              onClick={onRefreshClick}
            >
              <RotatingIcon loading={scanning} type="refresh" size={13} />
            </Button>

            <IconFlipper
              type="swap-rotate"
              iconType1="list"
              iconType2="cards"
              selectedDefault="cards"
              className="bg-neutral w-[28px] h-[28px] rounded-full"
              size={20}
              onLabelClick={changeNFTView}
            />
          </div>
        </div>
        <div>
          <NFTDisplay loading={scanning} nfts={foundNFTs} nftView={nftView} />
          <div className="flex pt-[18px]">
            <button
              className={`btn btn-sm rounded-full items-center ${
                hasMoreNFTs ? "border-primary-brand" : "border-none"
              }  dark:text-white hover:bg-primary-interactive-hover btn-secondary bg-transparent light:text-black`}
              disabled={!hasMoreNFTs}
              onClick={handleNextPage}
            >
              {hasMoreNFTs ? (
                <span className="text-primary-color">
                  {t("paginator.more")}
                </span>
              ) : (
                <>
                  <Icon type="check-circle" className="text-primary-brand" />
                  <span className="text-primary-color">
                    {t("paginator.everything_loaded")}
                  </span>
                </>
              )}
            </button>
          </div>
        </div>
      </section>
      {nftHasAmount && (
        <section>
          <TokenAmountInput ref={tokenAmountInput} />
        </section>
      )}

      <div className="flex items-center justify-between space-x-2">
        <p className="text-secondary-content">
          {t("bridge.nft.step.import.scan_screen.description")}
        </p>
        <ActionButton priority="secondary" onClick={onManualImportClick}>
          {t("common.add")}
        </ActionButton>
      </div>
    </div>
  );
}
