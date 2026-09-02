export const PUBLIC_RELAYER_URL = 'https://relayer.com';
export const PUBLIC_GUIDE_URL = 'https://guide.com';
export const PUBLIC_TEST_ERC20 =
  '[{"address": "0x876", "symbol": "BLL", "name": "Bull Token"}, {"address": "0x765", "symbol": "HORSE", "name": "Horse Token"}]';
export const PUBLIC_WALLETCONNECT_PROJECT_ID = '123';
export const PUBLIC_SENTRY_DSN = 'https://sentry.com';
export const CONFIGURED_BRIDGES = '';
export const CONFIGURED_CHAINS = '';
export const CONFIGURED_CUSTOM_TOKENS = '';
export const CONFIGURED_RELAYER = '';
// Shaped like the deployed value: several origins, no trailing path. The old single
// 'https://ipfs.io/ipfs/' produced '/ipfs//ipfs/<cid>' once the resolver appended its own
// prefix, so no test could see how a gateway URL is actually built.
export const PUBLIC_IPFS_GATEWAYS = 'https://ipfs.io,https://cloudflare-ipfs.com,https://dweb.link';
export const PUBLIC_FEE_MULTIPLIER = '';
