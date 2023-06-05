import "../styles.css";
import localFont from "next/font/local";
import { Analytics } from "@vercel/analytics/react";

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
    <main className={`${grotesk.variable} ${groteskmedium.variable}`}>
      <Component {...pageProps} />
      <Analytics />
    </main>
  );
}
