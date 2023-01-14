import { useRouter } from "next/router";
import { useConfig } from "nextra-theme-docs";
import Footer from "components//Footer";
import ThemedImage from "components/ThemedImage";

export default {
  chat: {
    link: "https://discord.gg/taikoxyz",
  },
  docsRepositoryBase:
    "https://github.com/taikoxyz/taiko-mono/blob/main/packages/taikoxyz",
  document: {
    StyleSheet: {
      styles: {
        body: {
          fontFamily: "Oxanium, sans-serif",
        },
      },
    },
  },
  footer: {
    component: <Footer />,
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
        <link rel="icon" href="/images/favicon.png" />
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" />
        <link
          href="https://fonts.googleapis.com/css2?family=Oxanium:wght@400;700&display=swap"
          rel="stylesheet"
        />
      </>
    );
  },
  logo: <ThemedImage />,
  primaryHue: 315,
  project: {
    link: "https://github.com/taikoxyz",
  },
  useNextSeoProps() {
    return {
      titleTemplate: "%s – Taiko",
    };
  },
};
