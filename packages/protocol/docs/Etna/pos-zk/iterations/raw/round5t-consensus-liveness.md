# Round 5 — angle: consensus safety and liveness under D-14 and D-12

**Snapshot:** `7759eb269` (branch `etna-pos-zk`) · **Reviewer:** r5-consensus-liveness (task-2) · **Severity counts: 2 Critical, 4 High, 2 Medium, 0 Low**

**Verdict.** The per-set-version framing of A-CONS-1 survives the withdrawal of the decay (no rule removes weight inside a
set version — verified, see "Checked and holds"), and the retired-height carve-outs keep CONS-04/CONS-12/CONS-15
coherent. But two of the round-5 mechanisms are defeated by their own rules: **D-12's enforcement point (the proof) reads a
chain-chosen anchored L1 view that no rule requires to advance or to be recent**, and **D-14's eligibility evidence has no
freshness term, so a single public heartbeat signature can be replayed forever and a cohort that stops attesting is never
excluded**. The rotation/recovery pair also contains a state-machine trap that permanently disables REC-02. All findings below
are reachable with the assumptions intact (A-CONS-1, A-L1-1, A-DA-2) unless stated otherwise.

---

## C-1 — Critical: the forced-inclusion boundary is bound to an anchored L1 view that nothing requires to advance or to be recent; D-12's proof enforcement can be held at a stale due set.
*Rationale: the whole narrow forced-inclusion obligation is a function of A, and A is a free, chain-chosen, non-advancing value; the per-block duty of CONS-01(v) is never checked by the proof.*

- **Rules / missing rule.** `spec/04-l1-integration.html` FI-10 ("A record is due at L1 view A iff
  record.l1BlockNumber + FI_INCLUSION_DELAY ≤ A"); FI-11 ("MUST reject a view that is not Ethereum-final at landing
  (A ≤ block.number − L1_FINALITY_DEPTH) **or that is older than the predecessor's recorded anchoredL1Block** (no
  stale-view escape)"); L1-05 row 36 and L1-08 (`error ForcedViewNotFinal`, `error ForcedViewRegression` — only
  *regression* is rejected, so A = predecessor's A is accepted); `spec/02-consensus.html` CONS-01(v) is **per block**
  ("Let A be the block's anchored L1 view"); `spec/05-proof-statement.html` PRF-04(vi) uses **one** A for the batch
  ("the batch's anchored L1 view A from the SYS-02 anchor step it re-executes"). **Missing rule:** a staleness/advance
  bound on A (e.g. A ≥ block.number − depth within the same batch window / A must advance with L2 height), and a rule fixing
  *which* block's anchor is "the batch's" A. `spec/08-migration-upgrades.html` MIG-08 asserts as a property that
  "a wrong or **stale** payload invalidates the block", but no rule defines staleness — SYS-02(b)–(c) admit any
  Ethereum-final L1 block, and the only contract-side checks are finality and non-regression.
- **Assumptions.** A-CONS-1 (a Byzantine proposer or prover is inside the fault model); A-L1-1 (ordinary L1 inclusion of
  valid transactions, which the attacker does not even need to censor). No assumption failure required.
- **Attack trace.** (1) A coalition that can place one block per settlement period (well under 1/3 of slots suffices) produces
  a block B* whose anchor step commits to an old but Ethereum-final L1 block A0 — legal under SYS-02(b)–(c). (2) It lands a
  batch whose head is B*, so the journal's `anchoredL1Block` = A0 (L1-05 row 36). The contract accepts: A0 is final and
  ≥ the predecessor's anchored view (equality/advance both legal). (3) d(A0) is frozen, so the required prefix
  [c, min(d(A0), c+cap)) never contains any record published after A0 − FI_INCLUSION_DELAY. (4) The guest's check
  (PRF-04(vi)) passes with that small prefix, and every later batch can keep A = A0 (monotone, not strictly monotone).
  (5) Records published by a user are never due, are never required, and simply reach their DA-09 deadline and are
  "discarded"; re-publication restarts the same cycle. CONS-01(v) still obliges *individual* proposers whose own block
  anchors to a fresher view, but the **proof — D-12's stated enforcement point — never sees it**, and a proposer whose blocks
  carry A0 breaks no rule, so honest validators must sign them (CONS-01 lists no anchor-recency condition among (i)–(viii))
  and cannot halt (CONS-15 has no such trigger). If the reserved anchor sender of SYS-02(g)/MIG-04 is the single writer of the
  anchor payload, the freeze is chain-wide with no proposer collusion at all.
