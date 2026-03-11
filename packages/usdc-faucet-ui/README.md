# Hoodi USDC Faucet UI

Standalone SvelteKit app for the Ethereum Hoodi USDC faucet. The app only submits
`claim()` on the Hoodi L1 faucet contract and then sends users to the existing
Hoodi bridge UI to move funds onto Taiko Hoodi.

## Environment

Copy `.env.example` to `.env` and set:

- `PUBLIC_HOODI_CHAIN_ID`
- `PUBLIC_HOODI_CHAIN_NAME`
- `PUBLIC_HOODI_RPC_URL`
- `PUBLIC_HOODI_EXPLORER_URL`
- `PUBLIC_USDC_ADDRESS`
- `PUBLIC_USDC_FAUCET_ADDRESS`
- `PUBLIC_HOODI_BRIDGE_URL`
- `PUBLIC_WALLETCONNECT_PROJECT_ID`

## Commands

- `pnpm dev`
- `pnpm build`
- `pnpm svelte:check`
- `pnpm lint`
- `pnpm test:unit`
