const withNextra = require("nextra")({
  defaultShowCopyCode: true,
  latex: true,
  theme: "nextra-theme-docs",
  themeConfig: "./theme.config.tsx",
});

module.exports = withNextra({
  // async redirects() {
  //   return [
  //     {
  //       source: "/docs/guides/deploy-a-contract",
  //       destination: "/docs/guides/build-on-taiko/deploy-a-contract",
  //       permanent: true,
  //     },
  //   ];
  // },
});
