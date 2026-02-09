# reorg-monitor

`reorg-monitor` is a standalone service derived from `packages/ejector` that only tracks L2
reorgs and exports Prometheus metrics.

## What it does

- Subscribes to L2 block headers over websocket.
- Detects reorgs with a local chain-history window.
- Exposes health and metrics over HTTP:
  - `GET /` health probe
  - `GET /metrics` Prometheus scrape endpoint

## Configuration

Use CLI flags or environment variables:

- `L2_WS_URL` / `--l2-ws-url` (default `ws://localhost:8546`)
- `HTTP_PORT` / `--server-port` (default `8080`)
- `REORG_HISTORY_DEPTH` / `--reorg-history-depth` (default `768`)

## Metrics

- `l2_blocks_total`
- `ws_reconnections_total`
- `reorg_count_total`
- `reorg_blocks_replaced_total`
- `reorg_depth_blocks`
- `last_reorged_to`
- `reorg_tracker_parent_not_found_total`
- `duplicate_block_notifications_total`
- `last_block_age_seconds`
- `last_block_number`

## Run locally

```bash
cargo run --bin reorg-monitor
```

Or with explicit args:

```bash
cargo run --bin reorg-monitor -- \
  --l2-ws-url ws://localhost:8546 \
  --server-port 8080 \
  --reorg-history-depth 768
```
