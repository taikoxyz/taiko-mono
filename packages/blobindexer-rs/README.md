# Blob Indexer (Rust)

The blob indexer ingests EIP-4844 blob sidecars from a Deneb-compatible beacon node and exposes an HTTP API for downstream Taiko services. It persists canonical blob data in MySQL while handling short-term reorgs safely.

## Features

- Polls the beacon REST API for new blocks and blob sidecars
- Automatically backfills the recent reorg window and replays reorged branches
- Stores blocks and blobs in MySQL with canonical tracking
- Exposes REST endpoints for blob retrieval by versioned hash, slot, or block root
- Structured logging with `tracing`
- Graceful shutdown and health checks

## Configuration

All configuration values can be provided via CLI flags or the matching environment variables.

| Flag | Env | Description | Default |
|------|-----|-------------|---------|
| `--beacon-api` | `BLOB_INDEXER_BEACON_URL` | Beacon node REST endpoint | _required_ |
| `--database-url` | `BLOB_INDEXER_DATABASE_URL` | MySQL connection string | _required_ |
| `--http-bind` | `BLOB_INDEXER_HTTP_BIND` | HTTP bind address | `0.0.0.0:9000` |
| `--poll-interval` | `BLOB_INDEXER_POLL_INTERVAL` | Indexer poll cadence (`6s`, `1m`, …) | `6s` |
| `--http-timeout` | `BLOB_INDEXER_HTTP_TIMEOUT` | Beacon client request timeout | `20s` |
| `--max-concurrency` | `BLOB_INDEXER_MAX_CONCURRENCY` | Concurrent beacon fetches | `4` |
| `--backfill-batch` | `BLOB_INDEXER_BACKFILL_BATCH` | Slots fetched per iteration | `32` |
| `--start-slot` | `BLOB_INDEXER_START_SLOT` | Optional bootstrapping slot | _none_ |
| `--reorg-lookback` | `BLOB_INDEXER_REORG_LOOKBACK` | Slots re-scanned each tick | `128` |
| `--finality-confirmations` | `BLOB_INDEXER_FINALITY_CONFIRMATIONS` | Finality margin before pruning | `64` |
| `--log-format` | `BLOB_INDEXER_LOG_FORMAT` | `pretty` or `json` | `pretty` |

## Database

Before running the indexer ensure the configured MySQL database exists. Migrations are applied automatically at startup via `sqlx`.

```bash
mysql -u root -p -e 'CREATE DATABASE IF NOT EXISTS blobindexer;'
```

### Make Targets

- `make db-up` / `make db-down` — start/stop the bundled MySQL container via Docker Compose
- `make migrate` — apply SQL migrations using `sqlx migrate run`
- `make run` — launch the blob indexer with the configured `DATABASE_URL` and `BEACON_API`
- `make db-logs` — stream MySQL logs for debugging
- `make fmt` / `make lint` / `make test` / `make check` — format, lint, test, and run the combined checks
- `make sqlx-install` — install the `sqlx` CLI with MySQL support

## Running Locally

```bash
# start MySQL locally (requires Docker)
make db-up

# apply migrations (install sqlx-cli first via `make sqlx-install`)
make migrate

# run the indexer (override BEACON_API/DATABASE_URL as needed)
make run BEACON_API=http://localhost:5052/

# follow database logs (optional)
make db-logs

# execute the test suite
make test

# tear down the database container when finished
make db-down
```

## HTTP API

- `GET /healthz` — liveness probe
- `GET /v1/status/head` — canonical head metadata
- `GET /v1/blobs/{versioned_hash}` — blob payload by versioned hash
- `GET /v1/blobs/by-slot/{slot}` — canonical blobs for a given slot
- `GET /v1/blobs/by-root/{block_root}` — canonical blobs for a specific block root

All binary fields are returned as `0x`-prefixed hex strings.

## Development

- `make fmt` — format the workspace
- `make lint` — run clippy on all targets
- `make test` — execute unit tests (uses `DATABASE_URL`)
- `make check` — run formatter + clippy together

The codebase favours explicit error handling and avoids panics; please keep it that way when extending functionality.
