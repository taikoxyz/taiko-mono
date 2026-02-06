import starlight from "@astrojs/starlight";
import { defineConfig } from "astro/config";
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
          errorOnLocalLinks: false,
          exclude: [
            "/api-reference/bridge-relayer",
            "/api-reference/event-indexer",
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
          "https://github.com/taikoxyz/taiko-mono/edit/main/packages/docs-site",
      },
      customCss: ["./src/styles/custom.css"],
      logo: {
        dark: "./src/assets/logo-dark.svg",
        light: "./src/assets/logo-light.svg",
      },
      social: [
        {
          icon: "github",
          label: "GitHub",
          href: "https://github.com/taikoxyz",
        },
        {
          icon: "x.com",
          label: "X (formerly Twitter)",
          href: "https://x.com/taikoxyz",
        },
        {
          icon: "discord",
          label: "Discord",
          href: "https://discord.gg/7cAp9kQ8",
        },
        {
          icon: "youtube",
          label: "YouTube",
          href: "https://youtube.com/@taikoxyz",
        },
      ],
      sidebar: [
        {
          label: "Start Here",
          items: [
            { label: "Getting started", link: "/start-here/getting-started/" },
            {
              label: "Set up your wallet",
              link: "/start-here/set-up-your-wallet/",
            },
            { label: "Contributing", link: "/start-here/contributing/" },
            { label: "Getting support", link: "/start-here/getting-support" },
          ],
        },
        {
          label: "Taiko Alethia Protocol",
          collapsed: true,
          items: [
            {
              label: "Protocol Design",
              collapsed: true,
              items: [
                {
                  label: "Based rollups",
                  link: "/taiko-alethia-protocol/protocol-design/based-rollups/",
                },
                {
                  label: "Inception layers",
                  link: "/taiko-alethia-protocol/protocol-design/inception-layers/",
                },
                {
                  label: "Pacaya Fork Taiko Alethia",
                  link: "/taiko-alethia-protocol/protocol-design/pacaya-fork-taiko-alethia/",
                },
                {
                  label: "Based preconfirmations",
                  link: "/taiko-alethia-protocol/protocol-design/based-preconfirmation/",
                },
              ],
            },
            {
              label: "Protocol Architecture",
              collapsed: true,
              items: [
                {
                  label: "Account abstraction",
                  link: "/taiko-alethia-protocol/protocol-architecture/account-abstraction",
                },
                {
                  label: "Block states",
                  link: "/taiko-alethia-protocol/protocol-architecture/block-states",
                },
                {
                  label: "Bridging",
                  link: "/taiko-alethia-protocol/protocol-architecture/bridging",
                },
                {
                  label: "Economics",
                  link: "/taiko-alethia-protocol/protocol-architecture/economics",
                },
                {
                  label: "Taiko nodes",
                  link: "/taiko-alethia-protocol/protocol-architecture/taiko-alethia-nodes",
                },
              ],
            },
            {
              label: "Codebase Analysis",
              collapsed: true,
              items: [
                {
                  label: "TaikoInbox Contract",
                  link: "/taiko-alethia-protocol/codebase-analysis/taikoinbox-contract",
                },
                {
                  label: "TaikoAnchor Contract",
                  link: "/taiko-alethia-protocol/codebase-analysis/taikoanchor-contract",
                },
                {
                  label: "SGXVerifier Contract",
                  link: "/taiko-alethia-protocol/codebase-analysis/sgxverifier-contract",
                },
                {
                  label: "ComposeVerifier Contract",
                  link: "/taiko-alethia-protocol/codebase-analysis/composeverifier-contract",
                },
                {
                  label: "SignalService Contract",
                  link: "/taiko-alethia-protocol/codebase-analysis/signalservice-contract",
                },
                {
                  label: "Bridge Contract",
                  link: "/taiko-alethia-protocol/codebase-analysis/bridge-contract",
                },
              ],
            },
            {
              label: "What is Taiko Alethia?",
              link: "/taiko-alethia-protocol/what-is-taiko-alethia/",
            },
          ],
        },
        {
          label: "Taiko Gwyneth Protocol",
          collapsed: true,
          items: [
            {
              label: "What is Taiko Gwyneth?",
              link: "/taiko-gwyneth-protocol/what-is-taiko-gwyneth/",
            },
            {
              label: "Booster rollups",
              link: "/taiko-gwyneth-protocol/booster-rollups/",
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
                  label: "Run a Taiko Alethia node with Docker",
                  link: "/guides/node-operators/run-a-taiko-alethia-node-with-docker/",
                },

                {
                  label: "Run an Ethereum testnet node",
                  link: "/guides/node-operators/run-an-ethereum-testnet-node/",
                },
                {
                  label: "Build a Taiko Alethia node from source",
                  link: "/guides/node-operators/build-a-taiko-alethia-node-from-source/",
                },
                {
                  label: "Run a node for Taiko Alethia",
                  link: "/guides/node-operators/run-a-node-for-taiko-alethia/",
                },
                {
                  label: "Run a node for Taiko Hoodi",
                  link: "/guides/node-operators/run-a-node-for-taiko-hoodi/",
                },
                {
                  label: "Enable a prover",
                  link: "/guides/node-operators/enable-a-prover/",
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
          collapsed: true,
          items: [
            {
              label: "Contract addresses",
              link: "/network-reference/contract-addresses",
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
              label: "Software releases",
              link: "/network-reference/software-releases-and-deployments",
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
