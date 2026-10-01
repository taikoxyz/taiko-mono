# Etna red team, round 6: judge report

Date: 2026-10-01. Design under test: `packages/protocol/docs/Etna/design/` at commit 9a208ed ("Etna round-5 second fix pass"). I read all fifteen pages in full as text extracts: index, roles, sequencing, preconf, landing, slashing, forced-inclusion, bridge-migration, interfaces, parameters, arguments, l1-dependencies, frame-transactions, limitations, glossary. The extracts were made after the last HTML write, which was at 00:28. I also read `01-threat-model.md` (TH1-TH25, W1-W7) and `README.md` (R1-R7, A1-A8) in full, all three round-6 attacker reports in full, and the round-5 judge report for format and duplicate checks. I checked the relevant lines of `01-judge.md` (R1-F4) and `04-judge.md` (R4H-2) for precedent.

Citations are `page.html:line` in `packages/protocol/docs/Etna/design/`.

I re-ran both of the censor attacker's simulations (`phase4/r6c/phantom_sim.py`, `phase4/r6c/combined_sim.py`) because the censor attacker and I are the same model family. Both reproduce:
- The launch registry with 144 parked seats gives mean m 10.4 and 11.6 % no-committee.
- The 8x8/32x1 revenue share is 44.0 % by term count and 50.8 % weighted by seconds.

I re-derived the strengthened form of R6H-1 by hand from V8, F3 and L8 (section 3). No repository file was modified.

## 1. Models used

| Attacker key | Requested model | Self-reported model | Report | Findings |
|---|---|---|---|---|
| steal | fable | claude-fable-5-1 ("Claude Fable 5.1 (claude-fable-5-1) ... fable was requested") | `round-6-steal.md` (complete; twelve could-not-break items) | R6S-1 to R6S-4 |
| halt | sonnet (by rotation; the report does not restate the request) | claude-sonnet-5-5 ("Sonnet 5.5 (model id `claude-sonnet-5-5`)") | `round-6-halt.md` (complete; fifteen could-not-break items) | R6H-1 to R6H-5 |
| censor | opus | claude-opus-5-5 ("claude-opus-5-5 (Opus 5.5) ... Opus was requested") | `round-6-censor.md` (complete; nine could-not-break items) | R6-C1, R6-C2 (Findings 1 and 2 in the report) |
| verifier (one per finding) | not recorded in the findings handed to the judge | not recorded | verdicts embedded in the findings JSON | 7 confirmed, 2 downgraded, 1 refuted (eleven findings; R6S-4 and R6H-5 overlap) |
| judge | session model | claude-opus-5-5 (Opus 5.5) | this file | verdict REVISE |

Process notes.

1. All three goals ran to completion. The rotation put each model on a different goal from round 5: steal on fable, halt on sonnet, censor on opus. Round 6 therefore counts as a full round.
2. The censor attacker and the judge share a model family. I re-derived both censor findings from the page text and re-ran both censor simulations independently (figures above).
3. Two pairs of findings overlap, and each pair counts once for convergence:
   - R6S-4 items 1 and 2 are the same defects as R6H-5 items (a) and (b): the stale exit formula and the registration gas.
   - R6S-2 and R6H-2 both attack the landing-reserve sizing, from opposite ends: a deliberate drain to just above the lapse line, and an honest drain past it. Their traces and fixes differ, so both are kept.
4. The verifier strengthened R6H-1: it showed the halt does not cycle every four hours but is indefinite. The verifier also refuted the steal attacker's only High, R6S-1.

## 2. Findings table

| Id | Title (short) | Attacker | Claimed | Verdict | Final | Requirement |
|---|---|---|---|---|---|---|
| R6S-1 | The L20 drain window is a holder-chosen, forced-batch-guaranteed reorg of every locked block; the 39-ETH locked bound and L6's "unprofitable to the forcer" are false | steal | High | REFUTED | none (restates L6, L14, L20) | R6, R7; TH5/W1, TH8; I4 as a claim; L6, L20 |
| R6S-2 | The landing reserve is non-withdrawable only down to 4,561 TAIKO per owner, not 9,200 per seat: a CAP owner frees 94 % of it at zero cost and keeps every draw | steal | Medium | CONFIRMED | Medium | R7 (I2 sizing, L20 as stated); R1 entry condition as published |
| R6S-3 | The FALLBACK gates protect committee(t)'s locked blocks only if committee(t) reaches Q at term end; a cartel that withholds TERM_END voids a view's locked blocks with no same-block race, at any slot time | steal | Medium | CONFIRMED | Medium | R6; P2, L5(b) as stated; TH5/W1 |
| R6S-4 | Internal contradictions: the slashing page's requestExit formula, registration gas understated, FI_ANCHOR_LAG still a block count on one page, committee-root key hashes undated across rotation | steal | Low | CONFIRMED | Low | R5, R7; I1 (documentation) |
| R6H-1 | A pre-posted poison stream defeats the round-3 skip escalation; two calldata poison entries due together halt every landing path until a DAO guest fix | halt | High | CONFIRMED (strengthened by the verifier) | **High** | R1, R7, P5; TH7, TH2; builds on R1-F4, R3H-1 |
| R6H-2 | "A chain-wide proving outage never suspends the honest set" is false: the reserve covers about two terms per seat, outages up to the horizon are tolerated, and a lapse lasts at least 36 h | halt | Medium | CONFIRMED | Medium | R1, R7; TH2, TH13; builds on R4-C2, R5S-4 |
| R6H-3 | At 2-s L1 slots the per-landing reward pays one of the five landings a full term needs; the "≈ 100 gwei whatever the term size" break-even is about 30 to 40 gwei | halt | Medium | CONFIRMED | Medium | R5, R7; TH13; regression of R4H-7 |
| R6H-4 | The attester state machine starts the view timer only at the first valid block, so a leader that publishes nothing is never timed out | halt | Medium | DOWNGRADED | Low | R4 (documentation of the normative trigger); TH3, TH10 |
| R6H-5 | Contradictory statements on the newest mechanisms: exit formula, registration gas, V5-failing leader, 123,720, open-empty definition | halt | Low | CONFIRMED | Low | I1 hygiene; TH12 (documentation) |
| R6-C1 | Suspended seats in the rank domain make committee size m reducible: a parked majority forces no-committee mode and lowers the locked bound | censor | Medium | DOWNGRADED | Low | R6 (TH9/TH10), P2 statement |
| R6-C2 | The blank-term revenue table counts certified terms, not seconds, and omits the handoff delay a blocking minority imposes | censor | Low | CONFIRMED | Low | R6 anti-monopoly figures; L2 |

Totals:

