# Repository Guidelines

## Project Structure & Module Organization

- `bin/client/` hosts the CLI entry point; keep orchestration light and delegate protocol logic to the crates.
- `crates/preconfirmation-node/` contains the P2P client, gossip handlers, storage, and sync flows.
- `crates/protocol`, `crates/proposer`, `crates/driver`, `crates/event-indexer`, and `crates/rpc` cover the core services. Document shared traits whenever exposing cross-crate APIs.
- `crates/bindings/` is generated via `just gen_bindings`; never hand-edit or reformat files under `crates/bindings/src`.
- The entire `bindings` crate is auto-generated; do not modify any files there manually.
- `tests/` contains Docker-backed integration assets run through `tests/entrypoint.sh`. Place every end-to-end scenario here and note any extra prerequisites.
- `script/` keeps repeatable maintenance scripts; extend them instead of duplicating ad-hoc helpers.

## Build, Test, and Development Commands

- `cargo build --workspace` (add `--release` for production binaries).
- `just fmt` installs toolchain `nightly-2025-09-27`, runs `cargo +nightly fmt`, then `cargo sort --workspace --grouped`. Use `just fmt-check` for CI parity.
- Always use `just fmt` (never call `cargo fmt` directly) so the nightly toolchain and `cargo sort` stay in sync with CI.
- `just clippy` maps to `cargo clippy --workspace --all-features --no-deps --exclude bindings -- -D warnings`; reserve `just clippy-fix` for mechanical cleanups.
- `just gen_bindings` executes `script/gen_bindings.sh` to refresh contract bindings whenever ABIs change.
- After every code change run `just fmt && just clippy-fix` locally so the workspace stays formatted and lint-clean.

## Coding Style & Naming Conventions

- Target MSRV 1.88 and gate newer features with `#[cfg]` as needed.
- Follow idiomatic Rust naming: snake_case for modules and functions, PascalCase for types, `SCREAMING_SNAKE_CASE` for constants. Prefer explicit `pub(crate)` boundaries.
- Respect the shared `rustfmt.toml` and rely on `just fmt`; never bulk-format `crates/bindings/src`. Document intentional deviations with a brief comment.

## Testing Guidelines

- Always run tests via `just test`; it launches the Dockerized L1/L2 stack and executes `cargo nextest`.
- To scope to a single Rust crate, set `TEST_CRATE=<crate-name>` when invoking `just test`; leaving it unset runs the full workspace (default).
- Name tests after observable behavior (e.g., `handles_invalid_proposal`) and capture container logs for any failing integration case.

## Event Scanner Integration

- Build `EventScanner` instances via `SubscriptionSource::to_provider()` and `EventScannerBuilder::connect` to avoid transport-specific helpers that no longer exist upstream.
- When syncing from a block/tag or from latest events, call `EventScannerBuilder::sync().from_block(...)` or `.from_latest(...)` and immediately `.connect(provider)` returned from the subscription source.
- Lookahead preconfirmation is split into `client`, `resolver`, `scanner`; use `LookaheadResolver::new` for the common path or `new_with_genesis` for custom/unknown chains. A default resolver type alias is exposed for the common provider stack.
- Solidity contracts for the bindings live in `../protocol` (relative to `crates/bindings`); consult them to mirror on-chain logic.

## Commit & Pull Request Guidelines

- Use Conventional Commit prefixes (`feat:`, `fix:`, `chore:`). Keep subject lines ≤72 characters with optional, meaningful scopes.
- PR descriptions must summarize impact, link issues, and include command output or screenshots for operator-facing flows.
- Confirm `just fmt`, `just clippy`, and `just test` pass locally; call out any follow-up work explicitly.

## Security & Environment Notes

- Use only the ephemeral test keys bundled in scripts; never commit real credentials or `.env` files.
- Ensure ports `18545` and `28545-28551` are free before running integration tests, and document deviations in your PR.
