"use client";

import { usePathname } from "next/navigation";

import BridgeTabs from "@/components/Bridge/BridgeTabs";
import { ConnectButton } from "@/components/ConnectButton";
import { IconFlipper } from "@/components/Icon";
import { LogoWithText } from "@/components/Logo";
import { drawerToggleId } from "@/components/SideNavigation";
import { ThemeButton } from "@/components/ThemeButton";
import { useAccount } from "@/stores/account";

export interface HeaderProps {
  /** Original two-way bound `sideBarOpen` (`export let sideBarOpen = false`). */
  sideBarOpen?: boolean;
  /** Emitted when the mobile menu toggle flips `sideBarOpen` (controlled parity). */
  onSideBarOpenChange?: (value: boolean) => void;
}

export default function Header({
  sideBarOpen = false,
  onSideBarOpenChange,
}: HeaderProps) {
  const isConnected = useAccount((state) => state?.isConnected ?? false);

  const pathname = usePathname();

  // $: handleSideBarOpen flips the bound value.
  const handleSideBarOpen = () => {
    onSideBarOpenChange?.(!sideBarOpen);
  };

  // $: flipped = sideBarOpen;
  const flipped = sideBarOpen;

  // $: isBridgePage = $page.route.id === '/';
  const isBridgePage = pathname === "/";
  // $: isTransactionsPage = $page.route.id === '/transactions';
  const isTransactionsPage = pathname === "/transactions";

  return (
    <header
      className="
    sticky-top
    f-between-center
    justify-between
    z-30
    px-4
    py-[20px]

    glassy-background
    bg-grey-5/10
    dark:bg-grey-900/10
    lg:px-10
    lg:py-7
 "
    >
      <div className="flex justify-between items-center w-full">
        <div className="lg:w-[226px] w-auto">
          <LogoWithText className="md:w-[125px] w-[77px]" />
        </div>

        {(isBridgePage || isTransactionsPage) && (
          <BridgeTabs className="hidden lg:flex md:flex-1" />
        )}
        <div className="f-row">
          <ConnectButton connected={isConnected} className="justify-self-end" />
          <div className="hidden lg:inline-flex">
            <div className="v-sep my-auto mx-[8px] h-[24px]" />
            <ThemeButton />
          </div>
        </div>
      </div>
      <label htmlFor={drawerToggleId} className="ml-[10px] lg:hidden">
        <IconFlipper
          type="swap-rotate"
          iconType1="bars-menu"
          iconType2="x-close"
          selectedDefault="bars-menu"
          className="w-9 h-9 rounded-full"
          flipped={flipped}
          onLabelClick={handleSideBarOpen}
        />
      </label>
    </header>
  );
}
