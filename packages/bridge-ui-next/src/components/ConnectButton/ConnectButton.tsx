"use client";

import { useEffect, useState } from "react";

import { ActionButton } from "@/components/Button";
import { Icon } from "@/components/Icon";
import { useResponsive } from "@/hooks/useResponsive";
import { useTranslation } from "@/i18n/useTranslation";
import { getChainImage } from "@/libs/chain";
import { web3modal } from "@/libs/connect";
import { refreshUserBalance, renderEthBalance } from "@/libs/util/balance";
import { shortenAddress } from "@/libs/util/shortenAddress";
import { cn } from "@/lib/utils";
import { useAccount } from "@/stores/account";
import { useEthBalanceStore } from "@/stores/balance";
import { useConnectedSourceChain } from "@/stores/network";

// Svelte: `export let connected = false;` plus implicit `$$props.class`.
export interface ConnectButtonProps {
  connected?: boolean;
  /** Mirrors Svelte's `$$props.class` (applied to the connected-state button). */
  className?: string;
}

export default function ConnectButton({
  connected = false,
  className,
}: ConnectButtonProps) {
  const { t } = useTranslation();

  // Svelte `let web3modalOpen = false`, synced from `web3modal.subscribeState`.
  const [web3modalOpen, setWeb3modalOpen] = useState(false);

  // $: currentChainId = $connectedSourceChain?.id;
  const currentChainId = useConnectedSourceChain((chain) => chain?.id);
  // $: accountAddress = $account?.address || '';
  const accountAddress = useAccount((acc) => acc?.address ?? "");
  // $: balance = $ethBalance || 0n;
  const balance = useEthBalanceStore((b) => b ?? 0n);
  // $: isConnected = connected || $account?.isConnected || false;
  const isAccountConnected = useAccount((acc) => acc?.isConnected ?? false);

  const { isMobile } = useResponsive();

  // $: isConnected = connected || $account?.isConnected || false;
  const isConnected = connected || isAccountConnected || false;
  // $: actuallyConnected = isConnected && accountAddress;
  const actuallyConnected = isConnected && accountAddress;

  function connectWallet() {
    if (web3modalOpen) return;
    web3modal.open();
  }

  // onMount: subscribe to the web3modal state + refresh the eth balance.
  // onDestroy: unsubscribe.
  useEffect(() => {
    const unsubscribe = web3modal.subscribeState((state: { open: boolean }) => {
      setWeb3modalOpen(state.open);
    });
    void refreshUserBalance();
    return () => {
      unsubscribe?.();
    };
  }, []);

  if (actuallyConnected) {
    return (
      <button
        onClick={connectWallet}
        className={cn(
          "rounded-full min-w-[140px] flex items-center justify-center md:pl-[8px] md:pr-[3px] md:max-h-[48px] max-h-[40px] min-h-[40px] wc-parent-glass !border-solid gap-2 font-bold",
          className,
        )}
      >
        <img
          alt="chain icon"
          className="w-[24px] ml-[10px]"
          src={
            (currentChainId && getChainImage(currentChainId)) ||
            "chains/ethereum.svg"
          }
        />
        <span className="flex items-center text-secondary-content justify-self-start gap-4 md:text-normal text-sm">
          {!isMobile && renderEthBalance(balance, 6)}
          <span className="flex items-center justify-center h-[35px] min-w-[133px] text-center text-tertiary-content btn-glass-bg rounded-full px-[10px] py-[4px] bg-tertiary-background">
            {shortenAddress(accountAddress, 4, 6)}
          </span>
        </span>
      </button>
    );
  }

  return (
    <ActionButton
      priority="primary"
      className="!max-w-[215px] !min-h-[32px] !max-h-[48px] !f-items-center !py-0"
      loading={web3modalOpen}
      onClick={connectWallet}
    >
      <div className="flex items-center body-regular space-x-2">
        {web3modalOpen ? (
          <span>{t("wallet.status.connecting")}</span>
        ) : (
          <>
            <Icon
              type="user-circle"
              className="md-show-block"
              fillClass="fill-white"
            />
            <span>{t("wallet.connect")}</span>
          </>
        )}
      </div>
    </ActionButton>
  );
}
