# Etna round 5, censor / monopolize attacker

## Model
claude-fable-5-1 (Fable 5.1), as requested; self-identified from the session's model string.

## Method
Read every design page from the current working tree (index, roles, sequencing, preconf, landing, slashing, forced-inclusion, bridge-migration, interfaces, parameters, arguments, l1-dependencies, frame-transactions, limitations, glossary) as text extracts, the thirteen learn/ lessons, 01-threat-model.md, README.md, iterations/04-round.md, 04-judge.md and 04-attack-censor.md. Attacked the round-4 mechanisms first as instructed: the leader-silence timeout with redraws (blank-term economics), the redraw vote itself as a censorship lever, the rank-based sortition and MIN_TENURE as entry barriers, the reserve and its lapse path, armEtna and the launch condition. Re-implemented the slashing §5 simulation myself (Python in the scratchpad, not committed): hypergeometric committee draw from the pool after excluding the primary by owner and backups by seat, first draw plus up to two redraws with the design's redraw precondition, for the design's seven owner structures plus additional ones. Every finding below is a trace against the text as written, with the exploited sentence quoted verbatim.

## F1 [High] The leader-liveness signal is free and unconditional: any holder keeps its view for the whole term while sequencing nothing, so takeover, the absence bleed and the 5-s bound on delayed sequencing are gone (R4H-4 fix overshoots)
Requirement: R4 (A7: "hard bound is the 5-s timeout"), R6 / TH10 (squatting "defended by bleed"), TH3 ("replacement within TIMEOUT per dark view"), TH6 (stale-state window "≤ TIMEOUT"); P3.

Actors: one holder H (any owner, one seat, 29,400 TAIKO bonded, nothing at risk). No attester collusion.

Trace (term t, lock h at termStart = 0 s):
1. 0.0 s: H gossips block h+1 (empty, carries the TERM_END VC); it is certified at ~0.7 s. From now on H publishes no payload.
2. 0.5, 5.4, 10.3, ... s (one every 4.9 s): H gossips a signed header PH with height h+200, h+201, ... (each height used once, so no S1 pair ever exists), timestamp inside the term, vcHash = the view's opening object. V1 and V2 pass; V3 fails (parent unknown). Every honest attester's timer restarts: "an attester signs kind TIMEOUT for (t, v) iff, for TIMEOUT seconds by its clock, it has received no header of (t, v) with a valid leader signature (V1, V2) at a height above its lock". No TIMEOUT, no VC, no backup, no MISS.
3. 55 s: H publishes h+2..h+6 with timestamps 55..59, built with 55 s of extra knowledge (L1 state, CEX prices, the whole term's user mempool), each carrying the newest certificate; STALE_MAX passes (fresh timestamps); all certify and land. H is paid in full.
Variant A (squat): H skips step 3 forever. Its term is blank; it pays no MISS ("silence forfeits rewards and costs the 50-TAIKO absence bleed"; there is no silence here), keeps its seat and is never suspended. Variant B (cartel strike): every cartel primary does A; p of all terms are dead at zero marginal cost, on top of the honest terms blanked through committees (F2).

Rules evaded: TIMEOUT needs "no header ... with a valid leader signature" (satisfied by header-only stubs, no payload needed); S1 needs equal heights; MISS needs a TIMEOUT VC; V4/STALE_MAX bound only the blocks H eventually publishes.

Design text (verbatim): "a leader that holds because a minority abstains keeps gossiping signed headers and is never timed out" (index §3). "one signed header above the lock every < 5 s keeps the view alive without certified progress, unrewarded, for at most the term" (preconf §14). "TH10 squatting: defended by bleed. A seat that never serves loses 50 TAIKO per draw" (sequencing §12). "TH6 stale-state MEV: reduced. Private state ≤ 2 blocks and ≤ TIMEOUT" (preconf §12). The page's own open question already asks whether provisional headers should be bounded; it lists the consequence as "unrewarded", which step 3 falsifies.

Cost / gain: cost 0 (no bond, no bleed, no eligibility effect). Gain: a 55-s free option on ordering every term H holds (TH6 window 5 s → 60 s); a squatter's seat costs only capital opportunity, so "MIN_TENURE ... drawn and bled" no longer prices phantom seats; a cartel strike removes p of all terms without the backup replacement that TH3 promises. Before round 4 the same behaviour lost the view at 5 s and 50 TAIKO.

Fix: make the liveness signal a re-broadcast of the leader's own next attestable block, not an arbitrary header: TIMEOUT is signed iff for TIMEOUT s no header of (t, v) at height ∈ {lock+1, lock+2} with a valid leader signature and an available payload (V1, V2, V6 pass) was received. A leader held by an abstaining minority keeps re-gossiping the two real uncertified blocks (still never timed out, so R4H-4's fix survives); a leader that withholds payloads or wants to delay is timed out at 5 s, and re-signing lock+1 later with new content is S1. State the consequence in A7, TH3, TH6, TH10 and the preconf §14 row.

