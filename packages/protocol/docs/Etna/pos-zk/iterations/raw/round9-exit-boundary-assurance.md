# Round 9 — confirmation review: the exit and the guarantee class

**Reviewer:** independent adversarial reviewer, round 9, angle `exit-boundary-assurance`.
**Snapshot reviewed:** `3b4096a77` (branch `etna-pos-zk`), extracted with `git archive`; all citations are snapshot content.
**Method.** MEM-15 (1)/(2a)/(2b), L1-13, L1-11, L1-08, MSG-03/MSG-04, ECON-02 clauses 5(a)–(e), pages 02/05/09/10, the index and the whole course were read against each other; every round-8 finding I raised was re-checked at its exact rule text; the rollback was re-scanned mechanically (all tombstoned rule ids and parameter names against live text, with context inspection); and the new round-8 mechanisms (permissionless freeze, cascade, reservation release, `attestedFamilies`, the split rows, the unranked-draw disclosure) were attacked directly.

**Counts: Critical 0 · High 0 · Medium 1 · Low 2.**

**This is a clean round on my angle.** Every round-8 finding of mine is genuinely closed, and I could not break the exit, the boundary or the guarantee class. The one Medium is a defect in a *new* round-8 mechanism (the endowment freeze cascade) that touches the exit's funding path but does not change any guarantee the specification makes: no fund loss, no false guarantee, no conflicting histories. The two Lows are disclosure-completeness items, not contradictions.

---

## F1 — The endowment freeze cascade is an unbounded loop over elapsed epochs, and its extent is ambiguous; a claim or a proving-share transfer can be unaffordable after a long lull, and the transfer is the exit's funded path

**Severity: Medium.** One-line rationale: `ECON-02` clause 5(d) requires every pool-touching call — including a validator claim and, decisively, the proving-share transfer to the L1-11 ledger — to first execute the freeze of *every freezable epoch not yet frozen*, in ascending order; no rule bounds, paginates or partially executes that loop, and the design's own loop discipline forbids exactly this shape ("every loop in `land` must be bounded by the transaction's own contents … never by an unbounded external structure", `L1-04`). After a long period with no pool-touching call (a full halt is the case the exit exists for), the cascade length equals the number of elapsed epochs, each freeze writes a per-epoch record, and the call can exceed the block gas limit — while the specification states "an epoch cannot be skipped by inaction" and "no epoch depends on a separate keeper".

**Exact rule / the contradiction.**
- `spec/07#ECON-02` clause 5(d) (07:248-264): "An epoch `e` becomes freezable exactly when `evidenceClose(e)` has passed … The freeze is permissionless and needs no keeper: the staking contract MUST expose `freezeEpoch(uint64 epoch)` … and **every call that can change the pool's balance or fix a later epoch's amounts — an inflow credit, a validator claim, a proving-share transfer, or the freeze of a later epoch — MUST first execute the freeze of every freezable epoch not yet frozen, in ascending epoch order, before applying its own effect.** Consequently no caller chooses when or whether an epoch's amounts are fixed … an epoch cannot be skipped by inaction, because its own first claim executes its freeze (5)(c) and any address may submit that claim".
- Clause 5(c) (07:202-204): "The first claim of `e` MUST execute the freeze of (5)(d) as its first step if `e` is not yet frozen".
- `spec/04#L1-04` (04:107): "every loop in `land(data, proof)` must be bounded by the transaction's own contents (its blob count, its claimed range length), **never by an unbounded external structure**".
- `spec/09` `Alloc(e)` and `allocRecord[e]` rows confirm the cascade is normative and that each freeze persists a record (participant set, denominators, amounts, reservation) in one step.
- **Missing rule:** a bound or pagination rule — e.g. the cascade freezes at most `K` epochs per call and any caller may resume it, or `freezeEpoch(earliest)` is explicitly defined to freeze exactly one epoch — plus the corresponding statement of what happens to a claim or transfer while a backlog exists.

