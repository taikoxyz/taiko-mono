# Etna anchor, proof and recovery implementation plan

> Required workflow: superpowers:subagent-driven-development. Root alone owns
> execution GO, source choices and readiness. No child subagents.

**Goal:** Verify the source178 composition of actual L1 settlement, lagged adopted
anchors, immutable proofs, trust gating and recovery at explicit finite bounds.
**Spec:** docs/superpowers/specs/2026-11-23-etna-anchor-proof-recovery-design.md
**Baseline:** f5ca696e1f2fb966be76971075b5194de423aaa7.
**Tools:** existing TLC1.7.4/JRE17, managed Python for isolated data readers.

## Global Constraints

- Preserve every old TLA/config/model/fixture/claim/classifier and all raw ledgers.
  Only existing REPORT append, WORKLIST/COVERAGE current indexes and the default
  count guard may change in addition to new stage files.
- Pin draft178/main360 and the independently frozen source oracle before model
  authoring. Never treat an operating premise as a proved normal-path fact.
- Keep actual Inbox, own-finalized view and adopted anchor distinct. Immutable
  jobs retain full p-to-h data and cuts; land uses execution-time actual c.
- Exact cut is height/EL/Comet/FI; saved state and origin fallback are identities,
  not height-only aliases. No old activeSnapshot statement field.
- Core bounds S10,U3,unit4Q/two four-key fallback sets,one recover; resource
  budget131072/window8191 use actual sparse L1 numbers from the oracle.
- One canonical model writer. No engine before root exact packet/source GO.
  Existing offline TLC45s/512MiB/one worker/seed1; no dependencies or native clients.
- No production/SPEC/Notion/comments/reviews/live/signing/keys/deploy/merge/ready.
  Existing draft normal push and owned body prefix remain authorized after gates.
- Preserve worktree/ignored ledgers and all partial/failed/UNRUN evidence.

## Review Focus

1. Advancing actual c or own finality must not rewrite a retained block's anchor,
   age, backpressure or historical H+2 committee calculation.
2. A short landing must not mutate an earlier full long proof. Check all current-c
   tuple fields, exact suffix application, actual parent and non-tip landing.
3. Pending trust/EL-only comparisons and generation-only recovery observations
   must hold signing closed; failed reads cannot forget a known target.
4. Recovery restores checkpoint14 rather than old tip15, keeps fixed R.F for
   first two blocks despite later G, and rejects old-domain jobs.
5. Distinguish p-only M/F authority from ordinary new/inherited anchors, and
   distinguish actual source-valid rollback from an unproved governance premise.

### Task 1: Freeze source contract, literal fixtures and builder review

**Owner:** root source/report metadata; independent source oracle in private tmp.
**Files:** new draft_rules/anchor_proof_source.json, anchor_proof_oracle.json,
anchor_proof_supplement.json, ANCHOR_PROOF_RECOVERY_CONTRACT.md.
**Consumes:** complete pinned178 normative source, old source pins, baseline byte map.
**Produces:** immutable fixture hashes and exact model/observer interface below.

- [x] Verify relevant normative blobs and copy source-derived fixtures unchanged.
- [x] Resolve sparse L1 ancestry/outage and normal/adversarial control premises.
- [x] Independent builder/source review of spec/plan and all fixture identities.
- [x] Write preflight interface table and root rulings; no engine or model yet.

### Task 2: New product, finite profiles and real RED/GREEN

**Owner:** one fresh implementer, new EtnaAnchorProofRecovery.tla and configs only.
**Files:** formal/etna/EtnaAnchorProofRecovery.tla; configs/apr-*.cfg;
ANCHOR_PROOF_RECOVERY_VIEW.md if an observation view is used.
**Consumes:** Task1 exact independent fixture and source contract.
**Produces:** s/receipt/cursor state product; shared actual dispatch; independent state,
proof, cut, signer, committee, recovery/frame safety checks and named observations.

