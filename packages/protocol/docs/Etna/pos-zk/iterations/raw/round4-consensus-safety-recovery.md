# Round 4 raw review — consensus safety and its interaction with recovery

**Reviewer angle:** A — consensus safety (CONS/MEM) attacked together with the recovery rules
(REC/HALT/WH) and the statement that carries the recovery authorization (PRF-02, PRF-04(viii), L1-05
row 31).

**Frozen snapshot:** `fe7373a13` (`docs(protocol): Mode B selected (D-7), ...`), working tree clean.
**Date:** 2026-10-05. **Method:** rules judged as written; in-text `(review round N)` / `(D-7)` notes
treated as claims, not evidence. Every quotation below is from the snapshot's HTML.

**Verdict: 1 Critical, 2 High, 2 Medium, 1 Low.**
The Critical is **inside the fault model** and uses the withholding schedule that
`01-requirements-and-threat-model.md` §6.2 makes mandatory. It means the selected recovery (D-7) is
**reversible by the party it is meant to defeat**, and that one normative rule
(REC-02 "Late proofs") is not implementable as written.
R4A-02's *wedge* is a consequence of a liveness-assumption failure (class F1) — the class D-7 was
selected to repair — so it is inside the requirement the selection was justified by, though the trigger
itself is not reachable by a sub-threshold coalition under REC-03's premises. R4A-03 needs no adversary.
I could **not** re-break: the per-height lock inside a generation, the same-height CometBFT safety
argument, the anchor duty of CONS-09(1)–(2), the PRF-05(ii) first-block re-keying, the single quorum
predicate, the single MEM-08 set encoding, the L1-resolved `epoch → setRoot` mapping, the two-epoch
lookahead wiring, or REC-01's boundary. The open item **F1** (epoch handoff) survives this angle's
re-attack except for one unoperational sentence, folded into R4A-02.

---

## R4A-01 — Critical — the recovery authorization is a tautology: `recoveryGeneration` is bound to no signed consensus object, so a pre-recovery certificate chain can be re-proven under the new generation and landed against the restored checkpoint

**Severity rationale (one line).** The rule that is supposed to make discarded history void
("a batch certified under generation `g` is void once generation `g+1` is active",
`REC-02` "Authorization binding"; "a proof whose batch lies above the restored checkpoint is void",
`REC-02` "Late proofs") is **unenforceable as written**, because no signed object in the protocol
carries a generation and the guest's generation check can only compare the journal to itself; a
discarded branch therefore remains landable by anyone who can re-prove it, which restores the discarded
history canonically and falsifies the D-7 guarantee class.

**Exact rules / missing rule (file + rule id).**
- `06-recovery-exceptions.html` **REC-02**, row *Authorization binding* (line 370): "A batch
  certified under generation `g` is void once generation `g+1` is active, and the guest MUST check
  the generation, so an alternative history is never accepted on execution validity alone."
- `06-recovery-exceptions.html` **REC-02**, row *Late proofs* (line 363): "A proof whose batch lies
  above the restored checkpoint is **void**: its predecessor no longer exists."
- `05-proof-statement.html` **PRF-02**(5)–(6) (lines 177–199) and **PRF-04**(viii) (lines 273–283):
  the guest "MUST require the journal's `recoveryGeneration` to equal the generation the L1 contract
  supplies as a public input".
- `04-l1-integration.html` **L1-05** row 31 (line 164) and §2.1 row 31 (line 203).
- **Missing rule:** nothing states how a *certificate* (or a vote, or a header) is bound to a
  generation, and nothing lets the guest learn the contract's generation. There is no generation field
  in `Vote` or `CommitCertificate` (`02-consensus.html` encoding table, lines 32–42), no
  generation-bearing witness object (`05-proof-statement.html` **PRF-03**(a)–(f), lines 218–232), and
  no L1 storage that records which heights were discarded.

