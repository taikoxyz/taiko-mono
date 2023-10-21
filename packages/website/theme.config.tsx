import { Footer } from "./components/Home";
import { ThemedImage } from "./components/ThemedImage";
import { useConfig } from "nextra-theme-docs";
import { useRouter } from "next/router";
import { ThemeToggle } from "./components/ThemeToggle";
import { TAIKO_CONFIG } from "./domain/chain";

export default {
  banner: {
    key: "banner",
    text: (
      <a href="/docs/guides" target="_blank">
        📌 {TAIKO_CONFIG.names.shortName} is here! Get started →
      </a>
    ),
  },
  chat: {
    link: "https://discord.gg/taikoxyz",
  },
  darkMode: false,
  docsRepositoryBase:
    "https://github.com/taikoxyz/taiko-mono/blob/main/packages/website",
  editLink: {
    text: "Edit this page 📝",
  },
  feedback: {
    content: (
      <button
        onClick={() => {
          const win = window.open(
            "https://forms.gle/TAnV1xLmFwH13ryj7",
            "_blank",
            "noopener,noreferrer"
          );
          if (win) win.opener = null;
        }}
      >
        Leave feedback 💬
      </button>
    ),
  },
  footer: {
    component: Footer,
  },
  head: () => {
    const { asPath } = useRouter();
    const { frontMatter } = useConfig();
    return (
      <>
        <meta property="og:url" content={`https://taiko.xyz${asPath}`} />
        <meta property="og:title" content={frontMatter.title || "Taiko"} />
        <meta
          property="og:description"
          content={
            frontMatter.description ||
            "A decentralized, Ethereum-equivalent ZK-Rollup."
          }
        />
        <meta
          property="og:image"
          content={"/images/Taiko_social_media_preview.png"}
        />
        <link rel="icon" href="/images/favicon.svg" />
      </>
    );
  },
  logo: <ThemedImage />,
  navbar: {
    extraContent: (
      <>
        <ThemeToggle />
      </>
    ),
  },
  nextThemes: {
    defaultTheme: "light",
  },
  primaryHue: 323,
  project: {
    link: "https://github.com/taikoxyz",
  },
  useNextSeoProps() {
    return {
      titleTemplate: "%s – Taiko",
    };
  },
  sidebar: {
    autoCollapse: true,
  },
};
