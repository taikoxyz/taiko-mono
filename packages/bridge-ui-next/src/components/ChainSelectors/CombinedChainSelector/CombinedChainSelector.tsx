"use client";

import { useEffect, useState } from "react";

import { chainConfig } from "@/config/generated/chainConfig";
import { destNetwork, useBridgeState } from "@/components/Bridge/state";
import ChainsDialog from "@/components/ChainSelectors/SelectorDialogs/ChainsDialog";
import ChainsDropdown from "@/components/ChainSelectors/SelectorDialogs/ChainsDropdown";
import type { ChainSelectChangeDetail } from "@/components/ChainSelectors/SelectorDialogs/ChainsDropdown";
import SwitchChainsButton from "@/components/ChainSelectors/SwitchChainsButton/SwitchChainsButton";
import { useDesktopOrLarger } from "@/components/DesktopOrLarger";
import { LoadingMask } from "@/components/LoadingMask";
import type { ChainConfigMap } from "@/libs/chain";
import { setAlternateNetwork } from "@/libs/network/setAlternateNetwork";
import { truncateString } from "@/libs/util/truncateString";
import { useAccount } from "@/stores/account";
import { useConnectedSourceChain } from "@/stores/network";
import { useTranslation } from "@/i18n/useTranslation";

// The generated chainConfig is typed loosely (Record<string, unknown>); narrow it
// to read `.icon`, matching the original `$chainConfig` usage.
const config = chainConfig as unknown as ChainConfigMap;

export interface CombinedChainSelectorProps {
  /** Svelte `selectChain` prop (wired to the dialog/dropdown `change` event). */
  onSelectChain?: (detail: ChainSelectChangeDetail) => void | Promise<void>;
}

export default function CombinedChainSelector({
  onSelectChain,
}: CombinedChainSelectorProps) {
  const { t } = useTranslation();

  const [sourceToggled, setSourceToggled] = useState(false);
  const [destinationToggled, setDestinationToggled] = useState(false);
  // NOTE: `switchingNetwork` is a LOCAL flag in the source (shadows the global
  // store) and is never set to true here — preserved verbatim as local state.
  const [switchingNetwork] = useState(false);
  const isDesktopOrLarger = useDesktopOrLarger();

  const iconSize = "min-w-[24px] max-w-[24px] min-h-[24px] max-h-[24px]";

  const onSourceToggle = () => setSourceToggled((v) => !v);
  const onDestinationToggle = () => setDestinationToggled((v) => !v);

  // $: disabled = !$account || !$account.isConnected;
  const $account = useAccount((a) => a);
  const disabled = !$account || !$account.isConnected;

  // $: srcChain = $connectedSourceChain;
  const srcChain = useConnectedSourceChain();
  // $: destChain = $destNetwork;
  const destChain = useBridgeState(destNetwork);

  const selectClasses = `select bg-transparent appearance-none w-full py-[12px] px-[15px]  focus:border-transparent focus:outline-none focus:bg-primary-background-hover ${
    disabled ? "cursor-not-allowed" : "cursor-pointer"
  }`;

  const containerClasses = `${
    destinationToggled && isDesktopOrLarger
      ? "rounded-t-[10px]"
      : "rounded-[10px]"
  } f-col w-full relative bg-neutral-background `;

  // onMount(() => { setAlternateNetwork(); });
  useEffect(() => {
    setAlternateNetwork();
  }, []);

  const srcIcon = srcChain
    ? config[Number(srcChain.id)]?.icon || "Unknown Chain"
    : undefined;
  const destIcon = destChain
    ? config[Number(destChain.id)]?.icon || "Unknown Chain"
    : undefined;

  return (
    <div className={containerClasses}>
      {switchingNetwork && (
        <LoadingMask
          spinnerClass="border-white absolute z-20"
          text={t("messages.network.switching")}
        />
      )}
      <div className="relative">
        <button
          onClick={() => !disabled && onSourceToggle()}
          className={selectClasses}
        >
          {srcChain ? (
            <div className="f-row items-center gap-2">
              <div className="f-row gap-2 text-right">
                <i role="img" aria-label={srcChain.name}>
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={srcIcon}
                    alt="chain-logo"
                    className={`rounded-full ${iconSize}`}
                  />
                </i>
              </div>
              <span className="text-primary-content text-base">
                {truncateString(srcChain.name, 8)}
              </span>
            </div>
          ) : (
            <span className="text-base text-secondary-content">
              {" "}
              {t("chain_selector.from_placeholder")}
            </span>
          )}
        </button>
        {isDesktopOrLarger ? (
          <ChainsDropdown
            onChange={onSelectChain}
            isOpen={sourceToggled}
            onIsOpenChange={setSourceToggled}
            value={srcChain}
            switchWallet
          />
        ) : (
          <ChainsDialog
            onChange={onSelectChain}
            isOpen={sourceToggled}
            onIsOpenChange={setSourceToggled}
            value={srcChain}
            switchWallet
          />
        )}
      </div>

      {!switchingNetwork && (
        <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 z-20">
          <div className="bg-neutral-background border-[1px] border-primary-border-dark h-6 w-6 rounded-full flex items-center justify-center">
            <SwitchChainsButton disabled={disabled} />
          </div>
        </div>
      )}

      <div className="relative border-t-[1px] border-primary-border-dark">
        <button
          onClick={() => !disabled && onDestinationToggle()}
          className={selectClasses}
        >
          {destChain ? (
            <div className="f-row items-center gap-2">
              <div className="f-row gap-2 text-right">
                <i role="img" aria-label={destChain.name}>
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={destIcon}
                    alt="chain-logo"
                    className={`rounded-full ${iconSize}`}
                  />
                </i>
              </div>
              <span className="text-primary-content text-base">
                {truncateString(destChain.name, 8)}
              </span>
            </div>
          ) : (
            <span className="text-base text-secondary-content">
              {" "}
              {t("chain_selector.to_placeholder")}
            </span>
          )}
        </button>
        {isDesktopOrLarger ? (
          <ChainsDropdown
            onChange={onSelectChain}
            isOpen={destinationToggled}
            onIsOpenChange={setDestinationToggled}
            value={destChain}
          />
        ) : (
          <ChainsDialog
            onChange={onSelectChain}
            isOpen={destinationToggled}
            onIsOpenChange={setDestinationToggled}
            value={destChain}
          />
        )}
      </div>
    </div>
  );
}