**Why the guest check cannot reject anything (the vacuity, precisely).** In the zkVM model the
*journal is the public input vector the contract hashes* (PRF-02 preamble; L1-05: "The contract hashes
the whole vector ... into `statementHash` and passes only that hash and the opaque proof to the
verifier"). The contract derives `recoveryGeneration` from its own storage and puts the **current**
value into the journal it hashes. A prover that builds a proof for any history simply sets the
journal's `recoveryGeneration` to that same current value (it can read L1). The guest, running
offline, has no access to contract storage, so "require the journal's `recoveryGeneration` to equal
the generation the L1 contract supplies" reduces to `x = x`; the only alternative an implementer could
invent — passing the contract's generation as an untrusted host hint — is exactly what `PRF-11`
("Nothing computed by the host is trusted ... unverified assertions at the point they enter") forbids.
`configHash` cannot repair this: recovery "may not be used as a configuration-capture mechanism"
(REC-02 "No discretion") and "no configuration value may be changed by recovery", so the pre- and
post-recovery configuration hashes are equal by rule. The generation is a **freshness counter for
proofs**, not a **provenance tag for certificates**: an *old proof* cannot be replayed, but the *old
history* can be re-proven, and `CONS-08`(3) makes its certificate "valid **forever**".

**Assumptions and preconditions.**
1. One recovery has completed, restoring checkpoint `H_c` and incrementing the generation to `g+1`
   (REC-02; a settlement stall of `T_STALL` is the trigger, and `T_STALL` elapses whenever the
   L2 or the prover fleet is unavailable — REC-03 names exactly these cases).
2. The discarded branch descends from the restored checkpoint: its block at `H_c+1` has
   `parent_hash` = the checkpoint's `blockHash`. This is the **normal** case: "discarded history
   above the checkpoint" is precisely the unlanded extension of the checkpoint (REC-01, REC-02
   "Invariant").
3. The attacker holds the discarded branch's payload (the withholding proposer distributed it
   selectively and kept it; or the stall was a proving outage and the data is still served) and the
   branch's commit certificates (public under CONS-05 "Publication", or held by the withholding
   proposer — the exact T-4 case).

**Concrete attack trace (no stake, no validator key, no bond).**
1. Honest chain runs; L1 checkpoint `H_c` = 1,000,000 at generation `g`; heights
   1,000,001–1,000,900 are PoS-certified (certificates exist and are valid forever, CONS-08(3)) but
   unsettled because no proof has landed (prover outage: outside A-DA-2; or the block bodies were
   selectively distributed: T-4).
2. `T_STALL` elapses. Any account invokes recovery (REC-02 "Who may invoke"); nothing lands during
   `T_RECOVERY_DELAY`; recovery **completes**. L1 now has: `lastLandedHeight = H_c` (unchanged —
   recovery "is not a batch: it accepts no data, advances no checkpoint forward") and
   `recoveryGeneration = g+1`.
3. The attacker splits the discarded range at the epoch boundaries PRF-05 forces, and for each
   resulting batch `[f, l]` builds a **new** proof over the discarded payload with the journal:
   `prevHeight = H_c`, `prevBlockHash`/`prevStateRoot` = the restored checkpoint's values
   (L1-05 rows 3–5), `recoveryGeneration = g+1` (L1-05 row 31), `configHash` unchanged.
4. Every check passes. `L1-06`: `firstBlockHeight = H_c+1 = lastLandedHeight+1`. PRF-04: the head
   certificate is valid under the L1-pinned `setRoot(epoch)` (CONS-08(3)). PRF-06: the header chain
   links to `prevBlockHash`, i.e. to the restored checkpoint, because the discarded branch was built
   on it. PRF-05(ii): the batch that opens an epoch carries the discarded branch's own
   `epoch_anchor` and its closing-epoch certificate — which also exists and is valid forever — and L1
   pins the same roots, so the anchor duty does not distinguish the branch either. PRF-04(viii): the
   journal's generation **is** the contract's current value. `land(data, proof)` accepts.
5. `lastLandedHeight` advances back to 1,000,900. The **discarded history is canonical again**, and
   the recovery's rollback is undone. Any post-recovery history the honest validators and users built
   above `H_c` (re-produced blocks, re-executed transactions, resubmitted bridge messages) is now a
   conflicting branch at the same heights, with its own valid certificates — the state CONS-15(1)/(2)
   orders nodes to halt in.

