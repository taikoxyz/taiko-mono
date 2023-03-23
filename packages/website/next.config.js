const withNextra = require("nextra")({
  defaultShowCopyCode: true,
  latex: true,
  theme: "nextra-theme-docs",
  themeConfig: "./theme.config.tsx",
});

module.exports = withNextra();
