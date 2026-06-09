import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  // Next.js 16 enables Turbopack by default; it handles the wallet libs' optional
  // Node-only deps without manual externals. An empty turbopack config is enough.
  //
  // NOTE: do NOT set `turbopack.root` via `import.meta.url`/`fileURLToPath` here —
  // Next's config loader chokes on it ("exports is not defined in ES module
  // scope"). The one-time "inferred workspace root" crash we saw was a symptom of
  // node_modules being wiped mid-reload, not a real config problem.
  turbopack: {},
};

export default nextConfig;