## F2 [Medium] The blank-term table understates the one-third cartel by about 2x for the honest set the launch condition itself produces; targeted blanking excludes a single entrant at the same rate (builds on R4-C1; the republished table is incomplete, not wrong)
Requirement: R6 (anti-monopoly figures), TH9, P3; limitation L2 and the R6 verdict on the index page.

Re-simulation (20,000 terms per row, hypergeometric committee from the pool after excluding the primary by owner and the backups by seat; blank at draw 0 iff cartel ≥ 16, else redraw when cartel ∈ [11, 15], blank at redraw 1 iff ≥ 16, else redraw 2, blank iff ≥ 11). The design's seven rows reproduce within 1 to 2 points (e.g. 40×1/20×1: 22 % blank, 39 % revenue; 8×8/32×1: 34 %, 43 %). Rows the table does not carry, all inside T11 (one third of seats, honest owners at the 8-seat cap that the "8 owners, 72 seats" condition encourages):

| registry (honest / cartel) | seats | blank, no redraw | blank, two redraws | cartel revenue share |
|---|---|---|---|---|
| 6×8 / 24×1 | 72 (launch condition met) | 77 % | 47 % | 48 % |
| 6×8 / 3×8 | 72 | 78 % | 49 % | 50 % |
| 7×8 / 28×1 | 84 | 72 % | 38 % | 45 % |
| 5×8 / 20×1 | 60 | 83 % | 60 % | 55 % |
| 4×8 / 16×1 | 48 (> 44 minimum) | 96 % | 90 % | 83 % |
| 48×1 / 24×1 | 72 | 55 % | 19 % | 37 % |
| 6×8 / 20×1 (29 %) | 68 | 50 % | 15 % | 32 % |

Mechanism: excluding the primary by owner removes 8 honest seats from the pool in every honest-primary term, so the cartel's committee share is 24/(72−8−4) = 40 % against a 33 % seat share; the redraws are drawn from the same shrunken pool, so they absorb less. The effect is honest-concentration-dependent, and the table lists only dispersed honest sets at one third (40×1, 100×1) plus one 8×8/96 row.

Trace (targeted exclusion, the censor goal): registry 6×8 honest + 24×1 cartel (705,600 TAIKO, about 106 ETH, nothing slashable). Entrant E registers one seat. 1. Every term with E as primary and ≥ 16 cartel seats in the committee: cartel attesters do not attest (t = 0..60 s); no certificate, no timeout (F1 or an honest HOLD keeps headers flowing), FALLBACK VC at the previous lock at termEnd + 12 s. 2. Terms with 11..15 cartel seats: honest 17+ redraw at ~5.5 s and ~11 s; blank iff both redraws also block. 3. Every other term certifies normally. E's terms are blank 47 % of the time; E earns 53 % of its fair revenue on 100 % of the capital and cannot tell a blank term from a slow one. The cartel's own terms certify normally; its cost per blanked term is the forgone 0.1-TAIKO-per-block attester share (≤ 6 TAIKO).