**Assumptions.** A period with no pool-touching call long enough for the cascade to exceed a block's gas. Epochs are L1-time-keyed (`CONS-13`), `EPOCH_LEN_L1` = 150 L1 blocks (~30 min), so a two-week full halt is ~670 epochs; a freeze writes a multi-field record, so the loop is out of gas well before that. No adversary is needed: a settlement/production halt produces the condition, and the halt is v1's disclosed state.

**Concrete attack trace (no adversary).**
1. The chain halts (the disclosed v1 position: no recovery path). No L2 fees sweep in, no proving-share transfer is callable, and claims are unattractive while the cascade is long. Epochs keep becoming freezable on the L1 clock; each adds one to the backlog.
2. A user needs the exit. The exit's k−1 attestation proofs are funded from the L1-11 ledger (L1-13(5), MEM-15(2b)); the ledger is credited only by the permissionless proving-share transfer, which is a pool-touching call and therefore MUST first run the full cascade.
3. The transfer reverts out of gas. The ledger is not credited; `attestRewardPaid` is 0 on any attestation (best-effort, never gating); the proving market is unpaid. That is MEM-15(2b)'s falsifier, reached through a rule defect rather than through market behaviour.
4. The same cascade blocks validator claims: a claimant who wants epoch `e` must pay for every earlier unfrozen freeze in one transaction.
5. Whether the backlog can be drained incrementally is **not determined by the text**: read literally ("every freezable epoch not yet frozen"), even `freezeEpoch(earliest)` must freeze all of them, so a large backlog is a deadlock until an upgrade; read teleologically ("A later epoch can never freeze before an earlier one", 07:260), `freezeEpoch(earliest)` freezes one epoch and the backlog drains one transaction at a time — but then the "first claim" backstop still forces the whole remaining cascade, and nothing states that the incremental path exists, is permitted, or is the intended recovery.

**Inside / outside the claimed fault model.** Inside. No assumption fails; the condition is the disclosed no-recovery halt, and the defect is the unstated bound on a normative loop. It is not a fund loss and not a false guarantee: the falsifier at MEM-15(2b) already discloses that an unfunded proving market blocks the exit, and "no allocation has been promised and no claim exists" while nothing is frozen. The defect is that the specification claims objective, keeper-free, unskippable freezing while providing an unbounded loop with an ambiguous extent on the same path.

**Attacker resources and cost.** None required. A griefer cannot create the backlog without L1 censorship (outside the model); elapsed time does it.

**Requirement / fixed decision affected.** D-16's shipped exit (its funding path runs through the gated transfer); `ECON-02` clause 5(c)/(d)'s own claims ("cannot be skipped by inaction", "needs no keeper"); `L1-04`'s loop-bound discipline; `PARAM-01` (the freeze's gas/complexity is a parameter-free obligation with no bound registered).

**Evidence.** `spec/07#ECON-02` clause 5(c) (07:202-207) and 5(d) (07:248-264, 269); `spec/09` `Alloc(e)` (09:198), `allocRecord[e]` (09:206); `spec/04#L1-04` (04:107); `spec/04#L1-13`(5) and `spec/03#MEM-15`(2b) (the funded transfer this gates); `spec/10` guarantee preamble (10:31).

---

## F2 — The MUST-DISCLOSE rules still phrase the exit's dependency as funding-only; MEM-15(2b) now names both, but MSG-03(5) item (i) and STATUS-08 do not

**Severity: Low.** One-line rationale: the round-8 repair added the retrievable-witness half to MEM-15(1)/(2a)/(2b), LIVE-01, LIVE-05, LIM-01, the guarantee preamble and the course, but the two rules that *impose* the disclosure duty still say the wait is for proofs "produced and funded" and name "the proving-market assumption", so a document written from MSG-03(5) alone would disclose only funding.

**Exact rule / missing rule.** `spec/04#MSG-03`(5): "the exit stays available during a stall whenever those proofs are produced and funded (L1-13(3),(5)) — **the proving-market assumption** and falsifier of MEM-15(2b)". `spec/index.html#STATUS-08`: "the wait is for the k−1 attestation proofs, **which the funded proving market of MEM-15(2b) must supply**". Against them, the owner clause now names both: `MEM-15`(2b) "(a) A funded proving market produces the k−1 attestation proofs … (b) The proofs' inputs remain available … the recorded certificate, the batch's data and the pre-state witness … an unfunded or absent proving market, **or proving inputs that are no longer retrievable**, leaves a user … unable to exit". **Missing rule:** add the retrieval half to MSG-03(5) item (i) and STATUS-08 ("produced, funded, and from inputs that remain retrievable"). The citation to MEM-15(2b) makes the omission a completeness gap rather than a false statement — a reader who follows the link gets the full assumption.

