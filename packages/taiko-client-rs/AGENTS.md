# Repository Guidelines

## Project Structure & Module Organization

- `bin/client/` hosts the CLI entry point (`abci`, `abci-genesis`, `abci-committee-record`, `lander`); keep orchestration light and delegate protocol logic to the crates.
- `crates/abci` is the ABCI++ application of the Etna PoS chain (CometBFT + `taiko-client abci` + alethia-reth). Keep `envelope`, `rules`, `schedule`, `committee` and `forced` (the forced inclusion rule) free of I/O so they can later move unchanged into a no_std crate for the guest. The envelope is version 5; validators enforce forced inclusion and anchor freshness per block.
- `crates/lander` constructs authenticated CometBFT batches, zlib-compressed V4 blob payloads and sidecars, binds the V7 statement (whose nineteen words include the parent-anchor committee configuration, the forced inclusion queue head before and after the batch, the fee recipient, the lander's sending address, and the hash of the batch's validator participation), passes each epoch-freezing landing's committee lists for the reward pool's settlement, authenticates historical derivation parents through EL ancestry, obtains proof through a trait (dummy `0x00` in this version), and durably submits to L1. Keep the journal independent of ABCI; never replace or cancel an outstanding nonce automatically.
- `crates/protocol` holds shared protocol helpers (including Shasta manifest decoding for raiko2); `crates/rpc` holds the Engine API / JWT provider helpers. FI bytes are authenticated calldata from exact-block admission events. Document shared traits whenever exposing cross-crate APIs.
- `crates/protocol` is also consumed by raiko2 (pinned by git rev); keep the `shasta` modules and `FixedKSigner` it imports.
- `crates/bindings/` is kept only for protocol's anchor builder, which raiko2 uses. It is generated via `just gen_bindings` (Solidity sources in `../protocol`); never hand-edit or reformat files under `crates/bindings/src`.
- `crates/test-harness` boots docker devnets (anvil as L1, alethia-reth, CometBFT) through the docker CLI, with calldata admission fixtures. The Docker scenarios live in `crates/abci/tests/`, `crates/lander/tests/` and `bin/client/tests/` and are marked `#[ignore = "docker"]`.
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
- `just test` runs the ABCI, lander and CLI Docker scenarios through `tests/entrypoint.sh`: it checks docker, pulls the anvil, alethia-reth and CometBFT images (override with `ANVIL_IMAGE`, `ALETHIA_RETH_IMAGE`, `COMETBFT_IMAGE`, `LANDER_ANVIL_IMAGE`; `PULL_POLICY=missing` reuses local images) and runs the scenarios serially with the nextest `integration` profile, since each boots its own devnet. Extra args go to nextest, e.g. `just test restart` for one scenario.
- Name tests after observable behavior (e.g., `handles_invalid_proposal`). The harness prints every container's log tail when a scenario fails (panics, returns an error or times out waiting for a height) or its devnet fails to boot; keep that output for any failing integration case.
- Targeted verification is fine while iterating, but completion still requires a final full `just fmt && just clippy && just unit && just test` pass with clean output.

## Commit & Pull Request Guidelines

- Use Conventional Commit prefixes (`feat:`, `fix:`, `chore:`). Keep subject lines ≤72 characters with optional, meaningful scopes.
- PR descriptions must summarize impact, link issues, and include command output or screenshots for operator-facing flows.
- Confirm `just fmt && just clippy && just unit && just test` pass locally with no warnings or errors in the final verification run; call out any follow-up work explicitly.

## Security & Environment Notes

- Use only the ephemeral test keys bundled in the test harness and `tests/docker`; never commit real credentials or `.env` files.
- Docker scenarios publish ephemeral RPC ports on loopback and name resources `abci-<id>-…` or `lander-<id>-…`. The harness cleans process-owned resources on SIGINT/SIGTERM; the entrypoint and CI also clean only the `taiko-client-rs.test-run` label for their run. For manual cleanup, filter that exact run label so other devnets are preserved.

- Lander real-contract fixtures (including `EtnaRewardPool`) pin protocol commit `07e36f73e7fcc81baefe834fd205035df121a5e0`, the same as `PROTOCOL_REVISION`. Regenerate with `script/gen_lander_artifacts.sh`, which also copies the shared Etna vectors (`testdata/etna_vectors`); generated artifact and vector hashes and compiler provenance are unit-tested, and `just check-lander-artifacts` checks that regeneration reproduces the committed files. Real-contract tests use `LANDER_ANVIL_IMAGE` (Foundry v1.8.5); existing ABCI tests retain their independent Anvil pin.

- FI preimages are published only for skips; ordinary and included proposals carry an empty witness tx field. Inclusion authenticates the canonical first transaction against the proven hash; due skips still authenticate even an empty preimage. Nonempty legacy preimages remain hash-checked.
- Calldata FI requires no beacon flags, blob fetches or KZG warmup. Preserve lander batch blobs and both sidecar modes. The lander requires authenticated Engine/JWT access for historical singleton skip checks; keep canonical-header unwind disabled. Missing execution history is retryable and non-consuming where classified as unavailable; generic RPC errors do not prove pruning.
- Wire compatibility is envelope v5 / payload v4 / journal schema 9 / ABCI APP_VERSION 2. Persisted app_version must equal 2; version 1 chains require an explicit consensus upgrade, never an automatic state rewrite. Do not migrate or rewrite signed journals. Keep the V7 nineteen-word statement, the six-field LandInput and the four-argument `land(input, participation, settlements, proof)` unchanged.
- Participation counts height h only from block h+1's verified `last_commit` (nil and absent votes do not count), never from the seen `/commit`; a batch `(p, L]` covers commit heights `max(p, 1)..=L-1`, and the landing whose commits reach an epoch's last height settles it. Prefix selection ends a batch at the latest at `h_first(e + 1)` for the epoch `e` of `max(p, 1)`, so a freezing landing carries exactly one part; `MAX_N_MAX = 300` keeps even a two-part freezing landing (the next epoch's first writes on top of the settlement) under the EIP-7825 cap. The pool pays the base part out of the committee's full weight (stake times epoch length) and the bonus out of `10_000 * epochLenL2`, so omitting a signature never raises another member's payout. Counts and committee lists use MEM-08 order and the committee's authenticated registry witness. Each part also carries proposer scores: block h+1 scores `floor(10_000 * includedEffStake / totalEffStake)` for the member whose key-derived CometBFT address is its certified `proposer_address`, nobody when the proposer is outside h's committee; a part's scores sum to at most 10,000 per height, as `land` requires.
- Current proof handling is dummy-only, so participation and committee lists are unproven too. debug_executionWitnessForTxList is a future collection primitive, potentially requiring skipZkGasDifficultyCheck=true for candidates; guest authentication/re-execution and participation proofs are unimplemented. See README for their state, the guest's participation (counts and proposer scores) obligations and cutoff limits.
- Regenerate test-only InboxSetter and ZkGasFixture artifacts with script/gen_test_harness_artifacts.sh. Verify both generators twice for reproducibility; never hand-edit generated artifacts.
