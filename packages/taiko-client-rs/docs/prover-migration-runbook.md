# Go → Rust Prover Migration Runbook

This runbook covers operating the Rust prover (`taiko-client prover`, `crates/prover`)
as a replacement for the Go prover (`packages/taiko-client` `prover` subcommand).

## What changed

The Rust prover keeps the same external behavior as the Go prover:

- Same raiko contract: `POST {raiko.host}/v3/proof/batch/shasta`, `X-API-KEY` auth, polled to completion.
- Same compose model: every batch submits two sub-proofs to `Inbox.prove` — an sgxgeth
  execution proof plus a base/ZK proof (`sgx`, or `risc0`/`sp1` via `zk_any`).
- Same hard-coded verifier IDs: sgxgeth=1, sgx(reth)=4, risc0=5, sp1=6.
- Same scheduling: proving-window expiry, `+72s` unassigned delay, contiguous buffer +
  out-of-order cache, forced aggregation interval, strict parent-transition ordering.
- Same submission resilience: the submit op (validate → wait-for-parent-transition →
  build → send) bounded-retries transient L1/contract read errors in place with the
  aggregated proofs still buffered (mirroring Go's `withRetry`, `BackOffMaxRetries=10`),
  and only re-requests proofs from raiko on an on-chain revert, an unretryable send, or
  retry exhaustion. The parent-transition wait is bounded to 60s like Go's
  `DefaultRpcTimeout`. A momentarily-missing L1 block during validation is treated as
  transient (retried), not as a permanent skip.
- Same fee-bump ceiling: the prove tx-manager's `fee_limit_multiplier` is pinned to 10 to
  match Go's `--tx.feeLimitMultiplier` default (the base tx-manager library default is 5).

Two deliberate behavior changes:

1. **WebSocket is no longer required.** The Go prover enforced `--l1.ws`; the Rust prover
   uses `event-scanner`/`robust-provider`, which poll over HTTP. Configure exactly one of
   `--l1.http` / `--l1.ws`.
2. **No private-mempool submission yet.** The Go `--l1.private` second tx-manager is not
   ported (deferred post-cutover). All prove transactions go through the public path.
3. **ZK proposal-distance catch-up gate (new, Rust-only).** When a proposal is more than
   `--prover.maxZKProofProposalDistance` (default 30) ahead of the last finalized proposal,
   the prover requests the faster base (SGX) proof instead of a ZK proof so a slow ZK proof
   does not block catch-up. The Go prover has no such gate — under deep backlog the two
   produce different proof-type mixes. Set the distance very high to match Go.

## Flag mapping (Go → Rust)

Env var names are unchanged, so existing operator env files port directly. CLI long-flag
names also match except where noted.

| Go flag / env                                                                | Rust flag                                                                       | Notes                                                                                                                                                                                                                   |
| ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--l1.proverPrivKey` / `L1_PROVER_PRIV_KEY`                                  | `--l1.proverPrivKey`                                                            | required                                                                                                                                                                                                                |
| `--raiko.host` / `RAIKO_HOST`                                                | `--raiko.host`                                                                  | required                                                                                                                                                                                                                |
| `--raiko.host.zkvm` / `RAIKO_HOST_ZKVM`                                      | `--raiko.host.zkvm`                                                             | enables zk_any-first                                                                                                                                                                                                    |
| `--raiko.apiKeyPath` / `RAIKO_API_KEY_PATH`                                  | `--raiko.apiKeyPath`                                                            | file read + trimmed                                                                                                                                                                                                     |
| `--raiko.requestTimeout` / `RAIKO_REQUEST_TIMEOUT`                           | `--raiko.requestTimeout`                                                        | seconds, default 600                                                                                                                                                                                                    |
| `--prover.startingProposalID` / `PROVER_STARTING_PROPOSAL_ID`                | `--prover.startingProposalID`                                                   | clamped to `[lastFinalized, nextProposalId)`                                                                                                                                                                            |
| `--prover.proveUnassignedProposals` / `PROVER_PROVE_UNASSIGNED_PROPOSALS`    | `--prover.proveUnassignedProposals`                                             | default false                                                                                                                                                                                                           |
| `--prover.proposal.window.size` / `PROVER_PROPOSAL_WINDOW_SIZE`              | `--prover.proposal.window.size`                                                 | 0 = unlimited                                                                                                                                                                                                           |
| `--prover.dummy` / `PROVER_DUMMY`                                            | `--prover.dummy`                                                                | filler proofs (tests/devnet)                                                                                                                                                                                            |
| `--prover.proofPollingInterval` / `PROVER_PROOF_POLLING_INTERVAL`            | `--prover.proofPollingInterval`                                                 | seconds, default 10                                                                                                                                                                                                     |
| `--prover.localProposerAddresses` / `PROVER_LOCAL_PROPOSER_ADDRESSES`        | `--prover.localProposerAddresses`                                               | comma-separated                                                                                                                                                                                                         |
| `--prover.blockConfirmations` / `PROVER_BLOCK_CONFIRMATIONS`                 | `--prover.blockConfirmations`                                                   | default 6                                                                                                                                                                                                               |
| `--prover.forceBatchProvingInterval` / `PROVER_FORCE_BATCH_PROVING_INTERVAL` | `--prover.forceBatchProvingInterval`                                            | seconds, default 1800                                                                                                                                                                                                   |
| `--prover.sgx.batchSize` / `PROVER_SGX_BATCH_SIZE`                           | `--prover.sgx.batchSize`                                                        | default 1                                                                                                                                                                                                               |
| `--prover.zkvm.batchSize` / `PROVER_ZKVM_BATCH_SIZE`                         | `--prover.zkvm.batchSize`                                                       | default 1                                                                                                                                                                                                               |
| txmgr retry interval                                                         | `--prove.retryInterval` / `PROVE_RETRY_INTERVAL`                                | seconds, default 48                                                                                                                                                                                                     |
| txmgr confirmation timeout                                                   | `--prove.confirmationTimeout` / `PROVE_CONFIRMATION_TIMEOUT`                    | seconds, default 180                                                                                                                                                                                                    |
| txmgr min tip cap                                                            | `--prove.minTipCap` / `PROVE_MIN_TIP_CAP`                                       | gwei, default 1                                                                                                                                                                                                         |
| txmgr min base fee                                                           | `--prove.minBaseFee` / `PROVE_MIN_BASE_FEE`                                     | gwei, default 1                                                                                                                                                                                                         |
| (new)                                                                        | `--prover.shadowMode` / `PROVER_SHADOW_MODE`                                    | full pipeline, no L1 submit                                                                                                                                                                                             |
| (new)                                                                        | `--prover.maxZKProofProposalDistance` / `PROVER_MAX_ZK_PROOF_PROPOSAL_DISTANCE` | Rust-only catch-up gate, default 30; beyond this distance from last finalized, skip ZK and use the base proof. Go has no equivalent (its ZK fallback is the 1h timeout + `zk_any_not_drawn`). Set very high to disable. |
| `--tx.gasLimit`                                                              | —                                                                               | **not ported**; prove gas is always estimated                                                                                                                                                                           |
| `--backoff.retryInterval` / `--backoff.maxRetries`                           | —                                                                               | **not ported**; request retries use `--prover.proofPollingInterval`                                                                                                                                                     |
| `--l1.private`                                                               | —                                                                               | **not ported**; remove from configs                                                                                                                                                                                     |

Common flags supplying L1/L2 endpoints, JWT, inbox, and metrics are shared with the other
subcommands (`--l1.http`/`--l1.ws`, `--l2.http`, `--l2.auth`, `--jwt.secret`,
`--shasta.inbox`, `--metrics.*`, `--devnet-unzen-timestamp`).

## Shadow-mode rollout

`--prover.shadowMode` runs the full pipeline — event handling, raiko proof generation, and
aggregation — but skips the final `Inbox.prove` send. Each would-be submission increments
`taiko_prover_shadow_would_submit`. Run a shadow prover alongside the production Go prover
and compare its would-submit set against the Go prover's on-chain `Proved` coverage; exit
the gate when they match for two consecutive weeks (excluding raiko-side incidents).

## Cutover and rollback

1. Stop the Go prover.
2. Start the Rust prover with `--prover.shadowMode` **off** and the same `L1_PROVER_PRIV_KEY`
   (the tx-manager picks up the account nonce from chain state — no split nonce management).
3. Watch `taiko_prover_proofs_sent`, `taiko_prover_submission_errors`, and
   `taiko_prover_latest_verified_id`.

**Rollback:** stop the Rust prover and restart the (frozen, still-buildable) Go prover with
the same key. Proving is permissionless after `permissionlessProvingDelay`, so a brief gap
delays finalization but does not lose funds.

## Operational notes

**No periodic proposal re-scan.** The Go prover re-ran `proveOp` from the L1 cursor every 15s
(`forceProvingTicker`), so a proposal whose handling hit a transient error was retried on the
next tick. The Rust prover consumes the `event-scanner` live stream once per proposal: the
proving loop itself retries forever once a proposal is enqueued, and the dedup cursor is only
committed after the routing reads succeed (so a transient read failure leaves the proposal
un-handled rather than mis-skipped). But a proposal is only re-examined on an L1 reorg replay
or a restart — there is no standalone periodic re-scan. The exposure is narrow (the routing
reads — core state + the event's L1 block — are fast), but if `taiko_prover_received_proposed_id`
stalls while `nextProposalId` advances, restart the prover to force a re-scan from the cursor.

## Metrics

The Rust prover exports (prefix `taiko_prover_`): `received_proposed_id`, `proofs_assigned`,
`latest_proven_block_id`, `latest_verified_id`, `proofs_sent`, `submission_errors`,
`submission_reverted`, and `shadow_would_submit`. The tx-manager exports under
`base_tx_manager_*` with a `name="prover"` label (emitted via the `metrics` facade).

`taiko_prover_latest_verified_id` tracks the **L2 block number** of the latest finalized
checkpoint (resolved from `coreState.lastFinalizedBlockHash`), matching Go's
`prover_latestVerified_id` — not the proposal id. Note the metric names are not the Go
names verbatim (Go used the `prover_` prefix); update dashboards/alerts accordingly.

Per-proof-type generation metrics (Go's `updateProvingMetrics`) are exported, recorded once
per first successful generation, for each of `sgx_geth`, `sgx`, `r0`, `sp1` in both single
and `_aggregation` modes: `taiko_prover_proof_<type>[_aggregation]_generation_time` (gauge,
last generation seconds), `…_generation_time_sum` (counter, cumulative seconds), and
`…_generated` (counter, count). These mirror Go's `prover_proof_*` series under the
`taiko_` prefix.
