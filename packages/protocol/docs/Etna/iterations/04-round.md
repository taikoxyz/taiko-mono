# Round 4

Date: 2026-09-30. Design under test: the design site as committed after the round-3 revisions (commit "Etna red-team round 3 and the revisions it forced").

## Models

| Role | Requested | Self-reported | Report | Findings |
|---|---|---|---|---|
| attacker: steal funds | opus | claude-opus-5-5 | [04-attack-steal.md](04-attack-steal.md) (interrupted before any finding; five partial could-not-break items) | none |
| attacker: halt liveness | fable | claude-fable-5-1 | [04-attack-halt.md](04-attack-halt.md) (complete; ten could-not-break items) | R4H-1 to R4H-8 |
| attacker: censor and monopolize | sonnet | claude-sonnet-5-5 | [04-attack-censor.md](04-attack-censor.md) (complete; ten could-not-break items) | R4-C1 to R4-C6 |
| verifier (one per finding) | fable (session model) | claude-fable-5-1 | verdicts embedded in the judge report | 13 confirmed, 1 refuted |
| judge | fable (session model) | claude-fable-5-1 | [04-judge.md](04-judge.md) | verdict REVISE |

Only two attack goals ran to completion: the opus steal session was cut off before its first finding, as in round 1. Round 4 therefore does not count toward the two-clean-rounds criterion, and round 5 re-runs the steal goal on a model that has completed it before.

## Verdict: REVISE

Unique new defects: Critical 0, High 6 (R4H-1, R4H-3, R4H-4, R4H-5, R4-C1, R4-C2), Medium 4, Low 3, refuted 1 (R4H-2). Requirement verdicts before revision: R1 fail, R2 pass, R3 pass, R4 fail, R5 pass, R6 fail, R7 fail.

**The pattern repeated for the fourth time.** Every High lives inside a mechanism round 3 introduced (eligible list, landing reserve, leader-silence timeout, recorded-REPLACE close). The judge's diagnosis: the fixes were written for the reported trace, not for the property that was lost. This revision was therefore done differently: a written spec stated five invariants first, derived each rule from them, fanned the edits out to three editors on disjoint pages, and passed the result through two independent verifiers (invariants, cross-page consistency) and a fixer before anything was rebuilt. The spec and the verifier findings are in the scratchpad (not committed); the verifiers found three blocking issues in the editors' output (a record-keying collision that recreated R4H-5 at the next view boundary, a cross-redraw lock-revert path, and a DELAY_S-dated reactivation), all fixed before this commit.

## Invariants adopted

- I1: sortition is a pure function of state at S(t) for every term inside the landing horizon.
- I2: a drawn term's lander reward exists at landing time whatever the owner does afterwards.
- I3: no minority takes a view from a producing leader; an abstaining minority can only blank a term.
- I4: nothing voids a locked block except a landed replacement after the deadline machinery or 2Q(m) − m slashings.
- I5: no accusation object exists; no rule infers fault from the absence of a landing.

## Findings and the revisions made

