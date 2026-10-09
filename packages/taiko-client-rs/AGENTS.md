# Repository Guidelines

## Project Structure & Module Organization

- `bin/client/` hosts the CLI entry point; keep orchestration light and delegate protocol logic to the crates.
- `crates/protocol` and `crates/rpc` cover the core services. Document shared traits whenever exposing cross-crate APIs.
- `crates/protocol` is also consumed by raiko2 (pinned by git rev); keep the `shasta` modules and `FixedKSigner` it imports.
- `crates/bindings/` is generated via `just gen_bindings`; never hand-edit or reformat files under `crates/bindings/src`.
- The entire `bindings` crate is auto-generated; do not modify any files there manually. The Solidity sources live in `../protocol`.
- `tests/` contains Docker-backed integration assets run through `tests/entrypoint.sh`. Place every end-to-end scenario here and note any extra prerequisites.
- `script/` keeps repeatable maintenance scripts; extend them instead of duplicating ad-hoc helpers.

## Build, Test, and Development Commands

- `cargo build --workspace` (add `--release` for production binaries).
- `just fmt` installs toolchain `nightly-2025-09-27`, runs `cargo +nightly fmt`, then `cargo sort --workspace --grouped`. Use `just fmt-check` for CI parity.
- Always use `just fmt` (never call `cargo fmt` directly) so the nightly toolchain and `cargo sort` stay in sync with CI.
- `just clippy` runs two passes: library targets with doc lints, then `--all-targets` (tests and test-harness included) with `-D warnings`; reserve `just clippy-fix` for mechanical cleanups.
- `just gen_bindings` executes `script/gen_bindings.sh` to refresh contract bindings whenever ABIs change.
- After every code change run `just fmt && just clippy-fix` locally so the workspace stays formatted and lint-clean.
- Before declaring work complete, run the full verification sequence `just fmt && just clippy-fix && just test` and require it to finish without warnings or errors.

## Coding Style & Naming Conventions

- Target MSRV 1.88 and gate newer features with `#[cfg]` as needed.
- Follow idiomatic Rust naming: snake_case for modules and functions, PascalCase for types, `SCREAMING_SNAKE_CASE` for constants. Prefer explicit `pub(crate)` boundaries.
- Respect the shared `rustfmt.toml` and rely on `just fmt`; never bulk-format `crates/bindings/src`. Document intentional deviations with a brief comment.
- Never add `#[allow(clippy::too_many_arguments)]` (including crate/module-level forms). When a function exceeds argument limits, introduce a named params struct and update call sites to pass that struct.

## Documentation Policy (Mandatory)

- Every non-test production Rust symbol must be documented with Rust doc comments (`//!` or `///`), including modules, structs/enums/traits, fields, constants/statics, type aliases, functions/methods, and associated items in `impl` blocks.
- Trait-implementation methods must also be documented (for example `Display::fmt`, `From::from`, `Default::default`, and `TryFrom::try_from`), even when rustdoc/clippy does not enforce them automatically.
- Comments must explain purpose and contract, not restate identifiers. Include units/invariants for fields and side effects or error semantics where relevant.
- Exclusions:
  - `crates/bindings/**` (generated code; never hand-edit)
  - `crates/test-harness/**`
  - files under `tests/**`
  - `#[cfg(test)]` items and test-only helpers
  - examples
- The docs gate is required before completion: run `just clippy`.

## Testing Guidelines

- Always run integration tests via `just test`; it launches the Dockerized L1/L2 stack and executes `cargo nextest`.
- `just unit` runs only the unit tests (everything outside `tests/` dirs) with no docker stack or contract deploy — use it for fast iteration.
- To scope to a single Rust crate, set `TEST_CRATE=<crate-name>` when invoking `just test`; leaving it unset runs the full workspace (default).
- Name tests after observable behavior (e.g., `handles_invalid_proposal`) and capture container logs for any failing integration case.
- Targeted verification is fine while iterating, but completion still requires a final full `just fmt && just clippy-fix && just test` pass with clean output.

## Commit & Pull Request Guidelines

- Use Conventional Commit prefixes (`feat:`, `fix:`, `chore:`). Keep subject lines ≤72 characters with optional, meaningful scopes.
- PR descriptions must summarize impact, link issues, and include command output or screenshots for operator-facing flows.
- Confirm `just fmt && just clippy-fix && just test` pass locally with no warnings or errors in the final verification run; call out any follow-up work explicitly.

## Security & Environment Notes

- Use only the ephemeral test keys bundled in scripts; never commit real credentials or `.env` files.
- Ensure ports `18545` and `28545-28551` are free before running integration tests, and document deviations in your PR.
