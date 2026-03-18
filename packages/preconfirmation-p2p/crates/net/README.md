# preconfirmation-net

libp2p + discv5 networking layer for Taiko preconfirmation P2P. It wires gossip and req/resp, adds reputation + per-peer rate limiting, and integrates Kona’s gating and connection limits.

## What to read first
- `src/lib.rs`: crate surface and re-exports.
- `src/config.rs`: `P2pConfig` (user-facing) plus internal knobs (listen/discv5, reputation, rate
  limits, gater).
- `src/codec.rs`: SSZ codecs for req/resp (varint-framed, per spec IDs).
- `src/behaviour.rs`: combined libp2p behaviour (gossipsub, request-response, ping/identify, gating).
- `src/driver/mod.rs`: `NetworkDriver` command/event loop, handlers for gossip and req/resp.
- `src/reputation.rs`: scoring, bans/greylists, per-peer rate limiter.

## Data flow (high level)
- Commands/events: the driver owns the swarm; callers use `P2pNode` + `P2pHandle` or send `NetworkCommand`
  and receive `NetworkEvent` directly.
- Gossip: topics built from `preconfirmation_types::topic_*` for commitments and raw txlists.
- Req/Resp: protocol IDs from `preconfirmation_types::protocol_get_*`; SSZ + libp2p varint framing with per-message size caps; handlers in `driver.rs` with validation + rate/reputation checks.
- Gating/DoS: Kona gater for dial decisions (subnet/redial limits), per-peer req/resp rate limit, reputation decay/ban/greylist (reth weights), txlist size caps.

## Spec & integration
- Protocol spec: `docs/specification.md` (authoritative P2P specification).
- Typical integration: use `P2pNode` + `P2pHandle` (see `crates/net/examples/p2p-node.rs`).

## Testing
- Unit + integration: `cargo test -p preconfirmation-net` (includes memory-transport and real TCP tests with retries).
- Default real TCP test runs; if needed in constrained environments, see crate docs/feature notes for disabling.
