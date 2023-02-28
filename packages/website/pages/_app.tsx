import "../styles.css";
import { Oxanium } from "next/font/google";

const oxanium = Oxanium({
  subsets: ["latin"],
  variable: "--font-oxanium",
});

export default function App({ Component, pageProps }) {
  return (
    <main className={`${oxanium.variable}`}>
      <Component {...pageProps} />
    </main>
  );
}
