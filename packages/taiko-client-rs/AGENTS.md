# Repository Guidelines

## Project Structure & Module Organization

- `bin/client/` hosts the CLI entry point (`abci`, `abci-genesis`, `abci-committee-record`, `lander`); keep orchestration light and delegate protocol logic to the crates.
- `crates/abci` is the ABCI++ application of the Etna PoS chain (CometBFT + `taiko-client abci` + alethia-reth). Keep `envelope`, `rules`, `schedule`, `committee` and `forced` (the forced inclusion rule) free of I/O so they can later move unchanged into a no_std crate for the guest. The envelope is version 6; validators enforce forced inclusion and anchor freshness per block.
- `crates/lander` authenticates CometBFT batches and historical committee ancestry, builds V6 blobs and the twenty-one-word V1 statement, obtains a proof through a trait (dummy `0x00` only), and durably submits nonpayable `land(input, leaves, proof)`. Fees and payouts are not consensus inputs. Never replace an outstanding nonce automatically.
- `crates/protocol` holds shared protocol helpers (including Shasta manifest decoding for raiko2); `crates/rpc` holds the Engine API / JWT provider helpers. FI bytes are authenticated calldata from exact-block admission events. Document shared traits whenever exposing cross-crate APIs.
- `crates/protocol` is also consumed by raiko2 (pinned by git rev); keep the `shasta` modules and `FixedKSigner` it imports.
- `crates/bindings/` is kept only for protocol's anchor builder, which raiko2 uses. It is generated via `just gen_bindings` (Solidity sources in `../protocol`); never hand-edit or reformat files under `crates/bindings/src`.
- `crates/test-harness` boots docker devnets (anvil as L1, alethia-reth, CometBFT) through the docker CLI, with calldata admission fixtures. The Docker scenarios live in `crates/abci/tests/`, `crates/lander/tests/` and `bin/client/tests/` and are marked `#[ignore = "docker"]`.
- `tools/etna-signer` is a standalone Go 1.27.2 module pinned to stock CometBFT v0.40.0. It owns FilePV signing files outside Comet mounts and gates every signature with a fresh session-bound private trust query; PubKey/Ping remain ungated. Never implement signing cryptography, reset existing signing state or add a local validator fallback.
- `tests/` holds `tests/entrypoint.sh` (run by `just test`) and the test JWT secret `tests/docker/jwt.hex`.
- `script/` keeps repeatable maintenance scripts; extend them instead of duplicating ad-hoc helpers.

## Build, Test, and Development Commands

- `just signer` builds the host guarded signer; `just signer-test` runs its race tests. Docker test entrypoints build the helper before starting devnets. Production images package `/app/etna-signer`; use `script/start_etna_validator.sh` with existing external key/state paths for validators.
- `cargo build --workspace` (add `--release` for production binaries).
- `just fmt` installs toolchain `nightly-2025-09-27`, runs `cargo +nightly fmt`, then `cargo sort --workspace --grouped`. Use `just fmt-check` for CI parity.
- Always use `just fmt` (never call `cargo fmt` directly) so the nightly toolchain and `cargo sort` stay in sync with CI.
- `just clippy` runs two passes: library targets with doc lints, then `--all-targets` (tests and test-harness included) with `-D warnings`; reserve `just clippy-fix` for mechanical cleanups.
- `just gen_bindings` executes `script/gen_bindings.sh` to refresh contract bindings whenever ABIs change.
- After each coherent batch of code changes, run `just fmt && just clippy-fix` locally so the workspace stays formatted and lint-clean. Use targeted tests while iterating.
- Before declaring work complete, run `just verify` once on the final change batch and require it to finish without warnings or errors. It checks formatting, strict lint, fast tests, committed artifact reproduction and all Docker scenarios (`just test-full`).

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

