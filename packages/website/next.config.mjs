import nextra from "nextra";
import remarkMdxDisableExplicitJsx from "remark-mdx-disable-explicit-jsx";

const withNextra = nextra({
  defaultShowCopyCode: true,
  latex: true,
  theme: "nextra-theme-docs",
  themeConfig: "./theme.config.tsx",
  mdxOptions: {
    remarkPlugins: [
      [
        remarkMdxDisableExplicitJsx,
        { whiteList: ["table", "thead", "tbody", "tr", "th", "td"] },
      ],
    ],
  },
});

// NOTE: please document the redirects
export default withNextra({
  async redirects() {
    return [
      // Migrate builder guides to new "Build on Taiko" section
      {
        source: "/docs/guides/configure-your-wallet",
        destination: "/docs/guides/build-on-taiko/setup-your-wallet",
        permanent: true,
      },
      {
        source: "/docs/guides/receive-tokens",
        destination: "/docs/guides/build-on-taiko/receive-tokens",
        permanent: true,
      },
      {
        source: "/docs/guides/use-the-bridge",
        destination: "/docs/guides/build-on-taiko/bridge-tokens",
        permanent: true,
      },
      {
        source: "/docs/guides/swap-tokens",
        destination: "/docs/guides/build-on-taiko/swap-tokens",
        permanent: true,
      },
      {
        source: "/docs/guides/deploy-a-contract",
        destination: "/docs/guides/build-on-taiko/deploy-a-contract",
        permanent: true,
      },
      {
        source: "/docs/guides/verify-a-contract",
        destination: "/docs/guides/build-on-taiko/verify-a-contract",
        permanent: true,
      },
      {
        source: "/docs/guides/build-a-dapp",
        destination: "/docs/guides/build-on-taiko/build-a-dapp",
        permanent: true,
      },
      // Migrate node runner guides to new "Run a node" section
      {
        source: "/docs/guides/run-a-node",
        destination: "/docs/guides/run-a-node/run-a-taiko-node",
        permanent: true,
      },
      {
        source: "/docs/guides/run-a-sepolia-node",
        destination: "/docs/guides/run-a-node/run-a-sepolia-node",
        permanent: true,
      },
      {
        source: "/docs/guides/enable-a-proposer",
        destination: "/docs/guides/run-a-node/enable-a-proposer",
        permanent: true,
      },
      {
        source: "/docs/guides/enable-a-prover",
        destination: "/docs/guides/run-a-node/enable-a-prover",
        permanent: true,
      },
      {
        source: "/docs/guides/claim-prover-ttko",
        destination: "/docs/guides/run-a-node/claim-prover-rewards",
        permanent: true,
      },
      // Introduce the concept of manuals
      {
        source: "/docs/resources/contributing",
        destination: "/docs/manuals/contributing-manual",
        permanent: true,
      },
      {
        source: "/docs/resources/integration-guide",
        destination: "/docs/manuals/integration-manual",
        permanent: true,
      },
      // Migrate dependency on "TTKO" symbol for claiming rewards
      {
        source: "/docs/guides/run-a-node/claim-prover-ttko",
        destination: "/docs/guides/run-a-node/claim-prover-rewards",
        permanent: true,
      },
    ];
  },
});
