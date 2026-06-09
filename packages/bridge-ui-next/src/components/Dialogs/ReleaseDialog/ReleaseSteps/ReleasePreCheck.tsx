"use client";

// React port of
// src/components/Dialogs/ReleaseDialog/ReleaseSteps/ReleasePreCheck.svelte.
//
// COMPONENT CONVENTION mapping:
//   - `export let canContinue` / `export let hideContinueButton` (two-way
//     `bind:`) -> controlled props + `onCanContinueChange` / `onHideContinueButtonChange`
//     callbacks. The parent (ReleaseDialog) owns the values; this component
//     reports derived changes up via those callbacks.
//   - Reactive `$:` derivations -> `useMemo` / `useEffect`.
//   - `$account` / `$connectedSourceChain` / `$switchingNetwork` stores ->
//     the ported zustand-backed hooks in `@/stores/*`.
//
// PARITY NOTES (verbatim source quirks, intentionally preserved):
//   - `switchChains` switches to `tx.srcChainId` (release happens on the source
//     chain) but the button label interpolates `txDestChainName` (derived from
//     `tx.destChainId`). This mismatch exists in the original and is kept as-is.
//   - `correctChain` compares `tx.srcChainId` against `$connectedSourceChain.id`.
//
// DOM / class strings preserved verbatim for pixel parity.

import { switchChain } from "@wagmi/core";
import { useEffect, useMemo } from "react";

import { ActionButton } from "@/components/Button";
import { Icon } from "@/components/Icon";
import { useTranslation } from "@/i18n/useTranslation";
import type { BridgeTransaction } from "@/libs/bridge";
import { getChainName } from "@/libs/chain";
import { config } from "@/libs/wagmi";
import { useAccount } from "@/stores/account";
import {
  switchingNetwork,
  useConnectedSourceChain,
  useSwitchingNetwork,
} from "@/stores/network";

export interface ReleasePreCheckProps {
  tx: BridgeTransaction;
  /** Two-way bound in the original (`bind:canContinue`). */
  canContinue?: boolean;
  onCanContinueChange?: (value: boolean) => void;
  /** Two-way bound in the original (`bind:hideContinueButton`). */
  hideContinueButton?: boolean;
  onHideContinueButtonChange?: (value: boolean) => void;
}

export default function ReleasePreCheck({
  tx,
  canContinue = false,
  onCanContinueChange,
  hideContinueButton = false,
  onHideContinueButtonChange,
}: ReleasePreCheckProps) {
  const { t } = useTranslation();

  // `$account` reactive subscription (the watcher writes the vanilla store).
  const account = useAccount((state) => state);
  // `$connectedSourceChain` / `$switchingNetwork` reactive subscriptions.
  const connectedSourceChainValue = useConnectedSourceChain();
  const switchingNetworkValue = useSwitchingNetwork();

  const switchChains = async () => {
    switchingNetwork.setState(true);
    try {
      await switchChain(config, { chainId: Number(tx.srcChainId) });
    } catch (err) {
      console.error(err);
    } finally {
      switchingNetwork.setState(false);
    }
  };

  // $: txDestChainName = getChainName(Number(tx.destChainId));
  const txDestChainName = useMemo(
    () => getChainName(Number(tx.destChainId)),
    [tx.destChainId],
  );

  // $: correctChain = Number(tx.srcChainId) === $connectedSourceChain.id;
  const correctChain = Number(tx.srcChainId) === connectedSourceChainValue?.id;

  // $: if (correctChain && $account) { hideContinueButton = false; canContinue = true; }
  //    else { hideContinueButton = true; canContinue = false; }
  useEffect(() => {
    if (correctChain && account) {
      if (hideContinueButton !== false) onHideContinueButtonChange?.(false);
      if (canContinue !== true) onCanContinueChange?.(true);
    } else {
      if (hideContinueButton !== true) onHideContinueButtonChange?.(true);
      if (canContinue !== false) onCanContinueChange?.(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [correctChain, account]);

  return (
    <div className="space-y-[25px] mt-[20px]">
      <div className="flex justify-between mb-2 items-center">
        <div className="font-bold text-primary-content">
          {t("transactions.claim.steps.pre_check.title")}
        </div>
      </div>
      <div className="min-h-[150px] grid content-between">
        <div>
          <div className="f-between-center">
            <span className="text-secondary-content">
              {t("transactions.claim.steps.pre_check.chain_check")}
            </span>
            {correctChain ? (
              <Icon type="check-circle" fillClass="fill-positive-sentiment" />
            ) : (
              <Icon type="x-close-circle" fillClass="fill-negative-sentiment" />
            )}
          </div>
        </div>
      </div>
      {!canContinue && !correctChain ? (
        <>
          <div className="h-sep" />
          <div className="f-col space-y-[16px]">
            <ActionButton
              onPopup
              priority="primary"
              disabled={switchingNetworkValue}
              loading={switchingNetworkValue}
              onClick={() => {
                switchChains();
              }}
            >
              {t("common.switch_to")} {txDestChainName}
            </ActionButton>
          </div>
        </>
      ) : null}
    </div>
  );
}
