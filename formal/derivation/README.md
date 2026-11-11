# Unzen derivation verification

This package proves safety properties of an executable Lean model of Taiko's Unzen block
derivation, as the Go driver (`packages/taiko-client`) and the Rust driver
(`packages/taiko-client-rs`) implement it today. It pins the specification at revision
`5a987fe921743af9fdfe33de7aba6671b18c8a69` in [`spec-coverage.json`](spec-coverage.json).
The theorems concern this model; they do not establish equivalence of production clients.

## Scope

The model covers one proposal that lands on L1 at or after `UNZEN_FORK_TIME` on top of an
Unzen parent block. That is every mainnet and Hoodi proposal after the first one or few at the
activation boundary. For such a proposal:

- the per-source block limit is `UNZEN_DERIVATION_SOURCE_MAX_BLOCKS` (768), because the
  clients pick it by the proposal's L1 timestamp;
- every derived block is an Unzen block (`blocks_after_unzen`), because block timestamps
  strictly increase from the parent's and the execution engines pick header rules by each
  block's own timestamp;
- every non-genesis header reserves `ANCHOR_GAS_LIMIT` (1M) for the anchor transaction.

A boundary proposal lands after Unzen on a Shasta parent and can mix Shasta and Unzen blocks.
Every claim except `blocks_after_unzen` still describes it: the rules modeled here (768 limit by
L1 time, 1M reserve, 7-byte extra data, anchor first) are the same for its Shasta blocks, and
only engine-set header fields, which are excluded, differ.

The clients' Shasta-era branches and Etna are outside the model. Those branches are the 192-block
limit and the parent-anchor calldata decoding: both drivers use it for mainnet proposals 1–7,
and Go also for proposal 1 on any non-genesis parent.

## Claims to review

For a browser-friendly reading, open [`STATEMENTS.html`](STATEMENTS.html) locally. It puts
English explanations beside the exact Lean declarations, lists the supporting theorems, and
makes the premises and scope limits explicit. It is self-contained and works offline.

Start with [`DerivationStatements/Claims.lean`](DerivationStatements/Claims.lean), then
[`DerivationProofs/Claims.lean`](DerivationProofs/Claims.lean). The four headline theorems have
exactly the corresponding named proposition as their type; the audit rejects added premises
or a replacement conclusion at that boundary.

