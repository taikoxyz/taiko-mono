# Rollup Monitor

`rollup-monitor` is an alert-only Rust service for Taiko rollup security monitoring. It polls HTTP RPC endpoints, scans configured contracts with overlap/backfill, deduplicates logs in memory, and exports Prometheus metrics for Grafana alerts.

The service does not submit transactions or mutate protocol state.

## Configuration

Configuration is provided through CLI flags or environment variables.

| Env                              | Default  | Description                                                                                                                                           |
| -------------------------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `L1_HTTP_URL`                    | required | L1 HTTP RPC URL.                                                                                                                                      |
| `L2_HTTP_URL`                    | unset    | Optional L2 HTTP RPC URL for later cross-chain checks.                                                                                                |
| `HTTP_PORT`                      | `8080`   | Metrics and health server port.                                                                                                                       |
| `POLL_INTERVAL_SECONDS`          | `12`     | Poll interval for HTTP RPC checks.                                                                                                                    |
| `CONFIRMATIONS`                  | `3`      | Blocks to subtract from latest head before scanning.                                                                                                  |
| `START_BLOCK`                    | unset    | Explicit first block to scan.                                                                                                                         |
| `START_BLOCK_LOOKBACK`           | `7200`   | Startup lookback when `START_BLOCK` is unset.                                                                                                         |
| `OVERLAP_BLOCKS`                 | `20`     | Blocks to rescan each cycle.                                                                                                                          |
| `MAX_BLOCK_RANGE`                | `2000`   | Maximum block span per scan chunk.                                                                                                                    |
| `EOA_SCAN_ENABLED`               | `false`  | Enables full-block transaction polling for `WATCHED_EOAS`. Keep disabled unless the RPC budget supports it.                                           |
| `EOA_SCAN_MAX_BLOCK_RANGE`       | `25`     | Maximum number of recent safe blocks to scan for EOA transactions per contract-log chunk.                                                             |
| `SEEN_LOG_CACHE_SIZE`            | `10000`  | In-memory dedupe cache size.                                                                                                                          |
| `WATCHED_CONTRACTS`              | empty    | Comma-separated `name=address` pairs.                                                                                                                 |
| `ALLOWED_PROVERS`                | empty    | Comma-separated prover addresses.                                                                                                                     |
| `ALLOWED_PROPOSERS`              | empty    | Comma-separated proposer addresses.                                                                                                                   |
| `WATCHED_EOAS`                   | empty    | Comma-separated EOA addresses whose transactions should be checked.                                                                                   |
| `ALLOWED_EOA_DESTINATIONS`       | empty    | Comma-separated destination addresses watched EOAs may send to. Empty means every watched EOA transaction is unexpected.                              |
| `EXPECTED_PROXY_IMPLEMENTATIONS` | empty    | Comma-separated `target=implementation` pairs used to label proxy upgrades as expected or unexpected.                                                 |
| `EXPECTED_OWNERS`                | empty    | Comma-separated `target=owner` pairs used to label ownership transfers as expected or unexpected.                                                     |
| `EXPECTED_VERIFIERS`             | empty    | Comma-separated `target=bytes32` pairs used to label verifier image/program changes as expected or unexpected. Repeat the target for multiple values. |
| `WITHDRAWAL_THRESHOLDS_WEI`      | empty    | Comma-separated `target=wei` withdrawal thresholds.                                                                                                   |

Example:

```sh
L1_HTTP_URL=https://ethereum-rpc.example \
WATCHED_CONTRACTS=inbox=0xabc...,bridge=0xdef... \
ALLOWED_PROVERS=0x123...,0x456... \
ALLOWED_PROPOSERS=0x789... \
WATCHED_EOAS=0xaaa... \
ALLOWED_EOA_DESTINATIONS=0xbbb... \
WITHDRAWAL_THRESHOLDS_WEI=bridge=100000000000000000000 \
cargo run --manifest-path packages/rollup-monitor/Cargo.toml
```

Implemented L1 checks:

- Inbox `Proposed`: non-allowlisted proposer and changed proposal observation after overlap scans.
- Inbox `Proved`: non-allowlisted prover.
- ERC20 vault `TokenSent` / `TokenReleased`: amount over configured target threshold.
- Common admin events: `Upgraded`, `OwnershipTransferred`, `RoleGranted`, `RoleRevoked`.
- Pause events: `Paused`, `Unpaused`.
- Safe activity: `ExecutionSuccess`, `ExecutionFailure`.
- Verifier trust/config events: `ImageTrusted`, `ProgramTrusted`. Verifier proxy `Upgraded` events are reported by the proxy upgrade metric.
- SGX registry events: `InstanceAdded`, `InstanceDeleted`.
- Watched EOA transactions: optional full-block polling catches configured signers sending to unapproved destinations. This is disabled by default and independently capped by `EOA_SCAN_MAX_BLOCK_RANGE`.

## Metrics

The service exposes Prometheus metrics at `/metrics` and health at `/healthz`.

Initial metrics include:

- `rollup_monitor_proxy_upgrades_total`
- `rollup_monitor_ownership_transfers_total`
- `rollup_monitor_role_changes_total`
- `rollup_monitor_pause_events_total`
- `rollup_monitor_safe_transactions_total`
- `rollup_monitor_unexpected_eoa_transactions_total`
- `rollup_monitor_large_withdrawals_total`
- `rollup_monitor_non_whitelisted_provers_total`
- `rollup_monitor_non_whitelisted_proposers_total`
- `rollup_monitor_verifier_changes_total`
- `rollup_monitor_sgx_anomalies_total`
- `rollup_monitor_reconciliation_mismatches_total`
- `rollup_monitor_proposal_reorgs_total`
- `rollup_monitor_scan_errors_total`
- `rollup_monitor_last_scanned_block`
- `rollup_monitor_safe_head_block`
- `rollup_monitor_scan_lag_blocks`

## Development

```sh
cargo fmt --manifest-path packages/rollup-monitor/Cargo.toml
cargo test --manifest-path packages/rollup-monitor/Cargo.toml
```
