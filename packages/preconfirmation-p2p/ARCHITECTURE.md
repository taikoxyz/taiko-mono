# preconfirmation-p2p architecture & usage

This crate group is a library-only scaffold for the Taiko preconfirmation P2P layer. It mirrors
`taiko-client-rs` style and leans on upstream P2P building blocks instead of reimplementing them.

## Crate roles

- `crates/types`: Spec-driven SSZ message types (gossip + req/resp), topic/protocol helpers,
  and crypto/validation utilities (domain-prefixed SSZ hashing, secp256k1 signing/recovery).
- `crates/net`: libp2p transport + behaviours (ping, identify, gossipsub, request/response),
  discovery scaffold (reth-discv5-backed), basic reputation + rate limiting, and the driver/handle
  API: `NetworkConfig`, `NetworkCommand`, `NetworkEvent`, `NetworkDriver`, `NetworkHandle`.
- `crates/service`: Async façade that owns the driver, spawns it on tokio, and exposes a small
  channel-based API (`publish_*`, `request_*`, `next_event`, `run_with_handler`). Examples live
  under `crates/service/examples/` (no binaries are installed).

## Upstream reuse (how pieces fit)

- **libp2p** (0.56.x): transport, gossipsub, request/response (now varint-framed per spec), ping,
  identify, allow/block list, connection limits.
- **reth-discv5** (tag `v1.9.3`, feature `reth-discovery`): discovery wrapper; reused to avoid
  custom ENR/UDP wiring.
- **Kona gossipsub presets** (tag `kona-client/v1.2.4`, always on): mesh/score defaults +
  heartbeat; we override only spec-required bits (max transmit size, validation mode).
- **Reputation via reth**: `ReputationChangeWeights` defaults come from reth; `RethReputationAdapter`
  mirrors bans to libp2p IDs, falling back to the local store on ID conversion failure.
- **Kona connection gater**: dial path first consults Kona gater (blocked subnets/redial limits),
  then local reputation; knobs exposed on `NetworkConfig`.
- **Rate limiting**: per-peer/per-protocol token bucket built on `reth-tokio-util` (upstream),
  replacing the old fixed window limiter.
- **Presets**: discovery presets (dev/test/prod) adjust discv5 lookup cadence; connection presets
  (dev/test/prod) set pending/established caps and dial concurrency (prod defaults: pending 40/40,
  established 110/110, total 220, dial factor 16). Event fanout uses broadcast so handlers, blocking
  helpers, and `next_event` can run concurrently.

## Feature flags

- `reth-discovery` (default on): enable discovery via `reth-discv5` wrapper.
- `kona-presets`: always on (Kona gossipsub mesh/score presets).
- `kona-gater`: always on (Kona connection gater reused in dial/ban path).
- `real-transport-test`: real TCP integration test now runs by default with retries; use this
  feature only to disable it in constrained environments. In-memory transport tests always run.
- Lighthouse-style peer scoring/gating: blocked (no published crate compatible with libp2p 0.56).

Note: Reth peer-id keyed reputation is always enabled and is the sole backend; it mirrors bans to
libp2p `PeerId` while using reth weights/thresholds for scoring. IP colocation protection today
relies on libp2p connection limits (per-peer/incoming caps) plus request limiting; Lighthouse-style
gating/scoring remains blocked until upstream publishes a compatible crate/API for libp2p 0.56.

## Protocol details (current implementation)

- Gossip: Kona gossipsub presets with max transmit size = `preconfirmation_types::MAX_GOSSIP_SIZE_BYTES`.
- Req/Resp: SSZ payloads framed with unsigned-varint length (libp2p style), protocol IDs from
  `preconfirmation_types`, per-message size caps enforced in codecs.
- Rate limits: fixed (tumbling) per-peer window (`NetworkConfig.request_window` and
  `max_requests_per_window`), rate-limit errors surface as NetworkEvent errors and reputation
  timeouts.

## Typical usage flow

1. Build a `NetworkConfig` (listen/discovery/reputation knobs, chain_id for topics/protocol IDs).
   The driver binds the libp2p swarm to `listen_addr` automatically; use port `0` for an ephemeral
   bind.
2. Start `P2pService::start(config)`; keep the returned command sender and subscribe to events as needed.
3. Publish via `NetworkCommand::Publish*` or helper methods; request via `NetworkCommand::Request*`.
4. Consume the `NetworkEvent` stream via `next_event`, `run_with_handler`, or your own subscription.

## Operations / Tuning (quick reference)

- Metrics to watch:
  - `p2p_reqresp_rtt_seconds{protocol,outcome}`, `p2p_reqresp_error`, `p2p_reqresp_rate_limited`.
  - `p2p_discovery_event{kind=lookup_success|lookup_failure}`, `p2p_discovery_lookup_latency_seconds{outcome}`.
  - `p2p_conn_rejected_total`, `p2p_dial_throttled_total` for limit hits; `p2p_conn_error` for other transport errors.
- Config knobs (all on `NetworkConfig`):
  - Rate limit: `request_window`, `max_requests_per_window` (per-peer fixed window).
  - Size caps: enforced in `preconfirmation_types` (txlist, commitments, head) and codecs.
  - Connection caps: `max_pending_{in,out}`, `max_established_{in,out,total,per_peer}`.
  - Kona gater: `gater_blocked_subnets`, `gater_peer_redialing`, `gater_dial_period`.
- Typical failure modes & reactions:
  - Many `reqresp_validation` / gossip invalid: inspect payloads/logs; tighten size caps or reject offending peers; check producer correctness.
  - Frequent `reqresp_rate_limited`: raise window/count if benign load, or leave as-is to throttle abuse.
  - Dial blocks (`kona_gater`/`reputation`/`missing_peer_id`): verify bootnodes/addrs, adjust blocked subnets or redial limits; ensure peer IDs are included in multiaddrs.
  - Timeouts: check `request_timeout`, network connectivity, and peer availability; consider increasing timeout conservatively.
