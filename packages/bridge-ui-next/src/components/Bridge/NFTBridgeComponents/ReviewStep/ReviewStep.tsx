"use client";

import { useEffect, useRef, useState } from "react";

import { chainConfig } from "$chainConfig";
import { Alert } from "@/components/Alert";
import {
  ProcessingFee,
  Recipient,
} from "@/components/Bridge/SharedBridgeComponents";
import type {
  ProcessingFeeHandle,
  RecipientHandle,
} from "@/components/Bridge/SharedBridgeComponents";
import {
  destNetwork as destChain,
  enteredAmount,
  selectedNFTs,
  selectedToken,
  useBridgeState,
} from "@/components/Bridge/state";
import {
  ChainSelector,
  ChainSelectorDirection,
  ChainSelectorType,
} from "@/components/ChainSelectors";
import { IconFlipper } from "@/components/Icon";
import { NFTDisplay } from "@/components/NFTs";
// The original defined a LOCAL `enum NFTView { CARDS, LIST }` inline. We reuse the
// shared NFTs `NFTView` (identical members + order: CARDS=0, LIST=1) so the value
// is type-compatible with the `NFTDisplay` prop. Behaviour is identical.
import { NFTView } from "@/components/NFTs/types";
import { useTranslation } from "@/i18n/useTranslation";
import { publicEnv } from "@/config/env";
import type { ChainConfigMap } from "@/libs/chain";
import { LayerType } from "@/libs/chain";
import type { NFT } from "@/libs/token";
import { fetchNFTImageUrl } from "@/libs/token/fetchNFTImageUrl";
import { shortenAddress } from "@/libs/util/shortenAddress";
import { connectedSourceChain } from "@/stores/network";

// Loosely-typed generated chainConfig narrowed to the original `ChainConfigMap` shape.
const chainConfigMap = chainConfig as unknown as ChainConfigMap;

export interface ReviewStepProps {
  /** Two-way bound `hasEnoughEth` (Svelte `bind:hasEnoughEth`). */
  hasEnoughEth?: boolean;
  onHasEnoughEthChange?: (value: boolean) => void;
  /** Svelte `dispatch('editTransactionDetails')` -> callback prop. */
  onEditTransactionDetails?: () => void;
}

