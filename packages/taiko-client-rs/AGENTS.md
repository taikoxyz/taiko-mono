# Repository Guidelines

## Project Structure & Module Organization

- `bin/client/` hosts the CLI entry point (`abci`, `abci-genesis`); keep orchestration light and delegate protocol logic to the crates.
- `crates/abci` is the ABCI++ application of the Etna PoS chain (CometBFT + `taiko-client abci` + alethia-reth). Keep `envelope`, `rules`, `schedule` and `committee` free of I/O so they can later move unchanged into a no_std crate for the guest.
- `crates/protocol` and `crates/rpc` hold shared protocol helpers and the Engine API / JWT provider helpers. Document shared traits whenever exposing cross-crate APIs.
- `crates/protocol` is also consumed by raiko2 (pinned by git rev); keep the `shasta` modules and `FixedKSigner` it imports.
- `crates/bindings/` is kept only for protocol's anchor builder, which raiko2 uses. It is generated via `just gen_bindings` (Solidity sources in `../protocol`); never hand-edit or reformat files under `crates/bindings/src`.
- `crates/test-harness` boots docker devnets (anvil as L1, alethia-reth, CometBFT) through the docker CLI. The docker scenarios live in `crates/abci/tests/` and are marked `#[ignore = "docker"]`.
- `tests/` holds `tests/entrypoint.sh` (run by `just test`) and the test JWT secret `tests/docker/jwt.hex`.
- `script/` keeps repeatable maintenance scripts; extend them instead of duplicating ad-hoc helpers.

## Build, Test, and Development Commands

- `cargo build --workspace` (add `--release` for production binaries).
- `just fmt` installs toolchain `nightly-2025-09-27`, runs `cargo +nightly fmt`, then `cargo sort --workspace --grouped`. Use `just fmt-check` for CI parity.
- Always use `just fmt` (never call `cargo fmt` directly) so the nightly toolchain and `cargo sort` stay in sync with CI.
- `just clippy` runs two passes: library targets with doc lints, then `--all-targets` (tests and test-harness included) with `-D warnings`; reserve `just clippy-fix` for mechanical cleanups.
- `just gen_bindings` executes `script/gen_bindings.sh` to refresh contract bindings whenever ABIs change.
- After every code change run `just fmt && just clippy-fix` locally so the workspace stays formatted and lint-clean.
- Before declaring work complete, run the full verification sequence `just fmt && just clippy && just unit && just test` and require it to finish without warnings or errors.

## Coding Style & Naming Conventions

- Target MSRV 1.95 (`rust-version` in `Cargo.toml`).
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

- `just unit` runs only the unit tests (everything outside `tests/` dirs) with no docker — use it for fast iteration. Unit tests live next to the code (`#[cfg(test)] mod tests`); abci's shared builders live in `crates/abci/src/test_utils*`.
- `just test` runs the abci docker scenarios through `tests/entrypoint.sh`: it checks docker, pulls the anvil, alethia-reth and CometBFT images (override with `ANVIL_IMAGE`, `ALETHIA_RETH_IMAGE`, `COMETBFT_IMAGE`; `PULL_POLICY=missing` reuses local images) and runs the scenarios serially with the nextest `integration` profile, since each boots its own devnet. Extra args go to nextest, e.g. `just test restart` for one scenario.
- Name tests after observable behavior (e.g., `handles_invalid_proposal`). The harness prints every container's log tail when a scenario fails (panics, returns an error or times out waiting for a height) or its devnet fails to boot; keep that output for any failing integration case.
- Targeted verification is fine while iterating, but completion still requires a final full `just fmt && just clippy && just unit && just test` pass with clean output.

## Commit & Pull Request Guidelines

- Use Conventional Commit prefixes (`feat:`, `fix:`, `chore:`). Keep subject lines ≤72 characters with optional, meaningful scopes.
- PR descriptions must summarize impact, link issues, and include command output or screenshots for operator-facing flows.
- Confirm `just fmt && just clippy && just unit && just test` pass locally with no warnings or errors in the final verification run; call out any follow-up work explicitly.

## Security & Environment Notes

- Use only the ephemeral test keys bundled in the test harness and `tests/docker`; never commit real credentials or `.env` files.
- The docker scenarios publish ephemeral host ports and name every container and network `abci-<id>-…`; after an interrupted run remove leftovers with `docker ps -aq --filter 'name=^abci-' | xargs -r docker rm -f -v` and `docker network ls -q --filter 'name=^abci-' | xargs -r docker network rm` (as CI does; the quotes keep shells with extended globbing, such as zsh with `EXTENDED_GLOB`, from expanding the `^`).