| Class | Count | Findings |
|---|---|---|
| Critical | 0 | |
| High | 1 | R6H-1 |
| Medium | 4 | R6S-2, R6S-3, R6H-2, R6H-3 |
| Low | 5 | R6S-4, R6H-4, R6H-5, R6-C1, R6-C2; R6S-4 and R6H-5 overlap on two items, so about 4 unique |
| Refuted | 1 | R6S-1 (claimed High) |

Two findings were downgraded: R6H-4 and R6-C1, both from Medium to Low. No finding was upgraded. R6H-1 keeps its claimed High, but its trace was strengthened from "4 h per entry" to "indefinite with two entries".

### Root causes

| Round that introduced the surface | Round-6 findings | Root cause |
|---|---|---|
| Round 1 F4 (FI_SKIP) and round 3 H1 (SKIP_ESCALATION, FI_BOND); round 4's R4H-2 refutation | R6H-1 | Two pieces combine:<br>- The skip is defined over one stored entry: `skipped(i, T)` "holds only for i = fiQueue.head" (forced-inclusion.html:27).<br>- The price is charged at save time and counts only skips that already happened: "skips is the number of head entries skipped in the last 24 h" (forced-inclusion.html:23).<br>The round-4 refutation of R4H-2 said "the entries behind the head are consumed with content". That assumes the entries behind the head are provable, which is exactly what an attacker pre-posting several poison entries breaks. |
| Round 4 R4H-3, R4-C4; round 5 R5S-4 (landing reserve, refill rule) | R6S-2, R6H-2 (and R6S-1, refuted) | The reserve is required per seat at register and reactivate (seats × 9,200) but enforced per owner at an absolute line (4,561, slashing.html:26, parameters.html:31). It is also sized against one LAND_WINDOW_MAX (60 terms, landing.html:69), while the design tolerates outages up to the 34-h horizon with nothing voided. The refill rule cannot tell a seatless rewardTo the owner controls from a third party (landing.html:72). |
| Round 5 R5S-5 (FALLBACK gates) | R6S-3 | Gate (iii) protects committee(t)'s locks only by letting committee(t)'s own TIMEOUT or TERM_END VC supersede the FALLBACK (preconf.html:87). That VC needs Q of committee(t), so a blocking minority of committee(t) removes the premise the gate relies on. |
| Round 4 R4H-7 (per-landing reward cap ⌈bytes / 780,264⌉) | R6H-3 | "One full landing" is hard-coded as 6 blobs (landing.html:63). Yet the design's own slot table, V9 and landing §15 give 3 blobs per L1 block at 2-s slots. |
| Round 5 R5S-2 (suspended seats stay in the rank domain) | R6-C1, R6H-5(e), part of R6H-2 | Suspended seats now dilute committees and holder lists instead of leaving them. The design analysed this only for ranks (no grinding), not for committee size or for terms whose five drawn holders are all void. |
| Round 5 fix passes (exit rule, domain tree, FI_ANCHOR_LAG, timeout trigger) | R6S-4, R6H-4, R6H-5 | Stale sentences on non-owning pages (slashing §9, sequencing §11, roles §1, forced-inclusion §15, bridge-migration §15) and an attester state machine that was not updated with the trigger. |

Pattern. Round 5's Highs were rules stated over a broader object than the case they were written for. Round 6's defects are the mirror image: protections stated over the case they were written for, not over the adversary's schedule.

| Protection | Where it falls short |
|---|---|
| Skip pricing | Counts skips after the fact; the attacker pays before any skip. |
| FALLBACK gate | Assumes an honest committee(t) VC exists. |
| Reserve | Its guarantee is per seat but its line is per owner, and it is sized for one window inside a 34-hour horizon. |
| Landing reward | Sized at 12-s slot capacity. |

None of invariants I1 to I5 is falsified as a statement under the normative pages. Three published claims are false as written:
- I2's sizing (R6S-2, R6H-2).
- The FI page's "DAO never needed" and the 112-minute bound (R6H-1).
- The L5 residual (R6S-3).

## 3. CONFIRMED and DOWNGRADED findings: trace, design gap, required revision

### R6H-1 [High] A pre-posted poison stream halts every landing path until a DAO guest fix

**Trace.** The precondition is a decodable manifest that executes inside FI_ZK_GAS_LIMIT but that no ZK guest can prove (a guest-completeness bug). The design keeps this precondition as a live residual: "a guest completeness bug inside that budget is the residual FI_SKIP covers" (forced-inclusion §8).

1. In one L1 block, attacker A posts N ≥ 2 calldata entries carrying that manifest.
2. Each entry pays FI_BOND + FI_BASE_FEE × (50 + pending)/50 × 4^skips with skips = 0, because "skips is the number of head entries skipped in the last 24 h" (forced-inclusion.html:23).
   - Nine entries cost about 0.46 ETH plus state gas.
   - The design's own pricing of nine sequential skips, "0.05 + 0.001 × 4^(n−1) ETH ... roughly 4 h × log4(budget / 0.001 ETH)" (forced-inclusion.html:153), prices the same nine entries at about 87.9 ETH.
3. 300 s later, every entry is due at every anchor. V8 forces FI blocks for E1, E2, ... into every sequencer chain. The certified chain then contains FI(E1) with content, which no guest proves.

The attacker's step 3 claimed that a 4-h REPLACE lands one anchor-only FI(E1) per cycle. The verifier showed that no landing path exists at all once two unprovable entries are due together. I re-derived this:

- **Skip window.** Only fiQueue.head can be skipped (forced-inclusion.html:27). The skip needs T − lastLanded.anchorTipTimestamp ≥ 14,400 s, where T is the landing's anchor tip.
- **An FI block cannot advance the anchor.** An FI block takes its parent's anchor and timestamp + 1 (F3). A range consisting only of FI(E1) on top of lastLanded therefore has anchor tip = lastLanded's tip and is never in the skip window. So a sequencer block S must precede FI(E1) in the range.
- **S can only come first if E1 was not yet due.** S is allowed only if E1 was not due at lastLanded's anchor (V8). If E1 was already due, V8 forbids S, and V2/A4 forbid an FI block as the first block of a current-term REPLACE or dead-mode view.
- **L8 then forces E2 into the range.** The shortest candidate is [S, FI(E1) skipped], with n = 2.
  - Its T_floor = max(lastLanded.anchorTipTimestamp, termStart(termId) − 1,801). For a range anchored at least 4 h after the last tip, that is hours after the entries became due, so D ≥ 2.
  - L8 requires c ≥ min(D, ⌈2n/3⌉) = 2 (forced-inclusion.html:44).
  - So E2 must be included with content, and E2 is unprovable.
  - Longer ranges only raise the floor.
- **The forced batch fails too.** A forced batch must contain exactly m = min(due, 64) FI blocks (forced-inclusion.html:71). E2 again carries content.
- **Dead mode does not help.** Dead-mode landings obey the same L8 and V8.