- `just unit` runs unit tests plus the `native_cli` process tests with no docker, then protocol tests without default features and abci doctests — use it for fast iteration. It builds only those targets; without extra args, lander's lib tests run in one `cargo test` process so the KZG trusted setup loads once. Unit tests live next to the code (`#[cfg(test)] mod tests`); abci's shared builders live in `crates/abci/src/test_utils*`.
- `just test` runs the ABCI, lander and CLI Docker scenarios through `tests/entrypoint.sh`: it checks docker, pulls the anvil, alethia-reth and CometBFT images (override with `ANVIL_IMAGE`, `ALETHIA_RETH_IMAGE`, `COMETBFT_IMAGE`, `LANDER_ANVIL_IMAGE`; `PULL_POLICY=missing` reuses local images) and runs the scenarios serially with the nextest `integration` profile, since each boots its own devnet. Extra args go to nextest, e.g. `just test restart` for one scenario. It skips the slowest scenario (the L1 finality stall); `just test-full` runs all of them, as CI does on main, nightly and manual dispatch.
- Name tests after observable behavior (e.g., `handles_invalid_proposal`). The harness prints every container's log tail when a scenario fails (panics, returns an error or times out waiting for a height) or its devnet fails to boot; keep that output for any failing integration case.
- `just test-smoke` runs exactly four Docker scenarios: single-validator header rules, epoch switch, four-validator native consensus/direct fees/FI/epoch/landing/restart, and lander CLI SIGKILL/SIGTERM restarts. This fixed recipe accepts no arguments; use `just test` for targeted filters or output options. Smoke is for iteration and never replaces the full merge gate.
- Targeted verification is fine while iterating; completion requires one final `just verify` pass with clean output. Regenerate artifacts only when their inputs change; `just verify` always checks reproduction of the committed artifacts.

## Commit & Pull Request Guidelines

- Use Conventional Commit prefixes (`feat:`, `fix:`, `chore:`). Keep subject lines ≤72 characters with optional, meaningful scopes.
- PR descriptions must summarize impact, link issues, and include command output or screenshots for operator-facing flows.
- Confirm `just verify` passes locally with no warnings or errors in the final verification run; call out any follow-up work explicitly.

## Security & Environment Notes

- Use only the ephemeral test keys bundled in the test harness and `tests/docker`; never commit real credentials or `.env` files.
- Docker scenarios publish ephemeral RPC ports on loopback and name resources `abci-<id>-…` or `lander-<id>-…`. The harness cleans process-owned resources on SIGINT/SIGTERM; the entrypoint and CI also clean only the `taiko-client-rs.test-run` label for their run. For manual cleanup, filter that exact run label so other devnets are preserved.

- The protocol rules live in the [Etna PoS ZK Design Spec](https://app.notion.com/p/taikoxyz/Etna-PoS-ZK-Design-Spec-3fe9673143d6817a9f0fdaaf1b965d7a); the README's Fresh deployment section names the pinned protocol and alethia-reth commits. Do not restate spec constants here or in comments; cite the spec section.
- Regenerate contract fixtures and shared vectors with `script/gen_lander_artifacts.sh` (its `PINNED_REVISION` is the protocol revision), and the test-only InboxSetter, ZkGasFixture and FeeRoutingFixture artifacts with `script/gen_test_harness_artifacts.sh`. Run each generator twice for reproducibility; never hand-edit generated artifacts.
- Never migrate or rewrite signed journals or persisted app state; reject other structural formats explicitly. Keep both lander sidecar modes, the complete committee snapshot, overflow, quorum and duplicate-key checks with the 301-member regression, `--engine.allow-unwind-canonical-header` disabled, and Shasta's shared helpers and `FixedKSigner` behavior. Missing execution history is retryable and non-consuming where classified as unavailable; generic RPC errors do not prove pruning.

- Every validator harness/runtime startup must set `priv_validator_laddr` and use the guarded
  signer with the actual private key outside the Comet home/mount. Preserve FilePV state and
  Comet WAL on restart; only ephemeral test initialization creates signing files. Every new
  Comet transport begins a closed opaque trust session; app-only restart invalidates it.
  Unavailable trust control denies signatures and leaves signing state unchanged. Stop/reap
  Comet before stopping the signer and app. Full nodes use an unregistered local identity.
- Etna readiness is app `/trust` or `/status`, distinct from stock Comet `catching_up` and raw
  EL/Comet progress. Public RPC output needs its own readiness gate; do not claim an atomic
  cross-process revocation for a signing request authorized just before an app crash.

- Supported validator images include Python 3.11+, the pinned unmodified Comet binary and the
  guarded signer. Run `python3 /app/script/etna_validator.py` separately from the app using
  shared private/persistent mounts. Private `observe` is nonmutating, never authorization;
  signer event sequence zero establishes session identity and positive sequences record
  denial/timeout. Stock Comet never retries a refused request, so recovery waits for private
  trust, restarts only the signer with `--await-trust` (it connects to Comet once its fresh
  session is Ready), then starts Comet, whose WAL replay re-requests the refused step. First
  starts run the signer without that flag together with Comet.
  Terminal trust/domain failures durably latch and quiesce across restartAlways restarts.
  Include `just supervisor-test` in the full verification gate.
