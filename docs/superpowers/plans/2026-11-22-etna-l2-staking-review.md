# Etna L2 Staking Review Implementation Plan

> **For agentic workers:** Use the established subagent-driven implementation,
> independent source review and independent behavioral verification workflow.

**Goal:** Review the L2-staking draft and add a bounded executable model for its
new committee/penalty/commit boundaries without transferring historical claims.

**Architecture:** A separate draft-only symbolic model and tests, immutable
source provenance, and a source/evidence disposition report. Existing production
and native receipt guards remain unchanged.

**Tech stack:** Python standard library, managed Python, Git/gh, inspected
network-disabled disposable test copies.

**Spec:** `docs/superpowers/specs/2026-11-22-etna-l2-staking-review-design.md`;
normative source PR22425 at `69e26df443e9b5a0f05127d4179e4833fc95823c`.

## Global constraints

- No production/SPEC/Notion changes, GitHub comments/reviews, merges or mark-ready.
- No native engines/proofs/live calls/signing/keys/dependency installs.
- Old source bundles, claims, models/configs and raw evidence retain their pins.
- Symbolic keys and pre-authenticated anchors are assumptions, not crypto checks.
- Actual normal-path protocol defects stop for user discussion; acknowledged
  limitations and an unverified exceptional repair obligation are distinct.

## Review focus

- A transaction cannot rewrite the snapshot taken before it in the same block.
- Old occupant misses cannot punish a new occupant after parent-state seat reuse.
- A full-width stale height and a maximal stored total cannot bypass fallback.
- Power-only changes require intermediate commit checks; labels alone do not.
- A failed block-start call preserves its state while the valid block continues.

### Task 1: Fixed source and independent interface review

**Files:** Create `formal/etna/L2_STAKING_REVIEW.md` and this plan/design.

- [x] Pin main and PR head/state; download all70 changed files and recompute each
  Git blob identity. Pin five core document SHA256 values in the model manifest.
- [x] Independently review committee/origin/fallback and miss/seat/exit/forfeit
  paths; inspect cross-file acceptance/vectors as source, not executed tests.
- [x] Record the root proof/landing/back-pressure assessment, old evidence
  invalidation map and concrete new implementation/resource obligations.

### Task 2: Draft-only executable boundary model

**Owner files:** Create `formal/etna/draft_rules/__init__.py`, `l2_staking.py`,
`source.json`, `README.md`, and `formal/etna/tests/test_l2_staking_model.py`.

**Interfaces:** The author publishes the typed `Config`, `Member`, `Snapshot`,
`Anchor`, `Bond`, `Action`, `State`, `Transition` records and the public functions
`initial_state`, `advance`, `derive_set`, `required_commits` in the initial test
proposal. Root and independent verifier freeze that proposal before execution.
`State` tracks the live seats/bonds, miss counters, last snapshot and three
successive signer sets. `advance` executes the block-start call before actions,
then shifts the H/H+1/H+2 pipeline. `required_commits(p,h,sets)` returns sorted
heights including h and exactly the interior key/power-change boundaries.

- [x] Write focused source-derived tests and API proposal first; root inspects
  imports/entrypoints and observes genuine RED in an offline copy.
- [x] Implement only the selected model/manifest/guide. Use immutable state;
  explicit refusal and numeric checks cannot disappear under Python optimization.
- [x] Check X+3/H+2 timing, origin first-two sets, call failure, seat reuse,
  fallback-key alias, sentinel/full-height/invalid-set/power boundaries and
  range endpoints/power-only changes. Report exact finite bank sizes, no broad
  exhaustive or deployable-unit claim.
- [x] Run focused GREEN and a separately frozen oracle; perform semantic guard
  mutations/restorations in disposable copies. No canonical mutation.
- [x] Independent complete-diff source review, independent behavioral checks and
  same-finder recheck of material repairs; accepted local candidate ready to commit.

### Task 3: Whole-scope verification and existing-draft publication

**Owner files:** Root updates `formal/etna/WORKLIST.md`, `REPORT.md`, the new
review report and plan; existing PR22387/issue22355 owned prefix only.

- [x] Preserve and compare old classifiers/claim inventories/source ledgers,
  model/config hashes and all19 archived INCONCLUSIVE dispositions.
- [x] Run focused documentation checks and complete ordinary suites in the
  supported360/f556 contexts. Re-run TLC only if its inputs/runner changed or a
  new concern requires it; otherwise identify the retained493 exact-outcome run.
- [x] Independent accumulated source/behavior/evidence review; inspect full
  intended-base diff and path hygiene before commit/push.

## Required post-commit publication receipts

After the immutable closing commit, normal-push the existing draft, synchronize
only its and issue22355's owned status prefix, and read back exact head/draft,
body preservation and actual new-head CI. Record those external receipts in the
monitor ledger and current PR prefix, then return to feedback-only. These are
observed after commit, not predicted by this checked-in local-gate snapshot.

## Scope after this round

Current draft admission/implementation, real staking/EL/guests, message transport,
proof cost and deployment remain unverified. The model is one selected finite
boundary bank; it does not close those dependencies or all changed rules.
