# Repository Guidelines

## Project Structure & Module Organization

- `bin/client/` hosts the CLI entry point (`abci`, `abci-genesis`, `abci-committee-record`, `lander`); keep orchestration light and delegate protocol logic to the crates.
- `crates/abci` is the ABCI++ application of the Etna PoS chain (CometBFT + `taiko-client abci` + alethia-reth). Keep `envelope`, `rules`, `schedule`, `committee` and `forced` (the forced inclusion rule) free of I/O so they can later move unchanged into a no_std crate for the guest. The envelope is version 6; validators enforce forced inclusion and anchor freshness per block.
- `crates/lander` authenticates CometBFT batches and historical committee ancestry, builds V6 blobs and the twenty-one-word V10 statement, obtains a proof through a trait (dummy `0x00` only), and durably submits nonpayable `land(input, proof)`. The independent `lander-claim` command authenticates receipt proofs and journals one immutable L2 transaction. Never replace an outstanding nonce automatically.
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

- `just unit` runs unit tests plus all nine `lander_claim_cli` process tests with no docker, then protocol tests without default features and abci doctests — use it for fast iteration. It builds only those targets; without extra args, lander's lib tests run in one `cargo test` process so the KZG trusted setup loads once. Unit tests live next to the code (`#[cfg(test)] mod tests`); abci's shared builders live in `crates/abci/src/test_utils*`.
- `just test` runs the ABCI, lander and CLI Docker scenarios through `tests/entrypoint.sh`: it checks docker, pulls the anvil, alethia-reth and CometBFT images (override with `ANVIL_IMAGE`, `ALETHIA_RETH_IMAGE`, `COMETBFT_IMAGE`, `LANDER_ANVIL_IMAGE`; `PULL_POLICY=missing` reuses local images) and runs the scenarios serially with the nextest `integration` profile, since each boots its own devnet. Extra args go to nextest, e.g. `just test restart` for one scenario. It skips the two slowest scenarios (L1 finality stall, anchor finality gate); `just test-full` runs all of them, as CI does on main, nightly and manual dispatch.
- Name tests after observable behavior (e.g., `handles_invalid_proposal`). The harness prints every container's log tail when a scenario fails (panics, returns an error or times out waiting for a height) or its devnet fails to boot; keep that output for any failing integration case.
- `just test-smoke` runs exactly four Docker scenarios: single-validator header rules, epoch switch, real L2 rewards claim/fee continuation, and lander CLI SIGKILL/SIGTERM restarts. This fixed recipe accepts no arguments; use `just test` for targeted filters or output options. Smoke is for iteration and never replaces the full merge gate.
- Targeted verification is fine while iterating; completion requires one final `just verify` pass with clean output. Regenerate artifacts only when their inputs change; `just verify` always checks reproduction of the committed artifacts.

## Commit & Pull Request Guidelines

- Use Conventional Commit prefixes (`feat:`, `fix:`, `chore:`). Keep subject lines ≤72 characters with optional, meaningful scopes.
- PR descriptions must summarize impact, link issues, and include command output or screenshots for operator-facing flows.
- Confirm `just verify` passes locally with no warnings or errors in the final verification run; call out any follow-up work explicitly.

## Security & Environment Notes

- Use only the ephemeral test keys bundled in the test harness and `tests/docker`; never commit real credentials or `.env` files.
- Docker scenarios publish ephemeral RPC ports on loopback and name resources `abci-<id>-…` or `lander-<id>-…`. The harness cleans process-owned resources on SIGINT/SIGTERM; the entrypoint and CI also clean only the `taiko-client-rs.test-run` label for their run. For manual cleanup, filter that exact run label so other devnets are preserved.

- Lander real-contract fixtures (including the immutable `L2FeeVault`) pin protocol commit `d9493c0c05260dd34573c951138bc95695450b84`, the same as `PROTOCOL_REVISION`. Regenerate with `script/gen_lander_artifacts.sh`, which also copies the shared Etna vectors (`testdata/etna_vectors`); generated artifact and vector hashes and compiler provenance are unit-tested, and `just check-lander-artifacts` checks that regeneration reproduces the committed files. Real-contract tests use `LANDER_ANVIL_IMAGE` (Foundry v1.8.5); existing ABCI tests retain their independent Anvil pin.

- FI preimages are carried in private consensus envelopes only for skips; ordinary and included proposals carry an empty witness tx field. Inclusion authenticates the canonical first transaction against the proven hash; due skips still authenticate even an empty preimage. Nonempty legacy preimages remain hash-checked.
- Calldata FI requires no beacon flags, blob fetches or KZG warmup. Preserve lander batch blobs and both sidecar modes. The lander requires authenticated Engine/JWT access for historical singleton skip checks; keep canonical-header unwind disabled. Missing execution history is retryable and non-consuming where classified as unavailable; generic RPC errors do not prove pruning.
- Wire compatibility is envelope v6 / payload v6 / journal schema 12 / ABCI APP_VERSION 4 / committee encoding 2 / `ETNA_PARENT_ANCHOR_V4`. Old formats are explicitly rejected. Never migrate or rewrite signed journals. Keep the twenty-one-word V10 statement, ten-field Receipt, nine-field LandInput, and `land(input, proof)` aligned with the pinned protocol.
- Rewards never cut batches at epoch ends. L1 queue fees and L2 basefee receipts bind separate recipients. Proposer tips follow the immutable registered recipient of the original proposer in the certified block header under that height's committee, including retained blocks across rounds. Compute basefee from executed header gas, never vault balance deltas; claim spends and forced ETH credits do not change earned fees. Preserve the 301-distinct-member registry-proof/committee-witness and real-certificate regression, including payout tampering and quorum rejection. The 4096 registry/configuration cap is not production resource validation. Preserve all FI checks and ordinary gas estimation/EIP-7825 bounds.
- The real guest is unimplemented: dummy verification does not prove consensus, execution or fee sums. No DAO funding, pre-funding, per-vote accounting, reward settlement or automatic bridge exists. Landers supply L1 working capital; proving income is not guaranteed. Do not claim measured proving-performance reductions.
- Regenerate test-only InboxSetter and ZkGasFixture artifacts with script/gen_test_harness_artifacts.sh. Verify both generators twice for reproducibility; never hand-edit generated artifacts.

- Every validator harness/runtime startup must set `priv_validator_laddr` and use the guarded
  signer with the actual private key outside the Comet home/mount. Preserve FilePV state and
  Comet WAL on restart; only ephemeral test initialization creates signing files. Every new
  Comet transport begins a closed opaque trust session; app-only restart invalidates it.
  Unavailable trust control denies signatures and leaves signing state unchanged. Stop/reap
  Comet before stopping the signer and app. Full nodes use an unregistered local identity.
- Etna readiness is app `/trust` or `/status`, distinct from stock Comet `catching_up` and raw
  EL/Comet progress. Public RPC output needs its own readiness gate; do not claim an atomic
  cross-process revocation for a signing request authorized just before an app crash.
