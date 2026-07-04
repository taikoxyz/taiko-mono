# Overseer RS

A lightweight Rust service that monitors Taiko preconfirmers against a set of blacklist criteria. The service polls an Ethereum execution-layer RPC, evaluates configurable rules, and (eventually) calls into on-chain governance contracts to quarantine misbehaving preconfirmers.

> **Status:** Prototype with stubbed contract integrations. The monitor already surfaces actionable violations; wiring the real contracts will enable automated blacklisting.

## How It Works

1. **Configuration:** CLI flags (or their environment-variable counterparts) determine the RPC endpoint, timing thresholds, polling cadence, metrics bind address, signing credentials, and mempool staleness budgets.
2. **Authorisation:** At boot the service derives the overseer address from the provided private key and queries the blacklist contract. If the wallet is not recognised as an overseer the process exits.
3. **Data Collection:** On each iteration the monitor issues two JSON-RPC calls over HTTP:
   - `eth_getBlockByNumber("latest", false)` for the latest block metadata.
   - `txpool_content` for all currently pending and queued transactions.
4. **Lookahead Discovery:** A `LookaheadBuilder` pulls validator duties from the consensus layer and URC registry to determine the active committer for the next slot.
5. **Evaluation:** The selected committer runs through the registered blacklist criteria. The first triggered rule logs a warning and invokes the on-chain blacklist contract with the resolved registration root.
6. **Tracking:** The monitor maintains an in-memory history of pending transaction hashes to detect transactions that persist across cycles.

## Command-Line Flags & Environment Variables

