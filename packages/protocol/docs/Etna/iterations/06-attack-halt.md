# ETNA round 6 - HALT LIVENESS attacker report

## Model

I am running as Sonnet 5.5 (model id `claude-sonnet-5-5`), as stated in my environment.

## Method

1. Read the design site (index, roles, sequencing, preconf, landing, slashing, forced-inclusion, bridge-migration, interfaces, parameters, arguments, l1-dependencies, frame-transactions, limitations, glossary) at commit 9a208ed, then 01-threat-model.md and README.md.
2. Targeted the round-5 fix mechanisms first (domain tree and versioning by effective time, receipt-time staleness, the own-attestation TIMEOUT rule, FALLBACK gates, suspended seats in the rank domain, reserve refill and ReserveLow, S3b / RESET / RESUME / REPLACE, FI_ANCHOR_LAG and the 112-minute bound), then everything else.
3. For each candidate, wrote the concrete message/transaction timeline with times, checked the exact design sentence, computed cost and gain, and tried to find the rule that stops it.
4. Checked numeric claims with small scripts (walk gas by Monte Carlo over a persistent tree, hash-walk simulation of holder lists and committees at the launch registry with suspended owners, binomial tables, fee and reserve arithmetic).
5. Findings are appended below as they are completed. Items that I could not break are listed at the end.

## Findings

(appended below)

---

## R6H-1 [High] A pre-posted poison stream defeats the round-3 fee escalation: landing halts 4 h per entry for about 0.05 ETH each (builds on R3H-1; its fix is inadequate)

Requirement: R1, R7, P5; TH7. Builds on R3H-1.

Actors: attacker A (no seat). Precondition, already priced by the design: a decodable manifest that executes but that no ZK guest can prove.

Trace:
1. t = 0: in one L1 block A posts N = 9 calldata FI entries with skips = 0. Each pays FI_BOND 0.05 ETH + 0.001 x (50 + pending)/50 ETH: 0.46 ETH in all. The 4^skips factor prices only entries posted after a skip.
2. At t + 300 s all are due; V8 makes sequencers emit FI, FI, seq, ... (certified, locked). A landing covering FI(E1) must prove E1: impossible.
3. A skip needs T - lastLanded.anchorTipTimestamp >= 14,400 s and applies only to the stored head. The certified FI(E1) carries content, so that chain never lands; only a REPLACE chain anchored 4 h or more after the last tip lands one anchor-only block. "A landing skips at most one entry": E2 is the new head, due and unprovable, so the next skip needs another 4 h. A forced batch must contain all min(due, 64) entries, so it is invalid too.
4. Result: for 4N = 36 h no ordinary block lands, no checkpoint is written (bridging stops), certified blocks are voided each cycle, and an honest FI request behind the stream waits 4N hours, not 112 minutes.

designText (forced-inclusion.html, section 12): "the n-th such entry within 24 h costs its poster 0.05 + 0.001 × 4^(n−1) ETH, all burned ... The stall length is therefore bounded by the attacker's budget, roughly 4 h × log4(budget / 0.001 ETH)"

Cost/gain: the design prices 36 h at 0.45 + 0.001 x (4^9 - 1)/3 = 87.9 ETH; pre-posting costs 0.46 ETH, 190 times less; a week (42 entries) is 2.2 ETH. Gain: finality, bridging and FI halted and locked blocks reverted every 4 h until a DAO guest fix, contradicting R1. Through an ordinary L2 transaction the same bug repeats the 35 to 65 minute replace cycle for cents, against "a few events per year" (landing section 6).

Suggested fix: let a landing that meets the 4-h gap skip the whole due prefix of its walk; escalate the bond with queue depth.

---

## R6H-2 [Medium] "A chain-wide proving outage never suspends the honest set" is false: the reserve covers about two terms per seat, the design tolerates 34-hour outages, and a lapse costs 36 hours

Requirement: R1/R3, R7; TH2, TH13. Builds on R5S-4 and R4-C2.

Actors: honest owners at the launch registry (A = 72 seats: eight 8-seat owners and eight single seats), a seatless lander L. Cause: any landing outage of D hours (ZK back-ends fail, or L1 fees above break-even). Nothing is voided for up to 34 h.

