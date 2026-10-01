# Etna red-team round 6 — CENSOR AND MONOPOLIZE

## Model

Running as: claude-opus-5-5 (Opus 5.5), as reported by the session environment. Opus was requested.

## Method

1. Read the design site in full (index, roles, sequencing, preconf, landing, slashing, forced-inclusion,
   bridge-migration, interfaces, parameters, arguments, l1-dependencies, frame-transactions, limitations,
   glossary), then 01-threat-model.md, README.md, and the round 1-5 iteration and judge files, at commit
   9a208ed ("Etna round-5 second fix pass").
2. Attack the newest mechanisms first (persistent domain tree, receipt-time staleness and REDRAW, the timeout
   rule on own attestations, FALLBACK gates and recording duty, suspended seats in the rank domain, reserve
   refill and ReserveLow, S3b and lock votes, FI_ANCHOR_LAG and the 112-minute bound), always toward the
   censor/monopolize goal: disproportionate share of terms, exclusion of entrants, censorship of a user or a
   forced inclusion beyond the stated bound, MEV via withholding/equivocation without slashing, attester
   collusion to reorg preconfirmations.
3. For each candidate: build a timed trace against the text as written, quote the exact sentence exploited,
   compute cost and gain, and check it against the stated residuals (certificate page 1(d), limitations page)
   so that no stated residual is re-reported unless its stated bound is false.
4. Cross-check every number the attack depends on across pages (parameters page vs. section text) and report
   contradictions by consequence.

Findings are appended below as each is completed.

---

## Finding 1 [Medium] Suspended seats staying in the rank domain make committee size m a reducible quantity, so the "locked = 12 double-signers" bound and preconf safety hold only while few owners are suspended; the R5S-2 fix traded a grinding lever for an un-analyzed committee-collapse lever

- Requirement affected: R6 (TH9/TH10), R4/P2 (preconf safety at the locked level); builds on round-3 R3H-5, whose fix round 5 partially reverted.
- Model: censor/monopolize.

Round 5 (R5S-2) reversed the rule of rounds 1-4 ("suspended seats removed from the rank domain"): a suspended owner's seats now stay in the domain, and a committee slot drawn on them is **empty** — "it stays in the walk's output, m shrinks by one, Q(m) scales, and no re-draw shifts the later slots" (sequencing §8, verbatim). The R5S-2 reassurance is only about ranks; it does not note that removing a slot shrinks m and scales Q(m) down for the committee *other* owners rely on, while the security claims assume m = 32 unconditionally: "the bound is 12 at full committees" (preconf §16); "a term with m < K_MIN_CERT = 8 is in no-committee mode (certificate-free landings, sequenced level only)" (sequencing §8).

Trace. An adversary registers N parked seats across N/8 owners and drives each owner into a suspension that keeps its seats in the domain, by either path the design lists as acting "through this flag" (sequencing §8): the open-ended hard floor (let a parked holder time out and bleed to 50 %, never reactivate), or the L20 reserve drain (land its own ramped terms to a seatless address it controls). Each parked owner's slots then draw as empty forever. Simulated (scratchpad/phase4/r6c/phantom_sim.py, not committed; 32-seat hypergeometric walk, primary excluded by owner): at the 72-seat launch registry, N = 144 → mean m 10.4, 11.6 % no-committee, mean 2Q−m bound down from 12 to 5.0; N = 216 → mean m 7.8, 45.5 % no-committee; at 400 seats, N = 1,200 → mean m 8.0, 43 % no-committee.

Consequence: on the no-committee fraction users get the sequenced level only (P2 void there); elsewhere the "39-ETH locked" bound is 4-6 double-signers, not 12.

Design text (verbatim, the falsified reassurance): "an owner that suspends itself after the seed is fixed removes only its own slots and cannot change which other seats sit in any committee or which owner holds any view" (sequencing §8).

