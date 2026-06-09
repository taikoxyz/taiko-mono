/**
 * Public runtime configuration.
 *
 * SvelteKit `$env/static/public` PUBLIC_* vars map to Next.js NEXT_PUBLIC_* vars.
 * Values are kept as STRINGS exactly as the original source consumed them — callers
 * coerce (e.g. `=== 'true'`) themselves, so do NOT auto-cast here.
 *
 * NOTE: process.env.NEXT_PUBLIC_* must be referenced statically (not via a dynamic
 * key) so Next.js can inline them at build time.
 */
export const publicEnv = {
  DEFAULT_EXPLORER: process.env.NEXT_PUBLIC_DEFAULT_EXPLORER ?? "",
  DEFAULT_SWAP_URL: process.env.NEXT_PUBLIC_DEFAULT_SWAP_URL ?? "",
  GUIDE_URL: process.env.NEXT_PUBLIC_GUIDE_URL ?? "",
  TESTNET_NAME: process.env.NEXT_PUBLIC_TESTNET_NAME ?? "",
  WALLETCONNECT_PROJECT_ID:
    process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID ?? "",
  NFT_BRIDGE_ENABLED: process.env.NEXT_PUBLIC_NFT_BRIDGE_ENABLED ?? "",
  NFT_BATCH_TRANSFERS_ENABLED:
    process.env.NEXT_PUBLIC_NFT_BATCH_TRANSFERS_ENABLED ?? "",
  IPFS_GATEWAYS: process.env.NEXT_PUBLIC_IPFS_GATEWAYS ?? "",
  SLOW_L1_BRIDGING_WARNING:
    process.env.NEXT_PUBLIC_SLOW_L1_BRIDGING_WARNING ?? "false",
  FEE_MULTIPLIER: process.env.NEXT_PUBLIC_FEE_MULTIPLIER ?? "",
} as const;

/** Whether to skip env/config validation in the prebuild config generator. */
export const SKIP_ENV_VALIDATION = process.env.SKIP_ENV_VALIDATION === "true";
