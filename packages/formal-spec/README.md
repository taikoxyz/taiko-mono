# formal-spec

A Lean 4 specification of Taiko's Shasta/Unzen/Etna block derivation. Given a proposal's
derivation sources, it defines normalized L2 blocks and checked pre-execution header plans.
The spec is executable, passes the manifest-decoding vectors the Go and Rust drivers share,
and comes with machine-checked proofs of its main properties.

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
- **Checked header plans** ([`Derivation/Header.lean`](TaikoSpec/Derivation/Header.lean)):
  header gas limit, `parentBeaconBlockRoot`, encoded `extraData` and candidate transaction order.
  `deriveHeaders` first derives every source, then constructs headers with one rolling parent
  commitment across all blocks and source boundaries.

### Forks, gas and header commitments

Each block selects its header rules from its final timestamp after inheritance and validation;
activation is inclusive. A default block can cross a fork even when the proposal timestamp
precedes it. The per-source block-count limit instead uses the proposal's landed L1 timestamp:
192 before Unzen and 768 from Unzen. `ChainParams` holds explicit fork times; Etna is unscheduled
(`none`) in the supplied mainnet, Hoodi and devnet parameters. Tests schedule it explicitly.

Derived blocks retain **manifest gas limits**. A non-genesis parent's manifest limit is recovered
from its header by subtracting the 1M system-anchor reserve before Etna, and subtracting zero
from Etna. Genesis uses its header gas unchanged. A child's header adds 1M before Etna and zero
from Etna, using the child's own timestamp. For example, a 31M Unzen parent supplies a 30M
manifest limit; an inheriting first Etna child and its Etna successor both have 30M headers.

| Child fork         | `parentBeaconBlockRoot`                                                 |
| ------------------ | ----------------------------------------------------------------------- |
| Before Unzen       | Absent                                                                  |
| Unzen, before Etna | Present zero root                                                       |
| Etna               | Present nonzero L1 execution **state root** for the final anchor number |

An Etna child reuses its parent's root only when the parent is non-genesis Etna and the final
anchor number is unchanged. The reused root must be present and nonzero. Otherwise construction
looks up the final anchor's L1 state root, including for the first Etna child of a pre-Etna
parent and for a child of genesis (anchor zero fetches L1 block zero). Roots have the fixed-width
word type `Fin (2^256)`, with canonical 32-byte big-endian representation `encodeBE 32 root.val`;
an absent field is distinct from a present zero root.

[`Derivation/ExtraData.lean`](TaikoSpec/Derivation/ExtraData.lean) encodes seven bytes before Etna,
`[basefeeSharingPctg(1) | proposalId(6)]`, and thirteen bytes from Etna,
`[basefeeSharingPctg(1) | proposalId(6) | anchorBlockNumber(6)]`. Integer fields are big-endian.
Etna rejects proposal IDs or final anchor numbers above `2^48 - 1`; the legacy encoder retains
its low-six-byte behavior and agrees on authenticated uint48 event IDs. Non-genesis Etna anchor
decoding requires exactly thirteen bytes; genesis anchor decoding always yields zero.

Before Etna, the transaction plan prepends a tagged system-anchor entry to manifest candidates.
Etna preserves the manifest candidate sequence exactly with no system entry; default Etna
blocks have no candidates. Candidates are RLP items before execution: sender authentication,
golden-touch sender handling and execution filtering are outside the model. The system-anchor
entry does not implement signed ABI/RLP transaction encoding.

Manifest extraction or metadata-validation failure still produces the default block with
inherited metadata. Header construction instead returns a structured `HeaderError` for missing
or zero parent/L1 roots, or separate proposal/anchor uint48 overflow errors. Any header failure
rejects the whole proposal plan, with no successful partial result, fabricated root or source
fallback.

Not covered yet:

- decoding blob field elements into bytes and authenticating L1 inputs;
- base-fee and `mixHash` calculation, signed system-anchor encoding and Engine API serialization;
- block execution, execution filtering, zk-gas metering and EIP-4788 state updates.

