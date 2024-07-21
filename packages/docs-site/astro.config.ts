import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";
import starlightLinksValidator from "starlight-links-validator";
import starlightOpenAPI, { openAPISidebarGroups } from "starlight-openapi";

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
      plugins: [
        starlightLinksValidator({
          exclude: [
            "/api-reference/bridge-relayer",
            "/api-reference/event-indexer",
            "/api-reference/prover-server",
          ],
        }),
        starlightOpenAPI([
          {
            base: "api-reference/bridge-relayer",
            label: "Bridge Relayer API",
            schema: "../relayer/docs/swagger.yaml",
          },
          {
            base: "api-reference/event-indexer",
            label: "Event Indexer API",
            schema: "../eventindexer/docs/swagger.yaml",
          },
        ]),
      ],
      components: {
        SiteTitle: "./src/components/starlight/SiteTitle.astro",
        Head: "./src/components/starlight/Head.astro",
      },
      title: "Docs",
      editLink: {
        baseUrl:
          "https://github.com/taikoxyz/taiko-mono/tree/main/packages/docs-site",
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
              label: "Contestable rollups (BCR)",
              link: "/core-concepts/contestable-rollups/",
            },
            {
              label: "Booster rollups (BBR)",
              link: "/core-concepts/booster-rollups/",
            },
            { label: "Multi-proofs", link: "/core-concepts/multi-proofs/" },
            { label: "Block states", link: "/core-concepts/block-states" },
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
              label: "App Developers",
              collapsed: true,
              items: [
                {
                  label: "Set up your wallet",
                  link: "/guides/app-developers/set-up-your-wallet/",
                },
                {
                  label: "Receive tokens",
                  link: "/guides/app-developers/receive-tokens/",
                },
                {
                  label: "Bridge tokens",
                  link: "/guides/app-developers/bridge-tokens/",
                },
                {
                  label: "Deploy a contract",
                  link: "/guides/app-developers/deploy-a-contract/",
                },
                {
                  label: "Verify a contract",
                  link: "/guides/app-developers/verify-a-contract/",
                },
              ],
            },
            {
              label: "Node Operators",
              collapsed: true,
              items: [
                {
                  label: "Run a Taiko node with Docker",
                  link: "/guides/node-operators/run-a-taiko-node-with-docker/",
                },

                {
                  label: "Run an Ethereum testnet node",
                  link: "/guides/node-operators/run-an-ethereum-testnet-node/",
                },
                {
                  label: "Build a Taiko node from source",
                  link: "/guides/node-operators/build-a-taiko-node-from-source/",
                },
                {
                  label: "Run a Taiko mainnet node from source",
                  link: "/guides/node-operators/run-a-mainnet-taiko-node-from-source/",
                },
                {
                  label: "Run a Taiko testnet node from source",
                  link: "/guides/node-operators/run-a-testnet-taiko-node-from-source/",
                },
                {
                  label: "Run a Taiko proposer",
                  link: "/guides/node-operators/enable-a-proposer/",
                },
                {
                  label: "Run a Taiko prover",
                  link: "/guides/node-operators/enable-a-prover/",
                },
                {
                  label: "Deploy a ProverSet",
                  link: "guides/node-operators/deploy-a-proverset/",
                },
                {
                  label: "Node troubleshooting",
                  link: "/guides/node-operators/node-troubleshooting/",
                },
              ],
            },
          ],
        },
        {
          label: "Network Reference",
          items: [
            {
              label: "Mainnet addresses",
              link: "/network-reference/mainnet-addresses",
            },
            {
              label: "Testnet addresses",
              link: "/network-reference/testnet-addresses",
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
              label: "Node releases",
              link: "/network-reference/node-releases",
            },
            {
              label: "RPC configuration",
              link: "/network-reference/rpc-configuration",
            },
          ],
        },
        {
          label: "Resources",
          autogenerate: { directory: "resources" },
        },
        {
          label: "API Reference",
          items: openAPISidebarGroups,
        },
      ],
    }),
  ],
});
