# ETNA red-team round 5: HALT (liveness) attacker

## Model
Running as Opus 5.5 (model id claude-opus-5-5), as requested.

## Method
Read design/index.html and every linked page, 01-threat-model.md, README.md, iterations/04-round.md; built attack traces against the round-4 mechanisms (Fenwick/mutation-ring sortition, reserve lapse, redraw vote, landing-based A3), plus partition, prover-failure, L1-congestion, short-slot, ePBS-empty-slot and no-Frame-Transactions scenarios. Findings are appended as they complete.


---

## R5H-1 [Medium] Header-gossip squatting is free: the round-4 silence rule voids the squatting bleed (TH10 regression + internal contradiction)

Requirement affected: R1/R4 liveness (persistent partial liveness denial); TH10 (squatting).

Actors: one cartel owner O with w seats (bond 28,400 TAIKO/seat, recoverable). No attester collusion needed.

Trace (times by O's own clock):
1. O registers w seats; two hours later they are ACTIVE and drawn as primaries at rate w/A.
2. For every term t O holds as primary (view 0), O never releases a certifiable block. Instead O's sequencer signs and gossips a header of (t,0) at height lock+1, then lock+2, …, one new signed header every 4 s (< TIMEOUT = 5 s), each with a valid leader signature above the committee's lock. It never publishes the bodies (or publishes bodies that fail a V-rule), so no attester can attest and no certificate forms.
3. Per preconf §5 an attester signs TIMEOUT for (t,0) only after 5 s "received no header of (t, v) with a valid leader signature above their lock and no new certificate". A fresh signed header arrives every 4 s, so the first conjunct never holds: no attester ever signs TIMEOUT, no Q-signed VC forms, no takeover to any backup, the term stays blank to termEnd.
4. MISS (50 TAIKO) is applied only "when a landed batch carries a timeout view change". No timeout VC ever exists for O's terms, so O is never debited. Per sequencing §7 "the bleed applies only to a leader silent to the whole committee" — O is never silent, so O is never bled, never strikes, never approaches the 50 % hard floor.

Result: O blanks its entire primary share (≈ w/A of all terms) for the whole tenure at zero marginal protocol cost — no TAIKO burned, no suspension, ever. The only cost is locked (recoverable) seat capital and running a node.

designText (verbatim, sequencing.html, one paragraph, self-contradicting): "the bleed applies only to a leader silent to the whole committee, so an honest online leader is never bled and a false view change needs Q colluders (outside T11). … Squatting is deterred by the bleed alone: a seat that never serves loses 50 TAIKO per draw and reaches the 50 % hard floor after 200 draws". A header-gossiping squatter "never serves" yet is not "silent to the whole committee", so the second sentence's premise ("loses 50 TAIKO per draw") is false for it. TH10's claim "TH10 squatting: defended by bleed" therefore fails.

The design acknowledges the single-term case but misframes its scope (preconf.html §14): "one signed header above the lock every < 5 s keeps the view alive without certified progress, unrewarded, for at most the term". This is "at most the term" per draw, but summed over a tenure it is an unbounded, self-sustaining fraction w/A of blank terms that the squatting-bleed was designed to eventually eject and now never does.

Cost/gain: cost = seat capital locked (recoverable after exit + EVIDENCE_WINDOW) + node opex; burn = 0. Gain: persistent denial of ≈ w/A of all L2 terms (users get nothing, not even the sequenced level, for those minutes), and the anti-squatting ejection (200-draw hard-floor) is defeated. At w/A = 1/3 this silently blanks a third of all terms forever for no ongoing cost.

Severity Medium: degraded service proportional to seat share, self-sustaining, not a full halt (full halt needs every seat = exclusion, priced at supply). It is a true regression: pre-round-4, timeout-on-silence made this cost 50 TAIKO/draw and self-suspended.

Suggested fix: restore a liveness debit for a leader that gossips headers but produces no certificate within the term. Objective trigger available without reintroducing the round-3 false positives: a view that received ≥ 1 leader header above the lock but for which no certificate and no TIMEOUT VC was ever recorded by termEnd is a "produced-but-uncertified" term; charge MISS to its holder, applied at the next landing that settles t (the committee's attestations of the headers, or their absence, are the evidence). Alternatively make the leader-liveness header signal require a body-availability attestation (a Q-signed "header retrievable" vote) so header-only gossip does not suppress timeout.

---

## R5H-2 [Medium] Committee-walk gas estimate omits the mutation-ring correction term M; under delayed pinning (L1 congestion) it compounds into unpinnable/unlandable terms

Requirement affected: R4 (1-s blocks / liveness), R7 (minute-level landing); TH-none direct (liveness under L1-congestion + churn).

The round-4 sortition computes committeeOf(t) on-chain as 512 rank lookups over a Fenwick tree "corrected by the ring entries with effective time in (termStart(t), now]" (sequencing §8). Each lookup is stated as "each try one rank lookup at O(log MAX_SEATS + M)", i.e. the correction cost M is paid per lookup, so a committee pin is 512·O(log MAX_SEATS + M). But the published gas figure drops M entirely: "Worst case 512 rank lookups: about 0.6 M gas at a 128-seat registry … and up to about 3 M at the 65,535-seat maximum". The 3 M figure is only valid at M ≈ 0.

M has no aggregate cap. sequencing §5 ("M is priced") bounds only the per-owner mutation rate via MIN_TENURE (≤ 16 entry/exit mutations per owner per week); it does not bound how many mutations fall in one 34-h correction window. With O active owners, M can be hundreds to thousands in a window.

Trace (L1-congestion + churn halt):
1. Precondition: a populated registry (thousands of seats, as the design intends: MAX_SEATS = 65,535, launch ≥ 72). Ordinary churn plus an adversary who registers N seats in a 2-h burst and requestExit-s them 7 days later (activeUntil = activeFrom + MIN_TENURE) clusters N "−1" mutations into a ~2-h span, so for the following 34 h every historical query over that span carries M ≈ N corrections.
2. recordAssignment/first-landing pins each term's committee ONCE; the cheap path is to pin promptly at termStart(t), when the correction window (termStart(t), now] is ~empty (M≈0). The design relies on this ("landers pin ahead").
3. Attacker floods L1 with high-fee transactions (the L1-congestion scenario) so that no one pins terms promptly. As terms go unpinned, the correction window for the head landable term widens toward 34 h and M grows to ≈ N.
4. Committee-pin cost for the head term now ≈ 512·(16 + N) storage reads. At N = 300, ≈ 512·316 ≈ 162k reads; at ~100 gas/warm-read ≈ 16 M gas > LANDING_GAS_BUDGET (10 M) and > EIP-7825 cap (16,777,216). The head term cannot be pinned in any single transaction.
5. Landings are "sequential in height" (landing §5), so the head term blocking its pin blocks every later landing. No landing lands ⇒ finalization and checkpointing halt for the duration (up to the 34-h decay of M), and bridging (saveCheckpoint per landing) stalls with it.

designText (verbatim): "each try one rank lookup at O(log MAX_SEATS + M), by" (sequencing §8) and "Worst case 512 rank lookups: about 0.6 M gas at a 128-seat registry (7 tree levels, the upper nodes warm after the first descents) and up to about 3 M at the 65,535-seat maximum" (sequencing §8) — the estimate that omits M.

Cost/gain: attacker's seat capital is recoverable (locked ~14 days); the L1-congestion cost is the standard price of a congestion window and is the real limiter. Gain: a landing/finalization halt of a term window whenever prompt pinning is suppressed, i.e. exactly when L1 is congested, which is when the chain most needs to catch up. Even with no attacker, the published 3 M-gas bound is violated by honest churn at a large registry whenever pinning lags.

Severity Medium: conditional on L1 congestion suppressing prompt pinning (prompt pinning defeats it), and the base gas is self-tagged "assumed". But the O(512·M) cost is a concrete, unpriced quadratic-in-window term and the halt is real when pins lag.

Suggested fix: (a) bound M by an on-chain cap on mutations effective per unit time (reject/queue registry writes whose effective slot already holds K mutations), making the committee-walk cost provably O(512·log + M_cap); (b) require and reward prompt committee pinning (pay recordAssignment from a small per-term pool) so the M≈0 path is the incentivised one even under congestion; (c) gather the correction set once per pin (O(M + 512·log)) and state that as the normative complexity, rather than O(M) per lookup.

---

## What I tried and could not break (≥5)

1. **Prover-failure halt.** Tried: kill all ZK back-ends so nothing lands. Stopped by landing §6 "A global proving outage shorter than the horizon voids nothing" and I4/I5 "no rule penalizes a term for not landing": nothing is voided or slashed; poke() keeps the seed fresh; after 2 h single-proof mode (one leaf) lets a landing resume (landing §7). The reserve is ring-fenced from liveness debits (R4-C4), so an outage cannot suspend the honest set. No halt beyond the outage itself.

2. **Partition halt / false takeover.** Tried: partition the leader from a sub-Q minority to force a view change and strand fresh locked blocks. Stopped by R4H-4: "A leader that keeps gossiping signed headers is never timed out, so an abstaining minority can only blank a term, never take the view" and by VC requiring Q lock votes over a certified lock. On heal the node "verifies the view change and stops" (sequencing §13). A minority cannot take the view; a majority partition is out of scope (T11). (The dual of this rule is abused in R5H-1, but for denial-of-own-term, not takeover.)

3. **Redraw vote as a halt/takeover lever.** Tried: use REDRAW (17 of 32) to re-roll committees until the honest leader's blocks cannot certify, or to reset a locked block. Stopped by preconf §5: REDRAW "changes no holder and applies no penalty", REDRAW_MAX = 2 caps it, and the cross-redraw reversion path has probability ≈ 6·10⁻⁷/view with only keys in both committees slashable (preconf §8/§14). It raises the blanking floor 11→16, it does not create a new liveness lever for a minority; a ≥17 cartel is already past T11.

4. **Reserve-lapse griefing halt.** Tried: drain an honest owner's landing reserve via third-party landings at max ramp to force RESERVE_LAPSED suspension and shrink committees into no-committee mode. Stopped by the economics: the holder lands its own terms at term-end minimum ramp (r_land ramps from 0), so forcing a high-ramp third-party landing requires censoring the holder's own landing tx for ~30 min per term; reserve = two terms of exposure per seat (8,400) and an 8-seat owner holds ~16 terms of reserve, so a lapse needs sustained L1 censorship of >15 of that owner's terms at max ramp — not practical. "Class-C debits never touch the reserve" (landing §5) blocks the cheap timeout route.

5. **Migration term-record ring collision (learn-11 hint).** Tried: choose a term id whose slot (aliased slot 254, key termId % 21,600) collides with an unproven Shasta proposal during the drain, to corrupt a landing or wedge it. Stopped by the "land reverts until drained" rule (bridge-migration §5 table: land "reverts NotActive" / "reverts" in every pre-drain row) combined with M1 "Drained once … every proposal is proven, or abandoned": no Etna term record is written to the aliased ring until every Shasta proposal is resolved, so no live collision exists. firstEtnaTerm ≤ ~1,500 even at a 25-h drain, far below the 21,600 wrap.

6. **Short-slot / ePBS-empty-slot / no-Frame-Transactions halt.** Tried: 2-s slots, ePBS payloads canonical one slot late, EIP-4788 gaps, and no EIP-8141 gate, to desync schedule or block landing. Stopped by parameters/robustness: "nothing counts slots" (sequencing §15), LOOKBACK/DELAY are in seconds so margins grow as slots shrink; "4788 is never read; the next block's prevrandao reflects every intervening reveal"; without Frame Transactions the primary path is a type-3 tx with expiry ("Without EIP-8141: a type-3 transaction from the lander's EOA with deadline", landing §8), zero registry-call races. The only short-slot pressure is the landing gas budget (10 M to fit a 2-s block), which is the surface R5H-2 exploits via M — reported there, not here.

7. **Dead-mode / no-committee unrecoverability.** Tried: drive the chain into dead mode and deny recovery without DAO action. Stopped by sequencing §6: after DEAD_TERMS = 75 "any address with bond ≥ B_SEAT may sequence with the sentinel view 255 and the first landing on L1 wins", certificate-free; "a chain whose whole registry and committee vanished is recovered by one honest bonded party within about 75 minutes plus proving", no DAO action. armEtna failing only starts launch in no-committee mode (degraded, still live).