| Statement               | Theorem in `TaikoSpec.Derivation.Proofs` | Content                                                                                                                                                                                                     |
| ----------------------- | ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DerivationSafety`      | `derivation_safety`                      | Per-source cardinality, exact forced-source cardinality, prefix isolation, consecutive numbers, increasing timestamps with bounded fallback drift, monotone anchors, and conditional anchor/gas bounds.     |
| `HeaderSafety`          | `header_safety`                          | Header plans keep the derived blocks and the Unzen layout; the Anchor contract's recorded anchor follows the derived anchors; the parent rebuilt from the last header and that anchor continues derivation. |
| `ForcedInclusionSafety` | `forced_inclusion_safety`                | Exact accepted/default condition for a one-block forced manifest, missing-manifest fallback, and prefix isolation.                                                                                          |
| `Claims`                | `claims`                                 | Conjunction of the three claims above.                                                                                                                                                                      |

Statement names are under `TaikoSpec.Derivation.Statements`. Detailed lemmas are in
[`DerivationProofs/Properties.lean`](DerivationProofs/Properties.lean), including
`rust_order_agrees` and `rust_failure_agrees`. The Rust driver also inherits metadata before
validating a manifest that looks exactly like the default one, and it turns a failed extraction
into one all-zero block that it then inherits. Both give the same blocks as the Go order.

`HeaderSafety` ties derivation to the next proposal. Both drivers start a proposal from the
previous block's header (number, timestamp, gas limit) and from `Anchor.getBlockState()`.
`anchorV4` stores a checkpoint's block number only when it is greater than the recorded one, so
the recorded anchor is a running maximum (`recordedAnchors`). Because derived anchors never
decrease, it equals each block's own anchor number, and `rebuiltParent` (last header plus
recorded anchor) is exactly the parent derivation continues from. Within a proposal, Rust carries
each block's anchor number forward while Go re-reads the parent between sources; the
recorded-anchor clause is what makes the two agree.

## Premises and witnesses

`InitialParentBounds ctx p` supplies only the bounds needed for bounded anchors and manifest
gas: the parent's anchor is not after the proposal origin, and its effective manifest gas is
between the protocol minimum and maximum. Sequence and source-isolation conclusions do not
require this record. The gas range is 10M–45M, excluding the 1M header reserve.

[`DerivationWitnesses/Examples.lean`](DerivationWitnesses/Examples.lean) shows the premises are
satisfiable, accepted forced and proposer sources, a forced source dropped once the parent's
anchor is too old, and a two-source proposal with its header plans and rebuilt parent. These
examples show inhabitability; they are not a completeness result for assumptions.

## Specification traceability and exclusions

The manifest links every headline to actual headings in the pinned file and verifies its SHA-256
hash. Links and hashes are traceability, not a percentage of specification proved. Review these
sections alongside the statements:

- [Manifest extraction and fallback](../../packages/protocol/docs/Derivation.md#manifest-extraction),
  [metadata validation](../../packages/protocol/docs/Derivation.md#metadata-validation-and-computation),
  and [forced inclusion submission requirements](../../packages/protocol/docs/Derivation.md#forced-inclusion-submission-requirements).
- [Pre-execution block header](../../packages/protocol/docs/Derivation.md#pre-execution-block-header)
  and [the anchor transaction](../../packages/protocol/docs/Derivation.md#anchor-transaction).

The Anchor contract is trusted: `recordedAnchors` models `anchorV4`'s running maximum
(`Anchor.sol`, `_validateBlock`), and every anchor transaction is assumed to succeed.

Outside scope: blob field-element decoding and availability, and the split between retried
fetch errors and defaulted sources; authenticating L1 events, chain configuration and parent
inputs; the anchor's L1 block hash and state root and its signed encoding; sender
authentication and execution filtering; execution, zk gas, base fee and `mixHash`; header fields
the execution engine sets (`parentBeaconBlockRoot`, blob gas, `requestsHash`, `difficulty`);
Engine API serialization; bridge verification; L1 proof/bond settlement; consensus security;
decoder resource bounds; and guaranteed eventual inclusion or inclusion deadlines. A header
transaction plan contains manifest candidates, not a proof of executed transactions.

The model follows checked client behavior where prose differs:

- Version words below `2^64` are accepted when their low 32 bits equal 1, not only for `0x1`.
- Proposer anchor 0 is validated normally; it does not request inheritance from the parent.
- Forced sources can default when their inherited timestamp, anchor or gas fails validation.
  An exhausted timestamp window or a stale parent anchor can therefore discard candidates.
- Zlib, exact canonical RLP and transaction grammar are explicit decoder behavior beyond the
  prose's “decompress” and “decode” instructions.

Where the two drivers differ only outside reachable inputs, the model follows one of them:

- Extra data keeps the proposal ID's low six bytes, as Rust does; Go returns an error above
  uint48, and `Derivation.md` requires uint48 fields to fit. `Proposed.id` is a uint48, so all
  three agree on every real proposal.
- The 1M parent reserve subtraction truncates at zero; Go's uint64 subtraction would wrap.
  Real non-genesis headers always carry the reserve.

These differences are documented, not resolved by a hash pin. Specification changes intentionally
fail CI until the model, claims, exclusions and pins are reviewed together.

## Evidence and trust boundary

The shared corpus in [`testdata/derivation_vectors`](../../testdata/derivation_vectors) contains
136 unchanged manifest-decoding vectors, which the Go and Rust unit tests also read. The Lean
runner checks all 136. This command does not run Go/Rust suites or establish whole-client
equivalence. Header and validation cases are Lean regressions adapted from checked
implementations; no client adapter runs them.

The witness library keeps executable `#guard` regressions in exactly four files:
`Tests/Derive.lean`, `Manifest.lean`, `Rlp.lean` and `Zlib.lean`. They run during compilation and
are **not kernel proofs**. Header and validation cases are kernel-checked equality examples.
Kernel replay checks declarations in the resulting modules; it does not turn executed guards or
JSON vector runs into proofs.