| Flag | Environment | Description | Default |
| ---- | ----------- | ----------- | ------- |
| `--rpc-url <URL>` | `OVERSEER_RPC_URL` | Execution-layer RPC endpoint (HTTP). | _required_ |
| `--expected-block-time <seconds>` | `OVERSEER_EXPECTED_BLOCK_TIME` | Target L2 block interval. Used with `allowable-delay`. | _required_ |
| `--allowable-delay <seconds>` | `OVERSEER_ALLOWABLE_DELAY` | Extra slack past the expected interval before latency is deemed a violation. | `12` |
| `--allowable-mempool-transactions <count>` | `OVERSEER_ALLOWABLE_MEMPOOL_TRANSACTIONS` | Maximum number of pending txs tolerated in the mempool. | `0` |
| `--poll-interval <seconds>` | `OVERSEER_POLL_INTERVAL` | Sleep between monitoring cycles. | `10` |
| `--pending-tx-max-age <seconds>` | `OVERSEER_PENDING_TX_MAX_AGE` | Maximum time a pending tx may remain un-included before triggering the age criterion. | `60` |
| `--enable-block-timeliness <bool>` | `OVERSEER_ENABLE_BLOCK_TIMELINESS` | Toggle the block timeliness criterion (`true` to enable, `false` to disable). | `true` |
| `--enable-mempool-stagnation <bool>` | `OVERSEER_ENABLE_MEMPOOL_STAGNATION` | Toggle the mempool stagnation criterion. | `true` |
| `--enable-pending-tx-age <bool>` | `OVERSEER_ENABLE_PENDING_TX_AGE` | Toggle the pending transaction age criterion. | `true` |
| `--metrics-addr <host:port>` | `OVERSEER_METRICS_ADDR` | Bind address for the Prometheus metrics endpoint. | `0.0.0.0:9646` |
| `--chain-id <id>` | `OVERSEER_CHAIN_ID` | Chain ID used when signing blacklist transactions. | `1` |
| `--private-key <hex>` | `OVERSEER_PRIVATE_KEY` | Hex-encoded private key that must belong to an authorised overseer. | _required_ |
| `--blacklist-contract <address>` | `OVERSEER_BLACKLIST_CONTRACT` | Address of the on-chain blacklist contract. | _required_ |
| `--registry-address <address>` | `OVERSEER_REGISTRY_ADDRESS` | Address of the operator registry contract to index. | _required_ |
| `--registry-rpc-url <URL>` | `OVERSEER_REGISTRY_RPC_URL` | Optional RPC endpoint for registry indexing (defaults to `--rpc-url`). | _inherit_ |
| `--registry-start-block <number>` | `OVERSEER_REGISTRY_START_BLOCK` | Block to begin indexing registry events from. | `1` |
| `--registry-max-fork-depth <number>` | `OVERSEER_REGISTRY_MAX_FORK_DEPTH` | Depth of L1 reorg tolerated before replaying. | `2` |
| `--registry-batch-size <number>` | `OVERSEER_REGISTRY_BATCH_SIZE` | Number of blocks to index per batch while catching up. | `25` |
| `--registry-db-url <mysql://…>` | `OVERSEER_REGISTRY_DB_URL` | MySQL connection string for the registry index database. | _optional_ |
| `--registry-db-path <path>` | `OVERSEER_REGISTRY_DB_PATH` | Filesystem path for the registry index when falling back to SQLite. | `registry_index.sqlite` |
| `--lookahead-store-address <address>` | `OVERSEER_LOOKAHEAD_STORE_ADDRESS` | Address of the lookahead store contract used to derive committers. | _required_ |
| `--consensus-rpc-url <URL>` | `OVERSEER_CONSENSUS_RPC_URL` | Beacon/consensus RPC endpoint for validator duty queries. | _required_ |
| `--consensus-rpc-timeout <seconds>` | `OVERSEER_CONSENSUS_RPC_TIMEOUT` | Timeout applied to consensus RPC calls. | `10` |
| `--lookahead-genesis-slot <slot>` | `OVERSEER_LOOKAHEAD_GENESIS_SLOT` | Starting slot number for the slot clock. | `0` |
| `--lookahead-genesis-timestamp <seconds>` | `OVERSEER_LOOKAHEAD_GENESIS_TIMESTAMP` | Genesis timestamp (UNIX seconds) for the slot clock. | _required_ |
| `--lookahead-slot-duration <seconds>` | `OVERSEER_LOOKAHEAD_SLOT_DURATION` | Slot duration in seconds. | `12` |
| `--lookahead-slots-per-epoch <count>` | `OVERSEER_LOOKAHEAD_SLOTS_PER_EPOCH` | Number of slots per epoch. | `32` |
| `--lookahead-heartbeat-ms <ms>` | `OVERSEER_LOOKAHEAD_HEARTBEAT_MS` | Preconfirmation heartbeat cadence in milliseconds. | `1000` |
| `--preconf-slasher <address>` | `OVERSEER_PRECONF_SLASHER` | Address used to locate operator registrations in the URC database. | _required_ |

All criteria are evaluated per preconfirmer each cycle. Lower thresholds make blacklisting more aggressive; increase them if your environment has known latency.

## Blacklist Criteria

The monitor ships with three composable criteria. Violations are logged and sent to the (stubbed) blacklist contract.

### Block Timeliness (`block_timeliness`)
- **Purpose:** Ensure preconfirmers keep pace with expected L2 block production.
- **Trigger:** The gap between now and the latest block timestamp exceeds `expected-block-time + allowable-delay`.
- **Example:** With `expected-block-time=8` and `allowable-delay=12`, any block delayed more than 20 seconds trips the rule.

### Mempool Stagnation (`mempool_stagnation`)
- **Purpose:** Detect when preconfirmers leave too many transactions unprocessed.
- **Trigger:** The number of pending + queued transactions returned by `txpool_content` is greater than `allowable-mempool-transactions`.
- **Context:** The violation message includes the latest block’s transaction count for quick comparison.

### Pending Transaction Age (`pending_tx_age`)
- **Purpose:** Catch situations where specific transactions remain in the mempool for too long despite being includable.
- **Mechanism:** The monitor tracks seen tx hashes across cycles. If a hash reappears for longer than `pending-tx-max-age`, it is considered stalled.
- **Trigger:** At least one stalled transaction exists. The reason enumerates the stalled count, the threshold, and the oldest tx hash/age.

