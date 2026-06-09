"use client";

import { switchChain } from "@wagmi/core";
import { type Chain, SwitchChainError, UserRejectedRequestError } from "viem";
import { toast } from "sonner";

import { destNetwork, useBridgeState } from "@/components/Bridge/state";
import { OnAccount } from "@/components/OnAccount";
import { OnNetwork } from "@/components/OnNetwork";
import { setAlternateNetwork } from "@/libs/network/setAlternateNetwork";
import { config } from "@/libs/wagmi";
import { toastConfig } from "@/app.config";
import {
  connectedSourceChain,
  switchingNetwork,
  useConnectedSourceChain,
} from "@/stores/network";
import { useTranslation } from "@/i18n/useTranslation";

import ChainPill from "./ChainPill/ChainPill";
import CombinedChainSelector from "./CombinedChainSelector/CombinedChainSelector";
import type { ChainSelectChangeDetail } from "./SelectorDialogs/ChainsDropdown";
import { ChainSelectorDirection, ChainSelectorType } from "./types";

// $components/NotificationToast `warningToast({ title, message })` -> sonner
// `toast.warning(title, { description: message })`, matching the convention used
// by the migrated `handleBridgeErrors.ts`.
const warningToast = ({
  title,
  message,
}: {
  title: string;
  message?: string;
}) =>
  toast.warning(title, {
    description: message,
    duration: toastConfig.duration,
  });

export interface ChainSelectorProps {
  type: ChainSelectorType;
  direction?: ChainSelectorDirection;
  label?: string;
  switchWallet?: boolean;
}

export default function ChainSelector({
  type,
  direction = ChainSelectorDirection.BOTH,
  label = "",
  switchWallet = false,
}: ChainSelectorProps) {
  const { t } = useTranslation();

  const $connectedSourceChain = useConnectedSourceChain();
  const $destNetwork = useBridgeState(destNetwork);

  async function selectChain(detail: ChainSelectChangeDetail) {
    const { chain: selectedChain, switchWallet } = detail;
    const currentChain = connectedSourceChain.getState();

    if (switchWallet && currentChain) {
      switchingNetwork.setState(true);
      try {
        await switchChain(config, { chainId: selectedChain.id });
        if (currentChain && selectedChain.id === currentChain.id) {
          // swap the chains
          destNetwork.setState(currentChain);
        } else {
          setAlternateNetwork();
        }
      } catch (err) {
        if (err instanceof SwitchChainError) {
          warningToast({
            title: t("messages.network.pending.title"),
            message: t("messages.network.pending.message"),
          });
        } else if (err instanceof UserRejectedRequestError) {
          warningToast({
            title: t("messages.network.rejected.title"),
            message: t("messages.network.rejected.message"),
          });
        } else {
          console.error(err);
        }
      } finally {
        switchingNetwork.setState(false);
      }
    } else {
      destNetwork.setState(selectedChain);
    }
  }

  const onNetworkChange = () => setAlternateNetwork();
  const onAccountChange = () => setAlternateNetwork();

  // $: pillValue = direction === SOURCE ? $connectedSourceChain : DESTINATION ? $destNetwork : null
  const pillValue: Maybe<Chain> | null =
    direction === ChainSelectorDirection.SOURCE
      ? $connectedSourceChain
      : direction === ChainSelectorDirection.DESTINATION
        ? $destNetwork
        : null; // invalid state for pill, must be either source or destination

  return (
    <>
      {type === ChainSelectorType.COMBINED && (
        <CombinedChainSelector onSelectChain={selectChain} />
      )}
      {type === ChainSelectorType.SMALL && (
        <ChainPill
          label={label}
          value={pillValue}
          onChange={selectChain}
          switchWallet={switchWallet}
        />
      )}

      <OnNetwork change={onNetworkChange} />
      <OnAccount change={onAccountChange} />
    </>
  );
}