The full gate combines independent checks:

1. Python lexes the accepted source subset, ignoring nested comments and escaped strings,
   and rejects proof escapes, metaprogramming commands and unreviewed compiler options.
   `#guard` is allowed only in those four regression modules. Model/Statements forbid source
   theorem/example commands. Built declarations additionally reject proof-valued definitions
   in these layers, while permitting generated lemmas and structure projections.
2. The import graph enforces downward library dependencies, existing modules and reachability
   from every library root. `Init`/`Std` imports are permitted; the sole explicit `Lean` import
   is `Lean.Data.Json` in `DerivationVectors.Main` for JSON IO.
3. The specification gate checks the exact source path, revision, hash, headline mappings,
   existing section headings and nonempty drift/exclusion explanations.
4. The separately compiled [`scripts/Audit.lean`](scripts/Audit.lean) dynamically inspects all
   five libraries. Every owned declaration may depend only on `propext`, `Classical.choice`
   and `Quot.sound`. It checks four exact headline types, named claim dependencies, premise
   field names, rejection of `True` premise fields, and live premise projections through package
   theorem calls.
5. `leanchecker` replays all five roots in Lean's kernel; the vector runner checks the corpus.

Mechanical limits: the source gate is a bounded lexer, not a complete Lean parser or adversarial
sandbox. Standard imports and the audit/CI scripts remain reviewable trusted tooling. The audit
removes unused lets and beta/letFun bindings before following theorem references, but records
field reads per structure, not per hypothesis. It can count a projection in a binder type or an
argument ignored by a callee; it does not unfold arbitrary definitions or recognize every
pattern-match use. Thus it can overcount or undercount use and does not prove logical necessity.
Named dependency anchors catch accidental erasure but not arbitrary weakening of statement
bodies. Review proposition meanings and premise relevance directly. Neither these checks nor
kernel replay prove that the model matches the prose, clients, authenticated inputs or runtime.
Executable tests also trust Lean's compiler/runtime; theorem checking trusts the Lean kernel
and the three standard axioms.

## Layout and validation

| Library                | Responsibility                   | Allowed package imports              |
| ---------------------- | -------------------------------- | ------------------------------------ |
| `DerivationModel`      | Executable definitions           | Model                                |
| `DerivationStatements` | Propositions and premise records | Statements, Model                    |
| `DerivationProofs`     | Detailed and headline proofs     | Proofs, Statements, Model            |
| `DerivationWitnesses`  | Examples and regressions         | Witnesses, Proofs, Statements, Model |
| `DerivationVectors`    | JSON manifest-vector runner      | Vectors, Model                       |

Audit tooling is outside these libraries in `scripts/`. Lean is pinned to 4.34.1, with no
third-party Lean packages. Install that toolchain through elan and use Python 3.11 or later.
From `formal/derivation`, the complete local and CI validation command is:

```bash
bash scripts/gate.sh
```

To inspect individual stages:

```bash
python3 scripts/check.py
python3 -m unittest discover -s scripts/tests -v
lake build
mkdir -p .lake/audit
lake env lean -o .lake/audit/Audit.olean scripts/Audit.lean
LEAN_PATH="$PWD/.lake/audit" lake env lean scripts/AuditTests.lean
LEAN_PATH="$PWD/.lake/audit" lake env lean --run scripts/RunAudit.lean
for library in DerivationModel DerivationStatements DerivationProofs DerivationWitnesses DerivationVectors; do
  lake env leanchecker "$library"
done
lake exe vectors ../../testdata/derivation_vectors/manifest_cases.json
```

Python mutations exercise malformed manifests, proof escapes, imports/reachability and spec drift.
Lean mutations exercise weakened/missing headlines, extra axioms, erased claim dependencies,
trivial/changed premise shapes, and live/transitive/dead/unused premise reads. CI runs on drafts
and watches the pinned specification, the package, shared corpus and workflow.