Consequences:
- Ordinary landing, replacement, forced batch and dead mode all stall.
- No checkpoint is written, so L2→L1 bridging stops. The forced-inclusion service is down for every requester.
- Calldata entries never void (forced-inclusion.html:81).
- Nothing is ever skipped, so the attacker's bonds (about 0.1 ETH) are not even burned. They are refunded if a fixed guest later consumes the entries.
- L2 preconfirmation continues at the certified level, but nothing above lastLanded can ever land until the DAO ships a guest fix.

**Design gap.** The single-entry skip and the after-the-fact escalation were sized against an attacker who posts one entry per cycle. The following published claims are false:
- forced-inclusion.html:27: "a landing skips at most one entry: the entries behind the head are consumed with content". This holds only if they are provable.
- forced-inclusion.html:153: the stream pricing.
- forced-inclusion.html:164: "DAO. Never needed ... a stream of them is priced geometrically".
- forced-inclusion.html:191: "proven FI_SKIP can fire only after four hours ... so it never skips an entry a live chain could have included". This is true but no longer sufficient.
- limitations.html:34 (L16): "a two-day stall costs thousands of ETH".
- The proven 112-minute bound of forced-inclusion §16, for any honest entry queued behind the stream.
- R1's "the chain stays live if the DAO never acts again". This failure is outside the one compound case L19 accepts.

Not a duplicate:
- R1-F4 (a single entry halts until the DAO acts) was fixed by FI_SKIP.
- R3H-1 (re-arming after each skip) was fixed by FI_BOND and SKIP_ESCALATION, and this finding attacks the timing of that fix.
- R4H-2 was refuted on the premise this trace removes (04-judge.md:158).

**Severity.** High, not Critical, for consistency with R1-F4 (01-judge.md:74: "High per the scale (prolonged halt of landing, not permanent: the DAO can upgrade out of it; L2 preconfs continue; no A1-A3 loss)") and with R3H-1. It sits at the High/Critical boundary, because without a DAO action the halt is permanent. It is conditional on a guest-completeness bug. A fix exists inside R1 to R7, so the round is REVISE, not NEGATIVE.

**Required revision.**
1. **Make the skip a property of the gap, not of one entry.** A landing that satisfies the 4-h gap voids every entry of the due prefix at its anchor tip, up to MAX_FI_PER_LANDING. Each voided entry derives to an anchor-only block and counts as consumed for L8. A pre-posted stream then costs 4 h per 64 entries, not an indefinite halt.
   - State the cost to honest entries queued behind poison: they are voided after a 4-h total stall and must re-post.
   - State whether their bond is burned or refunded. They cannot be told apart from the poster's, so a refund means the poster also gets its bond back, and the price must then come from item 2.
2. **Price depth at save time.** The bond (or fee floor) must escalate with the number of pending due entries, not only with past skips, for example FI_BOND × 4^(pending/8). A per-payer cap alone is Sybil-able and is at best a supplement.
3. **Re-derive the published figures.** Re-derive the stall-cost figures in forced-inclusion §12 and §13, L16, and the 112-minute bound's precondition. Restate R4H-2's refutation and its victim concern: skipping the prefix is now intended, and the victims' cost must be stated.
4. **Optional.** Add a provability witness at save time, for example a bound on manifest shape. This narrows the precondition but does not remove the need for items 1 and 2.

### R6S-2 [Medium] The landing reserve is non-withdrawable only down to 4,561 TAIKO per owner

**Trace.**
1. An 8-seat owner A lands its own terms at the happy-path lag with rewardTo set to a seatless address it controls.
2. The debit-and-credit skip applies only "when the lander's rewardTo and the holder are the same owner" (landing.html:68), so each landing debits about 200 to 430 TAIKO from reserveGwei. The attacker's figure of 250 is high; the verifier recomputed it.
3. "Credits to addresses with no seats and no key history are withdrawable immediately" (slashing.html:25).
4. A stops at reserveGwei = 4,562, just above the absolute per-owner lapse line: "a reserve below one term of exposure (4,561 TAIKO) makes the owner ineligible" (slashing.html:26; parameters.html:31 "lapse below 4,561").
5. Eligibility at the draw is inDomain ∧ ¬suspended (sequencing.html:48). Nothing checks the reserve at the draw. The per-seat amount (seats × 9,200) is enforced only at register and reactivate.

Result:
- A frees 69,038 TAIKO, about 10.4 ETH. This takes about 160 to 345 own terms, 24 to 52 h at 8 of 72 seats.
- A keeps all eight seats eligible.
- ReserveLapsed never fires and A pays no SUSPEND(3).
- The design concedes the mechanism: "moves from the reserve to a freely withdrawable balance at no net cost until the reserve lapses" (landing.html:72).

**Design gap.** The following published claims are false for any owner that chooses this:
- "Non-withdrawable" (landing.html:66; glossary; index R7 row).
- "about 16 terms ... below 0.1 %" (landing.html:69; L20).
- "it needs a third party's proof and landing" (landing.html:68).
- L20's costing of the drain at "one SUSPEND(3) per cycle" (limitations.html:37), because no cycle is needed.

The effective reserve of a drained CAP owner is one term, against R4H-3 (iii)'s "never one term deep". At 8 of 72 seats, the chance that more than one of the owner's terms falls in one LAND_WINDOW_MAX is about 99 %. An ordinary prover outage or fee spike for a drained owner therefore opens the L20 unfunded window that "honest operation does not reach". Landing is sequential, so later holders stall behind the unfunded term until it is landed at gas cost or replaced (L6).

It is not High:
- Nothing is taken from others.
- The slashable 1.05 × floor is untouched.
- The window exploit itself (R6S-1) was refuted, because funded later terms pay a third party to land through the unfunded one.

**Required revision.** Pick one of the following and state it on the landing page (§5), the slashing page (§1) and L20:

| Option | What it does | Trade-off to state |
|---|---|---|
| (a) Close the drain | Escrow reward credits to a rewardTo that owns no seats for EVIDENCE_WINDOW behind the non-withdrawable rule, or refuse them | Genuine third-party landers then register a seat or wait a week; state the effect on P4 |
| (b) Scale the guarantee to seats | Lapse an owner when reserveGwei < seats × one term of exposure, or refuse a drawn seat whose owner's reserve is below seats × LAND_RESERVE at termStart(t) (void view, as for any suspension; no rank moves, so R5S-2 is unaffected) | Re-derive the single-seat behaviour and the ReserveLow hysteresis |
| (c) Restate the guarantee | Declare the reserve non-withdrawable only down to one term per owner, and re-derive I2's sizing and L20's probabilities for drained owners | Weaker published guarantee |

The judge prefers (b), because it keeps third-party landing frictionless.

### R6S-3 [Medium] A cartel that withholds committee(t)'s TERM_END removes the premise of the FALLBACK supersession gate

**Trace.** Cartel C needs c ≥ 11 slots in committee(t) and ≥ 22 in committee(t+1). Both committees are public 20 minutes ahead.

