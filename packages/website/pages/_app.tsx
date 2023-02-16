import "../styles.css";
import { Oxanium } from "@next/font/google";
import ScrollTrigger from "gsap/dist/ScrollTrigger";
import gsap from "gsap/dist/gsap";

const oxanium = Oxanium({
  subsets: ["latin"],
  variable: "--font-oxanium",
});

gsap.registerPlugin(ScrollTrigger);

export default function MyApp({ Component, pageProps }) {
  return (
    <main className={`${oxanium.variable}`}>
      <Component {...pageProps} />
    </main>
  );
}