Exact planned configs: apr-micro (PASS); apr-reach-pressure (NoPressureRefusal),
apr-reach-overlap (NoOverlap), apr-reach-direct-long (NoDirectLong),
apr-reach-retained (NoRetained), apr-reach-trust (NoPendingTrust),
apr-reach-recovery (NoRecovered), apr-reach-new-domain (NoNewDomainLanded),
apr-reach-origin-fallback (NoOriginFrozen), apr-reach-expired-anchor
(NoAncestryBudget), apr-reach-p-only (NoPOnlyWitness); apr-cut-omit-comet
(ActualCutSafe), apr-pressure-latest-c (AnchorFenceSafe),
apr-recovery-latest-f (OriginFallbackSafe), apr-trust-drop-pending (SignerTrustSafe).
Parenthesized names except PASS mean EXPECT INVARIANT. Public faulty profiles
are explicitly sensitivity controls, not normal protocol findings.

- [x] First implement normal Fault=None scaffold with deliberately wrong latest-c pressure guard;
  no corrected guard until root observes real named AnchorFenceSafe RED.
- [x] Correct pressure and complete all source-aligned transition interfaces.
- [x] Keep prepare/admit/sign/commit semantics distinct; allow independent remote
  valid proof input and L1 landing without requiring this node's current tip.
- [x] Add receipt-independent actions and first-failure/observation view argument.
- [x] Independent actual full-diff/source review before full engine GO.

The model may narrow external argument alphabets by profile; it cannot condition
actions on desired endpoint flags or a reference oracle. Exact fixture/observer
API is frozen in the Task1 contract before extracting Task2 brief.

### Task 3: Independent raw verification, review and draft publication

**Owner:** independent oracle/behavior verifier private readers; root engines,
preservation, reports, source manifest, current indexes and publication.
**Files:** new ANCHOR_PROOF_RECOVERY.md and stage evidence/profile; existing
REPORT append, WORKLIST/COVERAGE and test_check default-count guard only.
**Consumes:** source-reviewed model/config packet and literal expected histories.
**Produces:** actual raw results, refusal/control/restoration evidence and exact-head
CI/official-artifact/independent semantic readback receipts.

- [x] Root runs completed micro graph and all positive/negative configured cases.
- [x] Independent typed reader validates real inputs, exact checkpoint/committee/
  FI/pending-gate fields and receipts, not only success labels.
- [x] Run meaningful full-range, root-scope, compound old-job refusal, restoration and missing-
  action controls; restore exact bytes and reverify. No setup-error credit.
- [x] Bind producer source/config/command/results/raw and all reader/oracle inputs;
  keep each RED/GREEN version separately attributable from final runs.
- [x] Check old-byte preservation and both supported360/f556 ordinary cohorts.
- [x] Final independent full-stage review, one consolidated final fix wave and
  same-finder recheck. Maximum two material task repair rounds beforehand.
- [x] Admit only actual certified default outcomes. If all15cases qualify,
  default531 = old516 +15,134 PASS/397 named. Incomplete safety stays off-bank.
- [ ] Normal push existing draft, read back only owned PR/issue prefix, audit
  exact-head official artifacts and independently read new hosted traces.

At stage completion return to feedback-only; do not restart previous stages or
create a new one from an hourly tick. Full-protocol progress remains judgement,
not added cases; reassess only from closed source interactions and stated limits.

## Task1 interface freeze

See ANCHOR_PROOF_RECOVERY_CONTRACT.md. Scenario/Fault, s/receipt/cursor,
all safety/observation names and input-family meanings are now fixed there.
Micro is the complete nine-offer/two-slot restricted instance with independent
node event interleavings; larger cases are conditional actual-dispatch input
sequences, never an unrestricted graph claim. Public oracle bytes remain frozen.

## Builder-review verification gates

- [x] Verify branch-local immutable L1 snapshot identities and immutable Main
  script selection; shared numeric heights do not share post-divergence roots.
- [x] Run nine private actual-dispatch Micro observations and compare both slot
  inputs, outcomes, records, FI and SignalService with all nine frozen rows.
- [x] Disable one valid second stale-offer branch and require genuine coverage
  failure, then restore exact bytes; do not infer completeness from PASS alone.
- [x] Preserve same normal Main/None config and inputs for pressure pre/post
  repair. The permanent LatestC mutant is a separate sensitivity run.
- [x] Check refusal storage frames independently from L1 slot/history advance;
  use pre-R1000 stale recovery and fresh R141000 as separate consumed offers.
- [x] Preserve app-gate versus actual refused-RPC/restart scope. Keep isolated
  generation sensitivity OPEN and qualify compound stale-transaction evidence.