- **Inside/outside the fault model.** Inside: it is a rule gap exploited by < 1/3 Byzantine (or even one) proposer/prover
  without violating any stated rule; no assumption failure, no L1 censorship.
- **Attacker resources and cost.** One block per batch period with an anchor step pointing at any old final L1 block; gas
  only; no stake, no bond, no L1 inclusion censorship. Nobody is slashable under ECON-04 (6) because the omission is not
  "due at the block's own A".
- **Requirement / fixed decision affected.** D-12 (fixed: enforcement point is the proof; the rule "fixes a deadline by
  which forced data must be proven"); R10 narrowed form (LIVE-04); FI-10/FI-11/DA-10.
- **Evidence.** Quoted rules above; `spec/04` L1-08 error list has no staleness error; FI-11's parenthetical "(no stale-view
  escape)" asserts what its normative clause (regression only) does not enforce; `spec/08` MIG-08 golden-touch row is the
  only text claiming stale payloads are invalid, and it names no bound. *(Aggravating sub-point, same root cause: because
  CONS-01(v) is per block and PRF-04(vi) is per batch with one A, the submitter chooses the batch range and therefore the
  binding A; a batch whose interior blocks anchored fresh, but whose head anchored stale, is provable with the smaller
  obligation, which is exactly the "two checks must agree" defect FI-11 itself calls a protocol defect.)*

## C-2 — Critical: the heartbeat signed payload has no freshness term, so any public heartbeat signature can be replayed forever; D-14's exclusion of non-attesting entries never happens.
*Rationale: eligibility is set to the including transaction's timestamp, the signed message binds only chain id and entry, so one signature is a permanent credential — the exact opposite of the presence evidence D-14 was commissioned to create.*