Design text (verbatim): "at the T11 boundary (one third) it gains about 5 to 10 points of revenue" (slashing §5 reading, index §2 R6 verdict, limitation L2, lesson 9). "The blanking probability is hypergeometric (the committee is drawn without replacement), so it depends on share and barely on registry size" (lesson 9): it depends strongly on honest owner size, which the launch condition drives to 8. T11 is stated as one assumption ("fewer than one third of the seats are malicious; for liveness, fewer than m − Q(m) + 1 abstainers in a committee and its redraws"), but at one third the second clause fails in 47 to 96 % of honest-primary committees, so the two clauses are not one bound.

Cost / gain: 24 seats of capital; +15 points of productive revenue at 72 seats (+50 at 48 seats), or a 47 % revenue cut to any chosen entrant, unprovable and unpenalized.

Fix: publish the table as a function of honest owner size (rows for 8-seat honest owners at every cartel share) and restate the reading; state T11 as the liveness clause only (it implies the seat clause, not the converse); consider excluding the primary by seat rather than by owner when the honest set is concentrated, or raising REDRAW_MAX with a per-attempt seed, since both redraws today are drawn from the same shrunken pool.

## F3 [Medium] The forced-inclusion bound is 122 minutes, not 112: a landing announcement and a recorded REPLACE VC each defer the forced path "once", and the record path lacks the C3 refusal
Requirement: P5 / TH7 (censorship bound), R7; claim "by about s + 112 min" (FI §16).

Actors: the current holder H (one seat; any single owner, no collusion; honest attesters). FI entry saved at s = 0, compliant-censor timeline of FI §9 (stale anchors, deadline landings): the first term that must consume it starts at 2,160 s; replaceableFrom for that term's landing = 6,120 s.
1. 6,119 s: H calls announceLanding(lastLanded + 1, …), bonding 2,000 TAIKO: "it defers replaceableFrom by LAND_CHAIN_GRACE, once per range". Not refused: the C3 rule refuses only "once the head FI entry has been due at T_floor of the first unlanded term for longer than LAND_WINDOW", and T_floor = max(lastLanded.anchorTipTimestamp, termStart − 1,801) ≈ 359 s, so the entry has been "due at T_floor" for 59 s. replaceableFrom = 6,719 s.
2. 6,720 s: H forms a REPLACE VC at lock = lastLanded with a true, ≥ 48-s-old L1 reference (A1 holds; honest attesters sign; nothing is S3d) and calls recordViewChange: accepted ("only if vc.lockHeight == lastLanded.height ... and block.timestamp > replaceableFrom at record time") and "priority evidence for the forced path, deferring it by LAND_CHAIN_GRACE once, exactly like a landing announcement". No refusal rule keyed on the FI entry's age exists for records. Forced path opens at 7,320 s.
3. H lands nothing. At 7,320 s + proving (≈ 4 min) a forced batch lands: ≈ 126 min after the save against the published 112. If H lands its own replacement instead, L8 forces the entry into it, at the same time.
Whether the two "once" deferrals share one key is not stated; landing A1 keys the announcement on lastLanded and A3 says the record defers "once", so as written they stack.

Design text (verbatim): "an announcement is refused once the head forced-inclusion entry has been due ... for longer than LAND_WINDOW (round 3, C3), so the forced path is deferred at most once" (landing A1). "a recorded REPLACE VC defers the forced path once by the same grace, as priority evidence and nothing more" (index §3). "landed ≤ s + 112 min (102 plus one LAND_CHAIN_GRACE deferral by a landing announcement)" (FI §9, §16).

Cost / gain: one 2,000-TAIKO bond, forfeited 40 % to the replacement lander (H itself if it lands the replacement) and 60 % burned: net ≈ 1,200 TAIKO (≈ 0.18 ETH) plus two L1 transactions, for 10 extra minutes of censorship of every due entry; repeatable per stall, not per entry (a consumed entry ends it).

Fix: key both deferrals on one per-range flag (a range gets one LAND_CHAIN_GRACE from whichever comes first), apply the C3 refusal to REPLACE/RESUME records as well, and restate the bound (or publish 122).

