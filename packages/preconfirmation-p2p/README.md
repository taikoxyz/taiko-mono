# preconfirmation-p2p

Project for the Taiko permissionless preconfirmation P2P layer (libp2p + discv5, SSZ messages).

## Layout (work in progress)

- `crates/types`: Spec-driven SSZ types and helpers (hashing/signing/validation). Provides
  topic/protocol ID helpers used by the network.
- `crates/net`: libp2p transport + behaviours (ping, identify, gossipsub, req/resp) and
  scaffolds for discovery (`discovery`, now backed by `reth-discv5` behind the `reth-discovery`
  feature) and peer reputation. Kona gossipsub presets and gater are always applied. Public API:
  `NetworkConfig`, `NetworkCommand` (publish/request), `NetworkEvent` (gossip/req-resp/lifecycle),
  `NetworkDriver`/`NetworkHandle`.
- `crates/service`: Async façade owning the network driver. Exposes a small channel-based API:
  `P2pService::start(cfg)` -> command sender + event stream; `shutdown()` for graceful stop.
- `crates/service/examples/p2p-node.rs`: Minimal CLI example that starts the service and logs
  network events (replaces the previous standalone `bin/p2p-node`).

## API mapping to the preconfirmation spec

- Gossip topics: SignedCommitment, RawTxListGossip (from `p2p-types` helpers).
- Req/Resp protocols: GetCommitmentsByNumber, GetRawTxList (SSZ over libp2p request-response).
- Commands: publish commitments/raw txlists; send commitment range or raw-txlist requests.
- Events: peer connect/disconnect, inbound gossip, req/resp responses, inbound requests, lifecycle.
- Discovery/reputation: discovery uses `reth-discv5` under the hood; reputation has basic scoring,
  block-list enforcement, and metrics with room to tune/extend.

## Upstream reuse and compatibility

- Discovery is backed by `reth-discv5` (git tag `v1.9.3`) behind the `reth-discovery` feature, so
  we reuse upstream maintenance instead of rolling our own.
- Kona gossipsub presets and gater come from `kona-gossip`/`kona-peers` at tag
  `kona-client/v1.2.4` and are always enabled.
- This package is library-only; runnable smoke testing lives in `crates/service/examples/p2p-node.rs`.

## Reputation & Scoring

- Default: local `PeerReputationStore` with decay/thresholds, libp2p block-list enforcement, and
  rate limiting.
- Upstream request-rate limiter swap: still local; no compatible upstream rate-limit module is
  published for our libp2p/reth/Lighthouse versions, so no code change here yet.
- `kona-presets`: (removed, always on). Gossipsub config now comes from Kona’s preset helper.
- `reth-peers`: always on. Reputation is keyed by reth `PeerId` when conversion succeeds; bans are
  mirrored to libp2p `PeerId`. Scoring still uses the local decay/threshold logic and falls back to
  the local store if conversion fails.
- Kona connection gater is always on and now consulted in the same dial path as reputation
  (`allow_dial`); NetworkConfig exposes minimal knobs (`gater_blocked_subnets`,
  `gater_peer_redialing`, `gater_dial_period`). Lighthouse-style gating remains blocked until a
  compatible crate is published.

## Using from taiko-client-rs (quickstart)

Add dependency:
```toml
[dependencies]
preconfirmation-types = { path = "packages/preconfirmation-p2p/crates/types" }
preconfirmation-service = { path = "packages/preconfirmation-p2p/crates/service" }
```

Key types: `NetworkConfig`, `NetworkCommand`, `NetworkEvent`, `P2pService`, and the SSZ message
types in `preconfirmation_p2p_types` (e.g., `SignedCommitment`, `RawTxListGossip`).

Feature switches:
- `reth-discovery`: use reth-discv5 wrapper for peer discovery (default on in p2p-net).
- `kona-presets`: (removed, always on).
- `kona-gater`: (removed, always on). Gossip scoring/gating is handled by Kona gossipsub; the
  local reputation backend focuses on request/response and dial behaviour.
- `real-transport-test`: the real TCP integration test now runs by default with retries; enable
  this feature only to disable the test in constrained environments.

## Future work
- Real TCP integration: stabilize the real-transport integration test so it can run by default
  (instead of being gated behind `real-transport-test`).

Typical flow:
1. Build a `NetworkConfig` (set listen/discovery, chain_id, reputation knobs as needed).
2. Start `P2pService::start(cfg)`; use `publish_*`/`request_*` helpers or send `NetworkCommand`s.
3. Receive `NetworkEvent`s via `next_event()` or `run_with_handler`.

### Operational knobs (CLI flags in `p2p-node`)
- `--listen-addr`, `--discv5-listen`, `--bootnode` (ENR): networking endpoints.
- `--chain-id`: select gossip topics/protocol IDs.
- `--no-discovery`: disable discv5.
- Reputation/DoS tuning:
  - `--reputation-greylist` (default -5.0), `--reputation-ban` (default -10.0),
  - `--reputation-halflife-secs` (default 600),
  - `--request-window-secs` (default 10), `--max-requests-per-window` (default 8).
  These feed `NetworkConfig` and drive score decay, greylist/ban, and req/resp rate limiting.

## Development

```bash
just fmt
just clippy
just test
```

## Status

- Networking and service layers are scaffolds; protocol logic, discovery wiring, and scoring are
  intentionally stubbed until the spec stabilises.
