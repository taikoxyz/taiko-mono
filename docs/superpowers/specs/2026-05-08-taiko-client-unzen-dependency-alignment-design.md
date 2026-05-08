# Taiko Client Unzen Dependency Alignment Design

## Goal

Align the Taiko Go and Rust clients with current downstream execution dependencies and the planned Hoodi Unzen activation time.

## Scope

- Bump the root `go.mod` `github.com/ethereum/go-ethereum` replacement to the latest `taikoxyz/taiko-geth` `taiko` branch revision.
- Bump the `packages/taiko-client-rs` Alethia-Reth git dependencies to the latest `taikoxyz/alethia-reth` `main` branch revision.
- Update the Rust Hoodi Unzen fork condition to `ForkCondition::Timestamp(1_779_368_400)`.
- Update only the existing lockfiles and tests required by those changes.
- Open a non-draft PR whose title starts with `chore(taiko-client,taiko-client-rs):`.

## Current State

The monorepo root currently replaces `github.com/ethereum/go-ethereum v1.15.5` with `github.com/taikoxyz/taiko-geth v1.18.1-0.20260427005750-f636489ae176`.

`packages/taiko-client-rs/Cargo.toml` currently pins `alethia-reth-consensus`, `alethia-reth-primitives`, and `alethia-reth-rpc-types` to Alethia-Reth commit `0ed31d96e91b5c7c37ab8a952c01e88ec7349e23`.

`packages/taiko-client-rs/crates/protocol/src/shasta/constants.rs` currently sets Hoodi Unzen to `ForkCondition::Never`, while the requested activation is timestamp `1_779_368_400`.

## Approach

Use exact upstream branch heads rather than floating branch references. The latest checked heads during design are:

- `taikoxyz/taiko-geth` `taiko`: `5ec860d6684ebe41d1430ac30dfdf5f0a8bc7745`
- `taikoxyz/alethia-reth` `main`: `2ebe77c3afaae3992270186d4d026e97b4c62e4c`

For Go, run the module tooling needed to produce the pseudo-version for the selected Taiko Geth revision and refresh `go.sum` if necessary.

For Rust, update all three Alethia-Reth dependency entries together, then run Cargo update for those packages so `Cargo.lock` carries the selected git revision and compatible transitive pins.

For Hoodi, change only the Rust protocol constant and the existing focused assertions that describe fork conditions, fork timestamps, and timestamp-aware derivation limits.

## Verification

Run focused verification first:

- Root Go module resolution for the updated replacement.
- `cargo test -p protocol shasta::constants::tests:: --lib` from `packages/taiko-client-rs`.

Then run broader practical verification for the touched packages as dependency changes allow, prioritizing compile or existing package test commands over unrelated monorepo-wide checks.

## PR

Commit the dependency and fork-constant changes on branch `codex/taiko-client-unzen-deps`, push it, and open a ready PR against `taikoxyz/taiko-mono` `main` with a title beginning:

`chore(taiko-client,taiko-client-rs):`
