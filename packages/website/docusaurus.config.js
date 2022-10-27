// @ts-check
// Note: type annotations allow type checking and IDEs autocompletion

const lightCodeTheme = require("prism-react-renderer/themes/github");
const darkCodeTheme = require("prism-react-renderer/themes/dracula");

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: "Taiko",
  tagline: "A decentralized Ethereum equivalent ZK rollup",
  url: "https://taiko.xyz",
  baseUrl: "/",
  onBrokenLinks: "throw",
  onBrokenMarkdownLinks: "warn",
  favicon: "img/taiko_icon.png",

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
        },
        theme: {
          customCss: require.resolve("./src/css/custom.css"),
        },
      }),
    ],
  ],

  stylesheets: [
    "https://fonts.googleapis.com/css2?family=Oxanium:wght@200;300;400;500;700&display=swap",
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
          src: "img/Taiko_Icon_Pink.svg",
          srcDark: "img/Taiko_Icon_Pink.svg",
        },
        items: [
          {
            href: "https://mirror.xyz/labs.taiko.eth",
            label: "Blog",
            position: "left",
          },
          {
            href: "https://discord.gg/tnSra3aFfg",
            label: "Discord",
            position: "right",
          },
          {
            href: "https://github.com/taikochain",
            label: "GitHub",
            position: "right",
          },
          {
            href: "https://twitter.com/taikoxyz",
            label: "Twitter",
            position: "right",
          },
        ],
      },
      footer: {
        style: "dark",
        links: [],
        copyright: `© Taiko Labs ${new Date().getFullYear()}`,
      },
      prism: {
        theme: lightCodeTheme,
        darkTheme: darkCodeTheme,
      },
    }),
};

module.exports = config;
