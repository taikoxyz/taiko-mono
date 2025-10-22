# Repository Guidelines

## Project Structure & Module Organization
- `bin/client/` hosts the CLI entry point; keep orchestration light and delegate protocol logic to the crates.
- `crates/protocol`, `crates/proposer`, `crates/driver`, `crates/event-indexer`, and `crates/rpc` cover the core services. Document shared traits whenever exposing cross-crate APIs.
- `crates/bindings/` is generated via `just gen_bindings`; never hand-edit or reformat files under `crates/bindings/src` (agents should treat this directory as read-only).
- `tests/` contains Docker-backed integration assets run through `tests/entrypoint.sh`. Place every end-to-end scenario here and note any extra prerequisites.
- `script/` keeps repeatable maintenance scripts; extend them instead of duplicating ad-hoc helpers.

## Build, Test, and Development Commands
- `cargo build --workspace` (add `--release` for production binaries).
- `just fmt` installs toolchain `nightly-2025-09-27`, runs `cargo +nightly fmt`, then `cargo sort --workspace --grouped`. Use `just fmt-check` for CI parity.
- `just clippy` maps to `cargo clippy --workspace --all-features --no-deps --exclude bindings -- -D warnings`; reserve `just clippy-fix` for mechanical cleanups.
- `just gen_bindings` executes `script/gen_bindings.sh` to refresh contract bindings whenever ABIs change.

## Coding Style & Naming Conventions
- Target MSRV 1.88 and gate newer features with `#[cfg]` as needed.
- Follow idiomatic Rust naming: snake_case for modules and functions, PascalCase for types, `SCREAMING_SNAKE_CASE` for constants. Prefer explicit `pub(crate)` boundaries.
- Respect the shared `rustfmt.toml`; never bulk-format `crates/bindings/src`. Document intentional deviations with a brief comment.

## Testing Guidelines
- Run `just test` before submitting changes; it launches the Dockerized L1/L2 stack and executes `cargo nextest` across the workspace.
- For focused suites, use `cargo nextest run -p <crate> --all-features` after exporting required RPC endpoints.
- Name tests after observable behavior (e.g., `handles_invalid_proposal`) and capture container logs for any failing integration case.

## Commit & Pull Request Guidelines
- Use Conventional Commit prefixes (`feat:`, `fix:`, `chore:`). Keep subject lines ≤72 characters with optional, meaningful scopes.
- PR descriptions must summarize impact, link issues, and include command output or screenshots for operator-facing flows.
- Confirm `just fmt`, `just clippy`, and `just test` pass locally; call out any follow-up work explicitly.

## Security & Environment Notes
- Use only the ephemeral test keys bundled in scripts; never commit real credentials or `.env` files.
- Ensure ports `18545` and `28545-28551` are free before running integration tests, and document deviations in your PR.
