"use client";

import { useState, type ReactNode } from "react";

import { AccountConnectionToast } from "@/components/AccountConnectionToast";
import { BridgePausedModal } from "@/components/BridgePausedModal";
import { Header } from "@/components/Header";
import { SideNavigation } from "@/components/SideNavigation";
import { SwitchChainModal } from "@/components/SwitchChainModal";

/**
 * AppShell — React port of the markup half of the original
 * `src/routes/+layout.svelte`.
 *
 * The original rendered:
 *   <Header bind:sideBarOpen />
 *   <SideNavigation bind:sideBarOpen>
 *     <main><slot /></main>
 *   </SideNavigation>
 *   <NotificationToast />
 *   <AccountConnectionToast />
 *   <SwitchChainModal />
 *   <BridgePausedModal />
 *
 * The two-way bound `sideBarOpen` (shared by Header's mobile menu toggle and
 * SideNavigation's drawer) is lifted into this client component's state and
 * threaded through the controlled `sideBarOpen` / `onSideBarOpenChange` props on
 * both components (the React equivalent of svelte's `bind:`).
 *
 * NotificationToast is mounted once globally in `app/providers.tsx`, so it is
 * intentionally NOT repeated here (it sits at the same root level either way).
 * The remaining three global singletons are rendered here at the root, matching
 * the original layout ordering.
 *
 * The onMount/onDestroy side effects (startWatching/stopWatching, media-query
 * init, pointer vars) live in `AppClientInit`, mounted by Providers.
 */
export default function AppShell({ children }: { children: ReactNode }) {
  // Ports `let sideBarOpen = false` + the two-way `bind:sideBarOpen`.
  const [sideBarOpen, setSideBarOpen] = useState(false);

  return (
    <>
      {/* App components */}
      <Header sideBarOpen={sideBarOpen} onSideBarOpenChange={setSideBarOpen} />
      <SideNavigation
        sideBarOpen={sideBarOpen}
        onSideBarOpenChange={setSideBarOpen}
      >
        <main>{children}</main>
      </SideNavigation>

      {/*
        The following UI is global and should be rendered at the root of the app.
        NotificationToast is mounted in app/providers.tsx.
      */}
      <AccountConnectionToast />

      <SwitchChainModal />

      <BridgePausedModal />
    </>
  );
}
