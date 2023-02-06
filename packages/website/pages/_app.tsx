import "../styles.css";
import { Oxanium } from "@next/font/google";
import { ThemeProvider } from "next-themes";

const oxanium = Oxanium({
  subsets: ["latin"],
  variable: "--font-oxanium",
});

export default function MyApp({ Component, pageProps }) {
  return (
    <main className={`${oxanium.variable}`}>
      <Component {...pageProps} />
    </main>
  );
}
