# Native Comet wire fixtures

Run `./generate.sh` from any directory. The generator uses Go 1.27.2 and the unmodified
`github.com/cometbft/cometbft v0.40.0` module. It signs with stock `secp256k1eth`, validates the
resulting certificates with stock Comet, and exports the actual RPC JSON and protobuf bytes.
Never edit the generated JSON or signatures by hand.

The fixed test scalars are 32 repetitions of a nonzero seed byte, producing full compressed
33-byte keys, Ethereum addresses, and low-S 65-byte `R || S || V` signatures. The chain ID is
schema-4 `chain_domains[0]` (L1 1, L2 167001, Inbox `0x1111…1111`, generation 0). Headers use
APP_VERSION 1, except the explicitly named `app_version_7` wire-preservation case. That case
checks lossless transport only; it does not authorize another Etna application version.

`vectors.json` contains six evidence cases. `differential.json` contains twelve named edge cases
and 48 cases from seeded PCG(22280, 2026), including partial/nil certificates, Unix-epoch and
Go-zero timestamps, int32-extreme rounds, duplicate-vote extensions, a 120-validator set, and
foreign generic-secp keys inside light-client attack evidence. Native keys occur throughout the
ordinary validator sets and light-client evidence. The non-cryptographic execution envelope is
an existing deterministic fixture; these files establish stock wire/commitment compatibility,
not complete Etna execution validity or a runnable devnet.

The Rust bridge is `crates/lander/src/native.rs`. Its wire types retain every stock key tag inside
foreign evidence without enabling those algorithms for Etna committee authentication. Actual
Etna committee authorization must continue to use `abci::key::ConsensusKey`, native
`abci::wire::validators_hash`, and strict native certificate/quorum validation. Original block
and commit bytes must remain private proof/journal inputs; decode/re-encode canonicality and
body/header/evidence/part-set commitments must be checked by their consumers.