| Id | Sev. | Finding (one line) | Revision applied to the design |
|---|---|---|---|
| R4H-1 | High | The eligible list was positional with no history: any mutation effective between a term's start and its landing made the term unlandable. | Sortition is a **rank among the seats eligible at termStart(t)** over the append-only seat array, computed from a Fenwick prefix-count tree over current eligibility corrected by a mutation ring (effective time, seat, ±1) for mutations effective after the term's start; mutations apply lazily in (effectiveTime, seatId) order before any right is computed; MIN_TENURE = 7 days bounds the ring (a seat is eligible, drawn and bled for at least a week). |
| R4H-3 | High | The landing reserve was withdrawable at any time, so a holder could certify a term nobody was paid to land. | The reserve is non-withdrawable while any seat is active or pending and leaves only through exit plus the evidence window; ring-fenced from liveness debits; a lapse is DELAY_REG-dated with a minimum SUSPEND(3) interval; sized at 8,400 TAIKO per seat (two terms of reward exposure, 4,161 per term); the residual (a term drawn before the debits that emptied the reserve) is stated. |
| R4H-4 | High | The "attested nothing in the window" timeout rule was defeated by V3, which silences a live leader after two uncertified blocks. | A timeout is signed only when no header of the view with a valid leader signature above the attester's lock has been received for TIMEOUT seconds; a HOLDing leader keeps gossiping signed headers, so it is never timed out; a minority can only blank the term. |
| R4H-5 | High | A REPLACE VC recorded after the backlog landed closed the live view and voided fresh locked blocks with no landing. | A record has no closing effect; `recordViewChange` accepts REPLACE and RESUME VCs only with lock equal to `lastLanded` and after `replaceableFrom`; the lock reset and RESET state trigger only on a landed replacement or forced batch; A3 returns to landing-based arbitration (whichever lands first wins). |
| R4-C1 | High | Blank terms turned a third of the seats into most of the productive revenue; the linear cost curve was wrong by 2× to 10×. | Anti-monopoly republished from simulation with primary share, blank rate without and with redraws, and productive revenue share per owner structure; the cost curve restated as the price of primary share; a bounded committee **redraw vote** (⌊m/2⌋ + 1 attested-but-uncertified signers, REDRAW_MAX = 2) raises the blanking threshold; T11 stated in one form on three pages; L2 rewritten to say that above one third of the seats the gain is superlinear and undefended. |
| R4-C2 | High | The reserve was an owner-triggered eligibility write on the short delay, enabling seed-known assignment grinding. | Rule: every eligibility input is either DELAY_REG-dated or not owner-triggerable; reserve lapse and hard-floor reactivation are DELAY_REG-dated. |
| R4H-6 | Medium | V10 counted forced-inclusion blocks, so a blob-shaped backlog exhausted the term budget and bled every leader. | V10 counts sequencer blocks only; FI blocks and forced batches are exempt in the guest and at attestation. |
| R4H-7 | Medium | The per-landing reward was paid per landing, so one-block landings drained the reserve. | Landing k of a term is paid r_land only if k ≤ ⌈bytes landed / (6 × 130,044)⌉, tracked in the term record. |
| R4-C3 | Medium | A recorded REPLACE VC voided the whole certified backlog with no proof. | Closed by the R4H-5 revision: only a landed replacement voids; the abandonment rule is removed (below). |
| R4-C4 | Medium | The reserve margin was 39 TAIKO, so one timeout made a minimum-funded entrant ineligible. | Liveness debits never touch the reserve; the 5 % buffer (20 timeouts per seat) and the 50 % hard floor are the only liveness consequences. |
| R4-C5 | Low | The launch condition was a one-time off-chain check that `initEtna` could not enforce. | `initEtna` takes no T0; a second upgrade-class `armEtna(T0)` sets the grid once the DAO has read the eligible count; the condition is stated as an unenforced heuristic and launch may begin in no-committee mode. |
| R4H-8, R4-C6 | Low | Documentation contradictions left by the round-3 pass (REPLACE timeout wording, TimeoutMsg evidence sketch, glossary lock, VC trigger prose, T11 in two forms, 400 gwei, 44 seats). | All corrected; a precedence list on the index page names the normative page for constants, selection rules, message formats, evidence types and landing checks. |
| R4H-2 | refuted | FI_SKIP was claimed to skip the whole queue and charge victims. | Refuted (only the entry at `fiQueue.head` can be skipped, once per landing); the wording now says so. |

## The abandonment rule is removed

The S4a lineage (rounds 2 and 3: outage gate, void waiver, escrow) kept producing false positives because it inferred fault from the absence of a landing. Under invariant I2 a certified view is landable by anyone and paid from the holder's reserve, so a holder cannot abandon a provable view; the only unlandable certified content is a guest-completeness bug, which any abandonment rule punishes wrongly. S4a, SLASH_ABANDON, the outage gate, the void waiver, the escrow and the hard deadline are gone; class C is the absence penalty only; `announceLanding` keeps a 2,000-TAIKO bond forfeited to the eventual forcer or replacer.

## Verification trace of this revision

Editors' grep list (S4a, abandon, escrow, OUTAGE_WINDOW, DEADLINE_HARD, eligible list, swap-and-pop, attested nothing, REPLACE timeout, closes the original tail, 400 gwei, 44 seats, six distinct, 3,470, 6,161, 0.5 / 24, SLASH_ABANDON, reportAbandoned) run over the built pages: zero survivors outside sentences that record the removal. Figures re-derived: per-term reward exposure (4,161), reserve (8,400 per seat; 67,200 for eight seats against about 7 expected terms per hour at the launch registry, P(> 16) < 0.1 %), the buffer (20 timeouts), the anti-monopoly table (seven owner structures, 20,000 terms each, with and without redraws), the cross-redraw revert probabilities, the worked examples.

## Convergence

Round 4 produced six new Highs and exercised only two attack goals, so the counter restarts at round 5, which must run all three goals to completion.
