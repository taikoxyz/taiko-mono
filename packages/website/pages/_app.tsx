import "../styles.css";

import { Analytics } from "@vercel/analytics/react";
import localFont from "next/font/local";

const grotesk = localFont({
  src: "../fonts/ClashGrotesk-Semibold.woff2",
  display: "swap",
  variable: "--font-grotesk",
});

const groteskmedium = localFont({
  src: "../fonts/ClashGrotesk-Medium.woff2",
  display: "swap",
  variable: "--font-groteskmedium",
});

export default function App({ Component, pageProps }) {
  return (
    <>
      <meta property="og:url" content="https://taiko.xyz/" />
      <meta property="og:type" content="website" />
      <meta property="og:title" content="Taiko" />
      <meta property="og:description" content="Taiko Website" />
      <meta
        property="og:image"
        content={"/images/Taiko_social_media_preview.png"}
      />
      <main className={`${grotesk.variable} ${groteskmedium.variable}`}>
        <Component {...pageProps} />
        <Analytics />
      </main>
    </>
  );
}