Only the first triggered criterion per cycle results in a blacklist call. Subsequent criteria are skipped until the next poll interval, preventing duplicate actions. Each rule can be enabled or disabled individually with the `--enable-*` CLI flags (or their environment variable equivalents).

### Adding a New Criterion

1. **Create the implementation:** Add a new module under `src/criteria/` and implement the `BlacklistCriterion` trait. The evaluation receives an `EvaluationContext` with the current preconfirmer, monitor configuration, latest observation, and any stalled transactions.
2. **Expose the module:** Register the module and `pub use` the new type inside `src/criteria/mod.rs` so it can be referenced elsewhere.
3. **Register it in the monitor:** Append the criterion to the `criteria` vector that is built in `src/main.rs`. If the rule needs custom configuration knobs (including an enable/disable toggle), extend `Config`, `MonitorConfig`, and the CLI parsing so the values are available in the evaluation.
4. **Test it:** Follow the existing unit tests in `src/criteria/**/*` as templates. Each criterion should cover both the triggering and non-triggering paths.
5. **Document behaviour:** Update this README (and any user-facing docs) with the rule’s intent, thresholds, and operational considerations.

## Building & Running

```bash
# Build the native binary
cargo build --release

# Run with flags
./target/release/overseer-rs \
  --rpc-url https://your.rpc.endpoint \
  --expected-block-time 8 \
  --allowable-delay 12 \
  --allowable-mempool-transactions 10 \
  --pending-tx-max-age 120
```

### Docker

A multi-stage `Dockerfile` is provided:

```bash
docker build -t overseer-rs .
docker run --rm \
  overseer-rs \
  --rpc-url https://your.rpc.endpoint \
  --expected-block-time 8 \
  --allowable-delay 12
```

Supply additional flags as needed. Configuration via environment variables can be layered on top with a wrapper script if desired.

## Prometheus Metrics

The service exposes Prometheus-formatted metrics at `http://<metrics-addr>/metrics` (default `0.0.0.0:9646`). The following counters are currently exported:

- `overseer_blacklist_calls_total` – Successful blacklist invocations.
- `overseer_blacklist_errors_total` – Blacklist invocations that failed to execute.
- `overseer_observation_errors_total` – Failures while fetching chain data.
- `overseer_criterion_errors_total` – Errors returned by blacklist criteria.

You can scrape the endpoint with Prometheus or `curl` to confirm the service is healthy.

## On-Chain Blacklist Contract

- The provided private key is loaded into a local wallet and validated against the contract's `overseers` mapping. The service exits early if the wallet is not authorised.
- When a criterion triggers, the monitor checks `isOperatorBlacklisted` and then calls `blacklistOperator` to quarantine the operator. Until the operator registration root data flow is wired in, the call uses a placeholder root (logged with a TODO message).
- An external URC indexer (e.g. `urcindexer-rs`) populates the same database; this service only issues read queries against it.

## Swapping in Real Contracts

- **Blacklist Contract:** Implement `BlacklistContract::blacklist` to call your on-chain blacklist function.
- **Registry Database:** Point `--registry-db-url` at your MySQL deployment (or omit it to fall back to a local SQLite file).
- **Lookahead Builder:** Ensure the external URC indexer is populating the registry database so the lookahead flow can resolve committers and registration roots.

Both integrations live in `src/contracts/` and are injected in `main.rs`.

## Future Enhancements

- WebSocket-based block streaming to reduce latency.
- Richer mempool analytics (e.g., filter by sender or gas price buckets).
- Persisted tracking state across restarts.
- Telemetry hooks (Prometheus, OpenTelemetry) for dashboarding.

## Development

```bash
# Format code
cargo fmt

# Run unit tests
cargo test
```

All criteria include unit tests illustrating triggering and non-triggering scenarios.
