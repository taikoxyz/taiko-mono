"use client";

import { useCallback, useEffect, useId, useState } from "react";
import { type Address, zeroAddress } from "viem";

import { chainConfig } from "@/config/generated/chainConfig";
import { destNetwork } from "@/components/Bridge/state";
import { useBridgeState } from "@/components/Bridge/state";
import { ActionButton, CloseButton } from "@/components/Button";
import { Icon } from "@/components/Icon";
import { Spinner } from "@/components/Spinner";
import { useTranslation } from "@/i18n/useTranslation";
import { cn } from "@/lib/utils";
import type { ChainConfigMap } from "@/libs/chain";
import type { NFT } from "@/libs/token";
import { getTokenAddresses } from "@/libs/token/getTokenAddresses";
import { shortenAddress } from "@/libs/util/shortenAddress";
import { useConnectedSourceChain } from "@/stores/network";

// The generated chainConfig is typed loosely (Record<string, unknown>); narrow it
// to read `.icon` / `.blockExplorers`, matching the original `$chainConfig` usage.
const config = chainConfig as unknown as ChainConfigMap;

const placeholderUrl = "/placeholder.svg";

export interface NFTInfoDialogProps {
  /** Svelte `bind:modalOpen` -> controlled `modalOpen` + `onModalOpenChange`. */
  modalOpen: boolean;
  onModalOpenChange?: (open: boolean) => void;
  viewOnly?: boolean;
  nft: NFT;
  /** Svelte `export let srcChainId = Number($connectedSourceChain?.id)`. */
  srcChainId?: number;
  /** Svelte `export let destChainId = Number($destNetwork?.id)`. */
  destChainId?: number;
  /** Svelte `dispatch('selected', nft)` -> `onSelected(nft)`. */
  onSelected?: (nft: NFT) => void;
}

