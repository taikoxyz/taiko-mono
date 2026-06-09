"use client";

import { QueryClientProvider } from "@tanstack/react-query";
import { I18nextProvider } from "react-i18next";
import { WagmiProvider } from "wagmi";

import AppClientInit from "@/app/AppClientInit";
import ThemeController from "@/app/ThemeController";
import { NotificationToast } from "@/components/NotificationToast";
import i18n from "@/i18n";
import { queryClient } from "@/libs/queryClient";
import { config as wagmiConfig } from "@/libs/wagmi";

/**
 * Centralized client providers.
 *
 * Order (outer -> inner) matters:
 *   WagmiProvider -> QueryClientProvider -> I18nextProvider
 * wagmi v2 requires TanStack Query, and Web3Modal/wagmi hooks expect the
 * QueryClient to be available beneath the WagmiProvider.
 *
 * ThemeController + AppClientInit run client-only side effects (theme sync,
 * web3modal init, pointer vars). NotificationToast is the global notification
 * container (sonner-backed) replacing the original zerodevx svelte-toast.
 *
 * Everything here is client-only — the original SvelteKit app is an SPA
 * (ssr=false) and modules like web3modal/theme read localStorage at runtime.
 */
export default function Providers({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        <I18nextProvider i18n={i18n}>
          <ThemeController />
          <AppClientInit />
          {children}
          <NotificationToast />
        </I18nextProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}
