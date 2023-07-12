const withNextra = require("nextra")({
  defaultShowCopyCode: true,
  latex: true,
  theme: "nextra-theme-docs",
  themeConfig: "./theme.config.tsx",
});

// NOTE: document each redirect please
module.exports = withNextra({
  // async redirects() {
  //   return [
  //     {
  //       source: "/docs/guides/configure-your-wallet",
  //       destination: "/docs/guides/build-on-taiko/deploy-a-contract",
  //       permanent: true,
  //     },
  //   ];
  // },
});