export default function NFTInfoDialog({
  modalOpen,
  onModalOpenChange,
  viewOnly = false,
  nft,
  srcChainId: srcChainIdProp,
  destChainId: destChainIdProp,
  onSelected,
}: NFTInfoDialogProps) {
  const { t } = useTranslation();

  // Stable, SSR-safe id replacing `crypto.randomUUID()` at script init.
  const dialogId = `dialog-${useId()}`;

  const $connectedSourceChain = useConnectedSourceChain();
  const $destNetwork = useBridgeState(destNetwork);

  const srcChainId = srcChainIdProp ?? Number($connectedSourceChain?.id);
  const destChainId = destChainIdProp ?? Number($destNetwork?.id);

  const [bridgedAddress, setBridgedAddress] = useState<Address>("" as Address);
  const [bridgedChain, setBridgedChain] = useState(0);

  const [fetchingAddress, setFetchingAddress] = useState(false);

  const [canonicalAddress, setCanonicalAddress] = useState("");
  const [canonicalChain, setCanonicalChain] = useState(0);

  const closeModal = useCallback(() => {
    onModalOpenChange?.(false);
  }, [onModalOpenChange]);

  const selectNFT = () => {
    onSelected?.(nft);
    closeModal();
  };

  const fetchTokenAddresses = useCallback(async () => {
    setFetchingAddress(true);

    if (!srcChainId || !destChainId || !nft) return;

    try {
      const tokenInfo = await getTokenAddresses({
        token: nft,
        srcChainId,
        destChainId,
      });

      if (!tokenInfo) return;

      if (
        tokenInfo.canonical?.address &&
        tokenInfo.canonical?.address !== zeroAddress
      ) {
        setCanonicalAddress(tokenInfo.canonical?.address);
        setCanonicalChain(tokenInfo.canonical?.chainId);
      }

      if (
        tokenInfo.bridged?.address &&
        tokenInfo.bridged?.address !== zeroAddress
      ) {
        setBridgedAddress(tokenInfo.bridged?.address);
        setBridgedChain(tokenInfo.bridged?.chainId);
      }
    } catch (error) {
      console.error(error);
    }
    setFetchingAddress(false);
  }, [srcChainId, destChainId, nft]);

  const [imageLoaded, setImageLoaded] = useState(false);

  function handleImageLoad() {
    setImageLoaded(true);
  }

  // $: if (modalOpen) { fetchTokenAddresses(); }
  // Faithful port of a Svelte reactive statement; `fetchTokenAddresses` flips a
  // loading flag synchronously, which is intentional here.
  useEffect(() => {
    if (modalOpen) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      fetchTokenAddresses();
    }
  }, [modalOpen, fetchTokenAddresses]);

  // onMount(async () => { await fetchTokenAddresses(); });
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    fetchTokenAddresses();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const imageUrl = nft?.metadata?.image || placeholderUrl;

  const showBridgedAddress = destChainId && bridgedAddress && !fetchingAddress;

  return (
    <dialog
      id={dialogId}
      className={cn("modal modal-bottom md:modal-middle", {
        "modal-open": modalOpen,
      })}
    >
      <div className="modal-box relative px-[24px] py-[35px] md:rounded-[20px] bg-neutral-background">
        <CloseButton onClick={closeModal} />
        <div className="f-col w-full space-y-[30px]">
          <h3 className="title-body-bold">
            {t("bridge.nft.step.import.nft_card.title")}
          </h3>
          {!imageLoaded && (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              alt="placeholder"
              src={placeholderUrl}
              className="rounded-[20px] self-center bg-white"
            />
          )}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            alt="nft"
            src={imageUrl || ""}
            className={cn(
              "rounded-[20px] self-center bg-white",
              !imageLoaded || imageUrl === "" ? "hidden" : "",
            )}
            onLoad={handleImageLoad}
          />
          <div id="metadata">
            <div className="f-between-center">
              <div className="text-secondary-content">
                {t("common.collection")}
              </div>
              <div className="text-primary-content">{nft?.name}</div>
            </div>
            {/*  CANONICAL INFO */}
            <div className="f-between-center">
              <div className="f-row min-w-1/2 self-end gap-2 items-center text-secondary-content">
                {t("common.canonical_address")}
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  alt="source chain icon"
                  src={config[Number(canonicalChain)]?.icon}
                  className="w-4 h-4"
                />
              </div>
              <div className="f-row min-w-1/2 text-primary-content">
                {fetchingAddress ? (
                  <>
                    <Spinner className="h-[10px] w-[10px] " />
                    {t("common.loading")}
                  </>
                ) : canonicalChain && canonicalAddress ? (
                  <a
                    className="flex justify-start link"
                    href={`${config[canonicalChain]?.blockExplorers?.default.url}/token/${canonicalAddress}`}
                    target="_blank"
                  >
                    {shortenAddress(canonicalAddress, 6, 8)}
                    <Icon
                      type="arrow-top-right"
                      fillClass="fill-primary-link"
                    />
                  </a>
                ) : null}
              </div>
            </div>
            {/* BRIDGED INFO */}
            <div className="f-between-center">
              {showBridgedAddress && bridgedAddress ? (
                <>
                  <div className="f-row min-w-1/2 gap-2 items-center text-secondary-content">
                    {t("common.bridged_address")}
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      alt="destination chain icon"
                      src={config[Number(bridgedChain)]?.icon}
                      className="w-4 h-4"
                    />
                  </div>
                  <div className="f-row min-w-1/2 text-primary-content">
                    {bridgedChain && bridgedAddress ? (
                      <a
                        className="flex justify-start link"
                        href={`${config[bridgedChain]?.blockExplorers?.default.url}/token/${bridgedAddress}`}
                        target="_blank"
                      >
                        {shortenAddress(bridgedAddress, 6, 8)}
                        <Icon
                          type="arrow-top-right"
                          fillClass="fill-primary-link"
                        />
                      </a>
                    ) : null}
                    {fetchingAddress ? (
                      <>
                        <Spinner className="h-[10px] w-[10px] " />
                        {t("common.loading")}
                      </>
                    ) : null}
                  </div>
                </>
              ) : null}
            </div>
            <div className="f-between-center">
              <div className="text-secondary-content">
                {t("common.token_id")}
              </div>
              <div className="text-primary-content">{nft?.tokenId}</div>
            </div>
            <div className="f-between-center">
              <div className="text-secondary-content">
                {t("common.token_standard")}
              </div>
              <div className="text-primary-content">{nft?.type}</div>
            </div>
          </div>
          <div className="f-col">
            {viewOnly ? (
              <ActionButton priority="primary" onClick={closeModal}>
                {t("common.ok")}
              </ActionButton>
            ) : (
              <>
                <ActionButton
                  priority="primary"
                  className="px-[28px] py-[14px] rounded-full flex-1 w-full text-white"
                  onClick={() => selectNFT()}
                >
                  {t("bridge.nft.step.import.nft_card.select")}
                </ActionButton>

                <button
                  onClick={closeModal}
                  className="flex mt-[16px] mb-0 justify-center link"
                >
                  {t("common.cancel")}
                </button>
              </>
            )}
          </div>
        </div>
      </div>
    </dialog>
  );
}
