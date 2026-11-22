# Etna quorum-feasible traces implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development with
> independent source review and independent behavioral verification. Root owns
> final validation and existing-draft publication; authors do not commit early.

**Goal:** Check the current draft's source correspondence and selected continuous
stake traces under separate strict parent and current quorum constraints.

**Architecture:** Add one immutable power/domain wrapper around the preserved
historical boundary model, its source manifest and source-derived tests.

**Tech Stack:** Python standard library, managed Python, Git/gh, inspected
network-disabled disposable test copies.

**Spec:** `docs/superpowers/specs/2026-11-22-etna-quorum-feasible-traces-design.md`.

## Global Constraints

- Source is unmerged draft178d7a7a; source69 evidence remains historical.
- No production/SPEC/Notion/comments/reviews/native engines/live calls/signing,
  keys, dependency installation, merge or mark-ready.
- Old model6065102a, source.json, runtime classifiers, bundles, claims and all
  old TLA/config inputs remain byte-identical. No draft runtime admission.
- Model abstract flags/availability only; no cryptographic, full-consensus,
  global reachability, production quotient or unconditional liveness claim.
- One implementation writer; separate source reviewer and behavioral verifier.
- Stop for an independently supported normal-path protocol defect.

## Review Focus

- Exact2/3 is insufficient, nil contributes no block power and unequal weights
  must not be replaced by validator counts.
- Parent uses current_signers, produced block uses next_signers, and neither
  may borrow keys or powers from pending_signers or their union.
- LastCommit omission and prior eligibility differ; a nil/commit cannot be
  attributed to a key explicitly unavailable at the parent height.
- A stalled block applies no penalties, actions or newly observed anchor and
  cannot jump to a future fallback. Valid retry retains its predecessor.
- Complete witness shape, exact integer domains and all refusals remain safe
  under Python optimization; a failed block-start call is not a stalled block.

### Task 1: Current-source correspondence

**Files:** Create `formal/etna/L2_QUORUM_REVIEW.md`,
`formal/etna/draft_rules/quorum_source.json`, this plan and its design.
**Owner:** Root, independently reviewed source analysis.
**Interfaces:** Fixed71 changed blobs from base360 to draft178; full20-file
delta from69; five document SHA256 values. No source/model admission side effect.

- [x] Verify exact source versions, all71 Git blob identities and the20-file
  delta; review changed normative clauses, vectors and acceptance independently.
- [x] Record new and preserved obligations, proof-origin witness interpretation,
  block-start abstraction boundary and non-normative index discrepancies.
- [x] Run the current rule corpus in the inspected exact-base disposable view;
  report migration purity separately and preserve the old evidence inventory.

### Task 2: Quorum-constrained transition projection

**Owner files:** Create only `formal/etna/draft_rules/quorum.py` and
`formal/etna/tests/test_l2_quorum.py`. Root owns all other files and execution.
**Inputs:** Existing public model types Config, Member, Selection, Anchor,
Action, State, Transition. Existing internal validators may be reused rather
than duplicated; the old module must not be edited.
**Interfaces:** Frozen dataclasses `FlagVote(key:str,flag:str)`,
`LastCommit(generation:int,height:int,votes:tuple[FlagVote,...])`,
`Availability(generation:int,height:int,keys:tuple[str,...])`;
`committed_power(selection,commit,*,generation,height)->int` and
`available_power(selection,availability,*,generation,height)->int` validate a
strict quorum and return its contributing power, otherwise raise ValueError.
`advance_with_quorum(state,anchor,*,parent,available,previous_available=None,
actions=(),block_start_ok=True)->Transition` implements the design's sequence.
The optional previous availability uses the parent's set/domain and disallows
commit or nil from unavailable keys. No wire decoder or full chain domain.

- [x] First write focused tests and an API-only missing implementation. Root
  inspects the entrypoints and observes real RED in an offline disposable copy.
  Do not implement bodies or run code until that GO.
- [x] Implement minimal immutable explicit validation and strict power gates;
  malformed origin/non-origin parent, duplicate/unknown/missing rows, flags,
  domains, invalid selections and availability keys must refuse atomically.
- [x] Tests cover the independent oracle's numerical seven-height trace,
  candidate/fallback changes, unequal-power same-key sets, persistent misses,
  reseating to a different live seat, failed-call/exit, counter reset and retry.
  Add the finite all-flags arithmetic bank for powers1..3 and members1..4,
  explicitly assert refusals at exact2/3, not just successful outputs.
- [x] Root runs focused normal/-O GREEN; independent verifier builds its bridge
  against its previously frozen hand oracle and executes normal/-O cases.
- [x] Independent private-copy mutations test strictness, parent/current set
  confusion, nil-as-commit, offline nil and gate-after-transition mistakes.
  Require semantic failures and exact restoration; never mutate canonical code.
- [x] Independent complete two-file source/quality review and same-finder repair
  rechecks before committing. Author reports full risks; does not push or commit.

### Task 3: Accumulated verification and publication

**Owner files:** Root updates `formal/etna/WORKLIST.md`, `REPORT.md`,
`L2_QUORUM_REVIEW.md`, `draft_rules/README.md` by append and this plan.
**Interfaces:** Reviewed immutable candidate, independent behavioral report,
the old evidence identity map and current whole-suite output.

- [x] Compare the complete old artifact map; run focused documentation tests
  and complete ordinary suites in supported360/f556 contexts, retaining all
  failures. No extra local TLC run if unchanged inputs/runner and no new concern.
- [x] Review complete intended-base diff, path hygiene and the three most
  plausible errors: mistaken signer-set domain, impossible sequential witness,
  and overstated current-source/runtime coverage. Fix confirmed in-scope issues.
## Required post-commit publication receipts

After the immutable closing commit, normal-push only the existing draft branch,
synchronize only PR22387/issue22355's owned status prefix and read back exact
head/draft/open plus preservation of every outside byte. Observe the exact
new-head CI and audit its evidence. Record these external receipts in the
monitor ledger, mark the selected stage complete and return to feedback-only.
This checked-in local-gate record does not claim a future publication or CI
outcome. No new stage starts automatically.
