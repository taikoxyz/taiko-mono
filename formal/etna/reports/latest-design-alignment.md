# Latest Etna design alignment

Authorities: main `589b542de790861efd8b4d9bb0a4b1d066c2685f` (2026-11-05) for SPEC,
ACCEPTANCE, ANCHORLESS and SWITCH. This revision aligns the model with #22338. Checkpoint records,
cuts, `LandInput` and the statement carry the validator-state hash; app import retains EL headers
from max(o, s − U + 1); its inspection handles the validator-state preimage. H3's import clause
changes accordingly. [The #22338 alignment](alignment-22338.md) has the details. The sections
below describe the current-only package and statement lock introduced by the previous revision.

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
- The manifest holds 643 exact contracts (609 current, 34 shared), down from 1,822 before the
  removal. Evidence after #22338: 38 partial / 529 deferred clauses; 41 partial / 35 supporting /
  530 deferred binding rules.
- The toolchain is stable Lean 4.35.0 (was 4.35.0-rc4).

## Statement lock

`review-surface.lock.json` hashes the kernel terms of the four headline theorems, the five
joint-premise witnesses and every Etna definition they use (1,430 constants after #22338;
proofs excluded).
CI compares it with the base branch using the base revision's copy of `scripts/review_surface.py`;
a change to the lock or to a gate file needs the `formal-statement-change` label.

## Local validation (macOS, Lean 4.35.0)

- Fresh `lake build` from an empty `.lake/build`: 90 jobs, 2 min 59 s, no warnings.
- `lint_sources`, `check_imports` (84 modules), `check_spec_coverage` (567 clauses),
  `rule_coverage --check`, `check_current_vectors`, `review_surface --check` (1,430 constants)
  and `generate_artifacts --check` pass.
- `audit_proofs.py`: 643 exact contracts, mechanical roles, allowed axioms, shadowing, library
  contents, headline claims, all fifteen premise fields read by a headline proof, fresh
  whole-kernel replay and 29 Lean regression modules; 167 s.
- Full suite (`ETNA_FULL_TESTS=1`, which includes every fast test): 348 tests in 1,594 s, 347
  passed. The failure was the new window mutant. It left `unsettled` unused, so the mutated
  model compiled with a warning that the harness rejects, and it was checked only against the
  light fixture. It now uses `min` and the full fixture; the 28-test mutation module then
  passed in 294 s.
- `lake check --paranoid` needs bubblewrap, which macOS lacks; it runs in the nightly CI job.
