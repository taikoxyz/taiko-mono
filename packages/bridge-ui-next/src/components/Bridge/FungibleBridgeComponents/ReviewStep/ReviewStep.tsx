"use client";

import { useEffect } from "react";
import { formatUnits } from "viem";

import { chainConfig } from "$chainConfig";
import { Alert } from "@/components/Alert";
import {
  ProcessingFee,
  Recipient,
} from "@/components/Bridge/SharedBridgeComponents";
import DestOwner from "@/components/Bridge/SharedBridgeComponents/RecipientStep/DestOwner";
import {
  destNetwork as destChain,
  destOwnerAddress,
  enteredAmount,
  processingFee,
  selectedToken,
  useBridgeState,
} from "@/components/Bridge/state";
import { useTranslation } from "@/i18n/useTranslation";
import { type ChainConfig, LayerType } from "@/libs/chain";
import { isWrapped, type Token, TokenType } from "@/libs/token";
import { isToken } from "@/libs/token/isToken";
import { account } from "@/stores/account";
import { ethBalance } from "@/stores/balance";
import { connectedSourceChain } from "@/stores/network";
import { publicEnv } from "@/config/env";

const chainConfigMap = chainConfig as Record<string, ChainConfig>;

export interface ReviewStepProps {
  /** Two-way bound (Svelte `bind:hasEnoughEth`). */
  hasEnoughEth?: boolean;
  onHasEnoughEthChange?: (value: boolean) => void;
  /** Two-way bound (Svelte `bind:needsManualReviewConfirmation`). */
  needsManualReviewConfirmation?: boolean;
  onNeedsManualReviewConfirmationChange?: (value: boolean) => void;
  /** Two-way bound (Svelte `bind:hasEnoughFundsToContinue`). */
  hasEnoughFundsToContinue?: boolean;
  onHasEnoughFundsToContinueChange?: (value: boolean) => void;
  /** Svelte `dispatch('editTransactionDetails')` -> `onEditTransactionDetails()`. */
  onEditTransactionDetails?: () => void;
  /** Svelte `dispatch('goBack')` -> `onGoBack()`. */
  onGoBack?: () => void;
}

export default function ReviewStep({
  hasEnoughEth = false,
  onHasEnoughEthChange,
  onNeedsManualReviewConfirmationChange,
  onHasEnoughFundsToContinueChange,
  onEditTransactionDetails,
  onGoBack,
}: ReviewStepProps) {
  const { t } = useTranslation();

  // Reactive store reads (Svelte `$store`).
  const $selectedToken = useBridgeState(selectedToken);
  const $enteredAmount = useBridgeState(enteredAmount);
  const $destChain = useBridgeState(destChain);
  const $processingFee = useBridgeState(processingFee);
  const $destOwnerAddress = useBridgeState(destOwnerAddress);
  const $account = useBridgeState(account);
  const $connectedSourceChain = useBridgeState(connectedSourceChain);

  // PARITY: source is `PUBLIC_SLOW_L1_BRIDGING_WARNING || false`. SvelteKit
  // `$env/static/public` yields the raw string (e.g. "false"/"true") or undefined
  // when unset, so we replicate the exact JS truthiness (any non-empty string is
  // truthy — including "false") rather than coercing with `=== 'true'`.
  const slowL1Warning = publicEnv.SLOW_L1_BRIDGING_WARNING || false;

  // $: renderedDisplay = isToken($selectedToken) ? formatUnits(...) : 0;
  const renderedDisplay =
    isToken($selectedToken) && $selectedToken
      ? formatUnits($enteredAmount, $selectedToken.decimals)
      : 0;

  // $: displayL1Warning = ...
  const displayL1Warning =
    slowL1Warning &&
    Boolean($destChain?.id) &&
    chainConfigMap[$destChain!.id]?.type === LayerType.L1;

  // $: wrapped = $selectedToken !== null && isWrapped($selectedToken as Token);
  const wrapped = $selectedToken !== null && isWrapped($selectedToken as Token);

  // $: wrappedAssetWarning = $t('bridge.alerts.wrapped_eth');
  const wrappedAssetWarning = t("bridge.alerts.wrapped_eth");

  // $: if (wrapped) { needsManualReviewConfirmation = true } else { false }
  useEffect(() => {
    onNeedsManualReviewConfirmationChange?.(wrapped);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [wrapped]);

  // $: hasEnoughFundsToContinue = ... (depends on token type, processingFee, enteredAmount, ethBalance)
  useEffect(() => {
    const eb = ethBalance.getState() ?? 0n;
    let hasEnough: boolean;
    if ($selectedToken?.type === TokenType.ETH) {
      hasEnough = !($processingFee + $enteredAmount > eb);
    } else if ($processingFee > eb) {
      hasEnough = false;
    } else {
      hasEnough = true;
    }
    onHasEnoughFundsToContinueChange?.(hasEnough);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [$selectedToken, $processingFee, $enteredAmount]);

  // Local mirror of `hasEnoughFundsToContinue` for the inline alert below
  // (Svelte read the bound prop directly; recompute it identically here).
  const eb = ethBalance.getState() ?? 0n;
  const hasEnoughFundsToContinue =
    $selectedToken?.type === TokenType.ETH
      ? !($processingFee + $enteredAmount > eb)
      : !($processingFee > eb);

  const editTransactionDetails = () => {
    onEditTransactionDetails?.();
  };

  const goBack = () => {
    onGoBack?.();
  };

  return (
    <>
      <div className="container mx-auto inline-block align-middle space-y-[25px] w-full">
        <div className="flex justify-between items-center">
          <div className="font-bold text-primary-content">
            {t("bridge.nft.step.review.transfer_details")}
          </div>
          <span
            role="button"
            tabIndex={0}
            className="link"
            onKeyDown={goBack}
            onClick={goBack}
          >
            {t("common.edit")}
          </span>
        </div>
        <div className="!mt-[10px]">
          <div className="flex justify-between items-center">
            <div className="text-secondary-content">{t("common.from")}</div>
            <div className="">{$connectedSourceChain?.name}</div>
          </div>

          <div className="flex justify-between items-center">
            <div className="text-secondary-content">{t("common.to")}</div>
            <div className="">{$destChain?.name}</div>
          </div>

          <div className="flex justify-between items-center">
            <div className="text-secondary-content">{t("common.amount")}</div>
            <div className="">{renderedDisplay}</div>
          </div>

          <div className="flex justify-between items-center">
            <div className="text-secondary-content">{t("common.name")}</div>
            <div className="">{$selectedToken?.symbol}</div>
          </div>
        </div>
      </div>

      {displayL1Warning && (
        <Alert type="warning">{t("bridge.alerts.slow_bridging")}</Alert>
      )}

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
        <Recipient small />
        {$destOwnerAddress !== $account?.address && $destOwnerAddress && (
          <DestOwner small />
        )}
        <ProcessingFee
          small
          hasEnoughEth={hasEnoughEth}
          onHasEnoughEthChange={onHasEnoughEthChange}
        />
      </div>

      <div className="h-sep" />
      {!hasEnoughFundsToContinue && (
        <Alert type="error">{t("bridge.alerts.not_enough_funds")}</Alert>
      )}
      {wrapped && (
        <Alert type="warning">
          {/* Source rendered this via `{@html wrappedAssetWarning}`. */}
          <span dangerouslySetInnerHTML={{ __html: wrappedAssetWarning }} />
        </Alert>
      )}
    </>
  );
}
