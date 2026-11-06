# Offline stock Comet checkpoint helper

Build from `tools/etna-signer` using the module's pinned Go toolchain:

```sh
go build -mod=readonly -o etna-comet-import ./cmd/etna-comet-import
go test -race -mod=readonly ./...
```

Package this binary beside `etna-signer` and `etna-comet-inspect` in runtime
images. It uses unmodified CometBFT v0.40.0 and GoLevelDB. It starts no service,
loads no signing keys and never reads/writes FilePV state or consensus WAL.

```sh
etna-comet-import verify --package checkpoint.json \
  --trusted-comet-hash 0x... --trusted-el-hash 0x... \
  --trusted-val-state-hash 0x...
etna-comet-import install --package checkpoint.json --home /absolute/fresh/home \
  --trusted-comet-hash 0x... --trusted-el-hash 0x... \
  --trusted-val-state-hash 0x...
etna-comet-import export --home /absolute/offline/home \
  --validator-state terminal-preimage.bin --first-height 100 --last-height 120 \
  --output checkpoint.json
```

The three trusted hashes must come from the Rust own-finalized-L1 verifier.
The package cannot supply them. `--trusted-el-hash` installs post-s State.AppHash;
the terminal header's AppHash still identifies s-1. The Rust verifier separately
authenticates the terminal Etna envelope's execution-header hash.

Version-1 package, block and validator fields use strict JSON with no unknown
or duplicate keys. The original stock genesis object is preserved:

```json
{
  "schema": 1,
  "genesis": { "chain_id": "original-chain-id", "initial_height": "71" },
  "blocks": [
    {
      "block": "0x<original canonical stock block protobuf>",
      "commit": "0x<original canonical own-height commit protobuf>",
      "validators": [{ "key": "0x<33-byte compressed SEC1>", "power": 10 }]
    }
  ],
  "validator_state": "0x<canonical appendix-A ABI preimage>"
}
```

The genesis object above is abbreviated: the actual original stock genesis JSON,
with Etna's fixed consensus parameters and validator entries, is required. Block
heights are contiguous, each has its own full-ID commit, and the terminal height
must equal the preimage height. Every nonterminal `commit` must be byte-for-byte
identical to the successor block's embedded LastCommit. Both native signatures and
the preceding full BlockID are verified for these embedded commits. Only the
first retained block's LastCommit is exempt, since its preceding signing set may
be outside the window. The terminal `commit` is independently supplied and
verified; no successor block is needed. The helper checks
stock block structure/DataHash/evidence hashes, full canonical part sets, native
secp256k1eth commits, chain linkage, historical signing-set hashes, exact preimage
encoding and the terminal next-validators commitment. It preserves the preimage's
priorities and stored proposers, rather than recomputing them from RPC state.

Verification/install output has `schema`, `first_height`, `last_height`,
`block_id` (`hash`, `parts.total`, `parts.hash`), `terminal_time` (RFC3339),
`chain_id`, `initial_height`, `validators_hash` (s+1), `next_validators_hash`
(s+2), and `package_hash`. Hash strings are lowercase 0x hex. `package_hash` is
Keccak-256 of Go `json.Marshal(Package)` output, with the field order above;
JSON whitespace and outer package field order do not affect it. Property order
inside the original raw `genesis` object is retained and affects this binding.
It detects corruption,
not authority. Export writes the complete package to `--output` and no report.

Exit 0 means the requested offline operation completed. Exit 1 rejects malformed,
missing or unsupported material, source/store errors, and ordinary bad candidates.
Exit 2 means the trusted terminal Comet hash and matching landed preimage
contradict `header(s).next_validators_hash`; the controller must durably safety-halt.
Rust handles independently derived committee and terminal EL contradictions.

The CLI streams one bounded block at a time into a private spool. Its default
aggregate disk profile is 1 TiB, configurable downward with `--max-package-bytes`
for verification/install. Each block JSON value is bounded to 128 MiB and each
metadata value to 64 MiB. Exceeding a bound rejects the entire package, without
shortening the window. The internal in-memory `Read`/`Verify` convenience API is
for small packages and has a 1 GiB decoding profile. Export streams directly
from read-only stock stores. No production budget has been measured here.

The Rust caller authenticates original genesis/generation, chooses and proves
the shortest complete evidence/switch/anchor window, checks envelope and EL
links, derives s+1/s+2 committees, verifies local EL state, owns offline leases,
and stages/publishes the durable cross-store manifest. `EvidenceExpired` exposes
stock's strict AND age rule using committed post-s height/time, never wall time.
The helper cannot infer a missing predecessor header's time from the package.

Installation requires a nonexistent absolute home with no symlinked ancestors.
It writes only config/genesis.json and stock state/blockstore/evidence databases,
flushes them, closes and reopens them through stock APIs, and fsyncs directories.
A crash leaves an unpublished partial home; the parent controller may remove
only its own staging and retry. Existing destinations are always refused.

Historical records use the pinned public ValidatorsInfo/ConsensusParamsInfo
protobufs and stock key formats: full validator sets at the first retained
height, changes and periodic 100,000-height checkpoints; metadata never points
below the retained window. Bulk reopen/export queries require the pinned stock
`LoadValidatorsFast` capability, which loads keys/powers without replaying
irrelevant historical proposer priorities; no slow fallback is allowed. Final
s/s+1/s+2 are full, and post-s state uses stock
Bootstrap. Stock SaveBlock retains each successor LastCommit and terminal
seen-commit. The terminal verified commit also populates stock C:s because
stock evidence's signed-header lookup requires it before s+1 exists. Evidence
Pool.Update rebuilds committed markers from authenticated lists without calling
historical ValidateBlock/CheckEvidence or fetching pre-window data. Pending
evidence starts empty, and normal new-evidence validation uses stock APIs.
