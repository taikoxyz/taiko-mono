# G5: research note on a later fix

**Labels.** [proven] means an argument written out on this page or in the cited spec text, not machine verification. Round findings and verdicts in sections 4 and 5 come from round reports that are not in the tree; a [proven] tag on a verdict means the step from the listed findings is written here, not that the findings were re-derived. [assumed] means a premise, a proposed rule, or a figure nobody has measured. [open] means unresolved; where possible the note says what would close it. Numbers use S2's defaults unless stated: `m = 32`, `Q = 22`, `2Q − m = 12`, a cross-count backing of 7, TERM 60 s, 12-s L1 slots, ANCHOR_MIN_AGE 48 s (C2's register), VC_FALLBACK 10 s, FB_CONTEST 3 L1 blocks and 30 s, and LANDING_GAS_BUDGET 10,000,000 gas (C2's register).

## 1. Purpose and status

This is a research note. It is not a specification and it changes no rule. [proven: by D73 (1)] D73 (1) is the user's decision to "accept now, fix later". Its terms are: adopt B's S2 candidate #22226 at `3d91d39` as S2 once its review completes; publish G5 in S2-R18's locked label, with S3's D1 discharge repeating that sentence word for word; and open a research track for a fix that adds on-chain state, to ship later as a DAO upgrade under R1. [proven: by D73 (1)] This note is the first entry in that track.

[assumed: reading of D73] G5 stays published in S2-R18's locked label, in the wording below, until a DAO upgrade ships a fix that has passed its own attack rounds and has the user's sign-off. [assumed: reading of R1] Any fix ships after launch the same way: an inbox upgrade under R1 together with a coordinated client release. [open: for the user] D73 (1) scopes this track to "a fix that adds on-chain state", and the same decision records that the state-free fix failed. LEL, the main line in section 6, adds no storage slot. Whether a fix without new storage belongs on this track is the user's decision, not this note's.

Section 4 records three candidate designs and the two independent red-team rounds run against each. [proven: from the findings listed in section 4, taken as recorded] No candidate removes the user-level harm D73 published. LEL narrows it, conditionally; ballot epochs would bound the stall of one form only once fixes that no round has tested are applied; TBCR fails.

## 2. G5 restated

[proven: quoted from S2-R18 of #22226 at `3d91d39`, the locked row] "A locked block can be lost with no slashable evidence when the leader plus one committee position wins R20’s private-continuation race; the resulting pipeline stall is repeatable and lasts until eligible certificate-free recovery, with no unconditional completion bound." [proven: S2-R18, D1 as published] D1's third exception before full backing is "a quorum's private continuation landed before the closing is recorded".

The trace, at `m = 32`, `Q = 22`, one redraw count, with C40 public. [proven: S2-R20 of the same candidate, the G5 TERM_END trace and the continuation-first stall; the stamp in step 1 is this note's example, and the formation time in step 3 is S2 §6's (b)-path figure]

1. The leader of the term's last view sends block 41, which carries C40, to exactly 21 honest keys before their receipt cutoff. It is stamped late enough (for example `termEnd − 1`) that no further block of the view follows it.
2. The one malicious committee position X adds the 22nd attestation privately. C(41) = C(h+1) then exists only in the coalition's hands.
3. At TERM_END(b) every honest key that still holds only C40 casts its single class-H vote at lock 40. R07's ban on voting after an uncertified attestation applies to TIMEOUT, not to TERM_END(b). The closing H(40) = H(h) forms at about `termEnd + 2.6 s`, and its successor view certifies blocks that are labelled locked.
4. The coalition lands a prepared original range ending at 41, with end certificate C(41), before H(40) is recorded. H(40)'s whole successor generation is now permanently unlandable, because it does not extend `lastLanded = 41`.

Why it cannot be repaired. [proven: S2-R20] The honest keys have spent their one class-H vote for this closing context. A second closing at 41 within the same count would need at least `2Q − m = 12` double-signing positions, and a redraw would intersect H(40)'s 22 voters in at least 7 positions. A FALLBACK is refused by honest later committees, because they hold H(40). Nodes holding certificates on the stranded successor keep their incompatible locks, so a certified REPLACE cannot assemble its end certificate. The remaining exits are certificate-free: C3's hatch, whose A1 gate opens about 36 min after the attack landing (46 min with C2's one deferral) and which also needs its cooldown, a queued request, proof, FI gate and inclusion; or S1's dead mode, whose earliest first block is about 76 min after the attack landing (75 min 36 s in S2-R20's trace, `E + 4,488 s` with `E = termEnd(z + 1)`), plus proving in either case. These are eligibility times: S2-R20 states no unconditional completion bound.

[proven: S2-R20, coalition and evidence] The attack needs the leader's role and one committee position. It leaves no S1, S3a, S3b, S3c′, S3d, S3e or S6 evidence and pays no MISS, since the trace closes by TERM_END. It can be repeated at every term end where the coalition again holds both roles and obtains selective timely delivery, a ready proof and favourable L1 ordering. [proven: S2-R20, limited prefix] The zero-evidence old prefix is at most `CERT_LAG_MAX + 1 = 2` blocks (41, or 42 carrying C40). A certificate at 43 or higher must carry a certificate above 40, and, within one redraw count, its quorum then meets H(40)'s quorum in at least 12 positions with S3b evidence when the authenticated evidence is available; across redraws, actual membership intersection and S3e apply. S2-R20 calls this a bound on the zero-evidence prefix, not on the displaced successor blocks or the stall. [proven: S2-R20] A reveal form exists as well: H(40) is recorded first, then C(41) is gossiped. Honest locks rise to 41 under R06, so honest keys refuse H(40)'s successor and the same stall follows.

[assumed: naming, this note] The sibling route that section 4's rounds turned up is called **G5-F** here. The coalition selectively reveals C(h+1) before any class-H closing forms, so the honest class-H votes split and no closing reaches Q. A later committee forms a FALLBACK F, and honest keys lock on F's successor. X then completes H(h) with its withheld vote and records it before F is final, and R14(iii) kills F. [assumed: from the round findings; B independently checked G5-F against S2 at `737439f` and is adding its disclosure and vector to S2 (#22235 review 5970501338), noting it needs no attacker proof or original-continuation landing] The keys locked on F's dead generation then refuse H(h)'s successor, and the stall runs to the hatch or dead mode. [proven: S2-R18's attested row] S2-R18 already publishes that "two colluders can time" a revert of a chain above a non-final FALLBACK. [proven: S2-V23 and S2-V33 as written] S2-V23 (a) kills a non-final F by a colluders' certificate record and loses its blocks unslashed, and S2-V33 (a) reveals a late certificate above a final F; neither vector states a stall of keys locked on the generation of a killed F. [open] Whether #22226's text discloses G5-F's stall, and not only its revert, is for S2's owner to confirm. A fix that leaves G5-F open does not remove D73's harm, because the coalition, the evidence (none) and the stall are the same.

## 3. What failed before and why

**The cap design** (`s2-variants/panel/rebase.md`, a scratch file not in the tree, "one cap per view"). [proven: from that file's §2] Each view got at most one L1 cap: its live class-H record, or else a final FALLBACK. L1 landed a view's blocks only along its cap's line. Nodes dropped certificates that a cap or a dead FALLBACK made unlandable, suspended off-line certificates of a closed opening while they held a closing, abandoned closed openings, and re-signed timeouts whenever their lock changed (rules B-1 to B-5). [proven: D73 (1)] It failed six attack rounds. [assumed: summary of the round records cited by D73] The failures came from the node-side void, suspend and abandon sets, and from making a recorded cap a precondition for landing any segment of a view: this created new wedges at view and term boundaries, and new FALLBACK interactions, faster than the fixes closed them. Lesson for this note: a fix should not gate ordinary landings on a per-view record, and should not add node-side certificate-suspension states.

**The state-free fix** (`s2-variants/S2-B-statefree.md`, a scratch file not in the tree). [proven: from that file's status block] It added no storage. Instead it retired held locks that a verified landing had made incompatible, or that sat above an aged operational closing of their own opening, marked the affected generations dead, and added a closing-vote floor because retirement had removed the lock monotonicity that S3b safety relied on. [proven: D73 (1)] It failed three rounds, one with a Critical finding. [assumed: summary of the round record, which is not in the tree] Lowering locks inside the closed opening let honest keys sign closing votes below certificates carried by headers they had attested, which reopened S3b slashing of honest keys. A rebase-marked vote plus an S3c′ exemption did not repair this, and a late-reveal variant still wedged locks. Lesson for this note: a fix must never lower a lock inside the closed opening, and the reveal form must be handled without an aged-record window.

## 4. Candidates

Each candidate below went through two independent attack rounds. [assumed: round verdicts as recorded in reports not in the tree] Round verdicts: LEL, survives-with-fixes twice. Ballot epochs, survives-with-fixes twice. TBCR, survives-with-fixes once and fails once.

### 4.1 Locked-end landing (LEL)

**Mechanism.** [assumed: proposed rules]

- *Rule 1, C2-R05 L5′ "end lock".* When a landing's last segment is a committee-mode holder view, the landing must carry one of two end locks, or it reverts with `EndNotLocked`. Sentinel 255, hatch 254, no-committee and replacement shapes keep today's L5.
  - Kind 0 is a two-chain witness: a PH preimage `PH_b` and a certificate `C_b`. `PH_b` is in the same term, view and opening as `endCert`, sits 1 or 2 heights above the end `e`, and carries `certHash(endCert)`. `C_b` passes L5's own quorum check.
  - Kind 1 is one trailing closing (class H, or a final non-dead FALLBACK) whose lock is the landing's end. It is consumed: it writes `lastVCHash`, and MISS applies if it is a TIMEOUT.
- *Rule 2, S2-R06′ two-chain lock.* `lock_i` is the highest of three things: the certificate carried by any header the key attested, the opening lock of any view it attested in, and `lastLanded`. `high_i`, the highest certificate held, is kept for building the tip and for timeouts.
- *Rule 3, toLock scoping (variant T1).* A key's timeout `toLock` for closing context X is the highest held certificate under X's own opening.
- *Rule 4.* A key that holds a redraw proof for count n signs no attestation at a lower count.
- *Rule 5.* Delete D1's third exception and amend the attested row.

**State added.** [proven: by construction] No storage slot. The lock commitment travels in calldata: an `EndLock` struct of about 0.7 to 1.0 KB, one new error, and for kind 1 a write to the existing `lastVCHash` slot.

**Gas.** [assumed: unmeasured, an MP-05 row] Kind 0 adds about 125k to 185k per landing: one EIP-2537 aggregate check of about 103k plus key aggregation, the PH hash and calldata. Kind 1 adds about 165k for one view-change witness. Round 2 (L-6) priced the range at about 110k to 185k. A typical landing goes from about 1.5M to 1.65M to 1.7M, and the worst pinned case from 2.7M to about 2.9M, which is 29% of LANDING_GAS_BUDGET. [open: round 2, Medium] The 2.7M base is C2's own figure and is open in MP-05, so the claim that L5′ fits the budget is not established.

**Argument.** [proven: conditional on C2 adopting L5′ and S2 adopting Rules 2 to 4] G5 exists because L5 lets a landing end at a block that is certified but not carried. Above the two-block prefix, any certified block carries a certificate above h. An ordinary landing that includes an O-block above H(h)'s lock therefore needs one of: a second closing of X (12 positions of S3c′ evidence, or 7 of S3e); a FALLBACK signed by Q dishonest keys of a later committee; or, at its end, a `C_b` whose 22 signers meet H(h)'s 22 voters in at least 12 positions, each an S3b pair (an attestation carrying a certificate above h, plus a closing vote at h). [proven: conditional on Rules 2 and 3] In the reveal form, a revealed C(h+1) enters no honest `lock_i` and no toLock for the successor's context, so the successor stays attestable. [assumed: the candidate's claim] Honest keys are never paired under S3b, because `lock_i` never falls below a carried certificate the key attested, and it is never lowered except by RESET. L-2 shows that Rule 2 as written is not lowered even by RESET, and L-3's fix and L-7's evidence form are still open, so this claim waits on items 3, 4 and 6 of section 6.

**Residual bound claimed.** [assumed: the candidate's claim] No extra stall in the D73 form. At most 2 privately certified, never-carried blocks are lost with zero evidence. [open: B-G5R-02] That bounds the old private prefix only, and a never-carried private block is not itself locked under the current label; it does not bound displaced locked successors while L-1 and L-4 remain open, since across a redraw an old-count end-lock witness and a new-count closing can coexist without an overlapping signer supplying S3b evidence. At most `m − Q = 10` honest keys per attacked committee are stuck until the next landing above their lock.

**Attack findings.**

| # | Severity | Finding | Fixable |
|---|---|---|---|
| L-1 | High (both rounds) | G5-F survives. Selective reveal splits the honest class-H votes 21 at h and 10 at h+1, a later committee forms F, X then completes and records H(h), and R14(iii) kills F. Keys locked on F's successor stall to the hatch or dead mode with zero evidence. Under T1 the split comes from Rule 3; round 2 shows it also arises under T2 (an alternative toLock scoping the round considered, not reproduced here), through R08(a)'s direct TERM_END vote, because Rule 2 keeps `lock_i` at h. The candidate's "no hatch or dead mode needed" headline overstates the result. | Not by LEL. It needs a separate fix to the kill rule. |
| L-2 | High | Rule 2 is a formula over the key's whole history, so after RESET it immediately re-evaluates to the displaced branch's height. R04 then refuses the RESUME generation, and the certificate-free exits that LEL itself relies on wedge until the DAO acts. | Yes. Scope clauses (i) and (ii) to the current generation since the last RESET, or keep `lock_i` as state that attestations raise and RESET sets. |
| L-3 | Medium (both rounds) | Gating attestation on the two-chain `lock_i` lets one equivocating leader reorg attested blocks using honest attestations at a different height, with only S1 against the leader. | Yes. Keep R04's attestation gate on `high_i` and use `lock_i` only for votes and R08(a). It must then be checked that this does not reopen the reveal form. |
| L-4 | Medium | Cross-redraw continuation-first. Count-0 keys that have not yet received the redraw proof attest a header carrying the private C(h+1) while H(h) forms at count 1. Overlap then exists only in keys sitting in both draws. The proposed L5′ patch, `C_b.redraw ≥ endCert.redraw`, does not bind, because the attacker is the lander and L1 has no redraw record. | Partly. Either a node Rule 4′ (no attestation below a count the key signed REDRAW for) plus a new S3 evidence form, or an on-chain redraw record, which is new state. |
| L-5 | Medium | A kind-1 landing creates a range shape (the opening already consumed by the previous landing) that C2-R04, L4 and the journal do not admit. Without a rule, the next landing either reverts or L4 accepts an unverified opening. | Yes. Specify the L4 skip, and add vectors. |
| L-6 | Medium | +110k to 185k gas on every landing, including MP-05's irreducible landing, whose fit to LANDING_GAS_BUDGET is already open (C2's register notes that four REPLACE or RESUME view changes exceed it). A malicious leader can force the costlier kind onto honest landers. | Yes. Require `C_b.redraw == endCert.redraw`, add an MP-05 row, and re-derive C2-R16. |
| L-7 | Low | S3b's attestation half taken from a bit of an aggregate `C_b` is a new evidence form that #22202 does not yet contain. | Yes, if S3 adopts it. |
| L-8 | Low | Boundaries into certificate-free terms can bypass L5′, and Rules 1 to 4 must activate at one term boundary. | Yes. Require a trailing closing at every such boundary, and specify an atomic activation term. |

**Verdict.** [proven: from the findings, conditional] LEL would close the D73 form (continuation landed first) and the reveal form, converting zero evidence into at least 12 positions with S3b, S3a or S3c′ evidence within one count, or 7 with S3e across counts. That conversion is conditional on L-2 and L-5 being fixed, on L-3's fix not reopening the reveal form (item 4 of section 6), on S3 adopting L-7's evidence form, and on L5′ fitting LANDING_GAS_BUDGET (L-6, MP-05). It does not close G5-F (L-1) or the cross-redraw window (L-4). [assumed: classification] Status: narrows G5; it does not fix it.

### 4.2 Landed-floor ballot epochs (vote release, G5-E)

**Mechanism.** [assumed: proposed rules] Each closing context X gets an on-chain `epoch` counter. `openBallot(X, evidence)` raises it when four conditions hold: a current-epoch class-H vote for X verifies against `committee(t)`; `lastLanded` is a holder block inside X; that vote's lock is dead at `lastLanded`, meaning `lastLanded` is higher, or the same height with a different phHash; and the floor rises strictly. The call records a floor `(height, phHash, block, timestamp)` for the new epoch. Honest keys read the aged epoch and floor. A key whose vote is still compatible carries it forward unchanged apart from `epoch`. A key whose vote is dead re-votes once at a lock at or above both its `lock_i` and the floor. `epoch` is a signed witness field kept outside the logical vcHash, so the guest and journal do not change. S3c′ exempts vote pairs across epochs when the earlier lock is dead at the later floor. A node retires the certificates of dead generations, but never lowers a lock inside X.

**State added.** [assumed: layout in C8-R15's gap] Two mappings: `ballotEpoch[xKey]` (one byte per X) and `ballotFloor[xKey][epoch]` (two words per epoch). That is `1 + 2E` words per X. E is zero in normal operation, claimed to be at most 2 under a zero-evidence attack, and floors are never cleared. The signed digests of LockVote, TimeoutMsg and the ViewChange witness gain `epoch` under new domain versions.

**Gas.** [assumed: unmeasured] `openBallot` is a separate transaction of about 260k to 290k (single-vote evidence) or about 330k to 380k (VC-bit evidence), outside the landing budget. Landings and `recordViewChange` add one SLOAD (2.1k) per carried class-H view change with `epoch ≥ 1`. S3c′ adds about 4.2k.

**Argument.** [assumed: the candidate's argument P1 to P6, summarised and not reproduced here; conditional on C2's append-only `lastLanded`, A-T1, A-T9 and one honest sender] A closing that is dead at a head inside X stays dead (P1). Incompatibility is upward-closed along floors (P2). A re-vote releases only a vote whose generation L1 has already voided, so no new loss route opens, and two live closings in different epochs still overlap in 12 non-exempt positions (P3). An honest key changes a logical field only when its every earlier vote is dead at an aged floor, and it never lowers its X-lock (P4). Production resumes about 62 to 74 s after the killing landing (P5). Only the two-block zero-evidence prefix can kill an epoch without S3b evidence, so at most 2 epochs go by with zero evidence (P6).

**Residual bound claimed.** [assumed: the candidate's arithmetic on defaults] About 2.5 to 3 min of stall from the first killing landing, with no proving tail. [open: as conceded by the candidate] Still open: the dead generation's locked blocks are lost (up to about 72 s of blocks), the reveal-after-record trace is not addressed, and L3 is unchanged.

**Attack findings.**

| # | Severity | Finding | Fixable |
|---|---|---|---|
| E-1 | High (both rounds) | A split within an epoch has no exit. In epoch 1, X reveals the private C(h+2) to about 10 honest keys during formation; they vote h+2 and the rest vote h+1. Neither reaches Q, no vote is dead at the head, so `openBallot` cannot fire. FALLBACK is refused because later committees hold the dead H(h). The exits are an honest prove-and-land of h+2 (unbounded proving) or the hatch or dead mode. Zero evidence. | Yes. Narrow R14's honest refusal to sign F to class-H closings that are head-compatible at aged `lastLanded`, so a dead H no longer blocks F. Alternatively add an honest duty to land h+2 and restate the bound. |
| E-2 | Medium (both rounds) | `openBallot` accepts one key's unbacked vote. A single position can bump the epoch after every landing inside X, with exempt pairs, so E per X is bounded only by the landed heights (about 60). Each bump forces re-signing, and a well-timed bump splits votes across epochs. | Yes. Require a Q-backed class-H witness (the VC-bit form), or a recorded dead H in slot 0. |
| E-3 | Medium (both rounds) | A TIMEOUT/TERM_END kind split among re-voters (or between carriers and re-voters) in an epoch has no exit, for the same reason as E-1. | Yes. Same fix as E-1, or fix the kind for re-votes. |
| E-4 | Medium (both rounds) | A C2-R14 DAO conflict reversal of a provisional killing landing brings a dead closing back to life while the stored floor persists. The result is two live closings with exempt honest overlap, and nothing slashable. | Yes. Accept `openBallot` only on a checkpointed (non-provisional) head. |
| E-5 | Low | An old-domain (pre-fork) vote paired with a post-fork re-vote could slash an honest key. Votes in epochs that never open cannot be slashed. | Yes. Adjudicate old-domain votes as epoch 0, and do not apply epochs to any X opened before the fork. |

[assumed: structural reading; not tested in either round] Ballot epochs do not address G5-F. In G5-F nothing lands inside X, so `openBallot`'s preconditions never hold, and the stranded keys are locked on a dead F generation rather than holding a dead vote. E-1's fix (H dead at the head no longer blocks F) does not reach G5-F either, because there H(h) is operational.

**Verdict.** [assumed: the candidate's bound, conditional on fixes for E-1 to E-4 that no round has tested] With E-1 to E-4 fixed, the candidate would bound the D73 form's stall to minutes rather than a hatch or dead-mode wait. It leaves the zero-evidence loss of locked blocks, the reveal-after-record trace and G5-F open. [assumed: classification] Status: bounds one form of G5; it does not fix it. Of the two candidates that add on-chain state (ballot epochs and TBCR), it is the only one that survives its rounds, so it is the only surviving candidate that matches D73's "adds on-chain state" framing.

### 4.3 Tail Bond and Conflict Record (TBCR)

**Mechanism.** [assumed: proposed rules] There are four parts.

- A node policy, S2-R06a: a held Q-backed class-H closing makes higher certificates under its opening non-locking for attestation.
- An open-tail landing, one whose end view has no operational closing at or above its end, escrows `TAIL_BOND` in an 8-slot ring.
- `recordConflict`, callable by anyone, records that a landed end in O sits above a Q-signed class-H closing of O. It forfeits the bond (40% to the caller, 60% burned) and charges `CONFLICT_MISS` to the leader.
- Once that ConflictRecord is aged, nodes reset to `lastLanded` and a later committee may form an ordinary FALLBACK at `lastLanded`, even though it holds H.

**State added.** [assumed] TailEscrow[8] (2 words per slot), one ConflictRecord (2 words), and constants: `TAIL_BOND` (placeholder 2,000 TAIKO), TAIL_CHALLENGE (5 blocks and 60 s), TAIL_RING, CONFLICT_MISS, and TAIL_GUARD.

**Gas.** [assumed: unmeasured] About 20k to 30k per open-tail landing, plus about 196k the first time each ring slot is used. `recordConflict` costs about 200k to 400k in a separate transaction. The recovery landing adds 0.2M to 0.7M to C2's worst case.

**Argument.** [assumed: the candidate's claims] The reveal form causes no stall under R06a. Every landing-form attempt forfeits collateral. The stall is bounded at about 75 to 95 s per cycle, at most two cycles, about 3 to 3.5 min in the worst case. [assumed: the candidate's impossibility argument, not reproduced here; S2-R20's rejected alternatives make the same point for one predicate] No predicate on signatures alone can slash X without also being able to frame honest attesters, because anyone can aggregate. Deterrence therefore has to rest on collateral.

**Attack findings.**

| # | Severity | Finding | Fixable |
|---|---|---|---|
| T-1 | Critical | X records the private C(h+2) just before the recovery F1 becomes final, and S2-R14(iv) kills F1. Honest locks have moved onto F1's generation, which extends `lastLanded`, so TBCR's reset leaves them in place and they refuse F2 at h+2. No new ConflictRecord fires. This restores G5's full hatch or dead-mode stall at the cost of one bond, 40% of which the attacker can recover, plus its stated CONFLICT_MISS and the transactions' gas. | Possibly, by a new reset trigger or by F1 immunity, each needing its own round. |
| T-2 | High | G5-F, with no landing at all, so no ConflictRecord fires and nothing is bonded. | Possibly. It needs a reset trigger on "an operational H killed a nonfinal F". |
| T-3 | Medium | The bond becomes profit for the attacker: it leaks C(k) to an honest fast lander, then front-runs `recordConflict` to collect 40%. A self-landing attacker loses only 60%. | Partly. Burn the bond in full, and require gossip plus a wait before an open-tail landing. |
| T-4 | Medium (both rounds) | C2 allows several landings per L1 block, so the ring overflows. A `TailRingFull` rule lets anyone halt landing; a forced-refund rule breaks the forfeit. | Yes. Key the escrow by landed end. |
| T-5 | Medium | [assumed: a workload of landings not aligned to term end; a term-aligned landing can already have a closing recorded] Almost every landing is open-tail, so permissionless landing needs 2,000 TAIKO of capital. Hatch and sentinel ends are open-tail too, which contradicts D51(3)'s `HATCH_BOND = 0`. | Yes. Exempt views 254 and 255, and charge the bond only near term end. |
| T-6 | Medium | The residual bound is understated: the steps can be chained to about 5 min, and the MISS deduplication is keyed wrongly. With TERM = 60 s, the attack displaces 2 to 5 terms each time. | Partly. |
| T-7 | Low | The F exception can collide with R09's one F vote per `(X, signerTerm)`. Routing to `recordConflict` can run out of gas. | Yes. |

**Verdict.** [proven: T-1 is a Critical with no fix specified] Fails. [assumed: assessment] Even with T-1 fixed, TBCR deters through collateral rather than slashable evidence, puts bonded capital on honest landers, and leaves the locked loss in place.

## 5. Comparison

| | LEL | Ballot epochs | TBCR |
|---|---|---|---|
| New L1 storage | none [proven] | `ballotEpoch`, `ballotFloor`: `1 + 2E` words per X [assumed] | TailEscrow[8], ConflictRecord [assumed] |
| New signed fields or messages | none (`C_b` is an ordinary certificate) [proven] | `epoch` in votes, timeouts and witnesses; new domain versions [assumed] | none [assumed] |
| Gas per landing | +110k to 185k on every landing ending in a committee-mode holder view (L-6; the candidate states 125k to 185k for kind 0) [assumed] | +2.1k per class-H VC with epoch ≥ 1 [assumed] | +20k to 30k per open-tail landing, plus bonded capital [assumed] |
| Other L1 transactions | none | `openBallot`, 260k to 380k, only under attack [assumed] | `recordConflict`, 200k to 400k [assumed] |
| D73 form (continuation landed first) | slashable, 12 or 7 positions, except the cross-redraw window (L-4) [proven: conditional] | stall bounded to minutes once E-1 to E-4 are fixed; zero evidence [assumed] | bounded, but T-1 restores the full stall [assumed: round finding] |
| Reveal form | no stall [proven: conditional on Rules 2 and 3] | not addressed [proven: candidate's own statement] | no stall under R06a [assumed] |
| G5-F (FALLBACK-kill) | open (L-1) [assumed: round finding] | open, not tested [assumed] | open (T-2) [assumed: round finding] |
| Zero-evidence loss | old private prefix at most 2 never-carried blocks [proven: conditional]; no established bound on displaced locked successors while L-1 (G5-F) and L-4 (cross-redraw) remain open [open] | up to about 72 s of blocks [assumed] | about 1.5 to 5 min of blocks [assumed] |
| Honest-key slashing risk | none argued; RESET wedge (L-2) is liveness, not slashing [proven: conditional] | E-5 (fork boundary) until fixed; E-4 (DAO reversal) loses slashability rather than slashing honest keys [assumed: round findings] | none in stake; bond risk for honest landers [assumed] |
| Worst finding | High (L-1, L-2) | High (E-1) | Critical (T-1) |
| Verdict | survives with fixes, L-1 not fixable by LEL; narrows G5 | survives with fixes; bounds one form | fails |

## 6. Recommendation and next research steps

[proven: from sections 4 and 5] None of the three candidates fixes G5 as D73 states the harm. The coalition is the leader plus one position, there is no slashable evidence, the stall lasts to the hatch or dead mode, and the attack repeats. In LEL and TBCR the rounds found that G5-F reaches that same harm, and for ballot epochs an untested structural reading (section 4.2) says the same. G5 therefore stays published in S2-R18's locked label without change.

[assumed: recommendation] Pursue LEL as the main research line, as a narrowing of G5 and not as a fix: apply the fixes for L-2 to L-8, pair it with a separate kill-rule design for G5-F (L-1, which is High and unfixed), and keep G5 published in S2-R18's locked label unchanged until both pass their own attack rounds and the user signs off. The reasons:

- LEL is the only candidate that, conditionally, turns the D73 form into slashable evidence rather than bounded harm, outside the cross-redraw window (L-4).
- It avoids the known mistakes of both failed attempts: it never lowers a lock, adds no node suspension sets, and gates no landing on a per-view record. Whether its Rule 3 reuses the cap design's B-5 is open (item 5).
- It needs no storage slot, only an inbox and client upgrade. Research can continue without a user decision; whether a storage-free fix fits D73's "adds on-chain state" track is an adoption-scope question for the user (section 1), not a research blocker.

Keep ballot epochs as the fallback line, with the fixes for E-1 to E-5, because they touch fewer S2 rules and add on-chain state as D73 framed the track. Drop TBCR.

What must be proven before LEL could leave this note.

1. [open] **G5-F closure.** Design and attack a kill-rule amendment. The two leads so far:
   - Lead (a): a class-H record kills a nonfinal F only if F's lock is not two-chain locked on F's successor, which L1 would check from presented calldata of the `C_b` kind.
   - Lead (b): narrow R14's honest refusal to sign F to class-H closings that are operational at aged `lastLanded`.
   Lead (b) does not reach G5-F, where H(h) is operational, so (a) is the lead. Without this item G5's label cannot change.
2. [open] **Cross-redraw (L-4).** [proven: by an honest S2-R16 schedule, B-G5R-01 on #22235] The raw pair "REDRAW(n) plus an attestation below count n" is **not** sufficient evidence and is rejected here: an honest key attests a count-0 block, waits TIMEOUT without seeing its certificate, then signs REDRAW(1). Both signatures are public, and neither authenticates their order, so an accuser could frame honest redraw participants for the price of submission gas (an R6 false-slashing defect if adopted). The open choices are an authenticated ordering (for example an on-chain redraw record, which is new state and fits D73's track) or a different signing policy that makes the forbidden order self-evident. Prove the 7-position overlap for whichever is chosen.
3. [open] **Rule 2 as state (L-2).** Restate `lock_i` as a value raised by attestations and set by RESET, and prove that RESET followed by RESUME is attestable.
4. [open] **The attestation gate (L-3).** Prove that keeping R04 on `high_i` while votes use `lock_i` leaves the reveal-form argument intact.
5. [open] **Rule 3 against cap B-5.** The arbiter must rule whether restricting the closing toLock to certificates under X's own opening reuses the failed cap design's B-5. The candidate argues it is forced by C2's guest projection.
6. [open] **S3 adoption.** #22202 must accept a set bit of an aggregate `C_b` plus the `PH_b` preimage from landing calldata as S3b's attestation half, across redraw counts.
7. [open] **Activation.** L5′ and node Rules 2 to 4 must switch at one term boundary, with C2, C4 and C8 text for the atomic switch.

Measurement-plan entries it would need. [assumed: proposed rows]

- An MP-05 row for L5′ kind 0 and kind 1 gas on mainnet EIP-2537, with `C_b` sharing the end certificate's count and with it not sharing.
- A re-derivation of C2-R16's lander payment condition.
- An A-T9 devnet measurement of how far a redraw proof's gossip lags its formation, and of whether H(h) reaches later committees before the FALLBACK gate.

Vectors it would need. [assumed: proposed]

- S2-V25 changes from a stall to an `EndNotLocked` revert, or to at least 12 S3b positions.
- S2-V33(a) and (b) change from a stall to "the successor is attestable".
- New vectors:
  - the G5-F trace;
  - a hatch after a displaced certified tail, followed by an attestable RESUME block;
  - a kind-1 tip landing followed by the next range;
  - a trailing TIMEOUT with MISS;
  - a trailing final F;
  - the cross-redraw schedule of L-4;
  - a holder view followed by a certificate-free boundary.

[open] If item 1 fails its own rounds, the honest outcome is that no fix that is known today removes G5's user-level harm. The track would then publish LEL, at most, as a narrowing (from zero evidence to slashable evidence in the landing form) and leave the S2-R18 sentence as it stands.

## 7. What this note does not change

[proven: scope of this note] This note changes no rule in S2, S3, C2, C3, S4 or any other section, and no decision record. S2-R18's locked label and D1's third exception stay as published under D73 (1), and so do S2-R20's G5 paragraphs, C2's L5 and S2's proposed L4c adoption (not yet in merged C2), C3's hatch, and S4-R07, R14 and R15. Every rule, constant, error name and gas figure in sections 4 to 6 is a research proposal tagged [assumed] or [open], and none is binding. [assumed: process] Any adoption needs a spec change in the owning sections, its own attack rounds, the user's sign-off on the changed labels, and, after launch, a DAO upgrade under R1 shipped together with the client release.