**Inside / outside the claimed fault model.** **Inside.** Threat T-4 (withholding of any message
class) and the mandatory schedule of `01-requirements-and-threat-model.md` §6.2 —
"4. Other participants initiate a leader change, validator change, or **recovery**. 5. The attacker
**reveals the certificate after the alternative path has progressed**" — is answered by WH-04 with the
assertion that "a certificate revealed later for a discarded height is evidence against an equivocator,
**never a second canonical history**". This attack is that schedule, under Mode B, and the assertion is
false: the revealed certificate is re-proven and landed. The trigger (a settlement stall) occurs in the
F1 class, which is the class REC-02 exists for; REC-03's premises do not need to be broken because the
attacker does not need to *induce* the stall — it only needs to be ready when one occurs. No security
assumption (A-CONS-1, A-CRYPTO-*) is broken.

**Attacker resources and cost.** The discarded payload and certificates (a withholding proposer, or any
node that served the branch, already holds them); one permissionless proof generation per batch
(minutes of commodity proving — the cost the honest provers already pay, and L1-10 pays a reward for
landing); L1 gas for `land`. **No stake, no bond, no validator key, no DAO action, no L1 censorship.**
The recovery bond is the *invoker's*, not the attacker's, and it is refunded on completion (REC-02
"Bond outcome").

**Harm and the exact requirement / fixed decision affected.**
- **D-7**: the guarantee class ("a PoS confirmation above it is provisional; recovery may replace
  history above the checkpoint") is not stable — the replacement can itself be replaced by the
  pre-recovery history, through the normal L1 acceptance path, without a second recovery.
- **REC-01 / REC-02 / HALT-04**: history above the checkpoint is replaced by a path *other than* the
  sanctioned recovery, and the "Late proofs"/"Late certificates" rows are falsified.
- **R5** (consensus safety and the selected mode's confirmation guarantee), **R13** (a rule that cannot
  be implemented without inventing a new one).
- **INV-01 / CONS-12** (see R4A-03): after the re-landing there are two valid certificate chains at the
  same heights.
- **Users**: every effect of the post-recovery chain (including bridge effects that the REC-02
  "Transaction replay" row had keyed to `(chainId, domain, height, commitment)` to be safe *in one
  direction*) is invalidated in the other direction; a user who acted on the restored checkpoint loses
  the action, and a user who acted on the discarded branch can have it restored *after* the recovery
  told them it was void.

**Evidence.** `06` REC-02 lines 356, 362–364, 370; `05` PRF-02 lines 112–117, 177–199, PRF-03
lines 218–232, PRF-04(viii) lines 273–283, PRF-11 line 449–463; `04` L1-05 row 31 (line 164) and
§2.1 (line 203), L1-06 (lines 207–218); `02` encoding table lines 32–42, CONS-08(3) lines 248–251,
CONS-02 lines 94–102; `01` §5 class F1 (line 146), §6.2 lines 168–182, T-4 line 160.

**Fix direction (not applied here).** Bind the generation to the *signed* consensus objects — add
`recoveryGeneration` (or the pair `(configHash, recoveryGeneration)`) to the `Vote`/`Proposal`
signed bytes and to the header commitment, so pre-recovery signatures are invalid under `g+1`; or
record an L1 "discarded-branch anchor" (the highest certified block hash at recovery time) and make it
a public input that the batch's header chain must not descend from. Either change makes REC-02's two
rows checkable. As written, neither exists.

---

## R4A-02 — High — recovery does not define what happens to per-height locks at discarded heights; CONS-04 then makes them permanent and the new chain is wedged at the first locked height, while CONS-04(2)/CONS-15(2) order the honest locked validators to halt

**Severity rationale (one line).** A completed recovery discards the heights above the checkpoint but
nothing releases the locks formed there; the only release rules are "the commit of `H`" or a
strictly-later same-height PoLC (CONS-04(1)–(2)), and the post-recovery chain restarts rounds at 0
with a different value, so a lock carried by ≥1/3 of the epoch's power makes that height — and
therefore the whole chain — unfinalizable forever, with no rule able to clear it. That converts the
F1 availability failure D-7 was selected to repair into the unbounded halt D-7 rejected.

**Exact rules / missing rule.**
- `02-consensus.html` **CONS-04**(1): the lock "is released by (a) the commit of `H` (CONS-05) ...
  or (b) the unlock of (2)". **CONS-04**(2): "A validator that holds a lock at `H` and obtains a
  valid commit certificate at `H` for a different block has evidence that the assumptions failed: it
  halts (CONS-15(2)) and MUST NOT treat the certificate as an unlock." **CONS-04**(4): no precommit
  without a PoLC.
- `02-consensus.html` **CONS-15**(2) lists "a valid commit certificate for a block conflicting with
  the validator's own lock at that height" as a halt trigger.
- `02-consensus.html` **CONS-09**(3): "a lock formed at a height of epoch `e` on a value that did
  not finalize there **is resolved at that height** ... the lock is not carried forward as an
  independent constraint" — **no rule performs this resolution**; it is an assertion, and it is the
  only text an implementer could use to release a stale lock.
- `06-recovery-exceptions.html` **REC-02** / **HALT-02** (lines 111–134): recovery restores the
  checkpoint and HALT-02 says a node "must not treat a discarded block above it as finalized", but
  neither rule mentions locks, and HALT-02(a) reaffirms that the persistent sign-state store survives
  ("the amnesia case is treated as a signing fault, not as a fresh start").
- **Missing rule:** the treatment of `(locked_height, locked_value, locked_round)` for heights above
  a completed recovery's restored checkpoint.

**Assumptions and preconditions.**
1. At least one height `H > H_c` has honest validators locked on a value `B` that never finalized
   locally, with locked share ≥ 1/3 of that epoch's voting power. Reachable under T-1 (selective
   delivery) and T-4 (withheld certificate): a proposer/aggregator that collects a PoLC and withholds
   the commit certificate leaves the validators that saw the PoLC locked on `B` (WH-01, row
   "Finality certificate": "the lock rule is what protects safety"). It is also the literal case
   HALT-01(a) names — "it cannot obtain the data for a finalized **or locked** block".
