// @ts-check
// Note: type annotations allow type checking and IDEs autocompletion

const lightCodeTheme = require("prism-react-renderer/themes/github");
const darkCodeTheme = require("prism-react-renderer/themes/dracula");
const math = require("remark-math");
const katex = require("rehype-katex");

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: "Taiko",
  tagline: "A decentralized Ethereum equivalent ZK rollup",
  url: "https://taiko.xyz",
  baseUrl: "/",
  onBrokenLinks: "throw",
  onBrokenMarkdownLinks: "warn",
  favicon: "img/Taiko_Token_Fluo.png",

  // Even if you don't use internalization, you can use this field to set useful
  // metadata like html lang. For example, if your site is Chinese, you may want
  // to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: "en",
    locales: ["en"],
  },

  presets: [
    [
      "classic",
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: require.resolve("./sidebars.js"),
          // Remove this to remove the "edit this page" links.
          editUrl:
            "https://github.com/taikochain/taiko-mono/tree/main/packages/website/",
          remarkPlugins: [math],
          rehypePlugins: [katex],
        },
        theme: {
          customCss: require.resolve("./src/css/custom.css"),
        },
      }),
    ],
  ],

  stylesheets: [
    "https://fonts.googleapis.com/css2?family=Oxanium:wght@200;300;400;500;700&display=swap",
    {
      href: "https://cdn.jsdelivr.net/npm/katex@0.13.24/dist/katex.min.css",
      type: "text/css",
      integrity:
        "sha384-odtC+0UGzzFL/6PNoE8rX/SPcQDXBJ+uRepguP4QkPCm2LBxH3FA3y+fKSiJ+AmM",
      crossorigin: "anonymous",
    },
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      colorMode: {
        defaultMode: "dark",
        respectPrefersColorScheme: true,
      },
      navbar: {
        logo: {
          alt: "Taiko Logo",
          src: "img/Taiko_Logo_Fluo.svg",
        },
        items: [
          {
            to: "docs/intro",
            label: "Docs",
            position: "left",
          },
          {
            href: "https://mirror.xyz/labs.taiko.eth",
            label: "Blog",
            position: "left",
          },
          {
            href: "https://discord.gg/tnSra3aFfg",
            position: "right",
            className: "header-discord-link",
            "aria-label": "Discord",
          },
          {
            href: "https://github.com/taikochain",
            position: "right",
            className: "header-github-link",
            "aria-label": "GitHub",
          },
          {
            href: "https://twitter.com/taikoxyz",
            position: "right",
            className: "header-twitter-link",
            "aria-label": "Twitter",
          },
        ],
      },
      footer: {
        style: "dark",
        links: [
          {
            label: "Discord",
            href: "https://discord.gg/tnSra3aFfg",
          },
          {
            label: "GitHub",
            href: "https://github.com/taikochain",
          },
          {
            label: "Twitter",
            href: "https://twitter.com/taikoxyz",
          },
        ],
        copyright: `© Taiko Labs ${new Date().getFullYear()}`,
      },
      prism: {
        additionalLanguages: ["solidity"],
        darkTheme: darkCodeTheme,
        theme: lightCodeTheme,
      },
    }),
};

module.exports = config;
