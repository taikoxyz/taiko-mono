/**
 * Creating a sidebar enables you to:
 - create an ordered group of docs
 - render a sidebar for each doc of that group
 - provide next/previous navigation

 The sidebars can be generated from the filesystem, or explicitly defined here.

 Create as many sidebars as you want.
 */

// @ts-check

/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  mySidebar: [
    {
      label: "Learn",
      items: ["intro/index", "intro/whitepaper", "intro/talks", "intro/faq"],
      type: "category",
      collapsed: false,
      link: {
        type: "generated-index",
      },
    },
    {
      label: "Alpha-1 testnet guide",
      items: [
        "alpha-1-testnet/start-here",
        "alpha-1-testnet/configure-wallet",
        "alpha-1-testnet/request-from-faucet",
        "alpha-1-testnet/use-the-bridge",
        "alpha-1-testnet/deploy-a-contract",
        "alpha-1-testnet/run-a-node",
        "alpha-1-testnet/explore-the-network",
        "alpha-1-testnet/get-help",
      ],
      type: "category",
      collapsed: false,
      link: {
        type: "generated-index",
      },
    },
    {
      label: "Contract documentation",
      items: [
        {
          type: "autogenerated",
          dirName: "smart-contracts",
        },
      ],
      type: "category",
      link: {
        type: "generated-index",
      },
    },
  ],
};

module.exports = sidebars;