2. A settlement stall of `T_STALL` follows (the L2 is stuck at `H`, so no batch extending the
   checkpoint can be produced or landed). Any account may then invoke recovery (REC-02 "Who may
   invoke"); nothing can cancel it because the L2 cannot produce a batch.
3. `T_RECOVERY_DELAY` elapses before the network/availability condition heals (or the withheld
   certificate is published). This is the ordinary case for the F1 events REC-03 itself lists.

**Concrete attack trace.**
1. At height `H` (say `H_c + 500`), >2/3 prevote `B` (selective delivery); the honest validators
   that see the PoLC precommit `B` and are locked on it; the certificate is withheld (or the data of
   `B` is already unavailable). `H` cannot finalize.
2. The L2 stalls at `H`; settlement stalls with it. After `T_STALL`, recovery is invoked
   (permissionlessly, possibly by an honest party) and completes: generation `g+1`, checkpoint
   `H_c`, "history above `H_c` is provisional and is replaced".
3. The L2 resumes at `H_c+1` (HALT-02: from the checkpoint restored by the recovery) and re-produces
   heights toward `H`. When it reaches `H`, the locked validators (≥1/3) must prevote their locked
   value `B` (CONS-02(b), CONS-04(4)); `B` is not a valid block of the new chain (its parent is a
   discarded block, or it is simply not the proposal). No PoLC for a different value can form, because
   that needs >2/3 and the locked share is ≥1/3. They cannot unlock: CONS-04(2) requires a PoLC at
   `(H,p)` for a different value with `locked_round < p < R`, and no such PoLC can exist. Timeouts
   grow to `T_max`; every round produces the same state. Height `H` never finalizes, and no later
   height can be produced (one block per height, parent validity of CONS-01(iii)). **The chain is
   permanently stuck at `H`.**
4. If the honest locked validators instead see a valid commit certificate for a *different* block at
   `H` on the new chain, CONS-04(2) and CONS-15(2) order them to **halt** and forbid treating it as
   an unlock. If they see the old certificate for `B` (the withholder publishes it), CONS-04(1)(a)
   says the lock is released by "the commit of `H`" — but HALT-02/REC-02 say they must not treat the
   discarded block as finalized, so it is ambiguous whether that certificate releases the lock. Either
   reading is a defect: the first is a permanent wedge, the second makes the chain's recovery depend on
   the **withholder choosing to publish**. A second recovery cannot help: it restores the same
   checkpoint `H_c` (nothing landed in between) and clears no lock; the bond is refunded on
   completion, so the loop is free.

**Inside / outside the claimed fault model.** The *lock state* is reachable inside A-CONS-1 (T-1/T-4,
and HALT-01(a) names it); the *trigger* is an F1 failure, which REC-03 correctly places outside a
sub-threshold coalition's power ("the absence of any prover is an availability failure rather than an
attack inside A-DA-2"). The finding is therefore not "a sub-threshold attacker induces recovery"; it is
that **Mode B does not repair the F1 class it was selected for**: the recovery removes the height whose
data/certificate was lost but leaves the state (the lock) that made it unfinalizable, and the new chain
reaches the same height with the same state. This is the failure D-7's own rationale says must not
happen ("an availability failure under Mode A produces an **unbounded halt** whose only remedies are
outside the protocol, while the requirement set also demands a chain that keeps serving users").

**Attacker resources and cost.** To create the lock: a proposer/aggregator position plus selective
delivery (T-1/T-3/T-4) — no stake is needed to *withhold* a certificate, and <1/3 Byzantine prevotes
plus selective delivery are enough to produce the split lock/no-certificate state. To keep the chain
dead afterwards: nothing; the honest validators' correct execution of CONS-04 does it. If the harm is
instead reached with no adversary (A-CONS-5 data loss at a locked block), the cost is zero.

**Harm and the exact requirement / fixed decision affected.**
- **D-7's justification** (a bounded rollback that lets the chain keep serving users) and **LIVE-01**
  ("the sanctioned recovery ... may replace the unsettled history ... and the chain resumes from the
  restored checkpoint") — false in this state.
- **R6** (conditional liveness with exact end conditions): this end condition is not stated; the
  limitation register (LIM-01) does not carry it.
- **R13**: an implementer must invent whether a lock survives a recovery — the unsafe choice (clear
  it) removes the withheld-certificate safety argument, the safe choice wedges the chain.
- **CONS-04(1)(a) vs CONS-04(2)**: "(a) the commit of `H`" is unqualified while (2) forbids treating a
  conflicting commit as an unlock; after a recovery-by-rule those two clauses point in opposite
  directions.

**Evidence.** `02` CONS-04 lines 133–176, CONS-15 lines 481–502, CONS-09(3) lines 272–279;
`06` HALT-01 line 83, HALT-02 lines 111–134, REC-02 lines 356, 361, 365–367, WH-01 line 227,
WH-04 lines 270–324; `10` LIVE-01 lines 118–135, LIM-01 liveness/consensus rows.

**Fix direction.** A rule in REC-02: on completion, every lock at a height above the restored
checkpoint is void (the value it protects is void by rule), and the honest validator resumes with an
empty lock at those heights, with the explicit carve-out from CONS-04(2)/CONS-15(2); plus a decision on
CONS-04(1)(a) — "the commit of `H` **of `locked_value`**" — and deletion or operationalisation of
CONS-09(3)'s "resolved at that height".

---

## R4A-03 — High — CONS-12's restated invariant and INV-01 are false as written under the selected mode: they claim uniqueness of *certificates* per height, which any completed recovery deliberately breaks

**Severity rationale (one line).** The central safety claim was restated "relative to the authenticated
checkpoint", but its antecedent still quantifies over all valid certificates, and Mode B guarantees
that two valid, forever-valid certificates at the same height with conflicting values exist after every
recovery; the rule therefore states something false and the reader cannot tell what the real claim is.

**Exact rule.** `02-consensus.html` **CONS-12** (lines 391–426): "if certificate `C1` finalizes block
`B1` at height `H1` and certificate `C2` finalizes block `B2` at height `H2 ≤ H1` (**each valid
per CONS-03 and CONS-05**), then the ancestor of `B1` at `H2` is `B2`: the finalized prefix is
unique." `10-assurance.html` **INV-01** (lines 17–19): "at most one block per height ever receives a
valid commit certificate under the consensus rules, and every such block is an ancestor of every later
such block". `06-recovery-exceptions.html` **WH-04** (lines 270–284) concludes that a late certificate
is "never a second canonical history".

**Counterexample (no adversary beyond the selected mode itself).** Let `C_old` be the commit
certificate that PoS-finalized block `B_old` at height `H` before the recovery; `CONS-08`(3) makes
it "valid **forever**", and REC-02 only makes it "void for canonical purposes". Let the recovery
complete, restoring `H_c < H`, and let the resumed chain finalize `B_new ≠ B_old` at the same height
`H` under the same L1-committed set `set_root(epoch_of(H))` (this is the designed outcome: the
restored chain must re-produce every height above `H_c`). Both certificates are "valid per CONS-03 and
CONS-05"; at `H2 = H1 = H` the ancestor of `B_new` at `H` is `B_new ≠ B_old`. CONS-12's conclusion
is false. INV-01's first clause ("at most one block per height **ever** receives a valid commit
certificate") is false for the same reason. The qualifier in CONS-12 ("above the last accepted
checkpoint the invariant is conditional on the recovery rules") is attached to the *discussion*, not to
the *antecedent of the implication*, so it does not make the statement true; and once it is attached,
the remaining claim is no longer "the finalized prefix is unique" but "the certified prefix is unique
**within one recovery generation**" — a different, unstated theorem.

**Assumptions and preconditions.** One completed recovery; the re-produced chain finalizes a different
block at a discarded height (guaranteed in general: the re-produced block's parent/contents/timestamp
differ, and the locked-value case is R4A-02).

**Inside / outside.** Inside (a completed recovery suffices; no assumption failure, no adversary).
The inconsistency is between two selected rules, so it cannot be dismissed as F1/F2.

**Attacker resources and cost.** None; this is a specification-level inconsistency.

**Harm.** The document's headline safety claim (README "no reviewer has found a
two-conflicting-finalized-histories attack", CONS-12, INV-01, WH-04) is not a well-posed theorem under
Mode B. An implementer that reads INV-01 literally will build a client that treats any second valid
certificate at a height as an assumption failure and halts after every recovery (R4A-02's halt path);
one that reads "void for canonical purposes" will invent a generation-scoping rule, which is exactly
what R4A-01 shows cannot be implemented from the current objects. Affected: R5, R13, CONS-12, INV-01,
WH-04, and REC-03's claim that the recovery is the *only* replacement path.

**Evidence.** `02` CONS-12 lines 391–426, CONS-08(3) lines 248–261, CONS-15(1) lines 490–493;
`10` INV-01 lines 17–59; `06` REC-02 lines 356–363, WH-04 lines 270–324; `01` §6.2 lines 168–182,
§6.5 lines 217–224.

**Fix direction.** Restate CONS-12/INV-01 as generation-scoped: "within one recovery generation, at most
one block per height receives a valid certificate and the certified prefix is unique; across
generations, exactly the generation named by the L1 checkpoints is canonical, and the only sanctioned
transition is REC-02." Then R4A-01's rule becomes the load-bearing one, and it must be made checkable.

---

## R4A-04 — Medium — concurrent recovery invocations and the generation counter's storage are unspecified; a stall can bump the generation repeatedly at no bond cost, and the counter contradicts the frozen L1-07 checkpoint record

**Severity rationale.** Two security-relevant rules are left for the implementer: whether a second
recovery may be invoked while one is pending (and what happens to the first bond), and where
`recoveryGeneration` lives, which PRF-02(5) puts in "the same record that holds the accepted
predecessor checkpoint" while L1-07 fixes that record's exact field list and hash without it.

**Exact rules.** `06` **REC-02** "Who may invoke" (line 358), "Bond outcome" (line 360), "Repeated
recovery" (line 367): the bond escalates with "the number of **completed** recoveries in the preceding
`REC_WINDOW`", and is "returned in full when the recovery completes". Nothing says a second invocation
during a pending recovery is rejected, cancelled, superseded or refunded. `04` **L1-07** (lines
223–239) fixes `Checkpoint = (height, blockHash, stateRoot, epoch, setRoot, dataCommitment,
l1BlockNumber)` "in this order", with the record hash over exactly those fields and "written once and
never edited". `05` **PRF-02**(5) (lines 177–188) and `04` **L1-05** row 31 (lines 164, 203) say
`configHash` and `recoveryGeneration` are read "from the same record that holds the accepted
predecessor checkpoint".

**Concrete case / attack trace.**
1. A stall of `T_STALL` is in progress (any F1 event). Accounts A₁…A_N each invoke recovery within one
   L1 block or across a few blocks. Each posts `B_REC(e) = B_REC_BASE · 2^n` with the same `n`
   (no completion has happened yet), i.e. the base bond, and each is "returned in full when the
   recovery completes".
2. If all N pending recoveries are honoured, the generation increments N times. A proof generated after
   completion i carries generation `g+i` and is rejected as stale after completion `i+1`, so honest
   provers must re-prove (minutes) after every bump; if the stall persists, the attacker can hold the
   chain in a bump loop and make settlement progress depend on outrunning it. If instead a superseded
   recovery's bond goes to the treasury, that destination, and whether the superseded invocation is
   cancelled at all, are unstated; an implementer must invent them.
3. Independently, if the generation is literally stored in the same record as the checkpoint (PRF-02(5),
   L1-05 row 31), a completed recovery **edits the record at `H_c`** — violating L1-07's "written once
   and never edited", changing the record hash that L1-05 row 2 uses as `previousCheckpointHash`, and
   forcing a storage-layout decision (MIG-02 slot budget; MIG/GOV obligations to "preserve the
   checkpoint record and the generation counter"). If it is stored elsewhere, "the same record" is
   false and the atomicity of "checkpoint and generation" is not specified.

**Inside / outside.** Inside (any account may invoke, per REC-02; no assumption failure is needed
beyond the stall that makes recovery available).

**Attacker resources and cost.** L1 gas for N invocations (bonds refunded on completion), plus the L1
inclusion race. No stake.

**Harm.** A generation-replay path of the second kind (repeated invalidation of honest proofs during a
stall), an unspecified bond destination for superseded invocations, and a normative storage conflict
with the frozen checkpoint record. Affects R11/R13, REC-02, L1-07, PRF-02(5), MIG/GOV preservation
duties.

**Evidence.** `06` REC-02 lines 358–367; `05` PRF-02 lines 177–188, 200–210; `04` L1-07 lines
223–243, L1-05 rows 2 and 31; `09` recoveryGeneration row line 149; `10` LIM-01 recovery rows.

---

## R4A-05 — Medium — the sign-state store and the recovery rollback interact: every re-produced height needs a fresh round, and no rule states it; the obvious "fix" (clearing the store) is the amnesia attack

**Severity rationale.** CONS-02's uniqueness store is keyed by `(chain_id, H, type)` with
`(round, value)` pairs and must survive restarts; recovery makes honest validators re-produce heights
at which they already signed, so at every re-produced height the rounds they used before are muted for
them. The behaviour is determined (skip to a fresh round) but the recovery's timing derivation and the
learning material do not account for it, and CONS-02 explicitly forbids the tempting alternative.

**Exact rules.** `02` **CONS-02** (lines 94–102): "if `(R, value')` is present with
`value' ≠ value(m)`, the signer MUST refuse to sign ... including votes for `NIL`"; the store "MUST
survive process restart". `06` **HALT-02**(a) (lines 117–121): the check applies "including after a
restart or a state resync ... the amnesia case is treated as a signing fault, not as a fresh start".
`06` **REC-02** "Derived rollback duration" (line 366): "`T_STALL + T_RECOVERY_DELAY` + resume time",
with no term for the muted rounds. `02` **CONS-07**(3) (lines 225–229): each extra round costs
`T_min·2^…` seconds (3, 6, 12, 24, 30 …).

**Concrete case (no adversary).** The pre-recovery chain is in its happy path: every validator signed
PREVOTE and PRECOMMIT at `(H, 0)` for every height `H` of the discarded range. After the recovery,
at each re-produced height the new chain's round 0 cannot obtain those validators' signatures for the
new block (and cannot obtain NIL either), so round 0 times out and the height finalizes at round 1 —
one extra `T_min` (3 s) per re-produced height, i.e. up to `D_MAX × T_min` of unstated delay on top of
"resume time", and more where the discarded chain used several rounds. An implementer who clears the
store at the recovery boundary to avoid this violates CONS-02/HALT-02(a) and re-opens the amnesia
equivocation.

**Inside / outside.** Inside (no adversary; a completed recovery suffices).

**Attacker resources and cost.** None.

**Harm.** The recovery's duration and liveness budget are wrong as stated; a client that clears its
sign state becomes slashable (CONS-11 same-`(height, round)` pairs). Affects R13, CONS-02, CONS-07,
REC-02's "Derived rollback duration", LIVE-01's "resume" claim, and the learning course's timing page.

**Evidence.** `02` CONS-02 lines 94–102, CONS-07 lines 225–234; `06` HALT-02 lines 117–127, REC-02
line 366; `09` TIMEOUT_MIN/MAX row.

---

## R4A-06 — Low — REC-02's "Late proofs" rationale is factually wrong on its own terms

**Severity rationale.** The conclusion ("void") is the substance of R4A-01; the stated *reason* is
false even if the conclusion were enforceable, so the citation misleads the implementer about what to
check.

**Exact rule.** `06` **REC-02** "Late proofs" (line 363): "A proof whose batch lies above the restored
checkpoint is void: **its predecessor no longer exists**." For a discarded branch that descends from
the restored checkpoint — the normal case — its predecessor at `H_c` is exactly the restored checkpoint
record, which exists by definition of the recovery, and L1-05 rows 3–5 would be filled from it. The
condition that would make the sentence true (the branch not descending from the restored checkpoint)
is the safety-failure case, not the recovery case.

**Inside / outside.** Textual (affects R13 clarity; substance in R4A-01).

**Harm.** None by itself; it hides the real rule that is missing.

**Evidence.** `06` REC-02 line 363 vs line 356 ("the checkpoint after recovery is exactly that
record") and `04` L1-06 lines 207–218.

---

## Checked, and I could not re-break (one line each)

- **Per-height lock within a generation (CONS-04(1)–(4), R2A-10 / R3A-03):** the lock is a per-height
  triple released by that height's commit or a strictly-later same-height PoLC; the same-height
  CometBFT Proof of Safety transfers, and WH-04's retracted "carry the closing epoch's lock forward"
  text is gone. Holds — the failure above is at the *recovery* boundary, not inside the rule.
- **Anchor duty and boundary case analysis (CONS-09(1)–(2), (4); F1):** the first block of `e+1` must
  carry `epoch_anchor` and descend from `B_anchor`, each correct validator verifies the epoch-`e`
  certificate itself, case (a)/(b) reduces a cross-boundary conflict to a same-height epoch-`e`
  conflict, and the evidentiary narrowing to same-`(height, round)` pairs is disclosed (CONS-09(4)(a),
  LIM-01). I could not construct a fork that avoids a violation of the signing/lock rules under
  A-CONS-1; F1's remaining exposure is the disclosed "no admissible evidence" case, not a new break.
- **PRF-05(ii) trigger keyed to the batch's first block, and `B_anchor.next_validators_hash` checked
  against the L1-pinned root of the opened epoch:** closes R2A-03/R2A-04/R3A-04 for this angle; the
  non-boundary headers' `next_validators_hash` is deliberately deferred to the next opening batch and
  not used as authentication in the meantime.
- **Single quorum predicate `3·s > 2·W` (CONS-03), single MEM-08 set encoding, L1-resolved
  `epoch → setRoot` (MEM-08/09, CONS-10, CONS-13), two-epoch lookahead wiring, and REC-01's boundary:**
  consistent across `02`/`03`/`04`/`05`; the P1–P5 premises of CONS-12 hold except that P5 plus the
  recovery rules produce R4A-03.

## Notes for the lead (ordering)

1. R4A-01 must be fixed *before* any further review of Mode B's economics: it is the mechanism the D-7
   selection and REC-03 are built on, and it is a wire-format change (vote/header generation binding),
   not an edit.
2. R4A-02 turns the "availability failure" case into the unbounded halt D-7 rejected; the lock-release
   rule and the CONS-04(1)(a)/(2) carve-out are needed in the same change.
3. R4A-03 is a restatement of CONS-12/INV-01 that should follow from (1) and (2): generation-scoped
   uniqueness, with WH-04's conclusion weakened to match.
