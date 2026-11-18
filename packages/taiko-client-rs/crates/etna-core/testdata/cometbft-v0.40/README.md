# Native Comet wire fixtures

To refresh these fixture copies, run the [lander fixture generator](../../../lander/testdata/cometbft-v0.40/generate.sh)
at the baseline identified in the crate docs. Copy its `envelope.base64`, `vectors.json`, and
`differential.json` byte for byte and compare each file with the lander version. The generator
uses Go 1.27.2 and stock CometBFT v0.40.0, signs with stock `secp256k1eth`, and exports its
validated RPC JSON and protobuf bytes.

The fixed test scalars are 32 repetitions of a nonzero seed byte, producing full compressed
33-byte keys, Ethereum addresses, and low-S 65-byte `R || S || V` signatures. The chain ID is
schema-4 `chain_domains[0]` (L1 1, L2 167001, Inbox `0x1111…1111`, generation 0). Headers use
APP_VERSION 1, except the explicitly named `app_version_7` wire-preservation case. That case
checks lossless transport only; it does not authorize another Etna application version.

`vectors.json` contains six evidence cases. `differential.json` contains twelve named edge cases
and 8 cases from seeded PCG(22280, 2026), including partial/nil certificates, Unix-epoch and
Go-zero timestamps, int32-extreme rounds, duplicate-vote extensions, a 120-validator set, and
foreign generic-secp keys inside light-client attack evidence. Native keys occur throughout the
ordinary validator sets and light-client evidence. The non-cryptographic execution envelope is
an existing deterministic fixture; these files establish stock wire/commitment compatibility,
not complete Etna execution validity or a runnable devnet.

These fixture bytes are copied from the lander at the baseline identified in the crate docs.
The tests exercise the independent Rust bridge in `../../src/comet/native.rs`. Its wire types
retain every stock key tag inside foreign evidence. Etna committee authentication uses
`etna_core::key::ConsensusKey`, `etna_core::validator::validators_hash`, and native
certificate and quorum validation. Consumers must keep original block and commit bytes private,
check canonical encoding, and verify the original body, header, evidence, and part-set commitments.
