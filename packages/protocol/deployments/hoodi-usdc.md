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

The standalone faucet app lives in the separate `taikoxyz/hoodi-usdc-bridge` repository. After deploying the contracts from this repo, backfill the addresses below in both places:

1. `packages/protocol/deployments/taiko-hoodi-contract-logs.md`
2. the Vercel environment for `taikoxyz/hoodi-usdc-bridge`
3. the Hoodi bridge Vercel `CONFIGURED_CUSTOM_TOKENS` environment value

## Addresses To Backfill

- L1 Hoodi USDC token proxy
- L1 Hoodi USDC token implementation
- L1 Hoodi USDC faucet
- L2 Taiko Hoodi USDC token proxy
- L2 Taiko Hoodi USDC token implementation

## Standalone Faucet App Environment

- `PUBLIC_HOODI_RPC_URL`
- `PUBLIC_HOODI_EXPLORER_URL`
- `PUBLIC_USDC_ADDRESS`
- `PUBLIC_USDC_FAUCET_ADDRESS`
- `PUBLIC_HOODI_BRIDGE_URL`
- `PUBLIC_WALLETCONNECT_PROJECT_ID`

## Hoodi Bridge UI Environment

Update the production `CONFIGURED_CUSTOM_TOKENS` payload for the Hoodi bridge deployment so `USDC` is available on:

- Ethereum Hoodi (`560048`)
- Taiko Hoodi (`167013`)

Use the deployed token addresses from this repo's deployment output and mark the token as:

- `decimals: 6`
- `type: ERC20`
- `attributes.supported: true`
- `attributes.stablecoin: true`
