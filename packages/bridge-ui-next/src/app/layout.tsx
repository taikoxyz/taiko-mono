import type { Metadata, Viewport } from "next";
import { Public_Sans } from "next/font/google";
import Script from "next/script";

import AppShell from "@/app/AppShell";
import Providers from "@/app/providers";

import "./globals.css";

// Public Sans (body font) — weights 100/400/700 as in the original app.html.
const publicSans = Public_Sans({
  variable: "--font-public-sans",
  subsets: ["latin"],
  weight: ["100", "400", "700"],
  display: "swap",
});

const APP_DESCRIPTION =
  "Bridge ETH, ERC-20, ERC-721 and ERC-1155 tokens between Ethereum and Taiko.";

export const metadata: Metadata = {
  title: "Taiko Bridge",
  description: APP_DESCRIPTION,
  icons: {
    icon: "/taiko-favicon.svg",
  },
  openGraph: {
    title: "Taiko Bridge",
    description: APP_DESCRIPTION,
    type: "website",
    siteName: "Taiko Bridge",
  },
  twitter: {
    card: "summary",
    title: "Taiko Bridge",
    description: APP_DESCRIPTION,
  },
};

export const viewport: Viewport = {
  width: "device-width",
};

/**
 * No-FOUC theme init — ported verbatim from the original src/app.html inline
 * <head> script. Sets <html data-theme> from localStorage 'theme' (or
 * prefers-color-scheme) BEFORE hydration so the theme never flashes.
 */
const themeInitScript = `
(function () {
  try {
    if (
      (localStorage.getItem('theme') && localStorage.theme.toLocaleLowerCase() === 'dark') ||
      (!('theme' in localStorage) && window.matchMedia('(prefers-color-scheme: dark)').matches)
    ) {
      document.documentElement.setAttribute('data-theme', 'dark');
      localStorage.setItem('theme', 'dark');
    } else {
      document.documentElement.setAttribute('data-theme', 'light');
      localStorage.setItem('theme', 'light');
    }
  } catch (e) {
    document.documentElement.setAttribute('data-theme', 'dark');
  }
})();
`;

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    // data-theme is finalized by the beforeInteractive script below; 'dark' is the SSR default.
    <html
      lang="en"
      data-theme="dark"
      className={publicSans.variable}
      suppressHydrationWarning
    >
      <head>
        {/* Clash Grotesk (headings) — NOT on Google Fonts; loaded from Fontshare.
            (Public Sans is self-hosted via next/font, so no Google Fonts
            preconnects are needed.) */}
        <link rel="preconnect" href="https://api.fontshare.com" />
        <link
          rel="preconnect"
          href="https://cdn.fontshare.com"
          crossOrigin=""
        />
        <link
          href="https://api.fontshare.com/v2/css?f[]=clash-grotesk@200,600&display=swap"
          rel="stylesheet"
        />
        {/* No-FOUC theme init runs before hydration. */}
        <Script id="theme-init" strategy="beforeInteractive">
          {themeInitScript}
        </Script>
      </head>
      <body>
        <Providers>
          {/*
            APP SHELL — ports the markup of the original src/routes/+layout.svelte:
            <Header> + <SideNavigation> wrapping <main>{children}</main>, plus the
            global singletons (AccountConnectionToast, SwitchChainModal,
            BridgePausedModal). NotificationToast is mounted inside Providers.
          */}
          <AppShell>{children}</AppShell>
        </Providers>
      </body>
    </html>
  );
}
