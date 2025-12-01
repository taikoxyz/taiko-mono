# Repository Guidelines

## Project Structure & Module Organization
- Root package: `preconfirmation-p2p` (library-only).
- Crates:
  - `crates/types`: Spec-driven SSZ types, hashing/signing/validation helpers.
  - `crates/net`: libp2p + discv5 networking, reputation, discovery, behaviours, tests.
  - `crates/service`: Async façade over the network driver; examples in `crates/service/examples/`.
- Key docs: `README.md`, `ARCHITECTURE.md`, `AGENTS.md`.

## Build, Test, and Development Commands
- Format/lint: `just fmt`, `just clippy` (uses rustfmt/clippy; keep edits minimal).
- Checks/tests:
  - `cargo check`
  - `cargo test -p preconfirmation-types`
  - `cargo test -p preconfirmation-net`
- `cargo test -p preconfirmation-net`
- `cargo test -p preconfirmation-net --features reth-peers`
  - `cargo test -p preconfirmation-service`
- Real TCP integration test runs by default with retries; use feature `real-transport-test` only to disable it in constrained environments.

## Coding Style & Naming Conventions
- Rust 2024; prefer module-level docs (`//!`) and `///` on public items.
- Keep code ASCII; add concise comments only where non-obvious.
- Config/command/event naming pattern: `NetworkConfig`, `NetworkCommand`, `NetworkEvent`.
- Tracing/metrics follow taiko-client-rs style.

## Testing Guidelines
- Unit tests live with code; `net` includes integration-style gossipsub + req/resp tests.
- SSZ/crypto validation in `types`; keep fixtures minimal.
- Run the feature matrix above when touching networking features.

## Commit & Pull Request Guidelines
- Commit messages: short, imperative (e.g., "Add head update command").
- PRs: include summary, affected features, and test commands run; link issues when applicable.

## Architecture & Extensibility
- Upstream reuse via features: `reth-discovery` (discv5) and `reth-peers` (reth peer-id backend). Kona presets and gater are always on.
- Reputation is pluggable via `ReputationBackend`; default remains the local store. Real TCP test is default-on with retries.
