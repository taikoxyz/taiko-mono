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
      // Add events page
      {
        source: "/events",
        destination:
          "https://taikoxyz.notion.site/Taiko-Events-calendar-be7f37a0d11849e5abfd0c332783dfc1",
        permanent: false,
        basePath: false,
      },
      // Redirect run a node to run a taiko node
      {
        source: "/docs/guides/run-a-node",
        destination: "/docs/guides/run-a-taiko-node",
        permanent: true,
      },
    ];
  },
});
