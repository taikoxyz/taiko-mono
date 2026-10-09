# formal-spec

A Lean 4 specification of Taiko's Shasta/Unzen block derivation. Given a proposal's derivation
sources, it defines the L2 blocks derived from them: their number, timestamp, coinbase, anchor
block, gas limit and transactions. The spec is executable, passes the decoding vectors the Go
and Rust drivers share, and comes with machine-checked proofs of its main properties.

This is the first step of formal verification for the Taiko clients: one readable definition that
the Go driver, the Rust driver and the prover guests can be checked against.

## What it covers

- **Manifest extraction** ([`Derivation/Manifest.lean`](TaikoSpec/Derivation/Manifest.lean)).
  From a source's blob bytes to its manifest blocks, or to the default manifest: the offset,
  version and size words, zlib, exact RLP decoding, the transaction grammar, the block limit
  and the one-block rule for forced inclusions.
- **Byte formats.**
  - [`Rlp.lean`](TaikoSpec/Rlp.lean): canonical RLP.
  - [`Deflate.lean`](TaikoSpec/Deflate.lean) and [`Zlib.lean`](TaikoSpec/Zlib.lean): zlib with the
    accept/reject behaviour of Go's `compress/zlib`.
  - [`Tx.lean`](TaikoSpec/Tx.lean): the transaction encodings a manifest block may carry.
- **Validation, inheritance and the default source**
  ([`Derivation/Validate.lean`](TaikoSpec/Derivation/Validate.lean)): timestamp, anchor and gas
  limit bounds, and the metadata forced inclusions and default blocks inherit.
- **Deriving a proposal** ([`Derivation/Derive.lean`](TaikoSpec/Derivation/Derive.lean)): sources
  in order, each building on the last block of the one before.

Not covered yet:

- decoding blob field elements into bytes;
- payload attributes (base fee, `mixHash`, `extraData`, the anchor transaction);
- block execution.

## Properties

[`Properties.lean`](TaikoSpec/Properties.lean) holds the proved statements; it is the file to
review. Its theorems:

- **Cardinality:** every source contributes between 1 and `maxBlocks` blocks, and a forced
  inclusion exactly one.
- **Source isolation:** later sources cannot change the blocks of earlier ones, so the proposer's
  source cannot affect the forced inclusions before it.
- **Block numbers** are consecutive.
- **Timestamps** strictly increase. Block `i` is at most `i + 1` seconds past the latest of the
  proposal timestamp, the parent timestamp and the fork time. Only default blocks can be later
  than the proposal timestamp.
- **Anchors** never decrease and never pass the origin block.
- **Gas limits** stay within `[10M, 45M]`.
- **Proposer progress:** a proposer's source that keeps its blocks raises the anchor.
- **Forced inclusions:** the exact condition under which a one-block forced inclusion keeps its
  transactions.
- **Driver order:** the Rust driver's order of inheritance and validation gives the same result
  as the Go driver's.

Each theorem with preconditions has a witness showing the preconditions can hold.

## Trust boundary

- **Proved:** the theorems in `Properties.lean`, about the definitions in `TaikoSpec/`.
- **Tested, not proved:** that the definitions match the drivers. The evidence is the shared
  vectors in [`testdata/derivation_vectors`](../../testdata/derivation_vectors) and the tests in
  `Tests/`, ported from the drivers' unit tests. The DEFLATE decoder is a reference
  implementation, checked the same way.
- **Assumed:**
  - the inputs: decoded blob bytes (availability, versioned-hash binding, blob encoding), L1
    facts (event fields, proposal timestamp, origin block) and L2 facts (parent header, parent
    anchor);
  - Lean's kernel and compiler.

CI rejects proofs with gaps or extra assumptions:

- [`scripts/gate.sh`](scripts/gate.sh) bans proof escape hatches in the spec sources;
- `lake exe checkaxioms` checks that every spec declaration depends only on `propext`,
  `Classical.choice` and `Quot.sound`;
- `leanchecker` replays the spec in Lean's kernel.

## Where it differs from `Derivation.md`

The spec follows the drivers, which agree with each other, where
[`Derivation.md`](../protocol/docs/Derivation.md) says otherwise:

- **Version word.** Any value below `2^64` whose low 32 bits equal 1 is accepted, not only `0x1`.
- **Anchor 0.** `anchorBlockNumber = 0` does not mean "use the parent's anchor". In a proposer's
  block it is validated like any other anchor number. Once the parent's anchor is above 0 it
  fails the no-regression rule, and the source becomes the default manifest. Forced inclusions
  inherit their anchor either way.
- **Forced inclusions can become the default block.** This happens when the timestamp window is
  used up, or when the parent's anchor is more than `MAX_ANCHOR_OFFSET` behind the origin block.
  See `forced_inclusion_accepted_iff`.
- **Decoding rules.** `Derivation.md` only says "Apply ZLIB decompression" and "RLP decode". The
  spec states the exact rules: the first complete zlib stream with a valid checksum, canonical
  exact RLP, and the transaction grammar.

## Running

Install [elan](https://github.com/leanprover/elan). The Lean version is pinned in
`lean-toolchain`. From this directory:

```bash
lake build                                                             # spec, proofs and tests
lake exe vectors ../../testdata/derivation_vectors/manifest_cases.json # shared vectors
lake exe checkaxioms                                                   # axiom allowlist
bash scripts/gate.sh                                                   # banned constructs
lake env leanchecker TaikoSpec                                         # kernel replay
```

## Layout

| Path                                                                       | Contents                                              |
| -------------------------------------------------------------------------- | ----------------------------------------------------- |
| `TaikoSpec/Bytes.lean`, `Rlp.lean`, `Deflate.lean`, `Zlib.lean`, `Tx.lean` | Byte formats                                          |
| `TaikoSpec/Derivation/`                                                    | Parameters, types, extraction, validation, derivation |
| `TaikoSpec/Chain.lean`                                                     | The `Chain` predicate used in statements              |
| `TaikoSpec/Properties.lean`                                                | Proved statements and their witnesses                 |
| `TaikoSpec/Proofs/`                                                        | Proofs                                                |
| `Tests/`                                                                   | `#guard` tests, run by `lake build`                   |
| `Main/Vectors.lean`, `Main/CheckAxioms.lean`                               | The `vectors` and `checkaxioms` executables           |

## Next steps

- Shared vectors for validation and whole proposals, with Go and Rust adapters.
- Blob field-element decoding.
- Proofs that RLP decoding is canonical and that encoding a manifest round-trips.
- Resource bounds on decoding.
- Payload attributes (Layer B) and the anchorless variant.
