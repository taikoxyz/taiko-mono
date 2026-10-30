# Derivation verification

This package proves safety properties of an executable Lean model of Taiko block derivation.
It pins both specification files at revision `d4d18d398936f3fb3fce43f34f0a3b3ebc917d00` in
[`spec-coverage.json`](spec-coverage.json). Its five-library organization and review gates follow
the delivery style of [#22292](https://github.com/taikoxyz/taiko-mono/pull/22292).
The theorems concern this model; they do not establish equivalence of production clients.

## Claims to review

Start with [`DerivationStatements/Claims.lean`](DerivationStatements/Claims.lean), then
[`DerivationProofs/Claims.lean`](DerivationProofs/Claims.lean). The four headline theorems have
exactly the corresponding named proposition as their type; the audit rejects added premises
or a replacement conclusion at that boundary.

| Statement               | Theorem in `TaikoSpec.Derivation.Proofs` | Content                                                                                                                                                                                                 |
| ----------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DerivationSafety`      | `derivation_safety`                      | Per-source cardinality, exact forced-source cardinality, prefix isolation, consecutive numbers, increasing timestamps with bounded fallback drift, monotone anchors, and conditional anchor/gas bounds. |
| `HeaderSafety`          | `header_safety`                          | Successful whole proposals preserve derived blocks, apply each child's fork policy, and conditionally preserve canonical L1 state-root correspondence through the final parent.                         |
| `ForcedInclusionSafety` | `forced_inclusion_safety`                | Exact accepted/default condition for a one-block forced manifest, missing-manifest fallback, and prefix isolation.                                                                                      |
| `Claims`                | `claims`                                 | Conjunction of the three claims above.                                                                                                                                                                  |

Statement names are under `TaikoSpec.Derivation.Statements`. Detailed stronger lemmas remain
in [`DerivationProofs/Properties.lean`](DerivationProofs/Properties.lean) and the other proof
modules. The model retains existing executable behavior and `TaikoSpec` namespaces.

## Premises and witnesses

`InitialParentBounds c ctx p` supplies only the bounds needed for bounded anchors and manifest
gas: the parent's anchor is not after the proposal origin, and its effective manifest gas is
between the protocol minimum and maximum. Sequence and source-isolation conclusions do not
require this record. The gas range is 10M–45M, excluding the pre-Etna header reserve.

`HeaderPremises c hc hp history` contains two independent authentication assumptions:

- `lookupsSound`: every available L1 lookup agrees with canonical `history`.
- `parentAuthenticated`: the initial non-genesis Etna parent commits to that same history.

Lookups may be unavailable. A reused anchor needs no new lookup; construction requiring a
missing root fails. Genesis does not authenticate a parent root. Header layout and sequence
preservation do not require these premises. Claims assert safety of successful construction,
not that construction succeeds, or that an arbitrary RPC response authenticates itself.

[`DerivationWitnesses/Premises.lean`](DerivationWitnesses/Premises.lean) contains kernel-checked
examples with concrete roots 17 and 29:

- `nonempty_proposal_under_premises`: both premise records hold and two sources produce two
  actual headers. This witness uses the allowed missing-manifest defaults.
- `forged_initial_root_counterexample`: sound lookups alone cannot authenticate a forged
  reused initial root; a successful proposal can return a noncanonical Etna commitment.
- `unsound_lookup_counterexample`: an authenticated parent alone cannot authenticate an
  unsound lookup at the first Etna block.

Existing accepted forced/proposer examples remain in
[`DerivationWitnesses/Examples.lean`](DerivationWitnesses/Examples.lean). These examples show
inhabitability and concrete failure modes; they are not a completeness result for assumptions.

## Specification traceability and exclusions

The manifest links every headline to actual headings in the two pinned files and verifies
both SHA-256 hashes. Links and hashes are traceability, not a percentage of specification proved.
Review these sections alongside the statements:

- [Manifest extraction and fallback](../../packages/protocol/docs/Derivation.md#manifest-extraction),
  [metadata validation](../../packages/protocol/docs/Derivation.md#metadata-validation-and-computation),
  and [forced inclusion submission requirements](../../packages/protocol/docs/Derivation.md#forced-inclusion-submission-requirements).
- [Fork-dependent header fields](../../packages/protocol/docs/Derivation.md#fork-dependent-header-fields)
  and [Etna blocks](../../packages/protocol/docs/Derivation.md#etna-blocks-without-an-anchor-transaction).
- [Etna header design](../../packages/protocol/docs/etna/ANCHORLESS.md#2-header)
  and [fork/migration](../../packages/protocol/docs/etna/ANCHORLESS.md#8-fork-and-migration).

Outside scope: blob field-element decoding and availability; authenticating L1 events, chain
configuration and parent inputs; signed system-anchor encoding; sender authentication and
execution filtering; execution, zk gas, base fee and mixHash; Engine API serialization;
EIP-4788 state updates; bridge verification; L1 proof/bond settlement; consensus security;
decoder resource bounds; and guaranteed eventual inclusion or inclusion deadlines.
A header transaction plan contains manifest candidates, not a proof of executed transactions.

The inherited model follows checked client behavior where prose differs:

- Version words below `2^64` are accepted when their low 32 bits equal 1, not only for `0x1`.
- Proposer anchor 0 is validated normally; it does not request inheritance from the parent.
- Forced sources can default when their inherited timestamp, anchor or gas fails validation.
  An exhausted timestamp window or a stale parent anchor can therefore discard candidates.
- Zlib, exact canonical RLP and transaction grammar are explicit decoder behavior beyond the
  prose's “decompress” and “decode” instructions.

These differences are documented, not resolved by a hash pin. Specification changes intentionally
fail CI until the model, claims, exclusions and pins are reviewed together.

## Evidence and trust boundary

The shared corpus in [`testdata/derivation_vectors`](../../testdata/derivation_vectors) contains
136 unchanged manifest-decoding vectors. The Lean runner checks all 136. This command does not
run Go/Rust suites or establish whole-client equivalence. There are no shared header vectors
executed by client adapters in this package; the header cases are Lean regressions adapted from
checked implementations.

The witness library retains 100 executable `#guard` regressions in exactly five files:
`Tests/Derive.lean`, `Etna.lean`, `Manifest.lean`, `Rlp.lean` and `Zlib.lean`. They run during
compilation and are **not kernel proofs**. The 55 former Header/Validation guards are now
kernel-checked equality examples. The named premise witnesses and counterexamples are theorems.
Kernel replay checks declarations in the resulting modules; it does not turn executed guards
or JSON vector runs into proofs.

The full gate combines independent checks:

1. Python lexes the accepted source subset, ignoring nested comments and escaped strings,
   and rejects proof escapes, metaprogramming commands and unreviewed compiler options.
   `#guard` is allowed only in those five regression modules. Model/Statements forbid source
   theorem/example commands. Built declarations additionally reject proof-valued definitions
   in these layers, while permitting generated lemmas and structure projections.
2. The import graph enforces downward library dependencies, existing modules and reachability
   from every library root. `Init`/`Std` imports are permitted; the sole explicit `Lean` import
   is `Lean.Data.Json` in `DerivationVectors.Main` for JSON IO.
3. The specification gate checks the exact source paths, revision, hashes, headline mappings,
   existing section headings and nonempty drift/exclusion explanations.
4. The separately compiled [`scripts/Audit.lean`](scripts/Audit.lean) dynamically inspects all
   five libraries. Every owned declaration may depend only on `propext`, `Classical.choice`
   and `Quot.sound`. It checks four exact headline types, named claim dependencies, premise
   field names, rejection of `True` premise fields, and live premise projections through package theorem calls.
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

| Library                | Responsibility                            | Allowed package imports              |
| ---------------------- | ----------------------------------------- | ------------------------------------ |
| `DerivationModel`      | Executable definitions                    | Model                                |
| `DerivationStatements` | Propositions and premise records          | Statements, Model                    |
| `DerivationProofs`     | Detailed and headline proofs              | Proofs, Statements, Model            |
| `DerivationWitnesses`  | Examples, counterexamples and regressions | Witnesses, Proofs, Statements, Model |
| `DerivationVectors`    | JSON manifest-vector runner               | Vectors, Model                       |

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
and watches both pinned specifications, the package, shared corpus and workflow.
