# Latched ZK→SGX drain/resume for the Rust prover — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port [taiko-mono#21795](https://github.com/taikoxyz/taiko-mono/pull/21795) (latched ZK→SGX drain/resume) to the Rust prover for full behavioral parity.

**Architecture:** A shared latch lives on the `Arc<Pipeline>` so every per-proposal tokio task agrees on ZK-vs-SGX (Go uses a mutex-guarded flag on the shared submitter; we use an `AtomicBool` with `compare_exchange` for the one-shot transition). The latch, the raiko2 control-plane calls, and the background clear are encapsulated in a focused `ZkFallback` unit (`submitter/zk_fallback.rs`) that owns its own state and has **no** access needs to `Pipeline` internals. The two pieces that must touch `Pipeline`'s private buffers/caches/channels — `decide_use_zk` (orchestration) and `clear_zk_buffers_and_resend` — stay as `Pipeline` methods in `submitter.rs`, because Rust module privacy forbids a sibling file from reaching a struct's private fields. (This composition refines the spec's "split impl block" wording, which Rust privacy makes non-idiomatic.)

**Tech Stack:** Rust, tokio, reqwest, `async-trait`, `dashmap`, prometheus (via `protocol::metrics`), clap, axum (test HTTP servers).

**Spec:** `packages/taiko-client-rs/docs/superpowers/specs/2026-06-16-rust-zk-sgx-drain-resume-design.md`

**Working directory for all commands:** `packages/taiko-client-rs/` (the Rust workspace root). The crate under test is `prover`.

---

## Task 1: `ProofCache::drain_all`

Add a helper to remove and return every cached proof — used when flushing ZK caches on SGX drain.

**Files:**

- Modify: `crates/prover/src/cache.rs` (add method to `impl ProofCache`; add a test)

- [ ] **Step 1: Write the failing test**

Add to the `#[cfg(test)] mod tests` block in `crates/prover/src/cache.rs` (after `prune_finalized_drops_entries_at_or_below_watermark`):

```rust
    #[test]
    fn drain_all_removes_and_returns_every_entry() {
        let cache = ProofCache::new();
        for id in [3, 4, 7] {
            cache.insert(test_response(id));
        }

        let mut drained: Vec<u64> = cache.drain_all().iter().map(ProofResponse::proposal_id).collect();
        drained.sort_unstable();

        assert_eq!(drained, vec![3, 4, 7]);
        assert!(cache.is_empty(), "cache emptied after drain_all");
        assert!(cache.drain_all().is_empty(), "second drain returns nothing");
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test -p prover --lib drain_all_removes_and_returns_every_entry`
Expected: FAIL — `no method named drain_all found`.

- [ ] **Step 3: Add `drain_all` to `impl ProofCache`**

In `crates/prover/src/cache.rs`, add this method inside `impl ProofCache` (e.g. after `prune_finalized`):

```rust
    /// Remove and return every cached proof (used when flushing ZK caches on
    /// entering SGX-draining mode). Keys are collected before removal so the
    /// `DashMap` is never iterated while a shard is being mutated.
    pub fn drain_all(&self) -> Vec<ProofResponse> {
        let ids: Vec<u64> = self.map.iter().map(|entry| *entry.key()).collect();
        ids.into_iter().filter_map(|id| self.map.remove(&id).map(|(_, value)| value)).collect()
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test -p prover --lib drain_all_removes_and_returns_every_entry`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cargo fmt -p prover
git add crates/prover/src/cache.rs
git commit -m "feat(taiko-client-rs): add ProofCache::drain_all"
```

---

## Task 2: ZK backlog metrics

Add the `prover_zk_backlog_sgx_mode` gauge and `prover_zk_backlog_clear` counter (Rust `taiko_prover_` prefix convention).

**Files:**

- Modify: `crates/prover/src/metrics.rs`

- [ ] **Step 1: Write the failing test**

`metrics.rs` has no test module yet. Add one at the end of `crates/prover/src/metrics.rs`:

```rust
#[cfg(test)]
mod tests {
    use super::ProverMetrics;

    #[test]
    fn zk_backlog_setters_are_callable_after_init() {
        ProverMetrics::init();
        // Exercising the setters must not panic and must be idempotent.
        ProverMetrics::set_zk_backlog_sgx_mode(true);
        ProverMetrics::set_zk_backlog_sgx_mode(false);
        ProverMetrics::inc_zk_backlog_clear();
        ProverMetrics::inc_zk_backlog_clear();
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test -p prover --lib zk_backlog_setters_are_callable_after_init`
Expected: FAIL — `no function ... set_zk_backlog_sgx_mode`.

- [ ] **Step 3: Add the handles, registration, and setters**

In `crates/prover/src/metrics.rs`:

(a) Add two fields to `struct ProverMetricHandles` (after `shadow_would_submit`):

```rust
    /// 1 while draining the ZK backlog via SGX, 0 while proving via ZK.
    zk_backlog_sgx_mode: Gauge,
    /// Number of ZK backlog clear requests fired on entering SGX-draining mode.
    zk_backlog_clear: IntCounter,
```

(b) Register them in `ProverMetricHandles::new()` (after the `shadow_would_submit` entry, before the `sgx_geth_single` line):

```rust
            zk_backlog_sgx_mode: gauge(
                "taiko_prover_zk_backlog_sgx_mode",
                "1 while draining the ZK backlog via SGX, 0 while proving via ZK",
            ),
            zk_backlog_clear: counter(
                "taiko_prover_zk_backlog_clear",
                "ZK backlog clear requests fired on entering SGX-draining mode",
            ),
```

(c) Add two associated functions to `impl ProverMetrics` (e.g. after `shadow_would_submit`):

```rust
    /// Set the ZK backlog drain-mode gauge (1 = draining via SGX, 0 = ZK).
    pub fn set_zk_backlog_sgx_mode(draining: bool) {
        METRICS.zk_backlog_sgx_mode.set(if draining { 1.0 } else { 0.0 });
    }

    /// Count one fired ZK backlog clear.
    pub fn inc_zk_backlog_clear() {
        METRICS.zk_backlog_clear.inc();
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test -p prover --lib zk_backlog_setters_are_callable_after_init`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cargo fmt -p prover
git add crates/prover/src/metrics.rs
git commit -m "feat(taiko-client-rs): add ZK backlog drain/clear prover metrics"
```

---

## Task 3: raiko status wire type + control-plane client methods

Add `RaikoProverStatusResponse` and the `clear_backlog` / `prover_status_clean` methods on `RaikoClient`, factoring the `X-API-KEY` header into a shared helper.

**Files:**

- Modify: `crates/prover/src/raiko/types.rs` (add response type)
- Modify: `crates/prover/src/raiko/client.rs` (add `with_api_key`, `clear_backlog`, `prover_status_clean`; refactor `request_batch_proof` to use the helper; add tests)

- [ ] **Step 1: Add the status response type**

In `crates/prover/src/raiko/types.rs`, after `RaikoProofResponse` (and its `lenient_proof_type` helper), add:

```rust
/// Body of `GET /v3/prover/status` (raiko2 #93). Only `data.clean` is consumed;
/// the other fields (`status`, `tasks`, `network`) are intentionally ignored.
#[derive(Debug, Clone, Deserialize)]
pub struct RaikoProverStatusResponse {
    /// Status payload; only `clean` is read.
    pub data: RaikoProverStatusData,
}

/// The `data` object of `GET /v3/prover/status`.
#[derive(Debug, Clone, Deserialize)]
pub struct RaikoProverStatusData {
    /// Whether the ZK backend is fully idle (no in-flight or queued work).
    #[serde(default)]
    pub clean: bool,
}
```

- [ ] **Step 2: Write the failing client tests**

In `crates/prover/src/raiko/client.rs`, add these tests inside the existing `#[cfg(test)] mod tests` block (after `request_times_out`). They reuse the existing `spawn_app` / `client_for` helpers:

```rust
    #[tokio::test]
    async fn clear_backlog_posts_to_clear_endpoint() {
        let app = axum::Router::new().route(
            "/v3/prover/clear",
            axum::routing::post(|headers: axum::http::HeaderMap| async move {
                assert_eq!(headers.get("x-api-key").unwrap(), "secret");
                axum::Json(serde_json::json!({ "status": "ok" }))
            }),
        );
        let addr = spawn_app(app).await;

        let client = client_for(addr, Some("secret".into()), Duration::from_secs(5));
        client.clear_backlog().await.unwrap();
    }

    #[tokio::test]
    async fn clear_backlog_errors_on_non_200() {
        let app = axum::Router::new().route(
            "/v3/prover/clear",
            axum::routing::post(|| async { axum::http::StatusCode::INTERNAL_SERVER_ERROR }),
        );
        let addr = spawn_app(app).await;

        let client = client_for(addr, None, Duration::from_secs(5));
        assert!(client.clear_backlog().await.is_err());
    }

    #[tokio::test]
    async fn prover_status_clean_parses_clean_field() {
        let app = axum::Router::new().route(
            "/v3/prover/status",
            axum::routing::get(|| async {
                axum::Json(serde_json::json!({
                    "status": "ok",
                    "data": { "clean": true, "tasks": { "pending": 0 } }
                }))
            }),
        );
        let addr = spawn_app(app).await;

        let client = client_for(addr, None, Duration::from_secs(5));
        assert!(client.prover_status_clean().await.unwrap());
    }

    #[tokio::test]
    async fn prover_status_not_clean() {
        let app = axum::Router::new().route(
            "/v3/prover/status",
            axum::routing::get(|| async {
                axum::Json(serde_json::json!({ "data": { "clean": false } }))
            }),
        );
        let addr = spawn_app(app).await;

        let client = client_for(addr, None, Duration::from_secs(5));
        assert!(!client.prover_status_clean().await.unwrap());
    }

    #[tokio::test]
    async fn prover_status_errors_on_non_200() {
        let app = axum::Router::new().route(
            "/v3/prover/status",
            axum::routing::get(|| async { axum::http::StatusCode::NOT_FOUND }),
        );
        let addr = spawn_app(app).await;

        let client = client_for(addr, None, Duration::from_secs(5));
        assert!(client.prover_status_clean().await.is_err());
    }
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cargo test -p prover --lib raiko::client::tests::clear_backlog_posts_to_clear_endpoint`
Expected: FAIL — `no method named clear_backlog`.

- [ ] **Step 4: Implement the client methods**

In `crates/prover/src/raiko/client.rs`:

(a) Extend the imports at the top to include the new type:

```rust
use super::types::{RaikoBatchProofRequest, RaikoError, RaikoProofResponse, RaikoProverStatusResponse};
```

(b) Add the two path constants next to `BATCH_PROOF_PATH` inside `impl RaikoClient`:

```rust
    /// Endpoint path for discarding the ZK (`zk_any`) backlog (raiko2 #93).
    const CLEAR_PATH: &'static str = "/v3/prover/clear";
    /// Endpoint path for the ZK backend idle status (raiko2 #93).
    const STATUS_PATH: &'static str = "/v3/prover/status";
```

(c) Add the helper and the two methods inside `impl RaikoClient` (after `request_batch_proof`):

```rust
    /// Apply the optional `X-API-KEY` header (omitted when `None`/empty), Go
    /// `common.go:114-116`.
    fn with_api_key(&self, req: reqwest::RequestBuilder) -> reqwest::RequestBuilder {
        match self.cfg.api_key.as_deref().map(str::trim).filter(|key| !key.is_empty()) {
            Some(key) => req.header("X-API-KEY", key),
            None => req,
        }
    }

    /// `POST /v3/prover/clear` — discard non-terminal `zk_any` tasks on the ZK
    /// backend. HTTP 200 = success; the response body is unused.
    pub async fn clear_backlog(&self) -> Result<(), RaikoError> {
        let url = self
            .cfg
            .endpoint
            .join(Self::CLEAR_PATH)
            .map_err(|_| RaikoError::Failed("invalid raiko endpoint".to_owned()))?;
        let resp = self.with_api_key(self.http.post(url)).send().await?;
        if resp.status() != reqwest::StatusCode::OK {
            return Err(RaikoError::Failed(format!(
                "raiko returned http status {}",
                resp.status().as_u16()
            )));
        }
        Ok(())
    }

    /// `GET /v3/prover/status` — true iff `data.clean`, i.e. the ZK backend is
    /// fully idle.
    pub async fn prover_status_clean(&self) -> Result<bool, RaikoError> {
        let url = self
            .cfg
            .endpoint
            .join(Self::STATUS_PATH)
            .map_err(|_| RaikoError::Failed("invalid raiko endpoint".to_owned()))?;
        let resp = self.with_api_key(self.http.get(url)).send().await?;
        if resp.status() != reqwest::StatusCode::OK {
            return Err(RaikoError::Failed(format!(
                "raiko returned http status {}",
                resp.status().as_u16()
            )));
        }
        Ok(resp.json::<RaikoProverStatusResponse>().await?.data.clean)
    }
```

(d) Refactor `request_batch_proof` to reuse the helper. Replace these lines:

```rust
        let mut req = self.http.post(url).json(request);
        if let Some(key) = self.cfg.api_key.as_deref().map(str::trim).filter(|k| !k.is_empty()) {
            req = req.header("X-API-KEY", key);
        }
        let resp = req.send().await?;
```

with:

```rust
        let resp = self.with_api_key(self.http.post(url).json(request)).send().await?;
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cargo test -p prover --lib raiko::client`
Expected: PASS — all client tests, including the four existing ones, pass.

- [ ] **Step 6: Commit**

```bash
cargo fmt -p prover
git add crates/prover/src/raiko/types.rs crates/prover/src/raiko/client.rs
git commit -m "feat(taiko-client-rs): add raiko clear/status control-plane calls"
```

---

## Task 4: `ZkBacklogController` trait + `ComposeProofProducer` impl

Define the control-plane trait and implement it on the compose producer (dummy short-circuits; otherwise delegates to the ZK-host raiko client).

**Files:**

- Create: `crates/prover/src/producer/zk_backlog.rs` (trait)
- Modify: `crates/prover/src/producer/mod.rs` (register + re-export)
- Modify: `crates/prover/src/producer/compose.rs` (impl + tests)

- [ ] **Step 1: Create the trait file**

Create `crates/prover/src/producer/zk_backlog.rs`:

```rust
//! raiko2 control-plane interface for draining the ZK (`zk_any`) task backlog
//! and reporting when the backend is idle (raiko2 #93). Mirrors Go's
//! `ZKBacklogController` interface (`prover/proof_producer/zk_backlog.go`).

use async_trait::async_trait;

use crate::raiko::RaikoError;

/// A proof backend whose host exposes the raiko2 ZK-backlog control plane.
#[async_trait]
pub trait ZkBacklogController: Send + Sync {
    /// Discard all non-terminal `zk_any` tasks (`POST /v3/prover/clear`).
    async fn clear_backlog(&self) -> Result<(), RaikoError>;
    /// Whether the ZK backend is fully idle (`data.clean` of
    /// `GET /v3/prover/status`).
    async fn status_clean(&self) -> Result<bool, RaikoError>;
}
```

- [ ] **Step 2: Register and re-export the module**

In `crates/prover/src/producer/mod.rs`, add `mod zk_backlog;` to the module list (after `mod sgx_geth;`):

```rust
mod compose;
mod dummy;
mod sgx_geth;
mod zk_backlog;
```

and add a re-export next to the others (after `pub use sgx_geth::SgxGethProofProducer;`):

```rust
pub use zk_backlog::ZkBacklogController;
```

- [ ] **Step 3: Write the failing impl tests**

In `crates/prover/src/producer/compose.rs`, add a test module at the end of the file (if a `#[cfg(test)] mod tests` already exists, add these to it instead; otherwise create it). Note: the dummy cases need no HTTP server.

```rust
#[cfg(test)]
mod zk_backlog_tests {
    use std::{net::SocketAddr, time::Duration};

    use super::ComposeProofProducer;
    use crate::{
        producer::{SgxGethProofProducer, ZkBacklogController},
        raiko::{RaikoClient, RaikoClientConfig},
    };

    fn raiko_for(addr: SocketAddr) -> RaikoClient {
        RaikoClient::new(RaikoClientConfig {
            endpoint: format!("http://{addr}").parse().unwrap(),
            api_key: None,
            request_timeout: Duration::from_secs(5),
        })
    }

    async fn spawn_app(app: axum::Router) -> SocketAddr {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        tokio::spawn(async move { axum::serve(listener, app).await.unwrap() });
        addr
    }

    fn dummy_compose() -> ComposeProofProducer {
        // endpoint is never hit in dummy mode; any URL parses fine.
        let raiko = RaikoClient::new(RaikoClientConfig {
            endpoint: "http://127.0.0.1:1".parse().unwrap(),
            api_key: None,
            request_timeout: Duration::from_secs(5),
        });
        let sgx_geth = SgxGethProofProducer::new(raiko.clone(), true);
        ComposeProofProducer::new_zkvm(raiko, sgx_geth, true)
    }

    #[tokio::test]
    async fn dummy_short_circuits_clear_and_status() {
        let producer = dummy_compose();
        producer.clear_backlog().await.unwrap();
        assert!(producer.status_clean().await.unwrap());
    }

    #[tokio::test]
    async fn non_dummy_delegates_status_to_raiko() {
        let app = axum::Router::new().route(
            "/v3/prover/status",
            axum::routing::get(|| async {
                axum::Json(serde_json::json!({ "data": { "clean": true } }))
            }),
        );
        let addr = spawn_app(app).await;
        let raiko = raiko_for(addr);
        let sgx_geth = SgxGethProofProducer::new(raiko.clone(), false);
        let producer = ComposeProofProducer::new_zkvm(raiko, sgx_geth, false);

        assert!(producer.status_clean().await.unwrap());
    }
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `cargo test -p prover --lib producer::compose::zk_backlog_tests::dummy_short_circuits_clear_and_status`
Expected: FAIL — `ZkBacklogController` not implemented for `ComposeProofProducer`.

- [ ] **Step 5: Implement the trait for `ComposeProofProducer`**

In `crates/prover/src/producer/compose.rs`:

(a) Add `RaikoError` and the trait to the imports. Change the `use super::{...}` block to include `ZkBacklogController`:

```rust
use super::{
    BatchProofs, DummyProofProducer, ProofProducer, ProofRequest, ProofResponse, RISC0_VERIFIER_ID,
    SGX_GETH_VERIFIER_ID, SGX_RETH_VERIFIER_ID, SP1_VERIFIER_ID, SgxGethProofProducer,
    ZkBacklogController, decode_proof_payload, prover_hex, raiko_proposals, request_validated,
};
```

and change the `crate::raiko` import to add `RaikoError`:

```rust
use crate::{
    error::{ProverError, Result},
    raiko::{ProofType, RaikoClient, RaikoError, types::RaikoBatchProofRequest},
};
```

(b) Add the impl (place it after the `impl ComposeProofProducer { ... }` block with the constructors):

```rust
#[async_trait::async_trait]
impl ZkBacklogController for ComposeProofProducer {
    /// Short-circuits in dummy mode; otherwise clears the ZK host's backlog.
    async fn clear_backlog(&self) -> Result<(), RaikoError> {
        if self.dummy {
            return Ok(());
        }
        self.raiko.clear_backlog().await
    }

    /// Short-circuits to "clean" in dummy mode; otherwise queries the ZK host.
    async fn status_clean(&self) -> Result<bool, RaikoError> {
        if self.dummy {
            return Ok(true);
        }
        self.raiko.prover_status_clean().await
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cargo test -p prover --lib producer::compose::zk_backlog_tests`
Expected: PASS (both tests).

- [ ] **Step 7: Commit**

```bash
cargo fmt -p prover
git add crates/prover/src/producer/zk_backlog.rs crates/prover/src/producer/mod.rs crates/prover/src/producer/compose.rs
git commit -m "feat(taiko-client-rs): add ZkBacklogController for compose producer"
```

---

## Task 5: `ZkFallback` latch unit

A self-contained unit owning the `AtomicBool` latch, the control-plane handle, and the background clear. No `Pipeline` access.

**Files:**

- Create: `crates/prover/src/submitter/zk_fallback.rs` (struct + a shared `#[cfg(test)] FakeZkBacklog` + unit tests)
- Modify: `crates/prover/src/submitter/mod.rs` (register module)

- [ ] **Step 1: Register the module**

In `crates/prover/src/submitter/mod.rs`, add to the module list (after `pub mod tx_manager_adapter;`):

```rust
mod zk_fallback;
```

- [ ] **Step 2: Create the module (struct, latch methods, test double, tests)**

This is a self-contained new unit, so write the implementation and its tests together. Create `crates/prover/src/submitter/zk_fallback.rs`:

```rust
//! Latched ZK→SGX drain/resume state shared across per-proposal proof tasks
//! (Go `prover/proof_submitter/zk_fallback.go`).
//!
//! Go guards a `bool` with a mutex on the shared submitter; here the latch is an
//! `AtomicBool` on the shared `Arc<Pipeline>`, and `compare_exchange` gives the
//! same one-shot transition (only the task that flips the latch fires the clear).

use std::{
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    time::Duration,
};

use crate::{metrics::ProverMetrics, producer::ZkBacklogController};

/// Bounds the best-effort background retries of `POST /v3/prover/clear`
/// (Go `clearBackoffMaxRetries`).
const CLEAR_MAX_RETRIES: usize = 5;

/// Shared ZK-backlog drain/resume latch + raiko2 control-plane handle.
pub(crate) struct ZkFallback {
    /// True while draining the ZK backlog via SGX.
    in_sgx: AtomicBool,
    /// raiko2 control-plane client; `None` disables the machine.
    controller: Option<Arc<dyn ZkBacklogController>>,
    /// Constant backoff between background clear retries (= proof polling interval).
    clear_retry_interval: Duration,
}

impl ZkFallback {
    /// Build a latch. With `controller == None` the machine is inactive and the
    /// submitter keeps the stateless distance behavior.
    pub(crate) fn new(
        controller: Option<Arc<dyn ZkBacklogController>>,
        clear_retry_interval: Duration,
    ) -> Self {
        Self { in_sgx: AtomicBool::new(false), controller, clear_retry_interval }
    }

    /// Whether a control-plane client is wired (one half of "machine active").
    pub(crate) fn has_controller(&self) -> bool {
        self.controller.is_some()
    }

    /// Whether the submitter is currently draining via SGX.
    pub(crate) fn in_sgx(&self) -> bool {
        self.in_sgx.load(Ordering::Acquire)
    }

    /// Latch into SGX-draining mode. Returns `true` only for the caller that
    /// performed the transition (it owns the one-off backlog clear).
    pub(crate) fn mark_sgx(&self) -> bool {
        let won = self
            .in_sgx
            .compare_exchange(false, true, Ordering::AcqRel, Ordering::Acquire)
            .is_ok();
        if won {
            ProverMetrics::set_zk_backlog_sgx_mode(true);
        }
        won
    }

    /// Unlatch SGX-draining mode. Returns `true` only for the caller that
    /// performed the transition.
    pub(crate) fn resume(&self) -> bool {
        let won = self
            .in_sgx
            .compare_exchange(true, false, Ordering::AcqRel, Ordering::Acquire)
            .is_ok();
        if won {
            ProverMetrics::set_zk_backlog_sgx_mode(false);
        }
        won
    }

    /// Whether SGX-draining can switch back to ZK: (A) the backlog is drained
    /// (`proposal_id <= last_finalized + 1`), and only then (B) the ZK backend
    /// reports `clean`. A status error degrades to resuming on (A) alone, so the
    /// prover never gets stuck on SGX if raiko2 #93 is absent.
    pub(crate) async fn can_resume(&self, proposal_id: u64, last_finalized: u64) -> bool {
        if proposal_id > last_finalized + 1 {
            return false;
        }
        let Some(controller) = self.controller.as_ref() else {
            return true;
        };
        match controller.status_clean().await {
            Ok(clean) => clean,
            Err(err) => {
                tracing::warn!(
                    %err,
                    proposal_id,
                    "ZK prover status unavailable, resuming ZK on backlog-drained condition alone"
                );
                true
            }
        }
    }

    /// Clear the ZK backlog in the background with bounded retries. Best-effort:
    /// clearing only accelerates the drain, so a final failure is logged and
    /// ignored. Spawned detached so it outlives the triggering proposal's task.
    pub(crate) fn fire_clear_async(&self) {
        let Some(controller) = self.controller.clone() else {
            return;
        };
        ProverMetrics::inc_zk_backlog_clear();
        let interval = self.clear_retry_interval;
        tokio::spawn(async move {
            for attempt in 0..=CLEAR_MAX_RETRIES {
                match controller.clear_backlog().await {
                    Ok(()) => {
                        tracing::info!("cleared ZK backlog after entering SGX-draining mode");
                        return;
                    }
                    Err(err) => {
                        tracing::warn!(%err, attempt, "failed to clear ZK backlog, retrying");
                        if attempt < CLEAR_MAX_RETRIES {
                            tokio::time::sleep(interval).await;
                        }
                    }
                }
            }
            tracing::warn!("failed to clear ZK backlog after retries");
        });
    }
}

#[cfg(test)]
pub(crate) use test_support::FakeZkBacklog;

#[cfg(test)]
mod test_support {
    use std::sync::atomic::{AtomicI32, Ordering};

    use crate::{producer::ZkBacklogController, raiko::RaikoError};

    /// Programmable [`ZkBacklogController`] double for the drain/resume tests
    /// (Go `fakeZKBacklog`). Shared by the `ZkFallback` unit tests and the
    /// `Pipeline` integration tests.
    pub(crate) struct FakeZkBacklog {
        /// Value returned by `status_clean` when `status_err` is false.
        pub clean: bool,
        /// When true, `status_clean` returns an error (degrade path).
        pub status_err: bool,
        /// When true, `clear_backlog` returns an error (retry path).
        pub clear_err: bool,
        /// Number of `clear_backlog` calls.
        pub clear_calls: AtomicI32,
        /// Number of `status_clean` calls.
        pub status_calls: AtomicI32,
    }

    impl FakeZkBacklog {
        /// A controller that reports `clean` and never errors.
        pub(crate) fn new(clean: bool) -> Self {
            Self {
                clean,
                status_err: false,
                clear_err: false,
                clear_calls: AtomicI32::new(0),
                status_calls: AtomicI32::new(0),
            }
        }
    }

    #[async_trait::async_trait]
    impl ZkBacklogController for FakeZkBacklog {
        async fn clear_backlog(&self) -> Result<(), RaikoError> {
            self.clear_calls.fetch_add(1, Ordering::SeqCst);
            if self.clear_err {
                Err(RaikoError::Failed("clear failed".to_owned()))
            } else {
                Ok(())
            }
        }

        async fn status_clean(&self) -> Result<bool, RaikoError> {
            self.status_calls.fetch_add(1, Ordering::SeqCst);
            if self.status_err {
                Err(RaikoError::Failed("status failed".to_owned()))
            } else {
                Ok(self.clean)
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use std::{
        sync::{Arc, atomic::Ordering},
        time::Duration,
    };

    use super::{FakeZkBacklog, ZkFallback};

    fn fallback(clean: bool) -> ZkFallback {
        ZkFallback::new(Some(Arc::new(FakeZkBacklog::new(clean))), Duration::from_millis(1))
    }

    #[test]
    fn mark_sgx_only_first_caller_wins() {
        let f = fallback(true);
        assert!(!f.in_sgx());
        assert!(f.mark_sgx(), "first caller latches");
        assert!(!f.mark_sgx(), "already latched");
        assert!(f.in_sgx());

        assert!(f.resume());
        assert!(!f.in_sgx());
        assert!(f.mark_sgx(), "can latch again after a resume");
    }

    #[test]
    fn mark_sgx_concurrent_single_winner() {
        // `mark_sgx` is sync, so use real threads for a genuine race.
        let f = Arc::new(fallback(true));
        let handles: Vec<_> = (0..50)
            .map(|_| {
                let f = f.clone();
                std::thread::spawn(move || f.mark_sgx())
            })
            .collect();
        let winners = handles.into_iter().map(|h| h.join().unwrap()).filter(|won| *won).count();
        assert_eq!(winners, 1, "exactly one thread performs the transition");
        assert!(f.in_sgx());
    }

    #[tokio::test]
    async fn can_resume_requires_backlog_drained_first() {
        let controller = Arc::new(FakeZkBacklog::new(true));
        let f = ZkFallback::new(Some(controller.clone()), Duration::from_millis(1));
        // proposal_id 100 > last_finalized 10 + 1 → not drained; status not queried.
        assert!(!f.can_resume(100, 10).await);
        assert_eq!(
            controller.status_calls.load(Ordering::SeqCst),
            0,
            "status not queried until the backlog is drained"
        );
    }

    #[tokio::test]
    async fn can_resume_when_drained_and_clean() {
        let f = fallback(true);
        assert!(f.can_resume(11, 10).await, "drained + clean resumes");
    }

    #[tokio::test]
    async fn stays_draining_when_not_clean() {
        let f = fallback(false);
        assert!(!f.can_resume(11, 10).await, "drained but not clean stays draining");
    }

    #[tokio::test]
    async fn degrades_to_drained_only_on_status_error() {
        let controller = Arc::new(FakeZkBacklog {
            clean: false,
            status_err: true,
            ..FakeZkBacklog::new(false)
        });
        let f = ZkFallback::new(Some(controller), Duration::from_millis(1));
        assert!(f.can_resume(11, 10).await, "status error degrades to resume on (A) alone");
    }

    #[test]
    fn inactive_without_controller() {
        let f = ZkFallback::new(None, Duration::from_millis(1));
        assert!(!f.has_controller());
    }
}
```

- [ ] **Step 3: Run the tests to verify they pass**

Run: `cargo test -p prover --lib submitter::zk_fallback`
Expected: PASS (all `ZkFallback` unit tests, including the 50-thread single-winner race).

- [ ] **Step 4: Commit**

```bash
cargo fmt -p prover
git add crates/prover/src/submitter/zk_fallback.rs crates/prover/src/submitter/mod.rs
git commit -m "feat(taiko-client-rs): add ZkFallback drain/resume latch"
```

---

## Task 6: Wire the machine into `Pipeline`

Add the latch field, `decide_use_zk`, the buffer clear-and-resend, and replace the per-task distance check in `request_proof_attempt`.

**Files:**

- Modify: `crates/prover/src/submitter/submitter.rs` (imports, `Pipeline` field, `Pipeline::new` param, two new methods, `request_proof_attempt`, harness + tests)

- [ ] **Step 1: Add imports, the `Pipeline` field, and the `new` parameter**

In `crates/prover/src/submitter/submitter.rs`:

(a) Extend the `crate::producer` import to bring in the trait, and add the `ZkFallback` import. Change:

```rust
    producer::{BatchProofs, ProofProducer, ProofRequest, ProofResponse},
```

to:

```rust
    producer::{BatchProofs, ProofProducer, ProofRequest, ProofResponse, ZkBacklogController},
```

and add, after the `use crate::{...}` block (or alongside the other `use super::` items — there is a `use crate::submitter::transaction::...` already; add this near it):

```rust
use crate::submitter::zk_fallback::ZkFallback;
```

(b) Add the field to `struct Pipeline` (after `cfg: SubmitterConfig,` — keep `cfg` last is fine; place `zk_fallback` before `cfg`):

```rust
    /// Shared ZK→SGX drain/resume latch + raiko2 control-plane handle.
    zk_fallback: ZkFallback,
```

(c) Change `Pipeline::new` to take the control-plane handle and build the latch. Update the signature to add one parameter after `zkvm_producer`:

```rust
    pub fn new(
        base_producer: Arc<dyn ProofProducer>,
        zkvm_producer: Option<Arc<dyn ProofProducer>>,
        zk_backlog: Option<Arc<dyn ZkBacklogController>>,
        buffers: HashMap<ProofType, Arc<ProofBuffer>>,
        caches: HashMap<ProofType, Arc<ProofCache>>,
        channels: SubmitterChannels,
        cfg: SubmitterConfig,
    ) -> Self {
        Self {
            base_producer,
            zkvm_producer,
            zk_fallback: ZkFallback::new(zk_backlog, cfg.proof_polling_interval),
            buffers,
            caches,
            channels,
            cfg,
        }
    }
```

- [ ] **Step 2: Add the failing integration tests**

In the `#[cfg(test)] mod tests` block of `submitter.rs`:

(a) Extend the test imports. Change:

```rust
    use super::{Pipeline, ProofRequestMeta, RequestAttempt, SubmitterChannels, SubmitterConfig};
```

to:

```rust
    use super::{Pipeline, ProofRequestMeta, RequestAttempt, SubmitterChannels, SubmitterConfig};
    use crate::submitter::zk_fallback::FakeZkBacklog;
```

(b) Update `harness_with` to accept a control-plane handle, and pass it to `Pipeline::new`. Change the signature and the `Pipeline::new` call:

```rust
    fn harness_with(
        base: Arc<dyn ProofProducer>,
        zkvm: Option<Arc<dyn ProofProducer>>,
        zk_backlog: Option<Arc<dyn crate::producer::ZkBacklogController>>,
        force_interval: Duration,
        max: u64,
        max_zk_proof_proposal_distance: u64,
    ) -> Harness {
        let (batch_proofs_tx, batch_rx) = mpsc::channel(16);
        let (aggregation_notify_tx, aggregation_rx) = mpsc::channel(16);
        let (proof_request_tx, request_rx) = mpsc::channel(16);
        let (flush_cache_tx, flush_rx) = mpsc::channel(16);

        let pipeline = Pipeline::new(
            base,
            zkvm,
            zk_backlog,
            HashMap::from([
                (ProofType::Sgx, Arc::new(ProofBuffer::new(max))),
                (ProofType::Risc0, Arc::new(ProofBuffer::new(max))),
            ]),
            HashMap::from([
                (ProofType::Sgx, Arc::new(ProofCache::new())),
                (ProofType::Risc0, Arc::new(ProofCache::new())),
            ]),
            SubmitterChannels {
                batch_proofs_tx,
                aggregation_notify_tx,
                proof_request_tx,
                flush_cache_tx,
            },
            SubmitterConfig {
                proof_polling_interval: Duration::from_millis(1),
                force_batch_proving_interval: force_interval,
                proposal_window_size: 0,
                max_zk_proof_proposal_distance,
                shadow_mode: false,
                inbox_address: Address::repeat_byte(0x11),
            },
        );
        Harness { pipeline, batch_rx, aggregation_rx, request_rx, flush_rx }
    }
```

(c) Update the `harness` helper to pass `None` for the new handle:

```rust
    fn harness(base: Arc<dyn ProofProducer>, force_interval: Duration, max: u64) -> Harness {
        harness_with(base, None, None, force_interval, max, 30)
    }
```

(d) Update the existing `far_ahead_proposal_falls_back_to_base_producer` test. The distance breach no longer flips the per-task `use_zk` flag (the latch governs ZK skipping now), so the machine stays **inactive** here (no controller) and falls back via `decide_use_zk → should_use_zk_proof`. Change its `harness_with` call and replace the `!use_zk` assertion:

```rust
        let h = harness_with(base, Some(zkvm), None, Duration::from_secs(3_600), 2, 5);
```

and replace:

```rust
        assert!(!use_zk, "zk disabled for a far-ahead proposal");
```

with:

```rust
        assert!(use_zk, "the per-task zk flag is untouched by the distance gate; the latch governs ZK");
```

(e) Add the new drain/resume integration tests at the end of the `mod tests` block (before its closing `}`):

```rust
    /// Build a request whose proposal id is `proposal_id`.
    fn request_for(proposal_id: u64) -> ProofRequest {
        response(proposal_id, ProofType::Sgx).request
    }

    #[tokio::test]
    async fn decide_use_zk_inactive_when_distance_zero() {
        // distance 0 disables the machine: stateless skip, no latch.
        let h = harness_with(
            Arc::new(MockProducer::default()),
            Some(Arc::new(MockProducer::default())),
            Some(Arc::new(FakeZkBacklog::new(true))),
            Duration::from_secs(3_600),
            2,
            0,
        );
        assert!(!h.pipeline.decide_use_zk(1000, 1).await);
        assert!(!h.pipeline.zk_fallback.in_sgx(), "machine never latched");
    }

    #[tokio::test]
    async fn decide_use_zk_inactive_without_controller() {
        // No control-plane client: stateless distance behavior, no latch.
        let h = harness_with(
            Arc::new(MockProducer::default()),
            Some(Arc::new(MockProducer::default())),
            None,
            Duration::from_secs(3_600),
            2,
            5,
        );
        assert!(h.pipeline.decide_use_zk(15, 10).await, "within distance uses ZK");
        assert!(!h.pipeline.decide_use_zk(16, 10).await, "beyond distance skips ZK");
        assert!(!h.pipeline.zk_fallback.in_sgx(), "no latch without a controller");
    }

    #[tokio::test]
    async fn decide_use_zk_breach_latches_clears_and_resends() {
        let controller = Arc::new(FakeZkBacklog::new(true));
        let mut h = harness_with(
            Arc::new(MockProducer::default()),
            Some(Arc::new(MockProducer::default())),
            Some(controller.clone()),
            Duration::from_secs(3_600),
            4,
            5,
        );
        // Seed a buffered ZK (risc0) proof that must be flushed and resent.
        h.pipeline.buffers().get(&ProofType::Risc0).unwrap().write(response(11, ProofType::Risc0)).unwrap();

        // Breach: proposal 100 > last_finalized 10 + distance 5.
        assert!(!h.pipeline.decide_use_zk(100, 10).await);
        assert!(h.pipeline.zk_fallback.in_sgx(), "breach latches SGX mode");
        assert_eq!(
            h.pipeline.buffers().get(&ProofType::Risc0).unwrap().len(),
            0,
            "ZK buffer flushed on latch"
        );
        // The flushed proposal is resent for SGX proving.
        assert_eq!(h.request_rx.try_recv().unwrap().proposal_id, 11);

        // The one-off clear fires in the background; wait briefly for it.
        for _ in 0..200 {
            if controller.clear_calls.load(std::sync::atomic::Ordering::SeqCst) > 0 {
                break;
            }
            tokio::time::sleep(Duration::from_millis(1)).await;
        }
        assert!(
            controller.clear_calls.load(std::sync::atomic::Ordering::SeqCst) >= 1,
            "one-off clear fired on latch"
        );
    }

    #[tokio::test]
    async fn decide_use_zk_stays_draining_until_clean() {
        let controller = Arc::new(FakeZkBacklog::new(false)); // not clean
        let h = harness_with(
            Arc::new(MockProducer::default()),
            Some(Arc::new(MockProducer::default())),
            Some(controller),
            Duration::from_secs(3_600),
            2,
            5,
        );
        assert!(h.pipeline.zk_fallback.mark_sgx(), "manually latch for the test");

        // Drained (11 <= 10+1) but not clean → keep draining.
        assert!(!h.pipeline.decide_use_zk(11, 10).await);
        assert!(h.pipeline.zk_fallback.in_sgx());
    }

    #[tokio::test]
    async fn decide_use_zk_resumes_when_drained_and_clean() {
        let controller = Arc::new(FakeZkBacklog::new(true)); // clean
        let h = harness_with(
            Arc::new(MockProducer::default()),
            Some(Arc::new(MockProducer::default())),
            Some(controller),
            Duration::from_secs(3_600),
            2,
            5,
        );
        assert!(h.pipeline.zk_fallback.mark_sgx());

        assert!(h.pipeline.decide_use_zk(11, 10).await, "drained + clean resumes ZK");
        assert!(!h.pipeline.zk_fallback.in_sgx(), "latch released");
    }
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cargo test -p prover --lib submitter::submitter`
Expected: FAIL — `no method named decide_use_zk`, and `zk_fallback` field is private to `Pipeline` (the test module is inside `submitter.rs`, so it CAN read it once the field exists; the failure is the missing method/field).

- [ ] **Step 4: Add `decide_use_zk` and the buffer clear-and-resend to `impl Pipeline`**

In `crates/prover/src/submitter/submitter.rs`, add these methods to the main `impl Pipeline` block (e.g. right after `should_use_zk_proof`):

```rust
    /// Apply the ZK backlog drain/resume state machine and report whether this
    /// proposal should be proven via ZK (Go `decideUseZK`). Side effects: on the
    /// first distance breach it latches SGX-draining mode, flushes buffered ZK
    /// proofs for re-proving via SGX, and fires a one-off backlog clear; it
    /// unlatches once the backlog is drained and the ZK backend reports clean.
    ///
    /// Inactive (distance 0, or no control-plane client) reduces to the stateless
    /// [`Self::should_use_zk_proof`] check, preserving the pre-#21795 behavior.
    pub(crate) async fn decide_use_zk(&self, proposal_id: u64, last_finalized: u64) -> bool {
        if self.cfg.max_zk_proof_proposal_distance == 0 || !self.zk_fallback.has_controller() {
            return self.should_use_zk_proof(proposal_id, last_finalized);
        }

        if self.zk_fallback.in_sgx() {
            if self.zk_fallback.can_resume(proposal_id, last_finalized).await {
                if self.zk_fallback.resume() {
                    tracing::info!(
                        proposal_id,
                        last_finalized,
                        "ZK backlog drained, resuming ZK proofs"
                    );
                }
                return true;
            }
            return false;
        }

        if !self.should_use_zk_proof(proposal_id, last_finalized) {
            if self.zk_fallback.mark_sgx() {
                tracing::warn!(
                    proposal_id,
                    last_finalized,
                    max_zk_proof_proposal_distance = self.cfg.max_zk_proof_proposal_distance,
                    "ZK proof backlog detected, clearing ZK backlog and draining via SGX"
                );
                self.clear_zk_buffers_and_resend().await;
                self.zk_fallback.fire_clear_async();
            }
            return false;
        }
        true
    }

    /// Flush buffered/cached ZK proofs (risc0, sp1) and re-enqueue their
    /// proposals so they are re-proven via SGX while draining (Go
    /// `clearZKProofBuffersAndResend`).
    async fn clear_zk_buffers_and_resend(&self) {
        for proof_type in [ProofType::Risc0, ProofType::Sp1] {
            self.clear_proof_buffer_and_resend(proof_type).await;
        }
    }

    /// Flush the buffer and cache for `proof_type` and resend each cleared
    /// proposal to the request channel. No-op when the type has no buffer/cache
    /// (no ZK producer configured).
    async fn clear_proof_buffer_and_resend(&self, proof_type: ProofType) {
        let (Some(buffer), Some(cache)) =
            (self.buffers.get(&proof_type), self.caches.get(&proof_type))
        else {
            return;
        };
        let buffered = buffer.read_all();
        let ids: Vec<u64> = buffered.iter().map(ProofResponse::proposal_id).collect();
        buffer.clear_items(&ids);

        let mut resend = buffered;
        resend.extend(cache.drain_all());
        for response in &resend {
            let _ = self
                .channels
                .proof_request_tx
                .send(ProofRequestMeta::from_request(&response.request))
                .await;
        }
        if !resend.is_empty() {
            tracing::info!(
                ?proof_type,
                count = resend.len(),
                "cleared ZK proof buffer and resent proposals for SGX draining"
            );
        }
    }
```

- [ ] **Step 5: Replace the per-task distance check in `request_proof_attempt`**

In `request_proof_attempt`, replace this block:

```rust
        // Too far ahead of finalization for a slow ZK proof: fall back to the
        // base proof to keep catching up (Rust-only distance gate; see
        // `should_use_zk_proof`).
        if *use_zk && !self.should_use_zk_proof(proposal_id, last_finalized) {
            tracing::info!(
                proposal_id,
                last_finalized,
                max_zk_proof_proposal_distance = self.cfg.max_zk_proof_proposal_distance,
                "proposal too far from last finalized, skipping ZK proof"
            );
            *use_zk = false;
        }

        if let (true, Some(zkvm)) = (*use_zk, self.zkvm_producer.as_ref()) {
```

with:

```rust
        // ZK backlog drain/resume state machine (see `zk_fallback.rs`): shared
        // across all per-proposal tasks via the latch on `self.zk_fallback`. May
        // latch SGX-draining mode (firing a one-off backlog clear + flushing
        // buffered ZK proofs) on the first distance breach, or resume ZK once the
        // backlog is drained and clean. Inactive (distance 0 / no control plane)
        // reduces to the stateless `should_use_zk_proof` check. The per-task
        // `use_zk` flag still handles the `zk_any_not_drawn` / timeout fallbacks.
        let backlog_allows_zk = self.decide_use_zk(proposal_id, last_finalized).await;

        if let (true, true, Some(zkvm)) = (*use_zk, backlog_allows_zk, self.zkvm_producer.as_ref()) {
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cargo test -p prover --lib submitter`
Expected: PASS — the new drain/resume tests plus all existing submitter tests (including the updated `far_ahead_proposal_falls_back_to_base_producer`).

- [ ] **Step 7: Commit**

```bash
cargo fmt -p prover
git add crates/prover/src/submitter/submitter.rs
git commit -m "feat(taiko-client-rs): drive ZK→SGX latch from the proof pipeline"
```

---

## Task 7: Wire the control-plane handle in the prover orchestrator

Build the ZK compose producer once and pass it to `Pipeline::new` as both the producer and the control-plane handle.

**Files:**

- Modify: `crates/prover/src/prover.rs` (producer construction + `Pipeline::new` call)

- [ ] **Step 1: Build the ZK producer as a concrete Arc and coerce to both traits**

In `crates/prover/src/prover.rs`, replace the `zkvm_producer` construction (currently lines ~102-109):

```rust
        let zkvm_producer: Option<Arc<dyn ProofProducer>> =
            cfg.raiko_zkvm_host.as_ref().map(|host| {
                Arc::new(ComposeProofProducer::new_zkvm(
                    RaikoClient::new(raiko_client_config(&cfg, host.clone())),
                    sgx_geth.clone(),
                    cfg.dummy,
                )) as Arc<dyn ProofProducer>
            });
```

with:

```rust
        // Build the ZK compose producer once, then view the same Arc as both a
        // proof producer and a raiko2 control-plane client (no downcasting). When
        // no ZK host is set, both stay None and the drain/resume machine is
        // inactive; when the host predates raiko2 #93 the control-plane calls 404
        // and the machine degrades by design (see `ZkFallback::can_resume`).
        let zkvm_compose: Option<Arc<ComposeProofProducer>> =
            cfg.raiko_zkvm_host.as_ref().map(|host| {
                Arc::new(ComposeProofProducer::new_zkvm(
                    RaikoClient::new(raiko_client_config(&cfg, host.clone())),
                    sgx_geth.clone(),
                    cfg.dummy,
                ))
            });
        let zkvm_producer: Option<Arc<dyn ProofProducer>> =
            zkvm_compose.clone().map(|producer| producer as Arc<dyn ProofProducer>);
        let zk_backlog: Option<Arc<dyn ZkBacklogController>> =
            zkvm_compose.map(|producer| producer as Arc<dyn ZkBacklogController>);
```

- [ ] **Step 2: Import the trait**

In `crates/prover/src/prover.rs`, add `ZkBacklogController` to the `producer` import. Change:

```rust
    producer::{BatchProofs, ComposeProofProducer, ProofProducer, SgxGethProofProducer},
```

to:

```rust
    producer::{
        BatchProofs, ComposeProofProducer, ProofProducer, SgxGethProofProducer, ZkBacklogController,
    },
```

- [ ] **Step 3: Pass `zk_backlog` to `Pipeline::new`**

In `crates/prover/src/prover.rs`, update the `Pipeline::new(` call to insert `zk_backlog` after `zkvm_producer`:

```rust
        let pipeline = Arc::new(Pipeline::new(
            base_producer,
            zkvm_producer,
            zk_backlog,
            buffers,
            caches,
            SubmitterChannels {
                batch_proofs_tx,
                aggregation_notify_tx,
                proof_request_tx,
                flush_cache_tx,
            },
            SubmitterConfig::from_prover_configs(&cfg),
        ));
```

- [ ] **Step 4: Verify the crate builds and all tests pass**

Run: `cargo build -p prover`
Expected: builds clean (no unused-import or type errors).

Run: `cargo test -p prover --lib`
Expected: PASS (whole crate unit-test suite).

- [ ] **Step 5: Commit**

```bash
cargo fmt -p prover
git add crates/prover/src/prover.rs
git commit -m "feat(taiko-client-rs): wire ZK control-plane handle into the prover"
```

---

## Task 8: Flag help text + stale comment fix

Align the `--prover.maxZKProofProposalDistance` help with Go's new wording, and fix the now-stale doc comment on `should_use_zk_proof`.

**Files:**

- Modify: `bin/client/src/flags/prover.rs` (help text + assert)
- Modify: `crates/prover/src/submitter/submitter.rs` (doc comment)

- [ ] **Step 1: Update the failing help-text assertion**

In `bin/client/src/flags/prover.rs`, in the `prover_help_lists_raiko_and_shadow_flags` test, add an assertion on the new wording (after the existing `--prover.maxZKProofProposalDistance` assertion):

```rust
        assert!(help.contains("drains via the base (SGX) proof"));
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cargo test -p taiko-client prover_help_lists_raiko_and_shadow_flags`
Expected: FAIL — help does not contain the new phrase yet.

- [ ] **Step 3: Update the help text**

In `bin/client/src/flags/prover.rs`, change the `max_zk_proof_proposal_distance` flag's `help`:

```rust
        help = "Maximum proposal distance above lastFinalizedProposalID for requesting ZK proofs. \
                Beyond it the prover stops requesting ZK, clears the ZK backlog, and drains via the \
                base (SGX) proof until the backlog is cleared and the ZK endpoint reports clean, then \
                resumes ZK. Set to 0 to disable ZK proving (always use the base/SGX proof)."
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cargo test -p taiko-client prover_help_lists_raiko_and_shadow_flags`
Expected: PASS.

- [ ] **Step 5: Fix the stale doc comment**

In `crates/prover/src/submitter/submitter.rs`, replace the doc comment above `should_use_zk_proof` (currently claims "no Go equivalent"):

```rust
    /// Whether a ZK proof should be requested for `proposal_id`: false once it
    /// is more than `max_zk_proof_proposal_distance` ahead of the last finalized
    /// proposal, so the prover falls back to the faster base proof to catch up.
    ///
    /// Rust-only catch-up optimization with no Go equivalent: the Go prover has
    /// no proposal-distance gate (its ZK fallback is purely the 1h timeout plus
    /// `zk_any_not_drawn`). Disable by setting the distance high enough that it
    /// never triggers.
    #[must_use]
    fn should_use_zk_proof(&self, proposal_id: u64, last_finalized: u64) -> bool {
```

with:

```rust
    /// Stateless distance check: whether a ZK proof is allowed for `proposal_id`,
    /// i.e. it is within `max_zk_proof_proposal_distance` of the last finalized
    /// proposal (Go `shouldUseZKProof`, #21782). This is the input to the latched
    /// drain/resume machine in [`Self::decide_use_zk`] (#21795); when that machine
    /// is inactive it is also the final verdict.
    #[must_use]
    fn should_use_zk_proof(&self, proposal_id: u64, last_finalized: u64) -> bool {
```

Also update the inline comment in the `should_use_zk_proof_boundary` test (it says "no Go equivalent"):

```rust
        // Stateless distance gate (Go `shouldUseZKProof`, #21782): distance 30,
        // last finalized 10 → 40 ok, 41 falls back to the base proof.
```

- [ ] **Step 6: Run the affected tests**

Run: `cargo test -p prover --lib should_use_zk_proof`
Expected: PASS (both boundary tests).

- [ ] **Step 7: Commit**

```bash
cargo fmt -p prover
git add bin/client/src/flags/prover.rs crates/prover/src/submitter/submitter.rs
git commit -m "docs(taiko-client-rs): align maxZKProofProposalDistance flag help and comment"
```

---

## Task 9: Final verification

Format, lint, and run the full prover suite; record the spec refinement.

**Files:**

- Modify: `packages/taiko-client-rs/docs/superpowers/specs/2026-06-16-rust-zk-sgx-drain-resume-design.md` (one-line note)

- [ ] **Step 1: Format and lint**

Run:

```bash
cargo fmt --all
cargo clippy -p prover --all-targets -- -D warnings
```

Expected: no diff after fmt, clippy clean.

- [ ] **Step 2: Full prover unit suite + build**

Run:

```bash
cargo test -p prover --lib
cargo build -p prover
```

Expected: all tests PASS, build clean.

- [ ] **Step 3: Record the spec refinement**

In the spec file, append to the "Notes" section:

```markdown
- Implementation refinement (during planning): the latch + control-plane calls
  live in a composed `ZkFallback` unit (`submitter/zk_fallback.rs`); `decide_use_zk`
  and the buffer clear-and-resend remain `Pipeline` methods in `submitter.rs`,
  because Rust module privacy forbids a sibling file from accessing `Pipeline`'s
  private fields. Behavior is unchanged from this spec.
```

- [ ] **Step 4: Commit**

```bash
git add packages/taiko-client-rs/docs/superpowers/specs/2026-06-16-rust-zk-sgx-drain-resume-design.md
git commit -m "docs(taiko-client-rs): note ZkFallback composition refinement"
```

---

## Verification summary

- Unit tests (`cargo test -p prover --lib`): raiko `clear`/`status` (method, path, parse, non-200), compose `ZkBacklogController` (dummy short-circuit + delegation), `ProofCache::drain_all`, `ZkFallback` (CAS single-winner incl. 50-task concurrency, condition-(A) gate, clean/not-clean resume, status-error degrade), `Pipeline::decide_use_zk` (inactive distance-0, inactive no-controller, breach latch+clear+resend, stay-draining, resume), flag help.
- `cargo clippy -p prover -- -D warnings` and `cargo build -p prover` clean.
- The `prove_e2e` integration test needs a live devnet (pre-existing) and is out of scope for this change's verification.
- Per repo memory: do not use `make test` (slow; Go/Rust suites can't run concurrently) — use the targeted `cargo` commands above.

## Out of scope

- raiko2 #93 deployment (the port degrades gracefully without it).
- Any change to the SGX/base proof path, aggregation, or tx submission.
