import type { NextConfig } from "next";

// Baseline hardening for a wallet-facing app. `frame-ancestors 'none'` (plus
// the legacy X-Frame-Options) prevents the bridge from being embedded in an
// attacker's iframe (clickjacking over wallet prompts). A full CSP is NOT set
// here: web3modal/WalletConnect load remote wallet icons and open websockets,
// so a strict default-src would break connection flows — scope any future CSP
// deliberately.
const securityHeaders = [
  { key: "Content-Security-Policy", value: "frame-ancestors 'none'" },
  { key: "X-Frame-Options", value: "DENY" },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  {
    key: "Permissions-Policy",
    value: "camera=(), microphone=(), geolocation=()",
  },
];

const nextConfig: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  // Next.js 16 enables Turbopack by default; it handles the wallet libs' optional
  // Node-only deps without manual externals. An empty turbopack config is enough.
  //
  // NOTE: do NOT set `turbopack.root` via `import.meta.url`/`fileURLToPath` here —
  // Next's config loader chokes on it ("exports is not defined in ES module
  // scope"). The one-time "inferred workspace root" crash we saw was a symptom of
  // node_modules being wiped mid-reload, not a real config problem.
  turbopack: {},
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: securityHeaders,
      },
    ];
  },
};

export default nextConfig;