Trace:
1. Landing stops; the chain keeps certifying 60 terms an hour.
2. After D hours L lands the backlog in order at the maximum ramp (terms older than 30 min), paid up to 4,561 TAIKO per term from each holder's reserve.
3. An owner lapses after about 2 terms per seat (reserve 9,200 per seat, lapse line 4,561): an 8-seat owner after 16 own terms, a single seat after 2 (the design's own sentence), i.e. 144 backlog terms = 2.4 h on average (A/30 hours in general; 3.6 to 5.4 h for one-landing terms of 1,961 TAIKO). About half the owners have lapsed by then, most by about 4 h.
4. A lapse is DELAY_REG-dated and lasts "at least SUSPEND(3)" = 36 h even if the owner tops up at once.
5. Simulation (launch registry, 200,000 terms): with the eight big owners suspended, 44.3 % of terms have all five drawn holders void (neither open-empty nor dead mode while other terms land), mean committee m = 3.9, and 99.8 % of terms are no-committee (m < 8: no certificates, takeover or MISS) for at least 38 h. With four suspended: no dead terms, m = 17.9.
The named mitigation (ReserveLow, auto top-up) needs about 30 k TAIKO of spare liquidity per outage hour per 8-seat owner.

designText (sequencing.html, section 7): "so a chain-wide proving outage never suspends the honest set." Landing section 5 sizes against "about 7 terms drawn inside one LAND_WINDOW_MAX (60 terms)".

Cost/gain: no attacker needed; owners without spare TAIKO lose eligibility and certification collapses chain-wide.

Suggested fix: cap the per-term debit against the 34-h horizon (falling with backlog age), end a lapse at top-up, and treat a term with five void holders as open.

---

## R6H-3 [Medium] At 2-second L1 slots the per-landing reward pays one of the five landings a full term needs; "about 100 gwei whatever the term size" is about 30 to 40 gwei

Requirement: R5 (works at 2-s slots), R7; TH13. Builds on R4H-7.

Actors: a third-party lander; L1 at 2-s slots (the L1 table allows at most 3 blobs per block; that column is marked assumed).

Trace:
1. No landing can carry the 6 blobs the rule assumes. A term at the V10 cap (15 blobs, 1,950,660 bytes) needs 5 landings of 390,132 bytes.
2. Landing k is paid r_land only if k <= ceil(bytesLanded_after / 780,264). After k landings the bound is ceil(k/2): only k = 1 passes. One r_land per term, not three.
3. Reward for a full term at the maximum ramp: 60 x 4 + 15 + 1,300 + 6 + 400 = 1,961 TAIKO = 0.294 ETH for 5 landings of 1.5 to 2 M gas: break-even 29 to 39 gwei. At 12-s slots: 4,561 TAIKO for 3 landings = 114 gwei. Landings 2 to 5 earn only about 50 TAIKO each.
4. Terms of at most 3 blobs are unaffected. For heavy terms landing waits about three times earlier in a fee spike; nothing is penalized, but the replace window (35 to 65 min) then exposes the backlog to limitation L6.

designText (landing.html, section 5): "landing k of term t ... is paid r_land only if k ≤ ⌈bytesLanded_after / (6 × 130,044)⌉, where 6 × 130,044 = 780,264 bytes is one full landing". And: "≈ 100 gwei per landing whatever the term's size".

Cost/gain: none needed; finality is delayed at 2-s slots.

Suggested fix: define one landing as min(6, L1 blobs per block) x 130,044 bytes (a slot-time parameter) and recompute V10, the exposure and the break-even.

---

## R6H-4 [Medium] The attester machine starts the view timer only at the first valid block: a leader that publishes nothing is never timed out and its term is never closed (contradicts the prose)

Requirement: R4; TH3, TH10. Same object as R5H-1, a case the fix pass missed.

Actors: any single primary holder H; the honest committee.

Trace (certificate page section 10 is the only place a timer origin is given):
1. H is dead or never gossips a header. Every attester stays in IDLE(t); the only edge out is "IDLE(t) --first valid block of (t,v)--> ATTESTING(v)". TIMING_OUT, where TIMEOUT and TERM_END are signed, is reachable only from ATTESTING.
2. No TIMEOUT is signed: backups never start and H is never bled (MISS needs a TIMEOUT VC). At termEnd + 2 s no TERM_END is signed either, so no VC closes the view and leader(t+1, 0) cannot start (V2 needs the carried closing VC). FALLBACK is not in the machine. Read literally, one silent primary stalls the chain until dead mode (75 terms); at best a silent seat is a free term-kill with no bleed whenever it is drawn.
3. The prose never defines the origin ("for TIMEOUT seconds ... no new certificate of the view has appeared") and says the opposite of the machine: a dead leader "is timed out after 5 s".

designText (preconf.html, section 10): "IDLE(t) --first valid block of (t,v)--> ATTESTING(v) ... ATTESTING(v) --(no new C for TIMEOUT and no own attestation of (t,v) still uncertified) or now ≥ termEnd+END_GRACE--> TIMING_OUT(v)". Section 1(b): "a dead leader leaves every block it produced either certified or unattested, so every honest attester times it out after 5 s and it pays MISS".

Cost/gain: zero cost; liveness denial without bleed for any seat, or a chain-wide stall if built as drawn. The page is normative for the trigger, so both statements cannot be implemented.

Suggested fix: start the timer when the attester learns the opening object, add IDLE edges for TIMEOUT, TERM_END and FALLBACK, and put FALLBACK and the redrawn-committee start in the machine.

---

## R6H-5 [Low] Contradictory statements on the newest mechanisms; (a) would unsort the domain-tree version log if built from the slashing page

Requirement: I1 hygiene; TH12. Rules stated two ways.

(a) Exit time. Sequencing section 2 (owner of eligibility inputs): requestExit "is accepted for a seat only once τ + DELAY_REG ≥ activeFrom + MIN_TENURE ... and sets activeUntil = τ + DELAY_REG", which keeps the log sorted. Slashing page machine: "ACTIVE --requestExit(seats)--> EXITING (per seat, activeUntil = max(τ + DELAY_REG, activeFrom + MIN_TENURE))". Built from it: a seat registered at τ0 (E = τ0 + 2 h) exits at τ0 + 1 d with E = τ0 + 7 d + 2 h; an entrant registers at τ0 + 2 d, E = τ0 + 2 d + 2 h. The log is [τ0+2h, τ0+7d+2h, τ0+2d+2h]; every later version is built on the tip that already lacks the exiting seat, so at termStart = τ0 + 3 d the inbox counts 1 seat while nodes evaluating [activeFrom, activeUntil) count 2. For 5 days (7,200 terms) the inbox's E_t differs from the nodes', holder checks revert and sequential landing stalls: one early exit by one owner.
(b) Entry cost. Roles section 1 "about two fresh storage slots per first seat" and sequencing section 11 "Registration gas ≈ 2 × 97,920 state + ~60k exec" versus sequencing section 5 "about 16 fresh nodes per seat (≈ 1.6 M gas of state": 8 times; an 8-seat register needs 13 to 15 M gas, near the 16.8 M cap.
(c) Dead L1 node. Anchor page section 15: blocks that fail V5 mean "no attester times it out; it earns nothing and pays nothing"; certificate page 1(c), normative: such a leader "is timed out at 5 s and bled".
(d) Sequencing section 11: "≥ ROLE_HORIZON + DELAY_S = 123,720"; 122,880 + 1,320 = 124,200.
(e) Sequencing section 5 "P(no holder) = 0 whenever E_t ≥ 1" and section 6 "open-empty if the walk finds no eligible seat" versus a walk that "does not read suspension": a term with five suspended holders (44.3 % in R6H-2) is neither open nor served.

Cost/gain: none directly; (a) is a one-transaction stall if built from the stale page.

Suggested fix: delete the max(...) form; one registration-gas figure; treat "no live view in H" as open (view 255); one rule for a V5-failing leader.

---

## What I tried and could not break

1. **Domain-tree version-log monotonicity across register, requestExit, exitSlashed, reserve lapse, reactivation.** Stopped by sequencing section 5 and the interface page: only entry and exit write the tree, both are dated tau + DELAY_REG, L1 timestamps are strictly increasing, and the tenure rule (tau + DELAY_REG >= activeFrom + MIN_TENURE) means no exit is dated later than a following write. Lapses, suspensions and reactivation are flags. The one break is a stale sentence on the slashing page (R6H-5a), not the rule itself.
2. **Seat recycling against old versions.** Stopped by RECYCLE_GRACE = 129,600 s >= ROLE_HORIZON + DELAY_S = 124,200 s: a hole is reused only after the exit version (E = activeUntil) is older than every landable term, so no landable term reads a version in which the old seat is in the domain; pinned terms older than the horizon read the pin.
3. **Walk gas against the 16.8 M cap.** I simulated 576 random lookups (the worst case) in a persistent tree: about 1.0 M gas at 128 seats, 5.4 M at 4,096, 10.1 M at 65,535 (14.5 M if each level costs two reads). The design's 4 M and 9 M are 11 to 26 % low but inside the cap, and a full registry needs only about 45 tries (distinct seats come fast), so the 512-try case occurs only at small registries where each try is cheap. Independence from later writes holds because versions are immutable.
4. **PIN_REWARD as a drain on a victim holder.** The ramp is about 0 at term end, the holder's own landing pins first (reward skipped), early third-party pins pay only below about 1 gwei, and the total per term is 400 TAIKO and only for terms nobody landed: no lapse path.
5. **Lone-leader receipt-time wedge (publish each block at the 3-s staleness edge so about half the committee attests).** It works and redraws cannot help (receipt time is per node), but it is exactly residual 1(d); I found no variant beyond it except the no-block case of R6H-4.
6. **S3b without an exemption, RESET, RESUME, REPLACE.** Stopped by the V3 argument (an honest lock vote of kind TIMEOUT, TERM_END or FALLBACK is at least the carried certificate it verified, and votes are monotone) and by RESET (only RESUME is signable under the old object). I could not build an honest-slashing trace.
7. **FALLBACK at lock = lastLanded voiding a backlog.** Needs Q of committee(t+1) (4e-5 per term at one third of the seats, reproduced) and an unrecorded committee(t) VC; the window is the proof time. This is limitation L5, though the "at most one term" wording understates it: every descendant block until consumption is orphaned (a few minutes).
8. **Forced-batch stream keeping the replace window open.** After an independent 35-to-65-minute stall, an attacker with a stock of due entries can land a forced batch (up to 64 blocks) in every L1 block, faster than the 48-s-old RESUME reference and the 72-s record the honest chain needs, and as the self-including lander it recovers fees and bonds (forced fees go to rewardTo, bonds are refunded on consumption), so the quadratic stuffing price does not bind it. What stops it is cost and the precondition: about 0.004 ETH of state gas per entry, roughly 77 ETH per hour at 12-s blocks, and the stall must exist first. Not a free halt, so not reported.
9. **Void-seat dilution through a free reserve lapse (a side effect of R5S-2).** P(all five drawn owners void) = q^5 for void share q; at q = 1/3 it is 0.4 %, so it matters only above one third of the seats (T11, L2).
10. **FI_ANCHOR_LAG = 288 s at 2-s slots.** Above ANCHOR_MIN_AGE (48 s) and above honest anchor lag (about 60 to 72 s); only deliberately stale anchors are withheld.
11. **Dead mode against the deferred replace window.** Dead mode opens at termEnd(t') + 74 x 60 = +4,440 s and the deferred replaceableFrom at +4,500 s, a 60-s inversion (the sequencing page claims 75 min > 65 min, without counting the deferral); harmless because dead-mode landings obey A1.
12. **Tiny-prefix landing races.** Each such landing advances the chain and pays the lander the ramp; it cannot stop landing.
13. **The 112-minute forced-inclusion arithmetic** (300 + 1,800 + 120 + 3,600 + 300 + 600 = 6,720 s) is correct; what breaks it is a poison head entry (R6H-1).
14. **The binomial tables in preconf section 14** reproduce (1.7e-4, 4.1e-2, 0.36 for offline committees; 2e-15, 3e-9, 4e-5, 6e-3 for Q cartels).
15. **Front-running registerKeys.** The sequencer key has no proof of control, so an attacker can bind a victim's pending sequencer address first; the victim re-registers a fresh key privately. Bounded griefing, no halt.
