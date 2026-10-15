# Align the formal derivation spec with Unzen and Etna

Date: 2026-10-15

## Goal and source revisions

Update PR #22177 so its executable Lean model covers fork-aware derivation and
the Etna header commitments described by #22189 and implemented by #22263.
Preserve the existing manifest-decoding behavior and derivation properties.

This design was approved in chat before being recorded here. The revisions used
for the design are:

| PR                                                          | Revision                                   | Role                                                       |
| ----------------------------------------------------------- | ------------------------------------------ | ---------------------------------------------------------- |
| [#22177](https://github.com/taikoxyz/taiko-mono/pull/22177) | `a49c4cbf8e3fb0c0cc441196ca071d15efdc33ca` | Existing Lean model and proofs                             |
| [#22189](https://github.com/taikoxyz/taiko-mono/pull/22189) | `5d35cdd7a28d93fb0c8f2cbb513f33e5ef4108a1` | Derivation rules in `packages/protocol/docs/Derivation.md` |
| [#22263](https://github.com/taikoxyz/taiko-mono/pull/22263) | `1204948fbf4e4b3a238ee82a54ef72a346ccb841` | Rust derivation, root resolution and extra-data encoding   |

The latest source of #22189 specifies an L1 execution **state root**, not an L1
block hash, in the Etna `parentBeaconBlockRoot`. Its PR description contains older
wording; the checked source is the reference.

## Scope and trust boundary

The deliverable is an executable, pure model of manifest derivation followed by
pre-execution header fields and a transaction construction plan. Changes belong
to `packages/formal-spec`, its existing CI entry points if necessary, this design
document, and the PR title/description.

Retain the existing byte decoding, transaction grammar, source replacement rules,
forced-inclusion inheritance, source order and chain parameters. Add Etna fork
selection, gas-reserve handling, header commitments and the system-anchor
insertion policy.

The inputs still assume authenticated L1 facts and a valid initial L2 parent.
Pre-Etna parent anchor metadata is supplied from the appropriate L2 state or
bootstrap source; an Etna parent's number is recovered from its header extra
data, and genesis anchors to number zero. The model does not perform RPC, prove
L1 header authentication, or implement the historical parent-state lookup.

The model produces candidate transactions before execution. System anchor
construction is represented explicitly without implementing its signed ABI/RLP
encoding. Base-fee calculation, mix-hash calculation, Engine API serialization,
execution filtering, zk-gas metering and EIP-4788 state updates remain outside
this extension. In particular, candidate transaction preservation is not a claim
that every transaction appears in the executed block body.

## Architecture and data flow

Keep the existing pipeline:

1. Decode each source into a manifest or a default marker.
2. Apply inheritance and validate the source.
3. Number its final blocks and advance the rolling parent across sources.

Make these stages fork-aware where they handle header gas. Their public block
outputs continue to store manifest gas limits and manifest transactions.

Add a separate header-construction layer in `TaikoSpec/Derivation/Header.lean`.
It consumes the final derived blocks, proposal header metadata, an initial parent
commitment and an immutable L1 state-root lookup. It constructs each block's
header plan and advances the parent commitment before constructing the next.
This must work within a source and across source boundaries.

The header plan contains header gas limit, fork-dependent beacon root, extra
data, and a transaction plan that distinguishes a system anchor from manifest
transactions. Proposal header metadata supplies `proposalId` and
`basefeeSharingPctg`; these fields need not enlarge the inputs used by the core
manifest validation functions.

Use a 32-byte root representation with length enforced by its type or checked
constructor. Distinguish an absent pre-Unzen header field from a present zero
root. Header construction returns a structured error or a complete plan. A
failed block prevents successful construction of the whole proposal; partial
results must not be exposed as a successful proposal.

## Fork selection

Add `etnaForkTime : Option Nat` to `ChainParams` and pure timestamp predicates.
The checked revisions leave Etna unscheduled on mainnet, Hoodi and devnet unless
a devnet override is supplied. Represent test/devnet overrides as explicit
parameter values rather than process-global mutable state.

Each block selects its own fork from its final timestamp after validation or
inheritance. Activation is inclusive: a timestamp equal to the fork time uses the
new fork. Default blocks can cross a fork even when their proposal timestamp is
older. The per-source block-count limit keeps its existing rule: choose Shasta
or Unzen limits from the proposal's landed L1 timestamp.

## Gas semantics

Recover the parent's manifest gas limit using the parent's fork and genesis
status:

| Parent               | Manifest gas limit                        |
| -------------------- | ----------------------------------------- |
| Non-genesis pre-Etna | Header gas limit minus `ANCHOR_GAS_LIMIT` |
| Non-genesis Etna     | Header gas limit                          |
| Genesis              | Header gas limit                          |

After finalizing a child manifest block, construct its header gas limit using
the child's own timestamp: add `ANCHOR_GAS_LIMIT` before Etna and add zero from
Etna onward. `ANCHOR_GAS_LIMIT` remains 1,000,000.

Update `effectiveGasLimit`, `advance`, their callers and their proofs together.
For a block advanced into the rolling parent, recovering its manifest gas limit
must return the block's original manifest gas limit, including at the Etna
boundary. Existing bounds apply to manifest gas limits, not to the pre-Etna
header after adding the system reserve.

For example, a non-genesis Unzen parent with a 31M header limit supplies a 30M
manifest limit. An inheriting first Etna child has a 30M header limit, and an
inheriting Etna successor keeps 30M. A genesis header with 30M supplies 30M
without subtracting a reserve.

## Beacon roots and inheritance

The consensus header plan uses these rules:

| Child fork         | `parentBeaconBlockRoot`                                           |
| ------------------ | ----------------------------------------------------------------- |
| Before Unzen       | Absent                                                            |
| Unzen, before Etna | Present and zero                                                  |
| Etna               | Present and equal to the anchor's nonzero L1 execution state root |

For an Etna child, reuse the parent root only if all three conditions hold:

- the parent is an Etna block;
- its block number is nonzero;
- the child's final anchor number equals the parent's anchor number.

A reused parent root must exist and be nonzero. Every other case looks up the
state root of the child's final anchor number in the supplied L1 facts. In
particular, the first Etna child of a pre-Etna parent fetches the root even when
it inherits the same anchor number. A child of genesis fetches L1 block zero's
state root when its final anchor is zero; it never reuses genesis's zero root.
An advancing anchor also fetches the corresponding L1 root.

Forced/default blocks obey the same rules after inheriting their anchor number.
State the root-correspondence theorem under an explicit consistency predicate:
the initial non-genesis Etna parent's number/root pair and every successful L1
lookup refer to the same authenticated L1 history. Root reuse alone does not
prove that an arbitrary input parent is authentic.

## Extra data and transactions

Before Etna, use the existing seven-byte layout:
`[basefeeSharingPctg(1) | proposalId(6)]`.

From Etna, use exactly thirteen bytes:
`[basefeeSharingPctg(1) | proposalId(6) | anchorBlockNumber(6)]`.

Both Etna integer fields are big-endian uint48 values; reject values above
`2^48 - 1` rather than truncating them. Encode the final anchor after inheritance
and validation. Proposal IDs from authenticated events are in their declared
uint48 domain. Preserve the pre-Etna encoder's existing behavior on that domain;
do not silently change the manifest decoder's wider integer grammar.

Model the pre-Etna system anchor as an explicit leading transaction-plan entry,
followed by the manifest transactions in order. Etna has no system entry and
preserves the manifest candidate list exactly. Consequently, an Etna default
block has an empty candidate list. Manifest transactions from the golden-touch
address receive no special treatment in the Etna construction plan.

## Failure semantics

Keep source-level fallback separate from header-construction failure:

- Manifest extraction or metadata validation failure produces the existing
  default block with inherited metadata.
- An unavailable L1 root, a zero fetched root, a missing/zero root on the reuse
  path, or Etna uint48 overflow returns a header-construction error.

Header-construction errors do not turn a source into a default block, fabricate
a root, or reuse a pre-Etna/genesis zero root. State error cases in an explicit
error type so executable tests can distinguish them.

## Properties and proofs

Retain all existing public derivation theorems and their non-vacuous witnesses:
source cardinality, source isolation, consecutive numbers, timestamp ordering
and drift, anchor ordering and origin bound, manifest gas range, proposer anchor
progress, forced-inclusion acceptance, and Go/Rust inheritance-order equivalence.
Generalize them to the fork-aware parent transition without adding proof escape
hatches or axioms.

Add header properties in `TaikoSpec/Proofs/Header.lean` and expose their reviewed
statements through `TaikoSpec/Properties.lean`:

- Header construction and parent recovery preserve manifest gas across both
  sides of Etna.
- Every successfully constructed Etna root is present and nonzero.
- Under consistent input facts, every Etna root corresponds to its final anchor
  number; inheritance preserves the parent's number/root pair.
- The seven/thirteen-byte layouts have the specified lengths; Etna uint48
  encoding/decoding round-trips on its valid domain and rejects overflow.
- Etna's candidate transaction plan contains no system anchor and preserves the
  manifest transaction sequence; default Etna blocks are empty.
- Sequential header construction uses the immediately preceding block's
  commitment, including across source boundaries.

Give conditional properties concrete witnesses for the first Etna block,
inherited Etna roots and Etna-at-genesis configurations.

## Tests and acceptance

Extend the existing validation/derivation tests and add focused header/Etna tests
under `Tests/`. Include:

- Etna unscheduled; timestamp immediately before activation; exact activation;
  and a positive post-activation timestamp.
- Valid multi-block sources and multiple sources crossing Unzen/Etna boundaries;
  proposal-time block-count selection remains independent of block-time fields.
- A default block whose inherited timestamp crosses Etna.
- Pre-Etna, Etna and genesis parents with explicit expected gas values.
- First Etna forced/default children fetching the inherited anchor's L1 root;
  later Etna children reusing roots; changed anchors looking up new roots.
- Genesis-at-Etna and L1 block zero inheritance.
- Exact seven/thirteen-byte encodings, zero and maximum uint48 values, and
  separate proposal-ID and anchor-number overflow errors.
- Every root error path and Etna candidate transactions with empty and nonempty
  lists, including ordinary golden-touch transactions at the construction level.
- Whole-proposal construction failure when any header cannot be constructed.

Use concrete expected values and cases adapted from the checked Rust tests.
These are Lean regression tests, not shared cross-client coverage unless an
adapter actually executes the same cases. Keep the existing shared manifest
corpus intact and replay all its cases.

From `packages/formal-spec`, acceptance requires successful completion of:

```bash
lake build
lake exe vectors ../../testdata/derivation_vectors/manifest_cases.json
lake exe checkaxioms
bash scripts/gate.sh
lake env leanchecker TaikoSpec
```

Import every new production definition/proof through the package entry point so
the axiom allowlist and kernel replay cover it. Import every new test module
through `Tests.lean` so the normal build and existing CI execute it. The README
and PR description must distinguish proved model properties, tested driver
alignment, and assumed input authenticity, and accurately list the remaining
coverage boundary.