- **Rules / missing rule.** `spec/03-membership-staking.html` MEM-13(2): "A heartbeat is the entry's heartbeat key's
  signature over a domain-separated message **binding the chain id and the entry** (GEN-05) … validity depends only on the
  signature and the entry's registered key, never on msg.sender", and `lastHeartbeatAt(v)` is "the run-time-visible
  block.timestamp of the **including** L1 transaction"; MEM-13(3) eligibility = `lastHeartbeatAt(v) ≥ t_root(e) −
  HEARTBEAT_WINDOW`; MEM-13(5) claims "a cohort that stops attesting is excluded at the next boundary … production
  resumes"; `spec/09-parameters.html` row `lastHeartbeatAt(v)` is "monotone, read by the set-commitment rule at N(k)".
  **Missing rule:** a signed freshness term (nonce, sequence, timestamp window) or a spent-signature store; `GEN-05` adds
  only a domain tag, and no `TAIKO_ETNA_HEARTBEAT_*` encoding or field list is registered anywhere. `HEARTBEAT_MIN_INTERVAL`
  is documented as an *interval between accepted heartbeats*, not as replay protection, and the 09 sizing rule keeps it
  strictly below HEARTBEAT_WINDOW. Also note `spec/10-assurance.html` LIVE-05(vi) contradicts MEM-13(2): "only a
  validator's own L1 transaction creates eligibility" — under MEM-13(2) *anyone* may create it.
- **Assumptions.** A-L1-1 (inclusion of valid transactions), which the design already depends on for every honest heartbeat;
  MEM-13(7) names only the opposite falsifier F8 (heartbeat *censorship*), so this direction is undisclosed.
- **Attack trace.** (1) A cohort of entries stops its L2 participation and destroys/loses its heartbeat keys, or simply
  refuses to keep signing (a ransom posture). (2) At least one publicly visible heartbeat signature σ per entry exists in L1
  calldata (it was needed to be in any version). (3) Anyone — the cohort itself, a griefer, or a third party paying gas —
  submits σ once per window, batched with `HEARTBEAT_BATCH_CAP` signatures in one transaction; `ecrecover` succeeds
  because σ was never bound to a time, nonce or entry-state version, and `lastHeartbeatAt` is refreshed to *now*.
  (4) At every commit point the predicate of MEM-13(3) is satisfied, the entries stay in R_k and in TotalVP_k, W′ never
  shrinks, and 3·s > 2·W′ stays unreachable for the validators that are actually online — the chain stays halted although
  the majority of the *live* weight could form a quorum. (5) CONS-16's rotation cannot repair it either, because the resumed
  set version is drawn from the same predicate (CONS-16(3)): the replayed cohort is eligible at that commit point too.
- **Inside/outside the fault model.** Inside: no key compromise, no stake, no censorship, no assumption failure; a
  permissionless path the specification itself opens ("Anyone may submit a heartbeat").
- **Attacker resources and cost.** One L1 transaction per window for an arbitrary number of entries (batching is explicitly
  allowed); no stake, no TAIKO, no validator cooperation, no ability to sign anything new required after the first heartbeat.
- **Requirement / fixed decision affected.** D-14 (fixed: "a validator that stops attesting is simply **not selected** into
  the next committed set version"); MEM-13(5); LIVE-05's attrition row ("an entry that does not attest within
  HEARTBEAT_WINDOW ending at a set version's commit point is excluded from that version's root"); R6's conditional liveness.
- **Evidence.** MEM-13(2) (quoted); 09 rows `HEARTBEAT_MIN_INTERVAL`, `HEARTBEAT_BATCH_CAP`, `lastHeartbeatAt(v)`;
  no heartbeat encoding/field list in 03, 09 or the rule index; LIVE-05(vi) contradicting MEM-13(2). *What would close it:*
  bind a monotone sequence number (or an L1-block timestamp window) into the signed message and reject a signature whose
  sequence is not greater than the stored one.

---

## H-1 — High: the rotation consumes a set version committed **after** the invocation (for eligibility) while asserting in the same clause that it was committed two L1-side epochs earlier (for finality); the missing relation `T_ROTATE_DELAY ≥ L1_FINALITY` makes the resumed root possibly non-final.
*Rationale: the resume-epoch rule and the finality assertion are mutually exclusive, so a correct implementation must invent the finality gate — and the wrong branch resumes the chain on a non-final L1 fact.*

- **Rules / missing rule.** `spec/02-consensus.html` CONS-16(3): e_r is "the lowest epoch whose mapping[e_r] entry is an
  Ethereum-final L1 fact **and whose stored t_root(e_r) is at or after the invocation timestamp**"; CONS-16(4): "the entry
  for e_r was appended two L1-side epochs earlier, is immutable and is **Ethereum-final well before** the rotation
  completes"; CONS-13(5): "the epoch it resumes into was committed two L1-side epochs earlier by the same L1 clock, so its
  entry is already an Ethereum-final fact". **Missing rule:** a registered relation making the consumed entry final at
  completion (e.g. `T_ROTATE_DELAY ≥ L1_FINALITY + T_L1_include + margin`). `spec/09-parameters.html` registers
  T_ROTATE_DELAY with no derivation at all (only T_ROTATE gets relations).
- **Assumptions.** None beyond the stated frame; the append path is permissionless (CONS-13(3)), so an entry can be appended
  immediately after the invocation transaction in the same or the next L1 block.
- **Attack trace (or honest-path trace).** T_inv = invocation time. A keeper appends the next entry at T_inv + ε (allowed:
  the append has a deadline, not an earliest time), so t_root(e_r) ≈ T_inv satisfies CONS-16(3). Anyone calls completion at
  T_inv + T_ROTATE_DELAY (permitted, "no earlier than T_ROTATE_DELAY"). If T_ROTATE_DELAY < L1_FINALITY + inclusion, the
  entry is not Ethereum-final when the chain is told to resume into e_r. Validators that obey SYS-02(c) must abstain
  ("A validator that cannot establish this must abstain") → boundary halt (CONS-13(5), F1); validators that follow
  CONS-16(4)'s assertion sign under a root that can still be reorged out → two nodes judge one height under two sets, the
  set-substitution failure CONS-13(5) names, with no slashable signer, and the superseded branch can then be landed or
  discarded inconsistently.
- **Inside/outside the fault model.** Inside: reachable on the honest path with a plausible parameter choice; no adversary
  needed.
- **Attacker resources and cost.** Gas only; or zero if the keeper simply appends promptly.
- **Requirement / fixed decision affected.** D-14 (the rotation is its reachability half); SYS-02(c); CONS-13(3)/(5);
  R5/R6.
- **Evidence.** The three quoted clauses; 09's T_ROTATE_DELAY row with no derivation. CONS-16(3) and CONS-16(4) cannot both
  hold for a t_root that lies between T_inv and the completion.

## H-2 — High: a **cancelled** rotation leaves a permanently pending record, because the clause that would clear it must revert; since a recovery may not be invoked while a rotation is pending, REC-02 is disabled forever.
*Rationale: "MUST revert at completion" cannot write state, and no other rule clears the pending invocation — the only sanctioned remedy for a settlement stall is then unreachable.*

- **Rules / missing rule.** `spec/02-consensus.html` CONS-16(2): "At most one rotation invocation may be pending at a
  time … a rotation MUST NOT be invoked while a recovery invocation of REC-02 is pending, and **a recovery MUST NOT be
  invoked while a rotation is pending**"; "It is cancelled by exactly REC-02's cancellation predicate: if a valid batch
  extending the checkpoint recorded at invocation is accepted on L1 after the invocation and before completion, **the
  rotation MUST revert at completion**". Compare `spec/06-recovery-exceptions.html` REC-02, which puts the analogous
  cancellation *in the accepting transaction* ("Acceptance of such a batch MUST cancel every pending recovery it extends
  past"); CONS-16 states no such landing-side clear. **Missing rule:** the pending-rotation record must be cleared by the
  batch acceptance (or by a permissionless cancel that does not revert), otherwise "pending" is permanent.
- **Assumptions.** A settlement stall of T_ROTATE (REC-03 itself discloses that an unfunded pool reaches the trigger "with
  no adversary at all"), then ordinary honest progress.
- **Attack trace.** (1) Settlement stalls for T_ROTATE (no adversary required). (2) Anyone invokes a rotation — free, no bond
  (CONS-16(2), clause (6) funding Open). (3) An honest prover lands a batch extending the checkpoint: the cancellation
  predicate of REC-02 is now true, and stays true forever because lastLandedHeight is monotone
  (`spec/04` L1-06). (4) Every completion attempt must revert, and a revert writes nothing, so the pending record is never
  cleared; no second invocation is allowed ("at most one … pending"). (5) REC-02's mutual-exclusion gate now rejects every
  recovery invocation for the life of the contract. When a later settlement stall becomes permanent (the empty-pool case
  LIVE-05 already lists), the chain has no remedy — the unbounded halt D-7 selected Mode B to avoid. An adversary can force
  the same lock-in deterministically: invoke the rotation, then land any certified batch itself (`land` is permissionless,
  L1-04).
- **Inside/outside the fault model.** Inside; needs only the trigger and permissionless `land`, both of which the
  specification grants to any account.
- **Attacker resources and cost.** Two L1 transactions (invoke + land) plus gas; no bond, no stake. (No attacker at all on
  the honest path above.)
- **Requirement / fixed decision affected.** D-7 (fixed: Mode B recovery is the selected remedy), D-12's premise that a
  settlement stall is recoverable, LIVE-01 ("A settlement stall is no longer terminal by itself"), REC-02.
- **Evidence.** Text quoted above; note the deliberate asymmetry with REC-02's landing-side cancellation and bond transfer.

## H-3 — High: the rotation's closing height `h_close(e)` has no L1 derivation, while the same rule asserts it is a function of L1 state.
*Rationale: the value that decides which heights are re-partitioned is unobservable on L1, and the wrong invention either strands produced history (the F7/REC-01 defect) or imports a privileged witness.*

- **Rules / missing rule.** `spec/02-consensus.html` CONS-16(3): closes "at the closing height h_close(e) — **the highest
  height any validator has produced in e**, and never a height any batch has claimed or landed"; CONS-16(6): "the invoker
  chooses nothing: **the closing height is a function of L1 state**"; CONS-16(5): "**L1 state does not carry the L2 tip**",
  and the legality precondition (no finalized height above h_close) is already Open/F7. **Missing rule:** the L1-derivable
  definition of h_close (or a completion-time evidence bundle, as REC-02 has, that fixes it).
- **Assumptions.** Any rotation invocation; the L1-side clock passing the trigger.
- **Attack trace / failure mode.** An implementer who resolves the contradiction by taking h_close = lastLandedHeight
  (the only height L1 knows) re-partitions finalized-but-unsettled produced heights; those become unlandable, which
  CONS-16(5) itself calls "a replacement of provisional history above the checkpoint by a path other than REC-02 — a REC-01
  defect". An implementer who instead accepts the tip from the invoker, a relayer or any witness creates a privileged input
  (INV-04, HALT-04, CONS-16(6)) and a censorship surface: the invoker picks the closing height. There is no third reading
  that satisfies (3) and (6) simultaneously.
- **Inside/outside the fault model.** Inside for the second variant (an input-taking implementation); the first variant is an
  implementation defect forced by the contradiction (F3, but no rule makes it detectable — the spec's own GEN-04/F3 clause).
- **Attacker resources and cost.** Zero, on both variants.
- **Requirement / fixed decision affected.** D-14's rotation half; REC-01/INV-01; CONS-12/INV-01's "no produced height is
  re-judged".
- **Evidence.** The three quoted clauses. Note F7 covers only the *precondition* (no finalized height above h_close), not the
  derivation of h_close itself, so this gap is not inside the Open item's disclosure.

## H-4 — High: FI-12's anti-shrink MUST has no enforcement point in PRF-04(vi), so the batch submitter chooses the drain rate and FI-12 claim (iii) is unsupported.
*Rationale: the counting argument that keeps the FIFO drain bounded depends on cap(batch) = FI_MAX_PER_BATCH, but the only check the guest is told to make is c′ ≥ min(d(A), c + cap) — computed from the batch's own (shrinkable) headers.*

- **Rules / missing rule.** `spec/04-l1-integration.html` FI-12: "When the window is non-empty the batch **MUST** have
  batchGasCapacity ≥ FI_MAX_PER_BATCH × FI_RECORD_GAS_MAX, so a submitter cannot shrink its batch to shrink the obligation:
  for every batch that can be required to do the work, cap(batch) = FI_MAX_PER_BATCH", and claim (iii) "a record at pending
  position j is reached after at most ceil((j+1)/FI_MAX_PER_BATCH) accepted batches". `spec/05-proof-statement.html`
  PRF-04(vi) enumerates the guest checks — it recomputes cap(batch) from the batch's own headers and requires
  c′ ≥ min(d(A), c + cap(batch)) — and **never rejects a batch whose capacity is below the threshold**. `land` never sees
  headers (L1-05 rows 7–8 see only heights/timestamps), so the MUST is orphaned. **Missing rule:** the guest check that
  enforces the minimum capacity whenever the window is non-empty.
- **Assumptions.** The submitter may choose a short range (L1-05 row 7 permits 1 block) and needs one certified range; any
  account may land (L1-04).
- **Attack trace.** A coalition that lands its own batches submits ranges whose `batchGasCapacity` is K × (header gas
  limits) with K small, so cap(batch) = floor(capacity / FI_RECORD_GAS_MAX) < FI_MAX_PER_BATCH; each landing drains only
  `cap` records. A record at position j then waits ≈ (j+1)/cap accepted batches instead of (j+1)/FI_MAX_PER_BATCH, and the
  queue can be padded (each publication is ordinary L1 gas) so the user's record passes its DA-09 deadline unresolved and is
  discarded; the user re-publishes and the loop repeats. FI-12's own counting argument — the answer to round 1's
  due-set-vs-cap critical — silently assumes the unenforced equality.
- **Inside/outside the fault model.** Inside (no assumption failure; the coalition is the batch author and the lander, both
  permissionless roles).
- **Attacker resources and cost.** Ordinary L1 gas for batches it would land anyway, plus padding publications; no stake.
- **Requirement / fixed decision affected.** D-12's constraints ("inclusion is a capped FIFO prefix … the failure mode that
  produced review round 1's critical finding must not return"; "the enforcement point is the proof"); FI-12; R10 narrowed.
- **Evidence.** FI-12 text vs. PRF-04(vi)'s exhaustive check list and FI-11(3), which says only "recompute … the cap from
  the batch's own contents".

---

## M-1 — Medium: the proof-bound settled frontier `c` is required to be guest-derived at A, but A is allowed to predate the predecessor checkpoint's own acceptance block, where that record does not exist.
*Rationale: the guest must derive c from A's state root while the contract reads c from its current storage; no rule forces A to be new enough, so the two derivations can be irreconcilable and a batch is unprovable.*

- **Rules / missing rule.** `spec/04-l1-integration.html` FI-10 (per-height settlement record "(settledCount,
  anchoredL1Block) written atomically by that height's accepting land"); FI-11(2) ("the guest derives **c** and d(A) from
  those anchored storage proofs"); L1-05 row 36 ("settledFrontier is read from the predecessor checkpoint's own settlement
  record"); L1-07 (the record carries `l1BlockNumber`, the L1 block that accepted it). **Missing rule:**
  A ≥ predecessor.l1BlockNumber (or c carried as a proof-bound committed value that the guest binds rather than derives).
- **Assumptions.** The predecessor's `settledCount` > 0 (at least one record already settled).
- **Attack trace.** A proposer anchors its block to A ∈ [predecessor.anchoredL1Block, predecessor.l1BlockNumber) — legal
  (final, ≥ predecessor's anchored view, no regression). Under A's state root the predecessor checkpoint's settlement slot is
  unwritten, so the guest's c = 0 while the contract's c = predecessor.settledCount > 0; the two `forcedBoundary`
  recomputations cannot match and the batch can never be proven. A certified range is stranded above the checkpoint with no
  rule broken by the proposer; only REC-02 can clear it, i.e. a proposer can manufacture the settlement stall that triggers
  a history replacement.
- **Inside/outside the fault model.** Inside: one legal anchor choice by one Byzantine proposer, < 1/3.
- **Attacker resources and cost.** One block's anchor field; gas only.
- **Requirement / fixed decision affected.** D-12 enforcement (FI-11); INV-01/LIVE-01 ("no timeout, rotation, admission rule,
  governance upgrade, operator action or failure of a liveness assumption may replace history").
- **Evidence.** FI-11(2), L1-05 row 36, L1-07; the contract's only view checks are finality and non-regression
  (`ForcedViewNotFinal`, `ForcedViewRegression`).

## M-2 — Medium: the void rule is discharged by omitting the sender's *unpublished* predecessor transactions, so a published record can be voided without anything being included, repeatably.
*Rationale: FI-13's nonce test is evaluated against a pre-state the proposer chooses, and nothing obliges a proposer to include the dependencies that would make the record includable.*

- **Rules / missing rule.** `spec/04-l1-integration.html` FI-13: "the sender's nonce at that pre-state equals the
  transaction's nonce"; void only if the transaction "was not includable in any block of the batch"; FI-10: a resolved
  (voided) record advances the frontier and the remedy is re-publication. Only the narrow forced-inclusion rule reaches
  published data; omission of unpublished transactions is explicitly not an offence (LIVE-04, ROLE-01(b)).
- **Assumptions.** A user's published record carries a nonce that depends on an earlier, unpublished transaction of the same
  sender — the ordinary case for any account with pending traffic.
- **Attack trace.** The record's tx has nonce n and the pre-state nonce is n−1 throughout every block of every batch (the
  coalition never includes the user's nonce-(n−1) transaction, which no rule requires). Every batch voids the record under
  FI-13, the frontier advances past it, and the user's only remedy — re-publication — reproduces the identical situation.
  The record is never "omitted" in the sense ECON-04 (6) punishes, because it was objectively not includable; the exclusion
  deadline is therefore satisfied by a void, not by inclusion.
- **Inside/outside the fault model.** Inside, and close to the disclosed limit (LIVE-04's "no remedy for unpublished data"),
  but not disclosed in this form: the specification's own worked description of the narrow rule presents void as the
  objective remedy for a record that *cannot* execute, not as a repeatable answer to a record that merely depends on
  unpublished data.
- **Attacker resources and cost.** Ordinary block-space decisions by the censoring proposers; no extra cost.
- **Requirement / fixed decision affected.** D-12 (upper bound on exclusion of *published* data); FI-13's F-FI-3.
- **Evidence.** FI-13's predicate and void rule; LIVE-04's statement that omission outside the due prefix is neither a
  validity failure nor an offence.

---

## Checked, and holds (no re-break found)

- **A-CONS-1 per set version / no rule removes weight.** MEM-13(4) and CONS-16(7) hold as written: the roster of a committed
  set version is immutable, weights inside a version never change, and exclusion is a future-roster property. The exposure
  is *roster composition* (C-2, and the disclosed F8), not intra-version re-weighting; the withdrawn decay's F5 transfer
  question does not return.
- **T_ROTATE ≥ HEARTBEAT_WINDOW.** For a cohort that stopped attesting at or before the last accepted batch, the derivation
  is sound: T_inv ≥ T_stall + T_ROTATE and t_root(e_r) ≥ T_inv give age ≥ T_ROTATE ≥ HEARTBEAT_WINDOW, so it is ineligible at
  the resumed version's commit point. (The residual "keeps heartbeating" case is disclosed in CONS-16(7)/LIVE-05.)
- **CONS-04 retired-height carve-out.** Locks at heights below resumeHeight are void and are not halt or equivocation
  evidence; locks at produced heights are never re-partitioned because h_close is defined as the highest *produced* height
  (subject to H-3's derivation gap). CONS-15's trigger list stays coherent after retirement.
- **CONS-12 / INV-01 generation scoping.** The unconditional "one certificate per height ever" claim is deleted, retirement
  makes a height permanently uncertifiable, and the rotation's re-partition of unproduced heights does not re-judge a
  produced height *given* the Open precondition F7. No new uniqueness break found.
- **CONS-01(vii), CONS-05 parent rule, REC-04 restart linkage.** The resumed chain's first parent is the restored checkpoint
  and retired heights are excluded at every generation; consistent across CONS-01(iii), CONS-05(iii), L1-06 and PRF-04(v).
- **Round-4's recovery-authorization tautology and retired-height Criticals.** Re-attacked: L1-06's contiguity equality and
  the derived `resumeHeight` close the re-landing path; I could not re-break them.

## Scope note

This review did not attempt the proof-binding, DA/blob, economics or migration angles except where they interact with the
rules above; the per-epoch configuration registry, the anchor-payload custody question of SYS-02(g)/MIG-04 and the storage
budget for a pending-rotation record (CONS-16(2) says the pending rotation "needs its own L1 record") belong to those angles
and are referenced here only where they gate a finding.
