# Repository Guidelines

## Project Structure & Module Organization
- Root package: `preconfirmation-p2p` (library-only).
- Crates:
  - `crates/types`: Spec-driven SSZ message types (gossip + req/resp, incl. `get_head`), topic/protocol
    helpers, size caps, hashing/signing, validation.
  - `crates/net`: libp2p transport + behaviours (ping/identify/gossipsub/req-resp), discv5 discovery,
    reth-backed reputation, Kona presets/gater, connection limits, request rate limiting, tests.
- Key docs: `README.md`, `ARCHITECTURE.md`, `AGENTS.md`, `docs/specification.md` (authoritative P2P
  protocol spec covering topics/IDs, varint framing, size/rate limits, and `get_head`).

## Build, Test, and Development Commands
- Format/lint: `just fmt`, `just fmt-check`, `just clippy` (fmt uses nightly toolchain + cargo sort).
- Checks/tests:
  - `cargo check`
  - `just test` (cargo nextest, workspace + all features)
  - `cargo test -p preconfirmation-types|preconfirmation-net`

## Coding Style & Naming Conventions
- Rust 2024; prefer module-level docs (`//!`) and `///` on public items.
- Keep code ASCII; add concise comments only where non-obvious.
- Config/command/event naming pattern: `P2pConfig`, `NetworkCommand`, `NetworkEvent`.
- Tracing/metrics follow taiko-client-rs style.

## Testing Guidelines
- Unit tests live with code; `net` includes integration-style gossipsub + req/resp tests.
- SSZ/crypto validation in `types`; keep fixtures minimal.
- Real TCP integration test runs by default with retries; use feature `real-transport-test` only to
  disable it in constrained environments.
- Run the feature matrix above when touching networking features.

## Commit & Pull Request Guidelines
- Commit messages: short, imperative (e.g., "Add head update command").
- PRs: include summary, affected features, and test commands run; link issues when applicable.

## Architecture & Extensibility
- Upstream reuse via features: `reth-discovery` (discv5, default on). Reth peer-id keyed backend is
  always on and is the sole reputation backend; it mirrors bans/greylist to libp2p `PeerId` and the
  Kona gater.
- Kona gossipsub presets and connection gater are always on; advanced gater tuning remains
  internal, while `P2pConfig` stays the user-facing surface.
- Request rate limiting uses reth's token-bucket limiter (per peer/per protocol) wired through
  `request_window` and `max_requests_per_window`.
- Connection caps and dial concurrency are configured directly; size caps + protocol IDs live in
  `preconfirmation-types` and codecs.
- Req/resp protocols cover commitments, raw txlists, and head; framing is libp2p unsigned-varint SSZ.
- Lighthouse-style scoring/gating reuse remains blocked until a published crate matches our
  libp2p version.
