const withNextra = require("nextra")({
  async redirects() {
    return [
      {
        source: "/docs/guides",

      },
    ];
  },
  defaultShowCopyCode: true,
  latex: true,
  theme: "nextra-theme-docs",
  themeConfig: "./theme.config.tsx",
});

module.exports = withNextra();