**Assumptions.** None.

**Concrete attack trace.** Not an attack: a document author or interface team implements MSG-03(5) literally, discloses funding and omits retention; on a halt that outlives blob retention with no archive at the height (MEM-15(2b)(b)), users are surprised by an exit that never opens. The course already gets this right, so the inconsistency is internal to the disclosure chain.

**Fault-model verdict.** N/A (disclosure completeness); no false claim, since the citation resolves it.

**Attacker cost.** None.

**Requirement affected.** `MSG-03`(5); `STATUS-11` via STATUS-08; `GEN-01`/`GEN-02`; D-16's guarantee class.

**Evidence.** `spec/04#MSG-03` (04:885-891); `spec/index.html#STATUS-08`; `spec/03#MEM-15`(2b); `spec/10` preamble (10:21-25).

---

## F3 — The attestation reward's front-running race is not disclosed, although the identical landing race is; the reward follows the transaction, so a copyist can take the prover's pay

**Severity: Low.** One-line rationale: `attestWithdrawalRoot` pays `attestRewardPaid` to `msg.sender` "never to an address named inside the proof", so an attestation proof broadcast publicly can be submitted first by another account, which collects the reward and leaves the prover unpaid; the landing path discloses exactly this race and its mitigation, the attestation path does not.

**Exact rule / missing rule.** `spec/04#L1-11` (04:544): "The attestation reward is paid on the successful call to the submitting account (`msg.sender`), never to an address named inside the proof"; `L1-13`(5) repeats it. The landing analogue is disclosed: `spec/04` (04:527) "a proof observed in the public mempool can be landed first by another account, which then collects the reward"; the course repeats it and names the mitigation (`learn/06:276, 402-403`: "No protection against a prover being front-run: the reward follows the landing transaction, so copying a public proof is allowed"). **Missing rule:** one sentence in `L1-13`(5) or the `attestRewardPaid` row (09:204) stating that the attestation reward follows the transaction, that a public attestation can be copied and submitted first, and that this is one way a funded market can fail to pay the prover who produced the proof (the prover's mitigation is private orderflow, exactly as for landings).

**Assumptions.** A prover broadcasts its attestation transaction publicly.

**Concrete attack trace (griefing, not theft).** A prover completes the k−1-th family's proof for a blocked user's checkpoint and broadcasts `attestWithdrawalRoot(height, imageId, proof)`. A watcher copies the calldata, lands it first, and receives `attestRewardPaid`; the original reverts on `FamilyAlreadyAttested`. The root still forms (the user is helped), but the prover is unpaid, weakening the funded market the exit depends on. Disclosed? The falsifier covers "unfunded or absent market" and the unranked-draw disclosure covers starvation by the landing draw, but not this capture.

**Fault-model verdict.** Inside (ordinary mempool behaviour, no assumption failure; the exit is not blocked, only its funding is diluted). No fund loss to users.

**Attacker cost.** Gas for the copied transaction; the reward it takes.

**Requirement affected.** D-16's funded-market assumption and its falsifier (MEM-15(2b)); `MSG-03`(5)'s disclosure duty; consistency with the landing-path disclosure.

**Evidence.** `spec/04#L1-11` (04:540-544); `spec/04#L1-13`(5) (04:510); `spec/09` `attestRewardPaid` row (09:204); `spec/04` (04:527); `learn/06-data-and-proof-together.html:276, 402-403`; `spec/10` preamble (10:31).

---

## Confirmation checklist (every item charged to this round, with its verdict)

1. **Round-8 F1 — CONS-12 reading a tombstone: CLOSED.** The scope paragraph now reads "The invariant is unconditional in v1. Above the last accepted checkpoint a certificate is a claim on provisional history, but no v1 rule discards or replaces that history … no height above the checkpoint is discarded, re-produced or re-judged", and keeps the old conditional only as labelled history ("historical, not a live rule"). The mechanical scan finds no live REC-02/GOV-04/REC-04 text on page 02.
2. **Round-8 F2 — the course and the v1 exit: CLOSED.** Every relevant page teaches the root, the k families, the veto and **both** dependencies: `learn/09:103, 193-196, 271, 386` ("a withdrawal root: k attestations … from data and a witness that are still retrievable"), `learn/08:50, 94, 137, 296`, `learn/02:216, 242`, `learn/07:84, 256`, glossary and limitations. Counts: "proving market" appears in 9 course files, "withdrawal root" in 10.
3. **Round-8 F3 — the proving split: CLOSED.** `PROVING_LAND_PPM, PROVING_ATTEST_PPM` are registered with unit, owner, the `= 1_000_000` constraint and the "not a third pool share" clarification (09:202); `attestRewardPaid` is registered as a derived payout with no value (09:204); `L1-11` names the split identifiers (04:544); and the disclosure states exactly what the rules enforce: "the landing draw and attestation draw are two unranked debits of one balance … no sub-accounting, reservation or ordering rule makes it true on-chain, so either draw may be starved … best-effort and never gate" (10:31). Matching L1-11's actual identity (two permitted debits, `require(attestRewardPaid ≤ ledger_before)`). No over- or under-claim.
4. **Round-8 F4 — both exit dependencies and the falsifier: CLOSED.** MEM-15(1) names both; (2a) names the recorded certificate, the batch's data and the pre-state witness; (2b) is titled "The proving dependencies" with (a) funding and (b) retained inputs, and its falsifier reads "an unfunded or absent proving market, **or proving inputs that are no longer retrievable**". Propagated to LIVE-01 ("not independent of proving or of retention"), LIVE-05, LIM-01, the guarantee preamble (10:21-25) and the course. Residual: F2 above (two disclosure phrasings).
5. **Round-8 F6 — the delay anchor: CLOSED.** MEM-15(1) now reads "measured from the **root checkpoint record's own** `l1BlockNumber` … which may be an earlier checkpoint than the latest accepted one, and never the latest accepted checkpoint's own"; L1-13(2), MSG-03, STATUS-08, the 09 `WITHDRAWAL_DELAY` row and every course page agree.
6. **Round-8 F5 — the un-relaxed-D5 rows: CLOSED.** MEM-05(5) and the 09 blob-quantisation row are re-based on D-11 (commit `698fb81da`); the blob ceiling is now derived from the publication transaction's contents.
7. **Round-8 F7 — DEFERRED.md: CLOSED.** The cross-cutting note now records the exit contradiction as repaired, the split and witness items as disclosed residuals, and the course-sync trigger as any live-rule change.
8. **The k-family root cannot be blocked by the veto or the delay: CONFIRMED.** MSG-04(4): "The veto MUST NOT gate `land(data, proof)`, settlement, consensus, staking, validator exits, rewards, **root attestation (L1-13)** or the L1→L2 direction"; it self-expires, cannot be extended by anyone, and delays but never cancels a proven withdrawal. L1-13(2): the delay runs from the root record, so a root formed after acceptance has already accrued its delay; nothing makes the delay a gate on root formation.
9. **The boundary survives the exit, the veto, an upgrade and a reorg: CONFIRMED.** The attach path "MUST NOT write a checkpoint, MUST NOT move L1-06's pointer" and a root is always at or below the current checkpoint (L1-13(2),(3)); the veto rewrites and recalls nothing (MSG-04(1),(4)); an upgrade/retirement "MUST NOT remove an attestation already recorded", PRF-10 preserves the recorded statement, MIG-05's per-epoch accepted sets are never deleted and retirement "must not invalidate a certificate, a checkpoint or a settled batch"; a reorg below finality removes the accepting transaction and every later attestation as one suffix, and L1-12 adds that no function may "repair" a reorganisation by writing a chosen checkpoint, height or state root.
10. **The new round-8 mechanisms: CONFIRMED except F1.** `freezeEpoch` is permissionless and freezable exactly at `evidenceClose(e)` with a call-before-close revert; the first-claim backstop exists; the reservation release is reachable (the last claim releases the floor remainder; an empty participant set releases at the freeze; `reserved_before` is a persisted running total with checked views); `attestedFamilies(uint64)` is in the L1-08 sketch; the referenced path's `daMode` and challenge index are derived from the record. The cascade's bound and extent are F1.
11. **No live rule reads a tombstoned rule, parameter or record: CONFIRMED.** The mechanical scan's 17 hits are all false positives: tombstone lists in 09, the historical change-order ledger in 10 (LIM-03, explicitly historical), the marked tombstone references in 02/03/05/08/learn, and — checked individually — live rules that cite `MEM-13`'s **tombstone section** for the v1 quorum-loss disclosure it deliberately carries ("Membership in v1 is the bonded set with NO liveness gate …", 03:530), which LIVE-05 states in parallel (10:218). The four deferred mechanisms' absences are disclosed in the guarantee preamble, LIVE-04/LIVE-05, LIM-01, the index and DEFERRED.md, and the course teaches none of them in the present tense.
12. **LIVE-01's re-scoped independence claim: CONFIRMED exactly.** "Not conditional on (L1), (L2) or (L6)", the exit needs "no new L2 block, no settlement progress, no quorum and no permission", and "It is not independent of proving or of retention, however: (L4) is the prover-completion assumption … and the exit therefore depends on the funded proving market that MEM-15(2b) assumes". Every claim is true of the rules as written.

## Checked, and holds (attacks I ran and could not break)

- **Two conflicting canonical histories** via the exit, the veto, an upgrade or a reorg: none constructible. Roots are designations of existing checkpoints, never writes; the veto is release-only and one-shot per contradiction; upgrades cannot remove attestations and cannot rewrite at or below the checkpoint; a reorg is a suffix and takes the accepting transaction with it.
- **Using the veto as a pause lever**: the trigger is an on-chain-verified contradiction, each is consumed once, the window self-expires, no party can extend or shorten it, and root attestation is explicitly exempt.
- **Blocking a root by suppressing one family**: suppressing a family prevents *that family's* attestation but cannot remove the accepting route's recorded attestation or another route's; with k live families the root forms, and with fewer the unbounded wait is disclosed (L1-13(5), L1-09 launch gate).
- **Making the exit unattestable at the contract**: L1-13(3) admits an attestation for any recorded statement while halted, needs no L2 progress and no permission; the only gates are the two disclosed economic/retention assumptions.
- **The disclosure exceeding or falling short of enforcement**: the unenforced-split and unranked-draw disclosures match L1-11's identity exactly (verified line by line); the best-effort/never-gating statements match the two identities; the only gaps are F2 and F3.
- **The course teaching more than the specification**: re-checked the withdrawal, stall, membership and economics lessons; the course now states the root, the two dependencies, the veto, the unbounded k-family wait and the no-recovery position, and teaches no deferred mechanism in the present tense.

## Verdict

**Clean round for this angle: 0 Critical, 0 High.** The exit and the guarantee class are internally consistent and honest about what they do and do not deliver: the boundary holds against every path I could construct, the k-attestation root is formable and permissionless for the latest accepted checkpoint, the delay and the veto cannot make it unavailable, and both dependencies of the exit — funding and a retrievable witness — are stated with a falsifier that covers both. The one Medium (F1) is a bound-and-extent gap in the new freeze cascade that can gate the exit's funded transfer after a long halt; it is a repair, not a redesign, and it does not falsify any guarantee the specification makes. The two Lows are wording.

**Would I build on this specification?** Yes. The core state machine (checkpoint record and boundary, `land`/publication, the k-attestation root and its per-family view, the L1-11 identities, the veto, the freeze/reservation accounting, the migration bars) is specified to the level where two implementations should agree, and the guarantee class is disclosed rather than implied. Before shipping I would want F1 fixed (a paginated/bounded cascade with its recovery path stated) because it is the one place where an unbounded loop sits on the exit's funding path, and I would fix F2/F3 as wording while touching those rules.
