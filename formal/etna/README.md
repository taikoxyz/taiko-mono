# Etna design verification

The current authorities are `SPEC.md`, `ACCEPTANCE.md`, `ANCHORLESS.md` and `SWITCH.md`
under `packages/protocol/docs/etna`, pinned to main commit
`1135c9b24fd03f50cb48eab250879435fd54f528` (2026-11-03).

This is partial design verification over decoded inputs. It does not establish production
conformance, launch readiness, or complete H1–H3 safety for this latest specification.

## Current results

`EtnaModel/Current.lean` and `EtnaProofs/Current.lean` define and prove selected changed
rules in the `Etna.Design.Current` namespace:

- Anchor-selected timestamp rules, owner-only scheduling, strict rescheduling deadlines,
  48-bit field checks, planned stops relative to S, and recovery's rules-number/stop reset.
  Batches may cross `rulesTime`; every covered block must use an implemented ruleset.
- Permanent bond IDs separate from 4096 slots, admission using effective plus pending
  stake with lowest-slot tie breaking, displacement retaining the old bond's liabilities,
  and withdrawal retaining issued/key identity without clearing a replacement's slot.
  Trace induction establishes monotone issuance and permanent key-to-id lookups.
- S-relative landing grids, absolute epochs, the first generation block's origin-only
  anchor floor, the Unzen first-landing fence, one-time origin writes and new-generation
  start correction. Trace induction preserves all prior origin records.
- Import candidate rejection versus authenticated-contradiction safety halt, durable
  publication with the full o..s header-number range, unchanged signer state and no
  automatic checkpoint trust. L1/MPT/Comet metadata authentication is a named adapter
  boundary; this is not an implementation of the complete stock-store importer.

There are **27 current exact theorem contracts**: 6 induction-derived properties and
21 supporting results. `tests/CurrentDesign.lean` supplies concrete boundary cases;
`tests/test_current_mutations.py` weakens semantic guards and requires the unchanged
evidence to reject them after each model-only mutant compiles.

The [alignment report](reports/latest-design-alignment.md) gives exact theorem names,
authority boundaries and remaining work. [Rule traceability](reports/rule-coverage.md)
uses the latest SPEC/INDEX and has **635 live IDs**, including 603 binding rules.
The four current sources contain **566 clauses: 4 partial, 562 deferred**. “Partial” is
narrow evidence linkage, not proof of an entire clause or a coverage percentage.
Acceptance measurements and the operational switch rehearsal remain deferred.

## Historical results are separate

All **1,216 original theorem/type pairs**, including the original H1–H3 claims, are retained.
They cite exact snapshots in `legacy/2026-10-30`, not the live specification. Their original
405-clause inventory (101 partial, 301 deferred, 3 then-design-pending) and 34 claims remain
historical. The latest upgrade mechanism is specified; those old three pending clauses do
not describe its current status.

Definitions outside `Etna.Design.Current` retain the original decoded machine. In
particular, its slot-ID reuse, zero-origin grid and conditional height-upgrade sketch
must not be used as current Etna semantics. Their proofs remain useful historical
results, without a theorem connecting the whole current machine to those headlines.
The existing JSON conformance vectors also remain historical.

The [historical verification report](reports/historical-verification.md),
[historical rule map](reports/historical-rule-coverage.md) and older reports describe those
pinned versions. The source checker rejects an old theorem linked into a live clause and
rejects claims mixing the two authorities; historical evidence cannot inflate current
coverage.

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

The audit checks exact types, theorem roles, derivation chains, transitive axioms, library
placement, original headline types/premise use and fresh whole-kernel replay. It also
replays every Lean regression module with zero diagnostics. The manifest has **1,243
contracts** in total. Generated audit/inventory output lives in ignored `.scratch`.

CI watches all four current authorities, including `SWITCH.md`. No execution plans or
`docs/superpowers` artifacts are tracked.
