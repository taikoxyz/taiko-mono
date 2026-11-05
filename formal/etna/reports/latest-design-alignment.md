# Latest Etna design alignment

Authorities: main `e84a9aaac526c15597d97ee93f8803f92b02c279` (2026-11-04) for SPEC,
ACCEPTANCE, ANCHORLESS and SWITCH, unchanged since [the #22335 alignment](alignment-22335.md).
This revision changes the package shape, not the decoded model, statements or proofs.

## Current-only package

The archived 2026-10-30 layer was removed. It remains readable at formal revision
[`583bc2620`](https://github.com/taikoxyz/taiko-mono/tree/583bc2620258838e75ce353c11f9344616ac1020/formal/etna).

- The set to keep was computed, not hand-picked: the transitive constant closure (types and
  values) of every declaration in a `Current*` module and of the names the current tests use.
  107 library modules and 21 Lean regression files outside that closure were deleted, and the
  unused declarations of 21 shared modules were removed by their exact declaration ranges.
- Thirty-four shared declarations outside `Current` stay as reviewed unsourced plumbing:
  twenty lemmas the current proofs reuse, and fourteen semantic pins on shared definitions the
  statements use (`EtnaProofs/Contracts.lean`, `Consensus.election_valid_iff`). The other 54
  archived pins referenced definitions outside the current review surface. Every definition the statements use is also
  covered by the review-surface lock.
- Removed with the layer: the historical statements and headlines, the legacy authority copies,
  `testdata/etna_conformance` (implementation pull requests keep their own copies), the
  historical reports and their Python tests.
- The manifest holds 640 exact contracts (606 current, 34 shared), down from 1,822. Clause and
  rule evidence is unchanged: 38 partial / 528 deferred clauses; 41 partial / 35 supporting /
  527 deferred binding rules.
- The toolchain is stable Lean 4.35.0 (was 4.35.0-rc4).

## Statement lock

`review-surface.lock.json` hashes the kernel terms of the four headline theorems, the five
joint-premise witnesses and every Etna definition they use (1,417 constants; proofs excluded).
CI compares it with the base branch using the base revision's copy of `scripts/review_surface.py`;
a change to the lock or to a gate file needs the `formal-statement-change` label.

## Local validation (macOS, Lean 4.35.0)

- Fresh `lake build` from an empty `.lake/build`: 90 jobs, 3 min 21 s, no warnings.
- `lint_sources`, `check_imports` (84 modules), `check_spec_coverage`, `rule_coverage --check`,
  `check_current_vectors`, `review_surface --check` and `generate_artifacts --check` pass.
- `audit_proofs.py`: 640 exact contracts, mechanical roles, allowed axioms, shadowing, library
  contents, headline claims, all fifteen premise fields read by a headline proof, fresh
  whole-kernel replay and 29 Lean regression modules; 150 s on the final tree.
- Fast suite (`python3 -m unittest discover -s tests`): 194 tests in 227 s, OK; 20 skipped
  (the 17 mutation modules and two slow gate classes).
- Full suite (`ETNA_FULL_TESTS=1`): 342 tests in 1,497 s with two failures, both
  `test_current_headlines` tests that call `EtnaAudit.dependencies`, which had been removed
  as dead code. It was restored; the 12 headline tests then pass, and the fast suite above
  includes them. The other 340 tests passed in that run.
- `lake check --paranoid` needs bubblewrap, which macOS lacks; it runs in the nightly CI job.