## F4 [Low] Internal contradictions that survive the round-4 pass
1. Sequencing §8: "seats can be exited two hours after the count is read" versus §2 "requestExit ... sets activeUntil = max(τ + DELAY_REG, activeFrom + MIN_TENURE)": a seat registered to pad the launch count is bound for 7 days, not 2 hours (bridge-migration §5 says MIN_TENURE correctly). Consequence: the launch-padding cost is misstated by 80x on the normative selection page.
2. requestExit is "all-or-nothing" (sequencing §2) and "all seats" (roles §1), while the interface is `requestExit(uint16[] calldata _seats)` (sequencing §10, interfaces §1) and the slashing §9 owner machine writes "EXITING (activeUntil = τ + DELAY_REG)" with no MIN_TENURE term. Per-seat exits change the mutation-ring bound M ("8 entries and 8 exits per week" assumes one exit event per seat either way, but a per-seat exit lets an owner spread 8 −1 entries over 8 effective times inside one horizon).
3. TimeoutMsg carries no redraw field (interfaces §1, preconf §1), yet a VC is proposed from "≥ Q timeouts of one (t, v, vcHash, kind)" and verified against "the committee of the recorded redraw count": after a redraw, timeouts of replaced committee-0 members count toward the off-chain trigger. Never on L1, so harmless, but the trigger set is unspecified.
4. Holders.mode has values 0..2 on sequencing §10 and 0..3 (NO_COMMITTEE) on the interfaces page.
5. Preconf §14 "keeps the view alive without certified progress, unrewarded" is false (F1 step 3).

## What I tried and could not break
1. Seed-known assignment grinding through any owner input (reserve withdrawal, reactivate, exit, re-register): every owner-triggerable eligibility input is DELAY_REG-dated (7,200 s) and the freshness window is 3,660 s, so no input can be flipped after the seed is known; the reserve is non-withdrawable while a seat is active (sequencing §2 eligibility-input rule).
2. Excluding an entrant at registration: indices are contract-assigned, FREE holes first then appends, so an incumbent's same-block append never reverts an entrant; the array cap (65,535) costs more than the supply; the BLS key is protected by the proof of possession (sequencer-key squatting at registerKeys costs the victim one retry, bounded).
3. Taking a producing leader's view with fewer than Q attesters: a TIMEOUT needs Q signers each of whom received no signed header for 5 s; below Q no VC forms and MISS is unreachable; an abstaining minority can only blank (I3). The redraw vote cannot be used by a cartel below 17 to escape a committee where it is small, and a cartel of 17 gains nothing by redrawing a term it already blanks.
4. Cross-redraw locked-block revert with precomputed committees: all three committees of a term are public 20 to 80 min ahead, so a cartel can pick its terms, but at one third of the seats my simulation found no term in 20,000 with ≥ 17 in draw 0 and ≥ 22 in a redraw; the design's 6·10^-7 per view stands inside T11.
5. Draining an entrant's landing reserve by minimum-price third-party landings (45 TAIKO per term at term end): the lander pays ≈ 2 M gas (≥ 0.02 ETH ≈ 130 TAIKO) per landing, ReserveLow fires one term of exposure ahead and a top-up avoids the lapse; net loss to the griefer.
6. Launch padding then exit (R4-C5 trace 1): MIN_TENURE binds fresh seats for 7 days ≥ MIGRATION_LEAD, so padded seats are drawn through T0 and the first terms; the residual is the accepted L2 cartel case (and, with F1, the padded seats are no longer bled).
7. Forced-inclusion stuffing or skipping to censor a user: the quadratic fee plus 196k state gas per entry bounds delay (L8); FI_SKIP needs four hours without any landing; a skipped entry's bond and fee are burned and the floor quadruples; the T_floor count forces every cartel-primary landing to consume due entries.
8. Chaining announceLanding to defer the forced path indefinitely: one deferral per lastLanded plus the C3 refusal; the residual is the one extra grace of F3.
9. Turning V10 or the byte budget into a MISS or a V8 deadlock: FI blocks are exempt from V10 and a sequencer block is always the sequencer's choice, so no budget state makes a leader silent.
10. Bleeding an online owner through the hard floor or the reserve: MISS never touches the reserve and needs a Q-signed TIMEOUT VC; reward debits never touch seat stake.
