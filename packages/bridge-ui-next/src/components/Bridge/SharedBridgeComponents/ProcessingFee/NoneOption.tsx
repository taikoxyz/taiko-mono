"use client";

import { useEffect, useRef } from "react";
import { type Address, parseEther } from "viem";

import { Alert, FlatAlert } from "@/components/Alert";
import {
  destNetwork,
  enteredAmount,
  recipientAddress,
  selectedNFTs,
  selectedToken,
  useBridgeState,
} from "@/components/Bridge/state";
import { claimConfig } from "$config";
import { recommendProcessingFee } from "@/libs/fee";
import { fetchBalance, type NFT, type Token, TokenType } from "@/libs/token";
import { useAccount, useConnectedSourceChain } from "@/stores";
import { useTranslation } from "@/i18n/useTranslation";

import { getManualClaimHref } from "./getManualClaimHref";

export interface NoneOptionProps {
  /** `bind:enoughEth` controlled value + write-back. */
  enoughEth?: boolean;
  onEnoughEthChange?: (value: boolean) => void;
  /** `bind:calculating` controlled value + write-back. */
  calculating?: boolean;
  onCalculatingChange?: (value: boolean) => void;
  /** `bind:error` controlled value + write-back. */
  error?: boolean;
  onErrorChange?: (value: boolean) => void;

  selected?: boolean;
  headless?: boolean;
}

export default function NoneOption({
  enoughEth = false,
  onEnoughEthChange,
  onCalculatingChange,
  onErrorChange,
  selected = false,
  headless = false,
}: NoneOptionProps) {
  const { t } = useTranslation();

  // Bridge-state stores (mirror the reactive `$selectedToken` etc.).
  const $selectedToken = useBridgeState(selectedToken);
  const $destNetwork = useBridgeState(destNetwork);
  const $enteredAmount = useBridgeState(enteredAmount);
  const $recipientAddress = useBridgeState(recipientAddress);
  const $selectedNFTs = useBridgeState(selectedNFTs);
  const $account = useAccount((s) => s);
  const $connectedSourceChain = useConnectedSourceChain();

  // Latest write-back callbacks via refs so re-renders never re-run compute.
  const onEnoughEthChangeRef = useRef(onEnoughEthChange);
  const onCalculatingChangeRef = useRef(onCalculatingChange);
  const onErrorChangeRef = useRef(onErrorChange);
  useEffect(() => {
    onEnoughEthChangeRef.current = onEnoughEthChange;
    onCalculatingChangeRef.current = onCalculatingChange;
    onErrorChangeRef.current = onErrorChange;
  });

  async function compute(
    token: Maybe<Token | NFT>,
    userAddress?: Address,
    srcChain?: number,
    destChain?: number,
    to?: Address,
    tokenIds?: number[],
    amounts?: number[],
  ) {
    if (!token || !userAddress || !srcChain || !destChain) {
      onEnoughEthChangeRef.current?.(false);
      return;
    }

    onCalculatingChangeRef.current?.(true);
    onErrorChangeRef.current?.(false);

    try {
      // Get the balance of the user on the destination chain
      const destBalance = await fetchBalance({
        userAddress,
        srcChainId: destChain,
      });

      // Calculate the recommended amount of ETH needed for processMessage call
      let recommendedAmount = await recommendProcessingFee({
        token,
        destChainId: destChain,
        srcChainId: srcChain,
        to,
        tokenIds,
        amounts,
      });

      const minimumClaimBalance = parseEther(
        String(claimConfig.minimumEthToClaim),
      );
      if (recommendedAmount <= minimumClaimBalance) {
        // should the fee be very small, set it to at least the minimum
        recommendedAmount = minimumClaimBalance;
      }

      // Does the user have enough ETH to claim manually on the destination chain?
      onEnoughEthChangeRef.current?.(
        destBalance ? destBalance.value >= recommendedAmount : false,
      );
    } catch (err) {
      console.error(err);

      onErrorChangeRef.current?.(true);
      onEnoughEthChangeRef.current?.(false);
    } finally {
      onCalculatingChangeRef.current?.(false);
    }
  }

  // $: compute(...)
  useEffect(() => {
    compute(
      $selectedToken,
      $account?.address,
      $connectedSourceChain?.id,
      $destNetwork?.id,
      $recipientAddress || $account?.address,
      $selectedNFTs?.map((nft) => nft.tokenId),
      $selectedToken?.type === TokenType.ERC1155
        ? [Number($enteredAmount)]
        : undefined,
    );
  }, [
    $selectedToken,
    $account?.address,
    $connectedSourceChain?.id,
    $destNetwork?.id,
    $recipientAddress,
    $selectedNFTs,
    $enteredAmount,
  ]);

  // $: manualClaimHref = getManualClaimHref({ selected, enoughEth })
  const manualClaimHref = getManualClaimHref({ selected, enoughEth });

  if (headless) return null;

  return (
    <>
      {!enoughEth ? (
        <FlatAlert type="error" message={t("processing_fee.none.warning")} />
      ) : selected ? (
        <div className="my-5 space-y-3">
          <Alert type="warning">
            <span className="body-small">{t("processing_fee.none.alert")}</span>
          </Alert>

          {manualClaimHref && (
            <a
              href={manualClaimHref}
              className="link inline-flex body-small-bold"
            >
              {t("processing_fee.none.claim")}
            </a>
          )}
        </div>
      ) : null}
    </>
  );
}
