# Maximal Simplification Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign preconfirmation-p2p for maximal simplification with a new API surface while preserving correctness and best practices; ensure `just fmt && just clippy-fix && just test` pass.

**Architecture:** Replace `P2pService` with `P2pNode` + `P2pHandle`, collapse config into `P2pConfig`, unify discovery and reputation into single-path implementations, and simplify req/resp correlation to per-request oneshots. Remove presets, compatibility scaffolding, and duplicate scoring/gating paths.

**Tech Stack:** Rust 2024, libp2p 0.56, tokio, reth-discv5 (optional), SSZ types.

---

## API Signatures (target)

```rust
pub struct P2pConfig {
    pub chain_id: u64,
    pub listen_addr: std::net::SocketAddr,
    pub enable_discovery: bool,
    pub discovery_listen: std::net::SocketAddr,
    pub bootnodes: Vec<String>,
    pub request_timeout: std::time::Duration,
    pub max_reqresp_concurrent_streams: usize,
    pub rate_limit: RateLimitConfig,
    pub reputation: ReputationConfig,
}

pub struct RateLimitConfig {
    pub window: std::time::Duration,
    pub max_requests: u32,
}

pub struct ReputationConfig {
    pub greylist_threshold: f64,
    pub ban_threshold: f64,
    pub halflife: std::time::Duration,
}

pub struct P2pNode { /* owns libp2p swarm */ }
pub struct P2pHandle { /* command sender + event stream */ }

impl P2pNode {
    pub fn new(cfg: P2pConfig, validator: Box<dyn ValidationAdapter>) -> (P2pHandle, P2pNode);
    pub async fn run(self) -> anyhow::Result<()>;
}

impl P2pHandle {
    pub async fn publish_commitment(&self, msg: SignedCommitment) -> anyhow::Result<()>;
    pub async fn publish_raw_txlist(&self, msg: RawTxListGossip) -> anyhow::Result<()>;
    pub async fn request_commitments(
        &self,
        start_block: Uint256,
        max_count: u32,
        peer: Option<libp2p::PeerId>,
    ) -> Result<GetCommitmentsByNumberResponse, NetworkError>;
    pub async fn request_raw_txlist(
        &self,
        hash: Bytes32,
        peer: Option<libp2p::PeerId>,
    ) -> Result<GetRawTxListResponse, NetworkError>;
    pub async fn request_head(
        &self,
        peer: Option<libp2p::PeerId>,
    ) -> Result<PreconfHead, NetworkError>;
    pub fn events(&self) -> impl futures::Stream<Item = NetworkEvent>;
}
```

---

## Migration Mapping (old → new)

- `P2pService::start(cfg, lookahead)` → `P2pNode::new(cfg, validator)` + `tokio::spawn(node.run())`
- `P2pService::publish_*` → `P2pHandle::publish_*`
- `P2pService::request_*_blocking` → `P2pHandle::request_*().await`
- `P2pService::subscribe()/events()` → `P2pHandle::events()`
- `NetworkConfig` → `P2pConfig`
- `DiscoveryConfig` → removed (discovery params folded into `P2pConfig`)
- `ReputationBackend`/`RethReputationAdapter` → `Reputation`

---

## Implementation Order (concise)

1. Add new API surface (`P2pConfig`, `P2pNode`, `P2pHandle`) and compile-only test.
2. Collapse discovery to `spawn_discovery -> Receiver<Multiaddr>`; remove `DiscoveryConfig/DiscoveryEvent`.
3. Collapse reputation + gating to a single store; remove adapters/traits; remove gossipsub app-score writes.
4. Replace req/resp correlation with per-request oneshot mapping.
5. Remove `crates/service`, move example to `crates/net/examples` and update imports.
6. Update README/ARCHITECTURE/specification for new API and config.
7. Run `just fmt && just clippy-fix && just test` and fix any failures.

---

### Task 3 Detail: Reputation backend simplification

**Files:**
- Modify: `packages/preconfirmation-p2p/crates/net/src/reputation.rs`
- Modify: `packages/preconfirmation-p2p/crates/net/src/driver/{mod.rs,discovery.rs,gossip.rs,tests.rs}`
- Modify: `packages/preconfirmation-p2p/crates/net/src/lib.rs`
- Modify: `packages/preconfirmation-p2p/crates/net/src/driver/behaviour.rs` (only if necessary)

**Step 1: Write failing test**
- Add `driver_exposes_peer_reputation_store` (or similar) in `driver/tests.rs` asserting driver stores a `PeerReputationStore` (no `Box<dyn ReputationBackend>`).

**Step 2: Run test to verify failure**
- Run: `cargo test -p preconfirmation-net driver_exposes_peer_reputation_store` (expect fail: type mismatch/trait still present).

**Step 3: Remove adapter/trait**
- Delete `ReputationBackend` trait and `reth_adapter` module; drop related tests.
- Replace driver fields/types to use `PeerReputationStore` directly; update constructor/builder signatures.

**Step 4: Update gating and gossip**
- Wire dial gating to Kona gater + `is_banned` check; remove `adjust_app_score/set_application_score` writes while keeping validation reporting.

**Step 5: Fix tests**
- Update or remove tests referencing `ReputationBackend`/`reth_adapter`; ensure new assertion uses store.

**Step 6: Verify**
- Run targeted tests: `cargo test -p preconfirmation-net driver_exposes_peer_reputation_store` and relevant unit tests touched.
- Ensure bans/greylists still enforced; disconnect + blocklist + Kona gater on ban.

---

## Execution Handoff

Plan complete and saved to `docs/plans/2025-12-23-max-simplification-plan.md`.

Two execution options:

1. Subagent-Driven (this session)
2. Parallel Session (separate)

Which approach?