1. During term t, the 32 − c honest attesters plus exactly c − 10 cartel keys attest, so blocks certify and lock up to h.
2. The other cartel keys of committee(t) attest nothing above h' < h.
3. At +2 s, the ≤ 21 honest keys sign TERM_END at lock h. That is below Q = 22, and cartel silence is unslashable. No committee(t) VC can form. TIMING_OUT's only exit is "VC(t,v) formed" (preconf.html:149-151). The REDRAW edge leaves only from ATTESTING.
4. At +12 s, gate (i) opens. C's 22 clean committee(t+1) keys sign FALLBACK at lock h'. Each gate passes:
   - Gate (ii) is met by the public C(h').
   - Gate (iii) has nothing to supersede the FALLBACK, because only "a TIMEOUT or TERM_END VC of committee(t) itself at a higher lock" can (preconf.html:87).
   - S3b needs an attestation by the same key under the same opening object (slashing.html:45), and clean keys have none. S3c needs two votes by one key.
5. Once recorded, "later landings must match it while it is live" (preconf.html:91). FALLBACK records have no deadness rule, and gate (i) then refuses committee(t+2)'s FALLBACK at h.
6. The honest leader(t+1, 0) accepts the VC under V2 (preconf.html:41) and builds on h'. Blocks h'+1..h−1 are orphaned with zero slashable keys, no proof race and no L1 ordering race, at every slot time.

Probability: about 2.3·10⁻⁵ per term at p = 1/3 with binomial draws (8·10⁻⁶ hypergeometric at a 300-seat registry). It falls to 2.5·10⁻⁶ at p = 0.3.

**Design gap.** The outcome class and its probability are already published. The §14 last row gives 4·10⁻⁵ at p = 0.33 for "Q of committee(t+1)", and L5 is "outside T11".

What is false is the mitigation narrative the R5S-5 fix rests on: "what protects committee(t)'s locked blocks is L1 ... the honest TERM_END VC ... is live before the earliest FALLBACK" (preconf.html:87). The same applies to:
- "What remains is the same-block race at 12-s slots" (limitations.html:23).
- "the same-block race it also needs ... multiplies it down further" (preconf.html:228).
- The locked credit-bound carve-out (slashing.html:59).
- The P2 and W1 text (arguments.html:20, :35).

The attack needs T11 broken in both committees, the liveness clause in t and the safety clause in t+1. So it is not High. Closing it needs a protocol rule, not a wording edit, so it is not Low.

**Required revision.**
1. Add an L1-recordable committee(t) certificate record per (t, v, closes), storing the highest certified (height, phHash) presented. recordViewChange and L4 refuse a FALLBACK whose lock is below that record.
2. A FALLBACK record that a higher recorded certificate supersedes is dead, like a dead REPLACE record, so committee(t+2) can close the view at the certified lock.
3. Make recording the view's highest certificate a duty of the leader and of every attester when no TERM_END VC has formed by termEnd + END_GRACE + 0.5 s. This is conditional, so it costs nothing on the happy path. The certificate exists before term end, so it reaches L1 well before +12 s.
4. Do not rely on "a lower FALLBACK lock is an objective lie". Committee(t+1) keys attested nothing under (t, v), and receipt of a certificate is unprovable.
5. Re-derive the P2 row, L5(b), the §14 last row and slashing §4 after the change. The residual returns to a same-block race only if the certificate record and the consuming landing share an L1 block.

### R6H-2 [Medium] A chain-wide landing outage suspends the honest set

**Trace.**
1. Landing stops for D hours. The cause can be both ZK back-ends down, or L1 fees above break-even. Nothing is voided for up to the horizon: 34 h, or 27 h at 12-s slots (landing.html:96; arguments.html:56).
2. When landing resumes, any party lands the backlog in height order and is paid up to 4,561 TAIKO per term from each holder's reserve. Every term older than LAND_WINDOW is at the maximum ramp. The holder has no priority over its own backlog terms.
3. During the outage, PIN_REWARD (up to 400 TAIKO) can also be collected by anyone through recordAssignment with no proof at all.
4. Lapse points:
   - An 8-seat owner lapses at its 16th maximum-exposure debit (73,600 − 16 × 4,561 = 624). That is about 144 backlog terms, about 2.4 h at the launch registry; 5.4 h for one-landing terms of about 1,961 TAIKO.
   - A single seat lapses at its 2nd or 3rd debit.
5. A lapse is DELAY_REG-dated and lasts at least SUSPEND(3) = 36 h, even after an immediate top-up (landing.html:70).
6. The client tops up only on ReserveLow, which fires one term above the lapse line. In catch-up, several landings can sit in one L1 block, so the "term or more" headroom of landing.html:70 is false.
7. Sizing the top-up to the horizon needs about 30.4k TAIKO per outage hour per 8-seat owner. A 27 to 34 h backlog needs 0.82 to 1.03 M TAIKO, against a registration bond of 241,600.

The verifier's walk Monte Carlo at the launch registry gives:

| 8-seat owners suspended | Terms with all five holder views void | Mean m | No-committee terms |
|---|---|---|---|
| 8 of 8 | 44.4 % | 3.85 | 99.84 % |
| 6 of 8 | 4.7 % | 10.9 | 10 % |
| 4 of 8 | 0 % | 17.9 | 0 % |

**Design gap.**
- sequencing.html:99, "so a chain-wide proving outage never suspends the honest set", is false. It contradicts slashing.html:221: "ineligible ... unless it tops up (the client does so automatically)".
- The reserve is sized against one LAND_WINDOW_MAX (landing.html:69), while the design tolerates outages up to the horizon.
- The ReserveLow mechanism is not sized for catch-up.
- Not a duplicate: R4-C4 and R5S-4 fixed the margin and the self-landing drain. The round-5 refutations relied on the holder landing its own terms at minimum ramp, which is impossible while no proof system works.

The result is degraded service, so Medium. After a rare multi-hour outage, certification collapses chain-wide for 36 h or more, and honest owners lose that revenue. There is no theft and no halt: landings continue with two ZK systems, and owners recover without admin action through top-up plus reactivate().

**Required revision.**
1. **Cap the per-term debit as backlog age grows.** For example, the ramp stops rising, or falls, beyond LAND_WINDOW_MAX. Alternatively, cap the total reward debit per owner per hour of backlog. Re-derive the "paid in full up to break-even" claim for old backlog.
2. **Shorten the lapse.** Either end a reserve lapse at top-up plus reactivate() (DELAY_REG-dated), or keep SUSPEND(3) but exempt debits for terms older than LAND_WINDOW_MAX from the lapse check.
   - Ending the lapse early breaks the "every stored interval ≥ 36 h" premise of the two-interval store (sequencing §7), so a lapse needs its own interval field or the store argument must be redone.
3. **Define a term whose five drawn holder views are all void.** Either treat it as open (view 255) or state that it idles. Today the pages disagree (R6H-5 (e)).
4. **Correct the claims.** Correct sequencing.html:99 and slashing.html:221, and size the client's top-up duty, or state its liquidity requirement on the roles page.

### R6H-3 [Medium] At 2-s L1 slots the per-landing reward does not cover a full term

**Trace.**
1. At 2-s slots an L1 block carries 3 blobs. Sources:
   - l1-dependencies.html:70 (the column is marked assumed).
   - Landing §15, "blobs per block 10/7/3 so landers shrink ranges" (landing.html:222).
   - V9, sized to exactly the 390,132 bytes one L1 block carries at 2-s slots.
2. A landing is one transaction in one block, so it carries at most 390,132 bytes.
3. A term at the V10 cap (1,950,660 bytes, "three landings of six blobs", preconf.html:47) therefore needs at least five landings, and six with framing.
4. Landing k is paid r_land only if k ≤ ⌈bytesLanded_after / 780,264⌉ (landing.html:63). After k landings of 3 blobs, the bound is ⌈k/2⌉ < k for every k ≥ 2, so one r_land is paid for the term.

Break-even for a full term:

| Slot time | Reward | Landings | Break-even |
|---|---|---|---|
| 2 s | 240 + 15 + 1,300 + 400 = 1,955 TAIKO, about 0.293 ETH | 5 (7.5 to 10 M gas) | about 29 to 39 gwei |
| 12 s | full term reward | 3 | about 114 to 152 gwei |

More generous readings of the rule still fail at 2 s:
- A lander that offsets its boundaries gets two r_land: about 49 to 65 gwei.
- If k counted only paid landings (as the field name landingsPaid suggests): about 68 to 91 gwei.

Mid-size terms are hit too. A 6-blob term gets about 73 gwei at 2 s against 146 at 12 s.

**Design gap.** "≈ 100 gwei per landing whatever the term's size" (landing.html:63; index.html:50; the TH13 defence; the parameters R_BLK row) is false at 2-s slots. R5 requires the design to work at 2-s slots, and the design claims "behaviour at 12/6/4/2-s slots is stated per page". Landing §15 states that landers shrink ranges but not what that does to r_land.

This is a 2-s regression of the R4H-7 fix. The precedent is R3H-3, a 2-s-only landing defect graded Medium.

**Required revision.**
1. Make the landing capacity a slot-time protocol parameter: LANDING_BYTES = min(6, max blobs per L1 block) × 130,044, published in protocolParams. Pay r_land to landing k only if k ≤ ⌈bytes / LANDING_BYTES⌉.
2. Recompute V10's rationale, the per-term exposure, LAND_RESERVE and the break-even per slot time.
   - Five r_land payments make the exposure about 7,161 TAIKO and two terms about 14,322. That breaks the stated bound LAND_RESERVE ≤ B_SEAT/2 = 10,000 (parameters.html:30).
   - So either cap V10 per slot time (fewer bytes per term at 2 s), or re-derive B_SEAT and the reserve, and publish the 2-s break-even beside the 12-s one.

### R6H-4 [DOWNGRADED to Low] The attester state machine omits the silent-leader edges

**Trace (summarized).** The only exit from IDLE(t) is "first valid block of (t,v)" (preconf.html:148). TIMING_OUT, where TIMEOUT and TERM_END are signed, is reachable only from ATTESTING. FALLBACK has no edge in the machine, and no page states when a view's TIMEOUT window starts, except for redrawn members (preconf.html:88). Read literally, a leader that publishes nothing is never timed out and its term never closes.

**Why Low.**
- Index §4 makes the certificate page normative for the timeout trigger (index.html:82).
- The trigger sentence, labelled "this page is normative for the trigger" (preconf.html:26), is an iff with no first-block precondition. Its cases (b) and (c) name exactly this leader.
- §5 makes TERM_END unconditional at termEnd + END_GRACE and lets a later committee close any unclosed term by FALLBACK.
- Every timing statement assumes the timer runs from the view's start: "Each view costs TIMEOUT + 0.5 s" (preconf.html:199), "Each view times out after 5 s" (roles.html:44), and the worked examples (sequencing.html:113, slashing.html:116).

A client that follows the binding rule times the silent primary out at 5 s and bleeds it. What remains is an incomplete machine and an unstated timer origin. Both matter in two ways:
- An implementer reading the machine builds a stall.
- An attester with no stated origin could sign TIMEOUT the moment it learns of an empty view.

This is the R5S-3 class (Low, editorial). Not a duplicate: the IDLE edge is unchanged since phase 3, and R5H-1 concerned restart-on-header.

**Required revision.**
1. State that the TIMEOUT window of (t, v) starts when the attester first holds the view's opening object (the closing VC of the previous view; termStart for view 0 once the closing VC of t−1 is held) and restarts on each new certificate.
2. Add these edges to the attester machine:
   - IDLE(t) → TIMING_OUT for TIMEOUT (v < V_MAX).
   - IDLE(t) → TIMING_OUT for TERM_END (now ≥ termEnd + END_GRACE).
   - A FALLBACK edge with its L1-time gate.
   - The redrawn-committee window start.

### R6S-4 and R6H-5 [Low] Documentation contradictions after the round-5 fix passes

Items are merged; the attacker's labels are in brackets. All are checked against the current text. Under the precedence rule (index.html:82) none changes the protocol.

1. **[R6S-4.1, R6H-5 a] Exit rule.**
   - slashing.html:160 gives activeUntil = max(τ + DELAY_REG, activeFrom + MIN_TENURE) with no acceptance gate.
   - Every normative statement accepts the exit only once τ + DELAY_REG ≥ activeFrom + MIN_TENURE and then sets τ + DELAY_REG: sequencing.html:47, parameters.html:19, interfaces.html:80, roles.html:39, the glossary.
   - Built from the slashing page, an early exit writes a version tagged activeFrom + MIN_TENURE ahead of later versions, and the version log becomes unsorted. That breaks I1 (the halt attacker's example: five days of inbox/node E_t disagreement).
   - This is a regression of the second fix pass (9a208ed changed only sequencing), not R5-C4.
2. **[R6S-4.2, R6H-5 b] Registration gas.**
   - sequencing.html:200 says "≈ 2 × 97,920 state + ~60k exec"; roles.html:38 says "about two fresh storage slots per first seat"; sequencing.html:237 says "fresh slots only at registration", although exits write versions too.
   - Against those: about 16 fresh nodes, ≈ 1.6 M state gas per seat (sequencing.html:66; parameters.html:20; interfaces.html:76). That is about 7 to 8× per seat, and 13 to 15 M for an 8-seat call.
   - Calls take any count, so callers split them. State gas falls outside the EIP-7825 cap under EIP-8037, so "near the cap" is overstated.
3. **[R6S-4.3] FI_ANCHOR_LAG.** forced-inclusion.html:179 still says "a block count (4 min to 40 s)". The value is 288 s on the same page (§8, §11) and in parameters.html:92. It is a residual of the round-5 B3 fix.
4. **[R6S-4.4] Committee-root key hashes are undated.**
   - committeeRoot[t] is keccak of the 32 attester key hashes (sequencing.html:103).
   - Operator holds a single attKeyHash (interfaces.html:32), and rotateKey is effective τ + DELAY_REG (interfaces.html:75).
   - keyOwnerAt maps key to owner per term, but nothing maps owner to key per term. A pin made after a rotation took effect (up to 34 h later) has no stated key.
   - The harm requires an implementation that reads the current key.
5. **[R6H-5 c] V5-failing leader.** bridge-migration.html:193 says "no attester times it out; it earns nothing and pays nothing". The normative trigger times it out at 5 s and bleeds it (preconf.html:26 case (c)), and the FI_ANCHOR_LAG row agrees. This row survives from the first R5H-1 wording.
6. **[R6H-5 d] Arithmetic.** sequencing.html:187 gives 123,720. With ROLE_HORIZON = 122,880 plus DELAY_S = 1,320 the sum is 124,200. 129,600 still exceeds it, so nothing changes.
7. **[R6H-5 e] Open-empty definition.**
   - sequencing.html:66 says "P(no holder) = 0 whenever E_t ≥ 1"; the §7 figure says "|H| = 0 → OPEN-EMPTY"; sequencing.html:194 says "sortition is over eligible ranks". All three predate R5S-2.
   - §6 (sequencing.html:75; glossary) says "open-empty if the walk finds no eligible seat", with eligible = inDomain ∧ ¬suspended (sequencing.html:48).
   - Both readings sit on the owning page, so precedence cannot settle it. This interacts with R6H-2.
8. **[Judge's note from the halt report's could-not-break item 3, not a finding] Walk gas.** The halt attacker's persistent-tree simulation gives about 5.4 M at 4,096 seats and 10.1 M at 65,535, against the design's 4 M and 9 M. That is 11 to 26 % higher, still inside the 16.8 M cap. The figures are marked assumed; record the discrepancy in the measurement list.

**Required revision.**
- Delete the max() form on the slashing page.
- State one registration and exit gas figure per seat, and correct roles §1 and sequencing §11 and §15.
- Replace forced-inclusion §15's block-count phrase with 288 s.
- Specify a per-owner attester-key history (validFrom, validUntil per key) and state in sequencing §8 and interfaces §1 that the walk reads the key valid at termStart(t).
- Replace the bridge-migration §15 row with the normative outcome (timed out at 5 s, MISS, outside §1(d)).
- Correct 123,720 to 124,200.
- Give one open-empty definition (see R6H-2 item 3).
- Run a grep pass for each corrected phrase over all fifteen pages.

### R6-C1 [DOWNGRADED to Low] Suspended seats in the rank domain make committee size reducible

**Trace (summarized).** Parked owners are driven into an open-ended suspension, either by the hard floor through a never-reactivated bleed or by the L20 reserve drain. Their seats stay in the domain, and every committee slot drawn on them is empty: "m shrinks by one, Q(m) scales, and no re-draw shifts the later slots" (sequencing.html:103).

I re-ran the simulation:

| Registry | Mean m | No-committee terms | Mean 2Q−m |
|---|---|---|---|
| Launch, 144 parked | 10.4 | 11.6 % | 5.0 |
| Launch, 216 parked | 7.8 | 45.5 % | — |
| 400 seats + 1,200 parked | 8.0 | 43.1 % | — |

Only class A has a permissionless exit (exitSlashed, sequencing.html:67; interfaces.html:81). The hard floor and reserve lapses are open-ended until the owner reactivates.

**Why Low.**
- Every headline number needs the attacker to own 67 to 75 % of the domain seats: 4.35 M TAIKO at launch, about 36 M at 400 honest seats. That is twice the T11 bound.
- Inside T11 (up to one third parked):
  - P(m < 8) ≈ 3·10⁻⁷ and the mean bound is about 8.4.
  - Parked seats sit in no committee, so a split budget lowers the cartel's chance of reaching Q: 4.4·10⁻⁵ at s = 0, 2.2·10⁻⁶ at s = 0.1.
- The bound is published per m, and nodes publish m (preconf.html:21).
- No-committee terms still land with two ZK systems.

The honest analogue is R6H-2: an outage-driven lapse of the big owners empties committees without any attacker. That is why the R6H-2 revision matters more than a backfill.

**Required revision.**
- State the committee size, the "12 at a full committee" figure and the 13 × B figure as conditional on the suspended share of the domain, and extend L16 to cover it.
- Give open-ended suspensions a permissionless exit dated DELAY_REG later, like exitSlashed, for example after the owner has been suspended for longer than a stated period. An exit is a DELAY_REG-dated domain write, so this does not reopen the R5S-2 lever.
- A backfill of empty slots would let a self-suspension change a committee after the seed is fixed. It needs its own grinding analysis before adoption.

### R6-C2 [Low] The blank-term revenue table counts certified terms, not seconds

**Trace (summarized).**
1. A cartel with a blocking minority of committee(t) also withholds its TERM_END lock votes. The next leader cannot start without a closing VC (V2; sequencer machine "WAIT --VC opening (t,v) held--> PRODUCING").
2. Committee(t+1) may FALLBACK only from +12 s, and +10 s for each further dark committee (preconf.html:87).
3. Withholding costs the cartel nothing: attester rewards go to the end certificate's signers.

I re-ran the simulation:

| Registry | Share by term count | Share by seconds |
|---|---|---|
| 8x8/32x1 | 44.0 % | 50.8 % |
| 6x8/24x1 | 48.9 % | 56.9 % |

The verifier's two corrections stand:
- The +7 points need the cartel to withhold TERM_END also after certified terms preceding an honest term. If delay follows only blanked terms, the gain is +2.4 to +3.5 points.
- The gain is real only if revenue from delayed seconds is lost. If queued transactions carry over, the term-count share is exact and the cost is user latency.

TH3's "replacement within TIMEOUT" concerns an absent holder and is not broken. The +12 s ladder is published (arguments.html:45, :73).

**Required revision.**
- State the revenue model of the slashing §5 table (term count, fees carry over), or add a column weighted by seconds.
- Add to preconf §1, L2 and the T11 row of the arguments page that a blocking minority also delays every handoff out of a committee it blocks by 12 to 22 s.

## 4. REFUTED findings

- **R6S-1 (claimed High).** Refuting rule: landing is sequential (L1 `firstHeight == lastLanded.height + 1`), and any lander may land a range spanning up to four views (landing L4). A third party therefore lands A's unfunded term together with the next holder's funded term, paid by that term's ramp from its own reserve (landing §5). That locks A's term below lastLanded, where no forced batch can reach it (A1 and the forced batch act only above lastLanded), well before replaceableFrom = termEnd(t') + 2,100 s. announceLanding gives that backlog bonded priority (landing A1). The residual is the published L6 and L14 caveat ("locked" holds only while landing keeps up within LAND_WINDOW; "replaceable" from replaceableFrom) plus L20.
  - Sub-claim refuted: "L6's 'unprofitable to the forcer' is false". L6's clause concerns protocol-internal payouts. An external double-spend against a counterparty crediting below the landed level during a visible stall is the general non-final-confirmation caveat.
  - Fix (a) is kept as an option under R6S-2.
- **R6H-1 sub-claim** ("a REPLACE chain anchored 4 h after the last tip lands one anchor-only FI(E1) per cycle; locked blocks voided each cycle"). Refuting rule: F3 (an FI block inherits its parent's anchor), V8, and L8's floor c ≥ min(D, ⌈2n/3⌉). With two or more unprovable entries due, no landable range exists, so nothing cycles. The finding was strengthened, not weakened.
- **R6H-2 sub-claim** (34-h horizon at every slot time). The horizon is 27 h at 12-s slots and 4.55 h at 2-s slots (EIP-2935 window, landing.html:96). The cliff needs at least about 6 of the 8 big owners not to top up.
- **R6-C2 sub-claim** (TH3 broken). "Replacement within TIMEOUT per dark view" (sequencing.html:205) concerns an absent holder. The FALLBACK latency for a silent committee is already published (arguments.html:45; preconf.html:201).
- **R6S-2 arithmetic.** The per-term drain is about 194 to 201 TAIKO at +150 s for one 6-blob landing and about 427 for 15 blobs, not 250. The drain therefore takes 24 to 52 h, not 35 h. The 69,038-TAIKO total is right. R1 is not affected, since a lower effective entry capital excludes nobody.
- **R6H-4 literal trace** (stall until dead mode). Refuted by the normative trigger (preconf.html:26) and the unconditional TERM_END and FALLBACK of preconf §5; see section 3.
- **R6-C1 headline** (locked bound "falsified"). The bound is stated per m, and m is published. The parked majority exceeds T11.

## 5. Requirement verdicts (CONFIRMED and DOWNGRADED findings only)

| Req. | Verdict | Reason |
|---|---|---|
| R1 fully permissionless | **fail** | R6H-1: given a guest-completeness bug, the design accepts as live (forced-inclusion §8), two pre-posted calldata entries halt ordinary, replacement, forced and dead-mode landing until the DAO ships a guest fix. "The chain stays live if the DAO never acts again" fails outside the one compound case L19 accepts, and forced-inclusion.html:164 "DAO. Never needed" is false. R6H-2: an ordinary multi-hour outage suspends the honest set for at least 36 h unless each owner holds about 30k TAIKO of spare liquidity per outage hour. Recovery needs no admin, but the published operating condition is false. No admission gate was introduced, and the DAO is on no other liveness path. |
| R2 reuse SignalService, Bridge, Vaults | pass | No finding touches the shared contracts, their storage, their addresses or the two `saveCheckpoint` calls. R6H-1 stops checkpoints being written; it changes no shared contract. |
| R3 richer roles | pass | Every role keeps entry, exit, duties, rewards, slashing and all-offline / all-malicious analysis. R6H-2 falsifies one failure-analysis sentence (sequencing.html:99) and leaves the top-up duty unsized. R6H-4 leaves the attester machine incomplete (Low). Those are R1/R7 economics and documentation defects, not missing role definitions (the round-5 convention). |
| R4 1-second blocks | pass | R6H-4 is downgraded: the binding trigger times out a silent leader at 5 s. R6-C2's 12 to 22 s handoff after a blocked committee is the published FALLBACK ladder. Certification and locking latency are untouched. |
| R5 no lookahead, no slot or epoch coupling | **fail (narrow)** | R6H-3: the per-landing reward hard-codes 6 blobs per landing, so at the 2-s slot regime the design lists as supported, third-party landing of a full term breaks even at about 30 to 40 gwei, not "≈ 100 gwei whatever the term size". R6S-4 item 3 keeps a block-count phrase for FI_ANCHOR_LAG (Low). No parameter is slot- or epoch-denominated and no lookahead is read. This is the same narrow failure class as R3H-3 (03-judge.md:120). |
| R6 objective slashing, anti-monopoly | **fail** | R6S-3: the R5S-5 mitigation narrative (committee(t)'s TERM_END VC supersedes a FALLBACK; residual only a same-block race that shrinks with slot time) is false when a blocking minority of committee(t) withholds TERM_END. The published P2, L5(b), §14 and slashing §4 statements must be restated, and a rule added. R6-C1 (Low): the "12 at a full committee" and 39-ETH figures are unconditional in the text but depend on the suspended share. R6-C2 (Low): the anti-monopoly revenue table's model is unstated and understates the one-third gain under a seconds-weighted model. Objectivity survives: no accusation object exists, and no honest signer is slashable under the normative pages. |
| R7 propose-with-proof, minute-level, DA explicit | **fail** | R6H-1: the forced-inclusion service and its 112-minute bound fail behind a pre-posted stream (P5). R6S-2: the "non-withdrawable" reserve and its 16-term sizing hold only for owners that do not drain to the per-owner line. R6H-2: the reserve and ReserveLow are sized for one window while outages up to the horizon are tolerated. R6H-3: the break-even claim fails at 2-s slots. The one-action land-with-proof primitive, the journal bindings and explicit blob DA are intact; no finding touches P1. |

## 6. Round verdict: REVISE

There is no Critical finding and one new High, R6H-1. Its fix lies inside R1 to R7:
- A landing that meets the four-hour gap voids the whole due prefix, up to 64 entries.
- Queue depth is priced at save time, not only after skips.

R6H-1 sits at the High/Critical boundary: without DAO action the halt is permanent. It is held at High for consistency with R1-F4 and R3H-1, and because a guest fix (a DAO upgrade) ends it. Even at Critical it would not make the verdict NEGATIVE, because the fix is within the requirements.

There are four Mediums: R6S-2, R6S-3, R6H-2 and R6H-3. Each has a stated revision; R6S-2 and R6H-2 should be revised together as one re-derivation of the reserve. The five Lows are documentation or analysis corrections.

**Convergence.** Round 6 ran all three goals to completion, so it counts as a full round. It produced a new High, so the two-clean-rounds counter restarts. The round cap is 8, so readiness now requires rounds 7 and 8 both to be clean.

The trend is favourable:
- Round 5 had three Highs, all safety. Round 6 has one High, conditional on a guest bug, in a mechanism that dates from round 1.
- No round-5 fix was broken outright. R6S-3 bypasses the R5S-5 fix's premise rather than its rules.
- The steal goal's only High was refuted.

The revision pass should do three things:
1. **Make each fix hold against the adversary's schedule, not only the reported case.** Check every protection added in rounds 1 to 5 against an adversary who acts before the protection's trigger: pricing paid before skips, a gate whose premise needs an honest quorum, a guarantee checked at register but not at the draw, a constant sized at 12-s slots.
2. **Re-derive the reserve once.** Cover R6S-2, R6H-2 and R6H-3 together: per-seat line, horizon-length outages, slot-time landing capacity, and the B_SEAT/2 bound.
3. **Run a grep pass** over all fifteen pages for every phrase the round-5 fix passes changed. The R6S-4 and R6H-5 items all come from pages that defer to an owning page.

## 7. What the attackers could not break (consolidated)

Merged from the three reports (steal 12, halt 15, censor 9 items), deduplicated and grouped. Each holds against the design as written.

State safety and proofs (P1):
1. A false root or a redirected reward through the landing or the forced batch. rewardTo is bound into every journal, and the forced journal is domain-separated. Blob hashes come from `blobhash`, the parent root from storage, and the anchor tip is checked against blockhash or EIP-2935. A forced batch can void but never finalize a false root or redirect fees (steal 11).

Sortition, registry and randomness (I1):
2. **Version-log ordering.** Every domain write (register, requestExit, exitSlashed) is tagged τ + DELAY_REG, and the tenure gate keeps effective times monotone. Lapses, suspensions and reactivation are flags, not tree writes. Only the stale slashing-page formula breaks it (R6S-4/R6H-5 (a)) (steal 1, halt 1).
3. **Seat recycling against old versions.** RECYCLE_GRACE = 129,600 s ≥ ROLE_HORIZON + DELAY_S = 124,200 s, so no landable term reads a version containing a recycled seat (steal 2, halt 2).
4. **Walk gas against the EIP-7825 cap.** About 1 M at 128 seats and 9 to 10 M at 65,535 (the halt attacker measured 11 to 26 % above the design's figures). This is inside the cap, independent of later writes, and large-registry pins go through a separate recordAssignment (steal 3, halt 3).
5. **Post-seed grinding by self-suspension (re-run of R5S-2).** A suspension changes no rank and no E_t; entry and exit are DELAY_REG-dated against a 3,660-s freshness window. What remains is the committee-size effect of R6-C1, not grinding (censor 2, steal 8).
6. **Pinning a committee of one's choosing, including after a redraw.** The root is the inbox's own walk, justified by ⌊m/2⌋ + 1 REDRAW signatures (censor 5).
7. **Excluding or delaying an entrant.** Indices are contract-assigned, there is no per-slot cap, and every write is effective at τ + DELAY_REG; filling the array costs more than the supply (censor 6).
8. **Front-running registerKeys with a victim's sequencer address.** Bounded griefing: the victim re-registers a fresh key privately (halt 15). Judge's note: the sequencer key has no proof of control; consider requiring one.

Certificates, timeouts and redraws (P2 outside R6S-3, I3):
9. **Reviving a private or late block through a redrawn committee (re-run of B4).** The staleness bound is measured at each honest node's own receipt, so private certification still needs Q colluders (L3). A lying receivedAt chooses only what the liar itself attests (steal 5, censor 7).
10. **Keeping a view with a partially attested block, or squatting without producing (re-run of R5H-1).** Both reduce to the stated §1(d) residual. A cartel of 17 delays a dead leader's takeover by at most REDRAW_MAX × TIMEOUT = 10 s (steal 6, halt 5, censor 8).
11. **Reverting a locked block with a TIMEOUT VC at a landed lock, or slashing an honest signer through S3b, RESET, RESUME or REPLACE (re-run of R5S-1).** An honest lock vote is at least the carried certificate verified at V3, votes are monotone, and after a reset only RESUME, which S3b never reads, is signable. A REPLACE or RESUME record is accepted only at lastLanded after replaceableFrom (steal 7, halt 6, censor 1).
12. **A FALLBACK VC voiding an honest term while committee(t) forms its VC (re-run of R5S-5).** Gated by L1 time, first record, a certificate at its lock and supersession; the residual is the same-block race of L5 (censor 3, halt 7). Judge's note from halt 7: "at most one term above the FALLBACK lock" understates the orphaned span, which is every descendant until consumption (minutes). Restate it with R6S-3's revision.
13. **Binomial and collusion tables.** Preconf §14 and the 1.7·10⁻⁴ / 4.1·10⁻² / 0.36 offline figures reproduce (halt 14), and the round-5 constants (4,561; 9,200 / 9,122; walk-gas ladder; DEAD_TERMS against 65 min; ReserveLow hysteresis) are consistent across pages (censor 9).

Reserve, rewards and pins (I2 outside R6S-2 and R6H-2):
14. **Lapsing an honest owner through third-party landings or attester shares in normal operation.** The holder self-lands at +150 s, attester credits refill reserves first, and the hysteresis fires once per crossing (steal 9).
15. **PIN_REWARD extraction or a pin-driven drain of a victim.** The ramp is about 0 at term end, the holder's own pin is unpaid, and the total is 400 TAIKO per unlanded term (steal 4, halt 4). The outage case is part of R6H-2.
16. **Void-seat dilution through a free lapse at or below one third of seats.** P(all five holders void) = q⁵, 0.4 % at q = 1/3 (halt 9). Above one third this is L2 and T11.

Forced inclusion and landing races (P4, P5 outside R6H-1):
17. **Stretching the 112-minute bound with landing announcements, REPLACE records or first-segment term games (re-run of R5-C3).** One shared deferral per lastLanded, and L8's T_floor forces the next landing to consume. The arithmetic 300 + 1,800 + 120 + 3,600 + 300 + 600 = 6,720 s is right (steal 10, halt 13, censor 4).
18. **FI_ANCHOR_LAG = 288 s at 2-s slots.** It is above ANCHOR_MIN_AGE and above honest anchor lag (halt 10). The stale §15 phrase is R6S-4 item 3.
19. **A forced-batch stream keeping the replace window open.** It needs an independent stall first and costs about 77 ETH per hour of state gas (halt 8).
20. **Dead mode against the deferred replace window.** Dead mode opens 60 s before the deferred replaceableFrom, which is harmless because dead-mode landings obey A1 (halt 11). Restate sequencing's "75 min > 65 min" to count the deferral.
21. **Tiny-prefix landing races.** Each such landing advances the chain and pays its lander (halt 12).
22. **Challenger loops, announcement-bond farming, FI fee farming.** The challenger share is capped and duplicates are keyed. A forfeited announcement pays 800 TAIKO against 1.2 M gas and a stall the forcer cannot create. FI fees go to the sequencer, and bonds burn on skip (steal 12).
