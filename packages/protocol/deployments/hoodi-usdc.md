# Hoodi USDC Deployment Notes

This repository owns the onchain Hoodi USDC deployment and bridge wiring.

## Deployment Flow

1. Deploy the L1 Hoodi canonical USDC token and faucet with `pnpm deploy:hoodi:usdc:l1`.
2. Deploy the L2 Taiko Hoodi native USDC token with `pnpm deploy:hoodi:usdc:l2`.
3. Dry-run and validate the full state with `pnpm validate:hoodi:usdc`.
4. Send the live L1 bridge message with `pnpm configure:hoodi:usdc:l1`.

The final bridge mapping is not an L2 direct-owner transaction on live Hoodi. The Taiko Hoodi
`ERC20Vault.owner()` is the L2 `DelegateController`, so the mapping must be triggered from the
Hoodi L1 contract-owner EOA through `Bridge.sendMessage(...)`.

The standalone faucet app lives in the separate `taikoxyz/hoodi-usdc-bridge` repository. The live Hoodi deployment is:

- L1 Hoodi USDC token proxy: `0x210737FC9fC991997c113E725b565a49AfbBCC07`
- L1 Hoodi USDC token implementation: `0xA3258180510Fc1ACDfBc67DF15e5610fcc36D132`
- L1 Hoodi USDC faucet: `0x75093abc48ea78dBc30DE9D372d44c40Bb6D10eB`
- L2 Taiko Hoodi USDC token proxy: `0xA4b776bA40D76Ae60acDD23f523Fe61B7b5b71Aa`
- L2 Taiko Hoodi USDC token implementation: `0x5cd7dc2A6B5D7F2167C6d933b39D66c51bF2299A`
- L1 -> L2 mapping message hash: `0x89cc7d5a72b831d1bf1b7f6f344d132628f10cc3b30bcc360499d43202b5ed4c`

Backfill the values below in both places:

1. `packages/protocol/deployments/taiko-hoodi-contract-logs.md`
2. the Vercel environment for `taikoxyz/hoodi-usdc-bridge`
3. the Hoodi bridge Vercel `CONFIGURED_CUSTOM_TOKENS` environment value

## Standalone Faucet App Environment

- `PUBLIC_HOODI_RPC_URL=https://l1rpc.hoodi.taiko.xyz`
- `PUBLIC_HOODI_EXPLORER_URL=https://hoodi.etherscan.io`
- `PUBLIC_USDC_ADDRESS=0x210737FC9fC991997c113E725b565a49AfbBCC07`
- `PUBLIC_USDC_FAUCET_ADDRESS=0x75093abc48ea78dBc30DE9D372d44c40Bb6D10eB`
- `PUBLIC_HOODI_BRIDGE_URL=https://bridge.hoodi.taiko.xyz`
- `PUBLIC_WALLETCONNECT_PROJECT_ID=4a8138348c4b06f4cdbfabb09fda5017`

## Hoodi Bridge UI Environment

Update the production `CONFIGURED_CUSTOM_TOKENS` payload for the Hoodi bridge deployment so `USDC` is available on:

- Ethereum Hoodi (`560048`)
- Taiko Hoodi (`167013`)

Use the deployed token addresses from this repo's deployment output and mark the token as:

- `decimals: 6`
- `type: ERC20`
- `attributes.supported: true`
- `attributes.stablecoin: true`
