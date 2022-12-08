// @ts-check
// Note: type annotations allow type checking and IDEs autocompletion

const lightCodeTheme = require("prism-react-renderer/themes/github");
const darkCodeTheme = require("prism-react-renderer/themes/dracula");
const math = require("remark-math");
const katex = require("rehype-katex");

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: "Taiko",
  tagline: "A decentralized Ethereum-equivalent ZK-Rollup",
  url: "https://taiko.xyz",
  baseUrl: "/",
  onBrokenLinks: "throw",
  onBrokenMarkdownLinks: "warn",
  favicon: "img/Taiko_Favicon_Fluo.png",

  // Even if you don't use internalization, you can use this field to set useful
  // metadata like html lang. For example, if your site is Chinese, you may want
  // to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: "en",
    locales: ["en"],
  },

  plugins: [
    [
      "content-docs",
      {
        id: "talks",
        path: "talks",
        routeBasePath: "talks",
        editUrl:
          "https://github.com/taikoxyz/taiko-mono/tree/main/packages/website/",
      },
    ],
    [
      "content-docs",
      {
        id: "faq",
        path: "faq",
        routeBasePath: "faq",
        editUrl:
          "https://github.com/taikoxyz/taiko-mono/tree/main/packages/website/",
      },
    ],
  ],

  presets: [
    [
      "classic",
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: require.resolve("./sidebars.js"),
          // Remove this to remove the "edit this page" links.
          editUrl:
            "https://github.com/taikoxyz/taiko-mono/tree/main/packages/website/",
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
        respectPrefersColorScheme: false,
      },
      navbar: {
        logo: {
          alt: "Taiko Logo",
          src: "./img/Taiko_Logotype_Horiz_1_Fluo_Black.svg",
          srcDark: "./img/Taiko_Logotype_Horiz_1_Fluo_White.svg",
        },
        items: [
          {
            to: "docs/intro",
            label: "Learn",
            position: "left",
          },
          {
            href: "https://mirror.xyz/labs.taiko.eth",
            label: "Blog",
            position: "left",
          },
          {
            to: "talks",
            label: "Talks",
            position: "left",
          },
          {
            to: "faq",
            label: "FAQ",
            position: "left",
          },
          {
            href: "https://discord.gg/taikoxyz",
            position: "right",
            className: "header-discord-link",
            "aria-label": "Discord",
          },
          {
            href: "https://github.com/taikoxyz",
            position: "right",
            className: "header-github-link",
            "aria-label": "GitHub",
          },
          {
            href: "https://www.reddit.com/r/taiko_xyz/",
            position: "right",
            className: "header-reddit-link",
            "aria-label": "Reddit",
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
        copyright: "© Taiko Labs " + new Date().getFullYear(),
        style: "dark",
        links: [
          {
            title: "About",
            items: [
              {
                label: "Careers",
                href: "https://www.notion.so/taikoxyz/Taiko-Jobs-828fd7232d2c4150a11e10c8baa910a2",
              },
              {
                label: "Media kit",
                href: "https://github.com/taikoxyz/taiko-mono/tree/main/packages/branding/",
              },
            ],
          },
          {
            title: "Developers",
            items: [
              {
                label: "Getting started",
                to: "docs/intro",
              },
              {
                label: "GitHub",
                href: "https://github.com/taikoxyz",
              },
            ],
          },
          {
            title: "Social",
            items: [
              {
                label: "Discord",
                href: "https://discord.gg/taikoxyz",
              },
              {
                label: "Reddit",
                href: "https://www.reddit.com/r/taiko_xyz/",
              },
              {
                label: "Twitter",
                href: "https://twitter.com/taikoxyz",
              },
              {
                label: "YouTube",
                href: "https://www.youtube.com/@taikoxyz",
              },
            ],
          },
        ],
      },
      prism: {
        additionalLanguages: ["solidity"],
        darkTheme: darkCodeTheme,
        theme: lightCodeTheme,
      },
    }),
};

module.exports = config;
