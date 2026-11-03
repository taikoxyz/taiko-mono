# Etna design verification

The current authorities are `SPEC.md`, `ACCEPTANCE.md`, `ANCHORLESS.md` and `SWITCH.md`
under `packages/protocol/docs/etna`, pinned to main commit
`1135c9b24fd03f50cb48eab250879435fd54f528` (2026-11-03).

The current decoded model proves H1, H2, H3 and their conjunction under the explicit
`Etna.Statements.Current.Premises`. This is conditional design verification, not production
conformance or launch readiness. Operational acceptance measurements remain deferred.

## Current H1–H3

Read `EtnaStatements/Current.lean` for the exact claims and nine named premise fields, then
`EtnaProofs/Headline/Current.lean` for their composition. The closed machine in
`EtnaModel/CurrentProtocol.lean` implements each modeled call and failed-call rollback;
its `Trace` has no caller-supplied custody, slashability or queue-service invariant.

| Claim                     | Derived result                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| H1 — fund safety          | Every recognized Etna signal and accepted landing edge has full-header custody, rooted in accepted genesis or the authenticated Unzen first fence. Pending/refused starts assert no authenticity. Actual overlap suffixes compose across correction, recovery, rollback and all other calls.                                                                                                                                                               |
| H2 — accountable finality | Same-round conflicting commits expose more than one third of power with persistent historical evidence, including displaced and later-generation bonds. Future paid slashes use the actual atomic token wrapper, conditional on standard transfer semantics and available balance. Honest stock-Comet round rules imply agreement of all overlapping headers within one World/generation from the same full origin header, using each chain's own archive. |
| H3 — forced inclusion     | Complete end-block journals authenticate actual queue entries. Accepted landings consume exactly `[oldHead,newHead)` in order; inclusive due/late bounds force canonical position-zero inclusion or a legal completed skip. Nonlanding calls cannot advance head; recovery clears exactly its listed hashes.                                                                                                                                               |

Per-block timestamp selection permits batches crossing `rulesTime`. S-relative grids,
absolute committee epochs, fresh first-generation anchors, permanent bond IDs, structural
K recovery and the Unzen fence use current definitions. The selected catalogue fixes
EL/payload/parser/singleton interpreters; a named refinement binds every interpreter's
transaction hash to the fixed admission/clearing hash.

The remaining premises concern backend statement soundness, authenticated decoded header
and Unzen bindings, token/signature refinement, deterministic Comet/EL codecs, honest
round executions and vote attribution, and strictly increasing canonical L1 timestamps.
The Byzantine-minority/honest-round condition is an explicit H2 agreement antecedent; H1 and H3
require no committee honesty. They do not assert any of the three headline conclusions. Unknown arbitrary DAO-installed
code, image-combination availability, stock-store import implementation and node-engine
refinement are outside these decoded safety claims. Node publication preserves signer
state and grants no trust; validated replay remains an explicit application abstraction.

Positive fixtures exercise nonempty accepted batches, overlap, corrected Unzen starts,
cross-ruleset byte actions, historical-evidence payments and recovery/rollback. Their
finite test adapters are not a complete realization of the global cryptographic premises.
Do not read executable acceptance fixtures as a production soundness proof.

There are **195 current exact theorem contracts** (including supporting obligations).
The [alignment report](reports/latest-design-alignment.md) describes exact evidence and
limits. [Rule traceability](reports/rule-coverage.md) covers **635 live IDs**, including
603 binding rules. The four authorities have **566 clauses: 24 partial, 542 deferred**.
“Partial” means a narrow theorem edge, not proof of the entire clause or a coverage rate.

## Historical results are separate

All **1,216 original theorem/type pairs**, including the original H1–H3 claims, are retained
against independently pinned `legacy/2026-10-30` snapshots. Their 405-clause inventory
(101 partial, 301 deferred, 3 then-design-pending) and 34 claims remain historical.
Model definitions outside `Etna.Design.Current` keep that original decoded machine. The original
JSON conformance vectors also remain historical; they do not establish current conformance.

The [historical report](reports/historical-verification.md) and
[historical rule map](reports/historical-rule-coverage.md) describe those versions.
Source checks reject historical proof edges in live clauses and claims mixing authorities.

## Verification

Use the exact compiler in `lean-toolchain`: Lean 4.35.0-rc4, Init/Std only. From `formal/etna`:

```sh
python3 scripts/lint_sources.py
python3 scripts/check_imports.py
lake build
python3 scripts/check_vectors.py
python3 scripts/generate_artifacts.py
python3 scripts/generate_artifacts.py --check
python3 scripts/check_spec_coverage.py
python3 scripts/rule_coverage.py --check
python3 scripts/audit_proofs.py
python3 -m unittest discover -s tests -v
```

Run the build/audit before the Python suite; both use shared compiled artifacts. The audit
checks **1,411 exact theorem contracts**, mechanical roles, derivation chains, transitive
axioms, library placement and fresh whole-kernel replay. Both current and historical
headline types and premise-field use are mandatory, even if a manifest entry is deleted.
Every Lean regression module is replayed with zero diagnostics. The final local run passed
all **478 Python tests** and **31 Lean regression modules**.

CI watches all four current authorities, including `SWITCH.md`. No execution plans or
`docs/superpowers` artifacts are tracked.