Cost/gain: capital-heavy and slow — ~30,200 TAIKO/seat plus the hard-floor bleed or L20 drain to suspend (~4.35 M TAIKO to park 144 at launch); strictly dearer than R3H-5's register-then-exit, which this rule re-enabled in costlier form. Gain: a registry advertising m = 32 is pushed to small/no committees over a material term fraction, falsifying the locked bound and preconf safety there. An honest analogue (correlated prover outage draining many reserves to the lapse) needs no attacker but is defended by the client auto-top-up unless it fails.

Suggested fix: continue the committee walk past empty (suspended) slots to backfill m up to K from live domain seats, using a seed-fixed candidate order so a self-suspension only promotes a predetermined next candidate (no grinding, preserving R5S-2); or cap the empty fraction before treating a term as small-registry. State that "12 at a full committee" and the 39-ETH bound hold only while suspended seats are a small share of the domain.

---

## Finding 2 [Low] The blank-term revenue table counts certified terms, not seconds, so it omits the handoff delay a blocking minority imposes on every surviving honest term; the published one-third gain (44 %, "about 11 points") understates the second-weighted share by ~7 points

- Requirement affected: R6 (anti-monopoly figures), TH9; refinement of limitation L2 (a stated figure is low).
- Model: censor/monopolize.

The table reports "Cartel share of productive revenue (certified terms)" (slashing §5, verbatim) — a term-count ratio p/(p+(1−p)(1−b)) that values every surviving honest term at a full 60 s. But a cartel holding a blocking minority of committee(t) withholds its TERM_END lock votes too, so the honest 21 < Q = 22 cannot form the closing VC and the next honest term waits for a FALLBACK VC recordable only at termEnd + END_GRACE + VC_FALLBACK = +12 s (and "+10 s per further committee"). The design notes the mechanism — "Two consecutive dark committees delay a term's closure by one more fallback interval" (preconf §5, verbatim) — but never debits those seconds from the late-starting surviving term.

Quantification (scratchpad/phase4/r6c/combined_sim.py, not committed; 40,000 terms, same committee model as slashing §5; a term after a blocked one starts at termEnd+12.5 s, +10 s per further consecutive blocked committee, capped at 60 s): the term-count share reproduces the design (8×8/32×1: 44.0 %; 6×8/24×1: 48.9 %), and weighting by productive seconds raises them to 50.8 % and 56.9 % — ~+7 points not in the published figures. The latency is also user-visible: a term after any blocked term starts 12-22 s late, not within the 5 s TH3 advertises ("replacement within TIMEOUT per dark view").

Design text (verbatim): "Cartel share of productive revenue (certified terms)" and "about 11 points against the eight 8-seat honest owners the launch condition produces" (slashing §5).

Cost/gain: no cost beyond the blank-term attack already accepted in L2; ~+7 points of second-weighted revenue over the published table, plus a 12-22 s start delay on surviving honest terms.

Suggested fix: weight the productive-revenue column by expected seconds per term, or state in L2 that the shares are certified-term counts and the second-weighted shares are a few points higher at/above one third; name the post-blocked-term handoff as TH3's exception to "within TIMEOUT".

---

## What I tried and could not break

1. **Revert a locked block with a TIMEOUT VC at a landed lock (re-run of R5S-1).** Stopped by: the landed-head exemption is deleted and the RESET state makes every mandatory post-reset message a RESUME, which S3b never reads; to form a VC at a lock below a certified block the cartel needs Q lock votes, and the ≥ 2Q−m = 12 cartel keys that attested the certified block above the lock are each S3b-slashable with no exemption (preconf §16, slashing §3 S3b). The intersection argument is intact.

2. **Post-seed assignment grinding by self-suspension (re-run of R5S-2).** Stopped by: a suspension of any kind changes no rank and no E_t (sequencing §2, §8: void view / empty slot, no re-draw), and the only rank inputs (entry, exit) are DELAY_REG-dated with τ ≤ freshFrom(c) = cycleStart − 3,660 s for any cycle (RND3). A self-suspension can empty the owner's *own* committee slots post-seed but cannot move another owner's rank or holder — which is finding 1's committee-size lever, not a rank-grinding lever.

