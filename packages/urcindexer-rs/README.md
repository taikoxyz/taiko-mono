# URC Indexer

The URC indexer is a thin wrapper around Nethermind's `urc` crate that continuously indexes the Ultra Rollup Committee (URC) registry from L1 and persists the state in MySQL. It runs the `RegistryMonitor::run_indexing_loop`, ensuring all `OperatorRegistered` and `OperatorOptedIn` events are stored so that other services can reconstruct the URC lookahead set efficiently.

## What it does

- Connects to the L1 RPC defined by `L1_RPC_URL` and the on-chain `REGISTRY_ADDRESS`.
- Streams registry events starting at `L1_START_BLOCK`, respecting fork depth and batching tuned by environment variables.
- Persists operators, signed registrations, protocols, and sync metadata using a MySQL database referenced via `DATABASE_URL`.
- Exposes the indexed state through MySQL for downstream services that need to query URC membership or construct lookahead windows.

## Configuration

All runtime configuration is provided via environment variables:

- `DATABASE_URL` (required): MySQL connection string.
- `L1_RPC_URL`: HTTP endpoint for the L1 node.
- `REGISTRY_ADDRESS`: Registry contract address.
- `L1_START_BLOCK`: First block to index (default `1`).
- `MAX_L1_FORK_DEPTH`: Safety buffer when selecting canonical blocks (default `2`).
- `INDEX_BLOCK_BATCH_SIZE`: Maximum number of blocks indexed per batch when catching up (default `25`).
- `RUST_LOG`: Logging level (default `info`).
- `HEALTH_SERVER_ADDR`: Optional address for the HTTP health check server (default `0.0.0.0:8080`).

## Running locally

```bash
# Start MySQL (listens on 127.0.0.1:3307 by default)
make db-up

# Run the indexer against your configured environment variables
make run
```

## Docker usage

```bash
# Build and start the indexer together with MySQL
DOCKER_DEFAULT_PLATFORM=linux/amd64 docker compose --profile app up --build
```

The indexer container runs as soon as the MySQL health check succeeds and will emit logs to stdout. Downstream services can connect to the MySQL container at `mysql://urcindexer:password@mysql:3306/urcindexer`.

## Intended consumers

This binary exposes a minimal HTTP server for infrastructure health checks at `GET /healthz`. Other Taiko services should continue to depend on the populated MySQL tables to reconstruct URC lookahead information or other committee queries. The schema mirrors the upstream `urc` crate tables and remains compatible with existing consumers in the monorepo.
