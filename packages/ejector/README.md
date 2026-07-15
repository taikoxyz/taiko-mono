# Ejector

Ejector is a preconfirmation operator service that monitors L2 progress and L2 reorgs, then sends
L1 transactions to eject operators from the preconfirmation whitelist when configured safety
conditions are met.

## What it does

- Polls the configured L2 HTTP endpoint and beacon node to track block progress.
- Watches the preconfirmation whitelist on L1.
- Ejects inactive or unsafe operators after `EJECT_AFTER_SECONDS`.
- Optionally ejects operators after L2 reorgs that meet `MIN_REORG_DEPTH_FOR_EJECT`.
- Exposes a health endpoint and Prometheus metrics on `SERVER_PORT`.

## Configuration

Runtime configuration is provided through CLI flags or environment variables. For local
development, copy `.env.example` to `.env` and fill in the required values.

Required values:

- `PRECONF_WHITELIST_ADDRESS`: Address of the preconfirmation whitelist contract.
- `PRIVATE_KEY`: Private key used to send L1 ejection transactions.

Common optional values:

- `L1_HTTP_URL`: L1 HTTP RPC endpoint (default `http://localhost:8545`).
- `L2_HTTP_URL`: L2 HTTP RPC endpoint (default `http://localhost:8547`).
- `BEACON_URL`: Beacon node endpoint (default `http://localhost:5052`).
- `EJECT_AFTER_SECONDS`: Maximum time without L2 block progress before ejection (default `96`).
- `HANDOVER_SLOTS`: Number of slots to allow for preconfirmation handover and the sole source for
  this setting (default `4`).
- `SERVER_PORT`: Health and metrics server port (default `8080`).
- `MIN_OPERATORS`: Minimum operators to keep in the whitelist (default `3`).
- `ENABLE_REORG_EJECTION`: Enables reorg-triggered ejection (default `true`).
- `ANCHOR_ADDRESS`: L2 anchor contract address, required when reorg ejection is enabled.
- `MIN_REORG_DEPTH_FOR_EJECT`: Minimum reorg depth before ejection (default `4`).
- `PRECONFER_ADDRESSES`: Comma-separated preconfer addresses expected in the active whitelist.

## Running locally

```bash
cd packages/ejector
cp .env.example .env
cargo run --bin ejector
```

The service listens on `0.0.0.0:${SERVER_PORT}`. The root path returns a health response, and
Prometheus metrics are exposed at `/metrics`.

## Development

```bash
cd packages/ejector
cargo fmt --check
cargo test
```