3. **FALLBACK VC voiding an honest term's locked blocks (re-run of R5S-5).** Stopped by: recordViewChange/L4 accept a FALLBACK only from termEnd(t) + END_GRACE + VC_FALLBACK × (signerTerm − t), only while no live committee(t) VC is recorded, with committee(t)'s own VC superseding it until consumed, and only with a certificate at its lock (so no uncertified block lands). The honest TERM_END VC forms at +2.5 s and the recording duty puts it on L1 before the FALLBACK is recordable at +12 s. The residual is the stated same-block race L5 (Q of one committee plus a proof ready in seconds, 4·10⁻⁵/term at one third).

4. **Stretch the 112-minute forced-inclusion bound past 112 (re-run of R5-C3).** Stopped by: the landing announcement and an accepted REPLACE/RESUME record share one per-lastLanded deferral flag, spent by whichever comes first; a second landing to reset the flag must itself consume the due head entry under L8's T_floor count, so it cannot extend censorship of that entry.

5. **Pin a committee of my choosing (after a redraw).** Stopped by: committeeRoot is the inbox's own on-chain walk keccak(seed ‖ 0x03 ‖ t ‖ n ‖ m) in the domain-tree version effective at termStart(t), justified by ⌊m/2⌋+1 REDRAW signatures of committee n−1; calldata key hashes are checked against the pinned root (sequencing §8, landing §4).

6. **Exclude or delay a new entrant at registration.** Stopped by: contract-assigned indices (FREE holes first, then appends at the scheduled length, so a same-block incumbent append never reverts the entrant), no per-slot cap on how many domain writes take effect per minute (the round-5 fix pass deleted it), and every domain write is effective at τ + DELAY_REG independent of later writes (sequencing §2, §5). Filling the 65,535-seat array costs 1.31 B TAIKO, above supply.

7. **Revive a privately-withheld block through a committee redraw (re-run of B4).** Stopped by: the staleness lower bound is measured at each honest node's own receivedAt, so a block delivered only to the cartel is late at every honest node and never attestable there; private certification still needs Q colluders in one committee (L3). receivedAt is local and unsigned, but an attester lying about its own receivedAt only chooses what it itself attests, which collusion already allows.

8. **Squat a view all term while producing nothing (re-run of R5H-1).** Stopped by: an attester signs TIMEOUT iff no new certificate appeared for 5 s AND it holds no block of the view it attested that is still uncertified; a non-serving holder gets nothing attested, is timed out at 5 s and pays MISS, outside the stated collusion/split cases of certificate §1(d).

9. **Internal contradictions in the newest constants.** Checked per-term exposure (4,561), LAND_RESERVE (9,200 / 9,122), the committee-walk gas ladder (1 M / 4 M / 9 M vs the 16.8 M EIP-7825 cap and the 0.6 M pairing-verification figure, which is a different quantity), DEAD_TERMS (75 min vs the distinct 65 min = LAND_WINDOW_MAX + REPLACE_GRACE), and the ReserveLow fire (9,122) / re-arm (seats × 9,200) hysteresis: all consistent across the index, sequencing, preconf, landing, slashing, parameters, roles and interfaces pages. The round-5 fix passes' documentation cleanup holds.

## Verdict for this goal

No new Critical or High for the censor/monopolize goal. The three round-5 Highs (S3b exemption, suspension grinding, un-gated FALLBACK) are closed as written. One new Medium (finding 1: committee size m is a reducible quantity because suspended seats stay in the domain, un-analyzed, degrading preconf safety toward no-committee mode and dropping the locked bound) and one Low (finding 2: the productive-revenue table counts certified terms, not seconds, understating the one-third gain by ~7 points and omitting the post-blocked-term handoff latency).
