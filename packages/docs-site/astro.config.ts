import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";
import starlightLinksValidator from "starlight-links-validator";

// https://astro.build/config
export default defineConfig({
  site: "https://docs.taiko.xyz",
  server: {
    host: true,
  },
  redirects: {
    "/": "/start-here/getting-started",
  },
  integrations: [
    starlight({
      plugins: [starlightLinksValidator()],
      components: {
        SiteTitle: "./src/components/starlight/SiteTitle.astro",
        Head: "./src/components/starlight/Head.astro",
      },
      title: "Docs",
      editLink: {
        baseUrl: "https://github.com/taikoxyz/docs/edit/main/",
      },
      customCss: ["./src/styles/custom.css"],
      logo: {
        dark: "./src/assets/logo-dark.svg",
        light: "./src/assets/logo-light.svg",
      },
      social: {
        github: "https://github.com/taikoxyz",
        "x.com": "https://x.com/taikoxyz",
        discord: "https://discord.gg/taikoxyz",
        youtube: "https://youtube.com/@taikoxyz",
      },
      sidebar: [
        {
          label: "Start Here",
          items: [
            { label: "Getting started", link: "/start-here/getting-started/" },
            { label: "Contributing", link: "/start-here/contributing/" },
            { label: "Getting support", link: "/start-here/getting-support" },
          ],
        },
        {
          label: "Core Concepts",
          items: [
            { label: "What is Taiko?", link: "/core-concepts/what-is-taiko/" },
            {
              label: "Based sequencing",
              link: "/core-concepts/based-sequencing/",
            },
            {
              label: "Contestable rollups",
              link: "/core-concepts/contestable-rollups/",
            },
            {
              label: "Booster rollups",
              link: "/core-concepts/booster-rollups/",
            },
            { label: "Multi-proofs", link: "/core-concepts/multi-proofs/" },
            {
              label: "Taiko nodes",
              link: "/core-concepts/taiko-nodes/",
            },
            {
              label: "Bridging",
              link: "/core-concepts/bridging/",
            },
            {
              label: "Inception layers",
              link: "/core-concepts/inception-layers/",
            },
          ],
        },
        {
          label: "Guides",
          items: [
            {
              label: "Set up your wallet",
              link: "/guides/set-up-your-wallet/",
            },
            { label: "Receive tokens", link: "/guides/receive-tokens/" },
            { label: "Bridge tokens", link: "/guides/bridge-tokens/" },
            { label: "Swap tokens", link: "/guides/swap-tokens/" },
            { label: "Deploy a contract", link: "/guides/deploy-a-contract/" },
            { label: "Verify a contract", link: "/guides/verify-a-contract/" },
            {
              label: "Run a Holesky node",
              link: "/guides/run-a-holesky-node/",
            },
            { label: "Run a Taiko node", link: "/guides/run-a-taiko-node/" },
            { label: "Enable a proposer", link: "/guides/enable-a-proposer/" },
            { label: "Enable a prover", link: "/guides/enable-a-prover/" },
          ],
        },
        {
          label: "Network Reference",
          items: [
            {
              label: "Addresses",
              link: "/network-reference/addresses",
            },
            {
              label: "Differences from Ethereum",
              link: "/network-reference/differences-from-ethereum",
            },
            {
              label: "Network configuration",
              link: "/network-reference/network-configuration",
            },
            {
              label: "RPC configuration",
              link: "/network-reference/rpc-configuration",
            },
          ],
        },
        {
          label: "API Reference",
          autogenerate: { directory: "api-reference" },
        },
        {
          label: "Resources",
          autogenerate: { directory: "resources" },
        },
      ],
    }),
  ],
});
