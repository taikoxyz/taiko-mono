# Review round four

> Historical round-four disposition. [Round five](review-round-five.md) corrects the
> deployment-window check, verifier footprint premise and witness/guest scope below.

Baseline: PR #22292 at `88043c92ee651f5c09ef5a3de62fee9e9a4dcbe1`.
This pass corrects formal model, proof and evidence gaps. It changes no production
contract/client/guest implementation. No new Etna design defect was confirmed.

## Important findings

| Finding                                | Verified disposition                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Archive not bound to the chain         | Confirmed by a kernel reproducer with archive anchor/cutoff 100 and reference 20. `Archive.Authenticated` now binds the authenticated origin, physical parent chain, batch parent and every actual block, with header hash binding and anchor/reference bounds. Both guest certificates and node replay require it. The terminal selection snapshot is derived no later than the reference.                                                                                                                                                                                                                                                                              |
| Wrong Unzen start can reopen the fence | Confirmed under the existing H1 primitives. Solidity already required strict proposal progress and finalized-parent linkage; the model omitted them. The model now checks both, and a proof-local Unzen extension primitive yields monotone endpoint height. Global legacy/Etna disjointness is derived. Replaying an equal proposal and supplying a disconnected higher proposal are independently rejected. A valid two-proof extension uses a nonzero authenticated parent.                                                                                                                                                                                           |
| No actual stake at risk                | Confirmed: the previous funded-liability/window contracts did not derive live/unconfirmed status for selected members. The new ordinary profile derives it from actual rollback-free execution and node-authenticated physical checkpoint ancestry. Accepted certificate/frontier binding derives every snapshot-order step; ancestor agreement derives cutoff order; that revision used an initializer check for the window/delay relation; round five replaces the non-SPEC check with an explicit deployment policy assumption. The current wrapper derives live/confirmation/snapshot/cutoff facts but explicitly assumes correct deployment evidence-window sizing. |
| CI never completed                     | Confirmed: runs 41619969756 and 41643255198 were cancelled at the 30-minute job deadline while testing. The job budget is now 90 minutes, with the complete audit and suite retained. The previous 504-test green result was local only; final local and hosted outcomes are recorded separately.                                                                                                                                                                                                                                                                                                                                                                        |
| Registry admission mutant survives     | Confirmed; FI payment mutations were unrelated. New general theorems prove the selected slot is within all 4096 slots, has globally minimum total principal, resolves ties at the lowest index, and preserves a displaced bond's principal/key/owner. Both 4094 and 4096 scan-length mutants compile the model and prior proofs but fail the unchanged full-slot contracts. Endpoint/nonzero-tie/pending-principal fixtures and eight current-model/payment-generated vectors are added.                                                                                                                                                                                 |

Normal at-risk liability distinguishes principal already exhausted by punishment from an
executable funded slash within the protected window. It never guarantees replenished
collateral after punishment or original stake forever. Exceptional verifier-failure
rollback is deliberately separate: a concrete paid-withdrawal/rollback counterexample
implements the irreversible loss described by RECOV-8-35, and cannot satisfy the ordinary
profile. This is a specified exception, not a newly discovered protocol design defect.

## Other feedback

- **Witness restrictions:** the former single new-network witness did not exercise Unzen,
  conflicting quorums, honest agreement or import. The README now lists restrictions of
  every interpretation. Separate full-fourteen-premise profiles positively exercise those
  branches, including an actual first switching landing and genuine honest locking rules.
  The risk/import profile has no EL landing; the honest engine is a decoded finite
  normalization. None is a production implementation or complete acceptance rehearsal.
- **Reference controls:** a changed later block is now closed before proving the original
  prefix/certificate survives, using actual `List.take` truncation. Rollback/landing
  examples include actual reachability and all premises. General pure-certificate
  transport is mechanically proved; operational reuse additionally needs raw live storage
  openings. It is not unconditional acceptance in an arbitrary World.
- **Guard evidence:** unchanged positive mutation harnesses must compile first. Exact
  strict-proposal and parent-link mutants preserve other guards. Nine further independent
  mutants cover the rollback signal filter and saved snapshot pair, one-shot origin,
  correction after landing/rollback, and all five first-fence fields. All mutant models
  compile before the unchanged executable assertions reject them; the unmodified fixture
  also passes. Individually corrupted fence records test the formula, not reachability or
  joint premises. The rule report counts supporting projections/guards as supporting,
  not independent derived rule properties.
- **Ghost guards:** DAO correction and rollback are normative upgrade actions, not claimed
  public bytecode checks of `everLanded` or `activeSnapshots`. Raw upgrade histories need
  explicit per-successful-upgrade historical authorization before refinement to `Trace`.
  Raw accepted-but-unauthorized histories demonstrate this is a material condition, not a
  decorative premise. Complete last-trusted/first-bad target selection remains deferred.
- **Roots and lifecycle:** `AuthenticRoot` retains the initial World and actual source
  `Trace`. H1 exports one-shot origin writing and legacy/Etna separation. H3 exports
  recovery head preservation. `recover_origin_exact` additionally gives the exact new
  c/R/timestamp tuple, literal origin-list append and checkpoint/record preservation.
- **Traceability:** generic conservation/wrapper helpers lose specific STAKE credit;
  custody results lose atomic-update credit; parameter immutability moves from 14e to 3d;
  slashing/evidence and pure agreement sources are separated. Exact narrow links now cover
  recovery clearing/untargeted entries, one-entry cardinality, due skip cases and ordinary
  recovery origin construction/preservation. The source view does not elevate those
  fragments to full-rule verification. No unsupported full FIFO conclusion comes from
  endpoint bounds alone.
- **Historical presentation:** the remaining conformance/V9 README references now identify
  their actual historical authorities. Historical vector bytes remain unchanged. The new
  displacement family is executable against the current model/payment wrapper, in a
  separate directory; adoption by separate contract/client harnesses is not asserted.
- **Existing-registry retargeting:** the fresh `Genesis` profile excludes START-10-16a.
  New seeded preservation helpers support a separately verified nonempty opening, but
  do not fabricate its history/funding or claim the complete retarget procedure is proved.
- **Short consequences:** some headline conjuncts intentionally expose direct call guards
  or definition-level consequences. Their brevity is not a correctness defect. They are
  classified/scoped separately from the derived global invariants and do not inflate
  protocol rule evidence.

## Validation and scope

An independent read-only semantic review found no remaining Important correctness issue in
archive authority, certificate transport, ordinary stake risk, Unzen progress, governance
refinement or admission. A separate exact-source review corrected the targeted mappings;
all 1,216 historical contract objects are unchanged. Kernel/type/role/axiom and full-suite
results are in [latest alignment](latest-design-alignment.md).

Remaining production boundaries include raw header/parent/storage decoding, commitments,
Unzen and Etna guests/images, EIP transaction parsing and singleton execution, token/Solidity
implementation, Comet engine/EL/store/import refinement, availability and all operational
acceptance measurements. These are separate from the proved decoded contracts.