The extension follows the checked sources of
[#22189 at `5d35cdd7`](https://github.com/taikoxyz/taiko-mono/blob/5d35cdd7a28d93fb0c8f2cbb513f33e5ef4108a1/packages/protocol/docs/Derivation.md)
and [#22263 at `1204948f`](https://github.com/taikoxyz/taiko-mono/pull/22263/changes/1204948fbf4e4b3a238ee82a54ef72a346ccb841).
The Etna commitment is an L1 state root, rather than the block-hash wording in the older PR description.

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
- **Manifest gas limits** stay within `[10M, 45M]` when the initial parent supplies an in-range
  manifest limit. This range does not include the pre-Etna header reserve.
- **Proposer progress:** a proposer's source that keeps its blocks raises the anchor.
- **Forced inclusions:** the exact condition under which a one-block forced inclusion keeps its
  transactions.
- **Driver order:** the Rust driver's order of inheritance and validation gives the same result
  as the Go driver's.
- **Header preservation:** successful proposal plans preserve every normalized derived block;
  advancing a constructed header recovers its manifest gas across the Etna boundary.
- **Header fields:** pre-Etna plans have the selected absent/zero root, seven-byte extra data and
  leading system anchor. Successful Etna plans have a nonzero root, thirteen-byte extra data,
  unchanged candidate order and no system anchor. Uint48 fields round-trip on their valid domain
  and reject overflow.
- **Conditional root correspondence:** if available lookups agree with a canonical L1 history
  and the initial non-genesis Etna parent commits to that history, successful sequential headers
  and the final parent retain the anchor/root correspondence, including across sources. A reused
  anchor need not be available in the partial lookup.

Each theorem with preconditions has a witness showing the preconditions can hold.

## Trust boundary

- **Proved:** the theorems in `Properties.lean`, about the definitions in `TaikoSpec/`.
- **Tested, not proved:** that the definitions match the drivers. The evidence is the shared
  vectors in [`testdata/derivation_vectors`](../../testdata/derivation_vectors) and the tests in
  `Tests/`, ported from the drivers' unit tests. The DEFLATE decoder is a reference
  implementation, checked the same way. New header/Etna cases are Lean regression tests adapted
  from the checked implementation, not shared header vectors executed by client adapters. These
  tests and proofs do not establish full client equivalence.
- **Assumed:**
  - the inputs: decoded blob bytes (availability, versioned-hash binding, blob encoding), L1
    facts (event fields, proposal timestamp, origin block) and L2 facts (parent header, parent
    anchor). The initial parent is assumed valid. Pre-Etna anchor metadata comes from the
    appropriate historical L2 state/bootstrap source; Etna extra data supplies the encoded anchor,
    and genesis anchors to zero. The model exposes decoding but performs no RPC or historical
    state lookup. Root authenticity is conditional on sound L1 lookups and an authenticated initial
    Etna parent; root reuse alone cannot authenticate arbitrary input;
  - Lean's kernel and compiler.

CI rejects proofs with gaps or extra assumptions:

- [`scripts/gate.sh`](scripts/gate.sh) bans proof escape hatches in the spec sources;
- `lake exe checkaxioms` checks that every spec declaration depends only on `propext`,
  `Classical.choice` and `Quot.sound`;
- `leanchecker` replays the spec in Lean's kernel.

## Where it differs from `Derivation.md`

The existing manifest-decoding and validation model follows the checked drivers where
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
| `TaikoSpec/Derivation/ExtraData.lean`                                      | Seven/thirteen-byte codecs and checked uint48 fields  |
| `TaikoSpec/Derivation/Header.lean`                                         | Checked header and candidate transaction plans        |
| `TaikoSpec/Proofs/ExtraData.lean`, `Proofs/Header.lean`                    | Encoding, header and conditional root proofs          |
| `Tests/Header.lean`, `Tests/Etna.lean`                                     | Header/fork boundaries and structured failures        |
| `TaikoSpec/Chain.lean`                                                     | The `Chain` predicate used in statements              |
| `TaikoSpec/Properties.lean`                                                | Proved statements and their witnesses                 |
| `TaikoSpec/Proofs/`                                                        | Proofs                                                |
| `Tests/`                                                                   | `#guard` tests, run by `lake build`                   |
| `Main/Vectors.lean`, `Main/CheckAxioms.lean`                               | The `vectors` and `checkaxioms` executables           |

## Next steps

- Shared vectors for validation, whole proposals and header plans, with Go and Rust adapters.
- Blob field-element decoding.
- Proofs that RLP decoding is canonical and that encoding a manifest round-trips.
- Resource bounds on decoding.
- Remaining payload fields, execution behavior and authenticated input integration.
