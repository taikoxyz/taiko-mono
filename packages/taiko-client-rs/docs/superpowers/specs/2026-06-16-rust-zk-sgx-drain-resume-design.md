# Latched ZK→SGX drain/resume for the Rust prover

**Date:** 2026-06-16
**Status:** Approved (design)
**Aligns:** [taiko-mono#21795](https://github.com/taikoxyz/taiko-mono/pull/21795) — "feat(taiko-client): latched ZK→SGX drain/resume for proof submitter" (Go `taiko-client`)
**Scope:** Full behavioral parity, ported to `packages/taiko-client-rs/crates/prover`.

## Problem

The Rust prover already ports #21782: a **stateless, per-proposal** distance check
`should_use_zk_proof(proposal_id, last_finalized) = proposal_id <= last_finalized + max_zk_proof_proposal_distance`
([submitter.rs:230](../../../crates/prover/src/submitter/submitter.rs)). Because each proposal runs in its own
tokio task with task-local `use_zk` state and no shared latch, proposals near the threshold flap
between ZK and SGX, and the ZK backend keeps churning a stale `zk_any` backlog nobody is waiting on.

Go #21795 replaces the stateless check with a **latched two-state machine** plus two raiko2
control-plane endpoints (raiko2 [#93](https://github.com/taikoxyz/raiko2/issues/93)). This spec ports
that machine to Rust.

## Behavior (target, identical to #21795)

- **Trigger:** the first time `proposal_id > last_finalized + max_zk_proof_proposal_distance`, latch into
  **SGX-draining** mode and fire a one-off `POST /v3/prover/clear` on the ZK endpoint to discard the
  stale `zk_any` backlog.
- **Drain:** while latched, every proposal is proven via SGX (ZK is not attempted). Local ZK proof
  buffers/caches are flushed and their proposals re-enqueued so partial ZK batches don't strand.
- **Resume:** switch back to ZK only when **both** (A) `proposal_id <= last_finalized + 1` (backlog
  drained) and (B) `GET /v3/prover/status` reports `data.clean == true`. A future breach repeats the cycle.
- **Degrade:** `clear` is best-effort (bounded background retries); a not-clean `/status` keeps draining;
  a `/status` error or 404 degrades to resuming on condition (A) alone — so the prover never gets stuck on
  SGX if raiko2 #93 isn't deployed. The per-proposal `zk_any_not_drawn` / timeout fallbacks are unchanged
  and never touch the latch.
- **Disable:** `max_zk_proof_proposal_distance = 0` disables the machine (always SGX), preserving prior
  behavior; no ZK host configured also disables it.

## Rust adaptation of the concurrency model

| Concern              | Go #21795                                                                | Rust port                                                                                                                  |
| -------------------- | ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| Latch storage        | `zkFallback{mu sync.Mutex, inSGX bool}` field on shared `ProofSubmitter` | `zk_in_sgx: AtomicBool` field on the shared `Arc<Pipeline>`                                                                |
| One-shot transition  | mutex-guarded flag flip, returns `true` for first caller                 | `compare_exchange(false, true)` / `compare_exchange(true, false)`; `Ok` ⇒ this task won the transition                     |
| Concurrency unit     | one goroutine per `RequestProof`                                         | one tokio task per proposal (`request_proof`), all sharing `Arc<Pipeline>`                                                 |
| Control-plane handle | `ZKBacklogController` interface, `ComposeProofProducer` cast to it       | `ZkBacklogController` trait; the ZK `Arc<ComposeProofProducer>` coerced to `Arc<dyn ZkBacklogController>` (no downcasting) |
| Background clear     | `go func()` + `backoff.WithContext(s.ctx)`                               | `tokio::spawn` + bounded retry loop with `proof_polling_interval` sleeps                                                   |
| Proposal IDs         | `*big.Int` (treated as u64)                                              | `u64` throughout (no nil-distance case)                                                                                    |

## File-by-file changes

### 1. `crates/prover/src/raiko/types.rs`

Add the status response type (only `data.clean` consumed; other fields ignored):

```rust
#[derive(Debug, Clone, serde::Deserialize)]
pub struct RaikoProverStatusResponse {
    pub data: RaikoProverStatusData,
}

#[derive(Debug, Clone, serde::Deserialize)]
pub struct RaikoProverStatusData {
    #[serde(default)]
    pub clean: bool,
}
```

### 2. `crates/prover/src/raiko/client.rs`

Two new methods on `RaikoClient`, reusing the existing url-join + strict-HTTP-200 pattern. Factor the
`X-API-KEY` application into a private helper to cut duplication with `request_batch_proof`:

```rust
const CLEAR_PATH:  &'static str = "/v3/prover/clear";
const STATUS_PATH: &'static str = "/v3/prover/status";

/// Apply the optional X-API-KEY header (omitted when None/empty).
fn with_api_key(&self, req: reqwest::RequestBuilder) -> reqwest::RequestBuilder { /* ... */ }

/// POST /v3/prover/clear — discard non-terminal zk_any tasks. 200 = success; body unused.
pub async fn clear_backlog(&self) -> Result<(), RaikoError>;

/// GET /v3/prover/status — true iff data.clean.
pub async fn prover_status_clean(&self) -> Result<bool, RaikoError>;
```

Non-200 → `RaikoError::Failed("raiko returned http status {n}")`, matching `request_batch_proof`.

### 3. `crates/prover/src/producer/zk_backlog.rs` (new — mirrors Go `zk_backlog.go`)

```rust
#[async_trait::async_trait]
pub trait ZkBacklogController: Send + Sync {
    async fn clear_backlog(&self) -> Result<(), RaikoError>;
    async fn status_clean(&self) -> Result<bool, RaikoError>;
}

#[async_trait::async_trait]
impl ZkBacklogController for ComposeProofProducer {
    async fn clear_backlog(&self) -> Result<(), RaikoError> {
        if self.dummy { return Ok(()); }
        self.raiko.clear_backlog().await
    }
    async fn status_clean(&self) -> Result<bool, RaikoError> {
        if self.dummy { return Ok(true); }
        self.raiko.prover_status_clean().await
    }
}
```

Register `mod zk_backlog;` and re-export `ZkBacklogController` from `producer/mod.rs`. (For the ZK
producer, `self.raiko` is the ZK-host client and `self.dummy` is the dummy flag — both already fields.)

### 4. `crates/prover/src/cache.rs`

Add a drain-all helper (mirrors Go's `IterBuffered` + `Remove` loop):

```rust
/// Remove and return every cached proof (used when flushing ZK caches on SGX drain).
pub fn drain_all(&self) -> Vec<ProofResponse>;
```

### 5. `crates/prover/src/submitter/zk_fallback.rs` (new — mirrors Go `zk_fallback.go`)

A split `impl Pipeline` block:

```rust
const CLEAR_MAX_RETRIES: usize = 5; // matches Go backoff.WithMaxRetries(5)

const ZK_PROOF_TYPES: [ProofType; 2] = [ProofType::Risc0, ProofType::Sp1];

impl Pipeline {
    fn mark_sgx_fallback(&self) -> bool;   // CAS false->true; gauge=1 on win
    fn in_sgx_fallback(&self) -> bool;     // atomic load
    fn resume_zk(&self) -> bool;           // CAS true->false; gauge=0 on win

    /// Drain/resume verdict for this proposal. Side-effecting: latches + clears on
    /// first breach, unlatches when drained+clean.
    async fn decide_use_zk(&self, proposal_id: u64, last_finalized: u64) -> bool;

    /// (A) proposal_id <= last_finalized+1, then (B) status_clean; status error => (A) alone.
    async fn can_resume_zk(&self, ctrl: &dyn ZkBacklogController, proposal_id: u64, last_finalized: u64) -> bool;

    /// Spawn bounded best-effort POST /v3/prover/clear; bumps the clear counter.
    fn fire_clear_async(&self);

    /// For [Risc0, Sp1]: drain buffer+cache, re-enqueue each proposal via proof_request_tx.
    async fn clear_zk_buffers_and_resend(&self);
    async fn clear_proof_buffer_and_resend(&self, proof_type: ProofType);
}
```

`decide_use_zk` logic:

```
if max_zk_proof_proposal_distance == 0 || zk_backlog.is_none():
    return should_use_zk_proof(proposal_id, last_finalized)   // stateless, today's behavior
if in_sgx_fallback():
    if can_resume_zk(...): resume_zk(); return true
    return false
if !should_use_zk_proof(proposal_id, last_finalized):
    if mark_sgx_fallback():            // CAS winner only
        clear_zk_buffers_and_resend().await
        fire_clear_async()
    return false
return true
```

Resend reuses the established pattern from `clear_proof_buffers`
([submitter.rs:393](../../../crates/prover/src/submitter/submitter.rs)):
`proof_request_tx.send(ProofRequestMeta::from_request(&response.request)).await`.

### 6. `crates/prover/src/submitter/submitter.rs`

- `Pipeline` gains fields: `zk_backlog: Option<Arc<dyn ZkBacklogController>>`, `zk_in_sgx: AtomicBool`.
- `Pipeline::new` takes the `zk_backlog` handle (init `zk_in_sgx` to `false`).
- In `request_proof_attempt`, replace the per-task distance block (currently lines ~351–362, which
  permanently sets that one task's `*use_zk = false`) with:
  ```rust
  let backlog_allows_zk = self.decide_use_zk(proposal_id, last_finalized).await;
  ```
  and gate the ZK attempt on `*use_zk && backlog_allows_zk`. The task-local `use_zk` continues to handle
  `zk_any_not_drawn` / timeout fallback, unchanged.
- `submitter/mod.rs`: add `mod zk_fallback;`.
- Fix the stale doc comment on `should_use_zk_proof` (lines ~221–228): it claims "no Go equivalent,"
  but #21782 added exactly this gate and #21795 builds the machine on top.

### 7. `crates/prover/src/prover.rs`

Build the ZK compose producer once as a concrete Arc and coerce to both trait objects:

```rust
let zkvm_compose: Option<Arc<ComposeProofProducer>> = cfg.raiko_zkvm_host.as_ref().map(|host| {
    Arc::new(ComposeProofProducer::new_zkvm(
        RaikoClient::new(raiko_client_config(&cfg, host.clone())),
        sgx_geth.clone(),
        cfg.dummy,
    ))
});
let zkvm_producer: Option<Arc<dyn ProofProducer>> =
    zkvm_compose.clone().map(|p| p as Arc<dyn ProofProducer>);
let zk_backlog: Option<Arc<dyn ZkBacklogController>> =
    zkvm_compose.map(|p| p as Arc<dyn ZkBacklogController>);
```

Pass `zk_backlog` into `Pipeline::new`.

### 8. `crates/prover/src/metrics.rs`

Add via the existing `gauge()`/`counter()` registration (Rust `taiko_prover_` prefix convention; Go has
no prefix — intentional naming divergence):

- `zk_backlog_sgx_mode` gauge → `taiko_prover_zk_backlog_sgx_mode` (1 = draining via SGX, 0 = ZK).
- `zk_backlog_clear` counter → `taiko_prover_zk_backlog_clear`.

Helpers:

```rust
pub fn set_zk_backlog_sgx_mode(draining: bool); // .set(if draining {1.0} else {0.0})
pub fn inc_zk_backlog_clear();
```

### 9. `bin/client/src/flags/prover.rs`

Update the `--prover.maxZKProofProposalDistance` help text to match Go's new wording: beyond the
distance the prover stops requesting ZK, clears the ZK backlog, drains via the base (SGX) proof until the
backlog is cleared and the ZK endpoint reports clean, then resumes; `0` disables ZK proving. Keep
`default_value = "30"`.

## Testing (full parity with Go's two new test files)

- **raiko client** (axum, like existing `client.rs` tests): `clear_backlog` hits POST `/v3/prover/clear`
  and accepts 200 / errors non-200; `prover_status_clean` parses `data.clean` true/false and errors on
  non-200.
- **zk_backlog producer**: `ComposeProofProducer` dummy short-circuits (`clear`→Ok, `status`→true);
  non-dummy delegates to raiko.
- **zk_fallback submitter**: `mark_sgx_fallback` first-caller-wins; a 50-task concurrent single-winner
  test; `decide_use_zk` for distance-0 (skip, no latch), no-backlog (stateless), within-distance (ZK),
  breach (latch + clear fired + buffers resent), stay-SGX-when-not-drained, resume-when-drained+clean,
  degrade-on-status-error; `can_resume_zk` condition-(A) gate. A `FakeZkBacklog` double with call
  counters (e.g. `AtomicI32`) and configurable `clean`/error, mirroring Go's `fakeZKBacklog`. Extend the
  existing submitter test harness to inject the fake controller. Existing `should_use_zk_proof` /
  `is_proposal_out_of_range` tests preserved.

## Verification

Targeted, per the repo memory that `make test` is slow and Go/Rust suites can't run concurrently:

```
cargo test -p prover            # prover unit + raiko + zk_fallback tests
cargo build -p prover
cargo clippy -p prover
```

The `prove_e2e` integration test needs a live devnet (pre-existing) and is not part of this change's
verification.

## Out of scope

- raiko2 #93 deployment — the port degrades gracefully without it (resume on condition A alone).
- Any change to the SGX/base proof path, aggregation, or tx submission.

## Notes

- This spec lives under `docs/superpowers/` and will be excluded from the PR diff (per repo convention).
