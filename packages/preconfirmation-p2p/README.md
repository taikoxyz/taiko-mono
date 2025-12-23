# preconfirmation-p2p

Project for the Taiko permissionless preconfirmation P2P layer (libp2p + discv5, SSZ messages).

## Layout (work in progress)

- `crates/types`: Spec-driven SSZ types and helpers (hashing/signing/validation). Provides
  topic/protocol ID helpers used by the network.
- `crates/net`: libp2p transport + behaviours (ping, identify, gossipsub, req/resp) and
  scaffolds for discovery (`discovery`, now backed by `reth-discv5` behind the `reth-discovery`
  feature) and peer reputation. Kona gossipsub presets + connection gater are always applied;
  req/resp uses SSZ with libp2p varint framing and per-message size caps. Public API:
  `NetworkConfig`, `NetworkCommand` (publish/request), `NetworkEvent` (gossip/req-resp/lifecycle),
  `NetworkDriver`/`NetworkHandle`.
- `crates/service`: Async façade owning the network driver. Exposes a small channel-based API:
  `P2pService::start(cfg, lookahead)` -> command sender + event stream; `shutdown()` for graceful stop.
- `crates/service/examples/p2p-node.rs`: Minimal CLI example that starts the service and logs
  network events (replaces the previous standalone `bin/p2p-node`).
- `docs/specification.md`: Authoritative specification for the permissionless preconfirmation P2P protocol.

## API mapping to the preconfirmation spec

- Gossip topics: SignedCommitment, RawTxListGossip (from `p2p-types` helpers).
- Req/Resp protocols: GetCommitmentsByNumber, GetRawTxList (SSZ over libp2p request-response).
- Commands: publish commitments/raw txlists; send commitment range or raw-txlist requests.
- Events: peer connect/disconnect, inbound gossip, req/resp responses, inbound requests, lifecycle.
- Discovery/reputation: discovery uses `reth-discv5` under the hood; reputation has basic scoring,
  block-list enforcement, and metrics with room to tune/extend.

## Upstream reuse and compatibility

- Discovery is backed by `reth-discv5` (git tag `v1.9.3`) behind the `reth-discovery` feature.
- Gossip and gating reuse Kona (`kona-client/v1.2.4`): gossipsub presets (mesh/score/heartbeat,
  max transmit size tied to `preconfirmation_types::MAX_GOSSIP_SIZE_BYTES`) and the connection
  gater (blocked subnets/redial limits).
- Reputation weights come from reth (`ReputationChangeWeights`); scoring and gating run through a
  single libp2p-keyed reputation store that enforces the libp2p block list and Kona gater.
- Req/resp: SSZ messages framed with libp2p unsigned-varint lengths, protocol IDs and size caps
  from `preconfirmation_types`; per-peer fixed-window rate limiting lives in `NetworkConfig`.
- This package is library-only; runnable smoke testing lives in `crates/service/examples/p2p-node.rs`.

## Reputation & Scoring

- Default: local `PeerReputationStore` with decay/thresholds, libp2p block-list enforcement, and
  rate limiting (no alternate adapters).
- Upstream request-rate limiter swap: still local; no compatible upstream rate-limit module is
  published for our libp2p/reth/Lighthouse versions, so no code change here yet.
- `kona-presets`: (removed, always on). Gossipsub config now comes from Kona’s preset helper.
- Single-path reputation keyed by libp2p `PeerId` using reth weights/thresholds; bans wire into the
  libp2p block list and Kona gater.
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
- Req/resp rate limiting now uses upstream `reth-tokio-util` token buckets (per-peer, per-protocol).
- Discovery presets (dev/test/prod) tune discv5 lookup cadence; connection presets (dev/test/prod)
  set pending/established caps and dial concurrency.
- `real-transport-test`: the real TCP integration test now runs by default with retries; enable
  this feature only to disable the test in constrained environments.

Typical flow:

1. Build a `NetworkConfig` (set listen/discovery, chain_id, reputation knobs as needed). The
   driver now binds the libp2p swarm to `listen_addr` automatically; use port `0` to request an
   ephemeral port.
2. Start `P2pService::start(cfg, lookahead)`; use `publish_*`/`request_*` helpers or send `NetworkCommand`s.
3. Receive `NetworkEvent`s via `next_event()`, `run_with_handler`, or a custom `subscribe()`d
   receiver (events are fanned out internally so multiple consumers are safe).

### Operational knobs (CLI flags in `p2p-node`)

- `--listen-addr`, `--discv5-listen`, `--bootnode` (ENR): networking endpoints.
- `--chain-id`: select gossip topics/protocol IDs.
- `--no-discovery`: disable discv5.
- `--expected-signer`: expected preconfer address for schedule validation.
- Reputation/DoS tuning:
  - `--reputation-greylist` (default -5.0), `--reputation-ban` (default -10.0),
  - `--reputation-halflife-secs` (default 600),
  - `--request-window-secs` (default 10), `--max-requests-per-window` (default 8).
    These feed `NetworkConfig` and drive score decay, greylist/ban, and req/resp rate limiting.
- Discovery/connection presets:
  - `discovery_preset` and `connection_preset` (dev/test/prod) adjust discv5 lookup intervals,
    pending/established caps, and dial concurrency (prod defaults: pending 40/40, established
    110/110, total 220, dial factor 16).
- Metrics of interest:
  - `p2p_reqresp_rtt_seconds{protocol,outcome}` (success|timeout|error)
  - `p2p_reqresp_rate_limited`, `p2p_reqresp_error` counters
  - `p2p_discovery_event{kind=lookup_success|lookup_failure}` and
    `p2p_discovery_lookup_latency_seconds{outcome}`
  - `p2p_conn_rejected_total`, `p2p_dial_throttled_total`

## Development

```bash
just fmt
just clippy
just test
```
