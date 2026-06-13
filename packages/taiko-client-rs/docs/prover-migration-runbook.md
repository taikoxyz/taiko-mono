# Go → Rust Prover Migration Runbook

This runbook covers operating the Rust prover (`taiko-client prover`, `crates/prover`)
as a replacement for the Go prover (`packages/taiko-client` `prover` subcommand).
See the design spec at `docs/superpowers/specs/2026-06-12-prover-migration-design.md`.

## What changed

The Rust prover keeps the same external behavior as the Go prover:

- Same raiko contract: `POST {raiko.host}/v3/proof/batch/shasta`, `X-API-KEY` auth, polled to completion.
- Same compose model: every batch submits two sub-proofs to `Inbox.prove` — an sgxgeth
  execution proof plus a base/ZK proof (`sgx`, or `risc0`/`sp1` via `zk_any`).
- Same hard-coded verifier IDs: sgxgeth=1, sgx(reth)=4, risc0=5, sp1=6.
- Same scheduling: proving-window expiry, `+72s` unassigned delay, contiguous buffer +
  out-of-order cache, forced aggregation interval, strict parent-transition ordering.

Two deliberate behavior changes:

1. **WebSocket is no longer required.** The Go prover enforced `--l1.ws`; the Rust prover
   uses `event-scanner`/`robust-provider`, which poll over HTTP. Configure exactly one of
   `--l1.http` / `--l1.ws`.
2. **No private-mempool submission yet.** The Go `--l1.private` second tx-manager is not
   ported (deferred post-cutover). All prove transactions go through the public path.

## Flag mapping (Go → Rust)

Env var names are unchanged, so existing operator env files port directly. CLI long-flag
names also match except where noted.

| Go flag / env                                                                   | Rust flag                                                    | Notes                                                                                |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------------ |
| `--l1.proverPrivKey` / `L1_PROVER_PRIV_KEY`                                     | `--l1.proverPrivKey`                                         | required                                                                             |
| `--raiko.host` / `RAIKO_HOST`                                                   | `--raiko.host`                                               | required                                                                             |
| `--raiko.host.zkvm` / `RAIKO_HOST_ZKVM`                                         | `--raiko.host.zkvm`                                          | enables zk_any-first                                                                 |
| `--raiko.apiKeyPath` / `RAIKO_API_KEY_PATH`                                     | `--raiko.apiKeyPath`                                         | file read + trimmed                                                                  |
| `--raiko.requestTimeout` / `RAIKO_REQUEST_TIMEOUT`                              | `--raiko.requestTimeout`                                     | seconds, default 600                                                                 |
| `--prover.startingProposalID` / `STARTING_PROPOSAL_ID`                          | `--prover.startingProposalID`                                | clamped to `[lastFinalized, nextProposalId)`                                         |
| `--prover.proveUnassignedProposals` / `PROVE_UNASSIGNED_PROPOSALS`              | `--prover.proveUnassignedProposals`                          | default false                                                                        |
| `--prover.proposal.window.size` / `PROVER_PROPOSAL_WINDOW_SIZE`                 | `--prover.proposal.window.size`                              | 0 = unlimited                                                                        |
| `--prover.maxZKProofProposalDistance` / `PROVER_MAX_ZK_PROOF_PROPOSAL_DISTANCE` | `--prover.maxZKProofProposalDistance`                        | default 30; beyond this distance from last finalized, skip ZK and use the base proof |
| `--prover.dummy` / `PROVER_DUMMY`                                               | `--prover.dummy`                                             | filler proofs (tests/devnet)                                                         |
| `--prover.proofPollingInterval` / `PROVER_PROOF_POLLING_INTERVAL`               | `--prover.proofPollingInterval`                              | seconds, default 10                                                                  |
| `--prover.localProposerAddresses` / `PROVER_LOCAL_PROPOSER_ADDRESSES`           | `--prover.localProposerAddresses`                            | comma-separated                                                                      |
| `--prover.blockConfirmations` / `PROVER_BLOCK_CONFIRMATIONS`                    | `--prover.blockConfirmations`                                | default 6                                                                            |
| `--prover.forceBatchProvingInterval` / `PROVER_FORCE_BATCH_PROVING_INTERVAL`    | `--prover.forceBatchProvingInterval`                         | seconds, default 1800                                                                |
| `--prover.sgx.batchSize` / `PROVER_SGX_BATCH_SIZE`                              | `--prover.sgx.batchSize`                                     | default 1                                                                            |
| `--prover.zkvm.batchSize` / `PROVER_ZKVM_BATCH_SIZE`                            | `--prover.zkvm.batchSize`                                    | default 1                                                                            |
| txmgr retry interval                                                            | `--prove.retryInterval` / `PROVE_RETRY_INTERVAL`             | seconds, default 48                                                                  |
| txmgr confirmation timeout                                                      | `--prove.confirmationTimeout` / `PROVE_CONFIRMATION_TIMEOUT` | seconds, default 180                                                                 |
| txmgr min tip cap                                                               | `--prove.minTipCap` / `PROVE_MIN_TIP_CAP`                    | gwei, default 1                                                                      |
| txmgr min base fee                                                              | `--prove.minBaseFee` / `PROVE_MIN_BASE_FEE`                  | gwei, default 1                                                                      |
| (new)                                                                           | `--prover.shadowMode` / `PROVER_SHADOW_MODE`                 | full pipeline, no L1 submit                                                          |
| `--tx.gasLimit`                                                                 | —                                                            | **not ported**; prove gas is always estimated                                        |
| `--backoff.retryInterval` / `--backoff.maxRetries`                              | —                                                            | **not ported**; request retries use `--prover.proofPollingInterval`                  |
| `--l1.private`                                                                  | —                                                            | **not ported**; remove from configs                                                  |

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

## Metrics

The Rust prover exports (prefix `taiko_prover_`): `received_proposed_id`, `proofs_assigned`,
`latest_proven_block_id`, `latest_verified_id`, `proofs_sent`, `submission_errors`, and
`shadow_would_submit`. The tx-manager exports under `base_tx_manager_*` with a `name="prover"`
label (emitted via the `metrics` facade).
