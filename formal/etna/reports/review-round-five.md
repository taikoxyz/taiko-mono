# Review round five

Baseline: PR #22292 at `1bb87356a2dc72d0133d40522c309e25d9b3b146`.
This pass checks the new minor findings against the decoded machine and pinned Etna
SPEC/SWITCH. It changes model/proof/evidence scope, not production contracts or guests.

## Verified corrections

- **Evidence-window sizing:** confirmed. The previous initializer checked an external
  evidence policy that SPEC PARAM-11-11 leaves to deployment. `Config.valid` and
  `initializeInbox` no longer make that comparison. `Premises.currentEvidenceWindow`
  explicitly supplies positive sizing no longer than the immutable withdrawal delay.
  `evidence_window_of_deployment` only transports it through actual immutable configuration.
  It receives no parameter-choice rule credit. A short delay is physically permitted in
  the regression while failing a longer deployment policy. All joint profiles now satisfy
  fifteen premises.
- **Verifier footprint:** confirmed. `ImageCertifies` now contains only the reference-local
  certificate and actual image/ruleset support. `certified_statement_footprint` derives the
  live footprint from fresh registry provenance, actual trace and the pure statement's
  generation binding; `accepted_landing_footprint` additionally obtains that certificate
  from ordinary verifier soundness and an actual accepted call. The reviewer’s bare
  `Trace ∧ land ⇒ footprint` implication is false: a reachable post-recovery call can
  accept a stale reference under an unsound verifier. A kernel regression constructs it
  and rejects its bound pure certificate. No extra land guard was introduced.
- **START-10-5d:** confirmed. Monotone finalized proposals do not verify the propose/FI
  cutoff upgrade. The rule is deferred, and its unrelated monotonicity evidence loses
  source credit. The model has no Unzen proposal creation or FI cutoff operation.
- **Historical-header budget:** confirmed abstraction gap. Certificates still quantify
  complete semantic ancestry from the generation origin. Separate extraction theorems
  show an ordinary decision suffix has at most L+2 headers, preserves physical links and
  hash authentication, and gives the exact post-origin decision anchor/cutoff, with a
  separate origin-floor case. A nonempty-prefix fixture exercises heights 88 through 99
  for L=10. This does not prove that the accepted full-certificate interpreter can be
  implemented by an L+2-only guest. Production decoding, bounded guest completeness and
  separate L1 ancestry/recovery material remain deferred.
- **H2 scope:** confirmed. The normal risk profile requires no rollback anywhere since
  fresh genesis and a candidate above the actual checkpoint. There is no automatic
  restart theorem after a rollback. The headline now also exports retention of every
  member of a valid authenticated candidate committee, independent of the overlap or
  consensus round. This uses a genuine valid election, not a supplied live/unconfirmed
  status. Evidence-window sizing remains the explicit deployment condition above.
- **H1 scope:** confirmed. The headline exports `SwitchingFence` as well as pairwise lane
  disjointness. After the first Etna landing it yields legacy heights at or below S and
  Etna heights above S. The modeled Unzen lane starts with no signals and zero finalized/checkpoint data,
  retaining its configured nextProposal; pre-deployment
  SignalService checkpoints are not covered. No claim of complete bridge/switch migration
  follows from this decoded result.
- **Witness restrictions:** confirmed. The switching profile recovers into generation 1
  before its first Etna landing, and its `UnzenExtension` has no true antecedent. The risk
  profile exercises paid authenticated equivocation above the genesis checkpoint, with
  no post-landing snapshot derivation. The honest profile is single-value/round-zero and
  compares a nonempty chain with itself. Positive accepted certificates all have empty
  prebatch `prior` lists. The new arbitrary-ancestry extraction fixture is not an accepted
  certificate or full-premise guest implementation. README descriptions now retain all
  these limits; the general theorems are not replaced by the fixtures.
- **Mutation evidence:** partly confirmed. The original fence tests compiled models and
  synthetic, sometimes unreachable, field states. Two hash guards imply each other on
  reachable traces; checkpoint presence also follows from a nonzero finalized hash.
  Clone-only kernel proofs now establish those redundancies. Four further compile-first
  mutants recompile the full substantive custody/switching proof chain, preserving guard
  conjunction shape and requiring rejection in the exact start-freeze, rollback-coherence
  or pending-fence lemma. This establishes proof sensitivity for those mutations, not
  independent reachability necessity of every individual fence field.
- **Raw DAO rollback:** confirmed. Retained `activeRecords` membership is removed from
  raw authorization checks and is an explicit per-successful-upgrade history duty together
  with the saved checkpoint/snapshot pair. The refinement theorem proves the bridge.
  A reachable archived-record example succeeds raw, fails normatively and fails historical
  authorization. The raw effect still uses instrumented retained history to describe
  physical clearing; this is not a proof of the deployed upgrade implementation or the
  complete last-trusted-before-first-bad target policy.
- **Vector validity:** confirmed with one correction to the review. Withdrawal actually
  clears confirmation, so a released bond need not retain `confirmedAt`. The defective
  seed retained `noExit` at a finite snapshot. It now executes requestExit, confirmation
  and paid withdrawal with finite effective exit, zero released balance and lifetime key/id
  preservation. All eight seeded openings satisfy the checked metadata/reserve boundary.
  Pending top-ups are also paid after activation and mature one block later. All eight
  case IDs, including equal-versus-below rejection, are listed explicitly.
- **Historical prose and dead field:** confirmed. Historical report generation instructions
  and removed README anchors now point to immutable appropriate historical evidence.
  The dangling V9 pronoun is replaced. The unused `archiveAuthenticated` field is removed.

## Remaining boundaries and verification

No new Etna protocol design defect was confirmed. These corrections remove model checks,
premise strength and evidence overclaims, and distinguish known exceptions and modeling
gaps. RECOV-8-35 already states that verifier rollback cannot recover paid withdrawals.
Existing-registry retarget opening provenance, production parser/crypto/header/parent/storage,
guests/images, token/Solidity, Comet/EL/store/import refinement, operational availability,
liveness and launch acceptance remain outside these decoded conditional contracts.

Exact declaration/role/source and full-suite validation are recorded in
[latest alignment](latest-design-alignment.md) and the final pushed SHA's PR checks/body.
Historical contract records and historical JSON vector bytes remain unchanged.