export default function ReviewStep({
  hasEnoughEth = false,
  onHasEnoughEthChange,
  onEditTransactionDetails,
}: ReviewStepProps) {
  const { t } = useTranslation();

  const recipientComponent = useRef<RecipientHandle>(null);
  const processingFeeComponent = useRef<ProcessingFeeHandle>(null);

  // let slowL1Warning = PUBLIC_SLOW_L1_BRIDGING_WARNING || false;
  const slowL1Warning = publicEnv.SLOW_L1_BRIDGING_WARNING || false;

  const $destChain = useBridgeState(destChain);
  const $selectedNFTs = useBridgeState(selectedNFTs);
  const $enteredAmount = useBridgeState(enteredAmount);
  const $connectedSourceChain = useBridgeState(connectedSourceChain);

  const [nftView, setNftView] = useState<NFTView>(NFTView.CARDS);
  const [nftsToDisplay, setNftsToDisplay] = useState<NFT[]>([]);

  // $: displayL1Warning = slowL1Warning && $destChain?.id && chainConfig[$destChain.id].type === LayerType.L1;
  const displayL1Warning = Boolean(
    slowL1Warning &&
      $destChain?.id &&
      chainConfigMap[$destChain.id].type === LayerType.L1,
  );

  const changeNFTView = () => {
    setNftView((prev) =>
      prev === NFTView.CARDS ? NFTView.LIST : NFTView.CARDS,
    );
  };

  const fetchImage = async () => {
    const nfts = selectedNFTs.getState();
    if (!nfts || nfts.length === 0) return;
    const srcChainId = connectedSourceChain.getState()?.id;
    const destChainId = destChain.getState()?.id;
    if (!srcChainId || !destChainId) return;

    await Promise.all(
      nfts.map(async (nft) => {
        fetchNFTImageUrl(nft).then((nftWithUrl) => {
          selectedToken.setState(nftWithUrl);
          selectedNFTs.setState([nftWithUrl]);
        });
      }),
    );
    setNftsToDisplay(selectedNFTs.getState() ?? []);
  };

  const editTransactionDetails = () => {
    onEditTransactionDetails?.();
  };

  // onMount(async () => { await fetchImage(); });
  useEffect(() => {
    void fetchImage();
  }, []);

  // $: nftsToDisplay = $selectedNFTs ? $selectedNFTs : [];
  useEffect(() => {
    setNftsToDisplay($selectedNFTs ?? []);
  }, [$selectedNFTs]);

  // $: isERC1155 = $selectedNFTs ? $selectedNFTs.some((nft) => nft.type === 'ERC1155') : false;
  const isERC1155 = $selectedNFTs
    ? $selectedNFTs.some((nft) => nft.type === "ERC1155")
    : false;

  void hasEnoughEth;

  return (
    <>
      <div className="container mx-auto inline-block align-middle space-y-[25px] w-full mt-[30px]">
        <div className="flex justify-between mb-2 items-center">
          <div className="font-bold text-primary-content">
            {t("bridge.nft.step.review.transfer_details")}
          </div>
          <span
            role="button"
            tabIndex={0}
            className="link"
            onKeyDown={editTransactionDetails}
            onClick={editTransactionDetails}
          >
            {t("common.edit")}
          </span>
        </div>
        <div>
          <div className="flex justify-between items-center">
            <div className="text-secondary-content">{t("common.from")}</div>
            <div className="">{$connectedSourceChain?.name}</div>
          </div>
          <div className="flex justify-between items-center">
            <div className="text-secondary-content">{t("common.to")}</div>
            <div className="">{$destChain?.name}</div>
          </div>

          <div className="flex justify-between">
            <div className="text-secondary-content">
              {t("common.contract_address")}
            </div>
            <div className="">
              <ul>
                {nftsToDisplay.map((nft, index) => {
                  const currentChain = $connectedSourceChain?.id;
                  if (currentChain && $destChain?.id) {
                    return (
                      <li key={index}>
                        <a
                          className="flex justify-start link"
                          href={`${chainConfigMap[currentChain]?.blockExplorers?.default.url}/token/${nft.addresses[currentChain]}`}
                          target="_blank"
                        >
                          {shortenAddress(nft.addresses[currentChain], 8, 12)}
                          {/* <Icon type="arrow-top-right" fillClass="fill-primary-link" /> */}
                        </a>
                      </li>
                    );
                  }
                  return null;
                })}
              </ul>
            </div>
          </div>

          <div className="flex justify-between">
            <div className="text-secondary-content">
              {t("inputs.token_id_input.label")}
            </div>
            <div className="break-words text-right">
              <ul>
                {nftsToDisplay.map((nft, index) => (
                  <li key={index}>{nft.tokenId}</li>
                ))}
              </ul>
            </div>
          </div>
          {isERC1155 && (
            <div className="flex justify-between">
              <div className="text-secondary-content">{t("common.amount")}</div>
              {String($enteredAmount)}
            </div>
          )}
        </div>
      </div>

      {displayL1Warning && (
        <Alert type="warning">{t("bridge.alerts.slow_bridging")}</Alert>
      )}

      {/*
      NFT List or Card View
      */}
      <section className="space-y-[16px]">
        <div className="flex justify-between items-center w-full">
          <div className="flex items-center gap-2">
            <span></span>
            <ChainSelector
              type={ChainSelectorType.SMALL}
              direction={ChainSelectorDirection.SOURCE}
              label={t("bridge.nft.step.review.your_tokens")}
            />
          </div>
          <div className="flex gap-2">
            <IconFlipper
              type="swap-rotate"
              iconType1="list"
              iconType2="cards"
              selectedDefault="list"
              className="bg-neutral w-9 h-9 rounded-full"
              onLabelClick={changeNFTView}
            />
            {/* <Icon type="list" fillClass="fill-primary-icon" size={24} vWidth={24} vHeight={24} /> */}
          </div>
        </div>
        <NFTDisplay
          loading={false}
          nfts={$selectedNFTs}
          nftView={nftView}
          viewOnly
        />
      </section>

      <div className="h-sep" />
      {/*
      Recipient & Processing Fee
      */}

      <div className="f-col">
        <div className="f-between-center mb-[10px]">
          <div className="font-bold text-primary-content">
            {t("bridge.nft.step.review.recipient_details")}
          </div>
          <button
            className="flex justify-start link"
            onClick={editTransactionDetails}
          >
            {" "}
            {t("common.edit")}{" "}
          </button>
        </div>
        <Recipient ref={recipientComponent} small />
        <ProcessingFee
          ref={processingFeeComponent}
          small
          hasEnoughEth={hasEnoughEth}
          onHasEnoughEthChange={onHasEnoughEthChange}
        />
      </div>

      <div className="h-sep" />
    </>
  );
}
