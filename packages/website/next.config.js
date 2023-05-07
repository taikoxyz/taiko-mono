const withNextra = require("nextra")({
  defaultShowCopyCode: true,
  env: {
    TESTNET_NAME: process.env.TESTNET_NAME,
  },
  latex: true,
  theme: "nextra-theme-docs",
  themeConfig: "./theme.config.tsx",
});

module.exports = withNextra();
