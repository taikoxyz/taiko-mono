"use client";

import { usePathname } from "next/navigation";
import {
  useCallback,
  useMemo,
  useRef,
  type KeyboardEvent,
  type ReactNode,
} from "react";

import BridgeTabs from "@/components/Bridge/BridgeTabs";
import { Icon } from "@/components/Icon";
import { LinkButton } from "@/components/LinkButton";
import { ThemeButton } from "@/components/ThemeButton";
import { chainConfig } from "@/config/generated/chainConfig";
import { publicEnv } from "@/config/env";
import { useTranslation } from "@/i18n/useTranslation";
import { useConnectedSourceChain } from "@/stores/network";

import { sideNavigationTabs } from "./navigationItems";

export const drawerToggleId = "side-drawer-toggle";

export interface SideNavigationProps {
  /** Controlled drawer-open flag (mirrors svelte's two-way bound `sideBarOpen`). */
  sideBarOpen: boolean;
  /** Emitted when the component closes the drawer (mirrors `sideBarOpen = false`). */
  onSideBarOpenChange?: (open: boolean) => void;
  /** Default slot content rendered inside `.drawer-content`. */
  children?: ReactNode;
}

/** Narrow accessor for the (placeholder-typed) generated chainConfig block explorer url. */
function getExplorerUrl(chainId: number | undefined): string | undefined {
  if (chainId === undefined) return undefined;
  const entry = (chainConfig as Record<string, unknown>)[String(chainId)] as
    | { blockExplorers?: { default?: { url?: string } } }
    | undefined;
  return entry?.blockExplorers?.default?.url;
}

export default function SideNavigation({
  onSideBarOpenChange,
  children,
}: SideNavigationProps) {
  const { t } = useTranslation();
  const pathname = usePathname();
  const connectedSourceChain = useConnectedSourceChain();

  const drawerToggleElem = useRef<HTMLInputElement>(null);

  const testnetName = publicEnv.TESTNET_NAME || "";

  const closeDrawer = useCallback(() => {
    if (!drawerToggleElem.current) return;
    drawerToggleElem.current.checked = false;
    onSideBarOpenChange?.(false);
  }, [onSideBarOpenChange]);

  const onMenuKeydown = useCallback(
    (event: KeyboardEvent) => {
      if (event.key === "Escape" || event.key === "Enter") {
        closeDrawer();
      }
    },
    [closeDrawer],
  );

  function getIconFillClass(active: boolean) {
    return active ? "fill-white" : "fill-primary-icon";
  }

  const isFaucetPage = useMemo(() => pathname === "/faucet", [pathname]);

  return (
    <div className=" drawer lg:drawer-open">
      <input
        id={drawerToggleId}
        type="checkbox"
        className="drawer-toggle"
        ref={drawerToggleElem}
      />
      <div className="drawer-content relative f-col w-full">{children}</div>

      <div className="drawer-side z-20 pt-[81px] lg:pt-[20px] h-full">
        <label htmlFor={drawerToggleId} className="drawer-overlay" />

        {/*
          Slow transitions can be pretty annoying after a while.
          Let's reduce it to 100ms for a better experience.
        */}
        <div className="w-full !duration-100">
          <aside
            className="
        h-full
        px-[20px]
        lg:mt-0
        lg:px-4
        lg:w-[226px]
      "
          >
            <div className="hidden lg:inline-block"></div>
            <div
              role="button"
              tabIndex={0}
              onClick={closeDrawer}
              onKeyPress={closeDrawer}
            >
              <BridgeTabs
                className="lg:hidden flex flex-1 mb-[40px] mt-[20px]"
                onClick={closeDrawer}
              />
            </div>
            <div
              role="button"
              tabIndex={0}
              onClick={closeDrawer}
              onKeyDown={onMenuKeydown}
            >
              <ul className="menu p-0 space-y-2">
                {sideNavigationTabs.map((tab) => (
                  <li key={tab.routeId}>
                    <LinkButton
                      href={tab.href}
                      active={pathname === tab.routeId}
                      onClick={closeDrawer}
                    >
                      <Icon
                        type={tab.icon}
                        fillClass={getIconFillClass(pathname === tab.routeId)}
                      />
                      <span>{t(tab.label)}</span>
                    </LinkButton>
                  </li>
                ))}
                {testnetName !== "" && (
                  <li>
                    <LinkButton href="/faucet" active={isFaucetPage}>
                      <Icon
                        type="faucet"
                        fillClass={getIconFillClass(isFaucetPage)}
                      />
                      <span>{t("nav.faucet")}</span>
                    </LinkButton>
                  </li>
                )}
                {publicEnv.DEFAULT_SWAP_URL &&
                  publicEnv.DEFAULT_SWAP_URL !== "" && (
                    <li className="border-t border-t-divider-border pt-2">
                      <LinkButton href={publicEnv.DEFAULT_SWAP_URL} external>
                        <Icon type="swap" />
                        <span>{t("nav.swap")}</span>
                      </LinkButton>
                    </li>
                  )}
                <li>
                  <LinkButton
                    href={
                      connectedSourceChain
                        ? getExplorerUrl(connectedSourceChain.id)
                        : publicEnv.DEFAULT_EXPLORER
                    }
                    external
                  >
                    <Icon type="explorer" />
                    <span>{t("nav.explorer")}</span>
                  </LinkButton>
                </li>
                <li>
                  <LinkButton href={publicEnv.GUIDE_URL} external>
                    <Icon type="guide" />
                    <span>{t("nav.guide")}</span>
                  </LinkButton>
                </li>
              </ul>
            </div>
            <ul className="">
              <li>
                <div className="p-3 rounded-full flex lg:hidden justify-start content-center">
                  <Icon type="settings" />
                  <div className="flex justify-between w-full pl-[6px]">
                    <span className="text-base">{t("nav.theme")}</span>
                    <ThemeButton mobile />
                  </div>
                </div>
              </li>
            </ul>
          </aside>
        </div>
      </div>
    </div>
  );
}
