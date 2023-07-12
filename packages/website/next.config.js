const withNextra = require("nextra")({
  defaultShowCopyCode: true,
  latex: true,
  theme: "nextra-theme-docs",
  themeConfig: "./theme.config.tsx",
});

// NOTE: document each redirect please
module.exports = withNextra({
  async redirects() {
    return [
      // Rename use the bridge -> bridge tokens, sounds cleaner
      {
        source: "/docs/guides/use-the-bridge",
        destination: "/docs/guides/bridge-tokens",
        permanent: true,
      },
      // Rename configure your wallet -> setup your wallet, sounds cleaner
      {
        source: "/docs/guides/configure-your-wallet",
        destination: "/docs/guides/setup-your-wallet",
        permanent: true,
      },
    ];
  },
});
