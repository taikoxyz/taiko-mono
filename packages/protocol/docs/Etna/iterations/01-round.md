# Round 1

Date: 2026-09-30. Design under test: the design site as committed at the start of Phase 4 (commit after "Etna phase 3, the design site").

## Models

| Role | Requested | Self-reported | Report | Findings |
|---|---|---|---|---|
| attacker: steal funds | opus | claude-opus-5-5 | [01-attack-steal.md](01-attack-steal.md) (truncated before its first trace) | none delivered |
| attacker: halt liveness | sonnet | claude-sonnet-5-5 | [01-attack-halt.md](01-attack-halt.md) | F1 to F10 |
| attacker: censor and monopolize | haiku | claude-haiku-4-5-20251001 | [01-attack-censor.md](01-attack-censor.md) | none claimed; five could-not-break attempts (one with wrong probabilities) |
| verifier (one per finding) | fable (session model) | claude-fable-5-1 | verdicts embedded in the judge report | 9 confirmed, 1 refuted |
| judge | fable (session model) | claude-fable-5-1 | [01-judge.md](01-judge.md) | verdict REVISE |

Three distinct models attacked, as assumption A8 requires, but only one produced findings: the steal report was cut off (the agent's output ended mid-sentence) and the censor report found nothing. Round 2 re-runs both goals with a fresh instruction to write each finding to the report as it is found.

## Verdict: REVISE

New Critical 0, new High 3, new Medium 5, new Low 1. Requirement verdicts before revision: R1 fail (F1, F3, F4), R2 pass, R3 pass, R4 fail (F1, F9), R5 pass, R6 fail (F3, F5, F8), R7 fail (F4, F6, F7).

## Findings and the revisions made

| Id | Sev. | Finding (one line) | Revision applied to the design |
|---|---|---|---|
| F1 | High | Quorum was a constant 22 while a committee can be smaller than 22; the "widening rule" the sequencing page cited did not exist; no-committee mode only below 4 seats. | Quorum is now a function of the actual committee size, Q(m) = ⌊2m/3⌋ + 1; no-committee mode applies below K_MIN_CERT = 8; the collusion bound 2Q(m) − m is published per term; the committee walk has a try bound (512) and returns however many seats it finds; the dangling sentence was replaced by the fallback rule; the migration checklist claim was corrected. |
| F3 | High | Timeouts fed a strike ladder that suspends owners; 11 abstaining committee seats (or a stakeless network flood at a public term start) could remove honest operators from eligibility and cascade. | Timeouts never change eligibility: no strike, no floor check; the only consequence is the 50-TAIKO burned bleed, and the 50 % hard floor is the only eligibility consequence of repeated absence. Strikes and suspension now come only from structural offences (class B), which need the offender's own signed lie. Anti-monopoly text recomputed with the bleed as the lever; limitations L2 rewritten. |
| F4 | High | A decodable forced-inclusion entry that no ZK guest can prove had to be consumed by every landing path, and calldata entries never expired, so landing could halt until a DAO guest upgrade. | FI_SKIP: a due head entry of either kind unconsumed for four hours of anchored time is voided (anchor-only block, fee to the includer); it can only fire when nothing has landed for four hours. FI blocks additionally run under a per-block zk-gas budget the guest checks. Declared as a clock rule on the arguments and limitations pages. |
| F5 | Medium | The availability escalation (S7) could slash 23 honest seats when certified data was available but unprovable. | A data post of the range's canonical blobs (recorded by the inbox by blob hash) now answers a demand; S7 protects availability only. A REPLACE view may carry a Q-signed quarantine list of transactions not to re-include. |
| F6 | Medium | The maximum lander reward (4 TAIKO per block) did not cover a landing above about 20 gwei; the "100-gwei hour" rationale was wrong by a factor of five. | R_BLK_MAX raised to 24 TAIKO per block (1,440 per term ≈ 0.22 ETH); a landing may now cover up to four consecutive views (segments) to amortize gas; the break-even fee (≈ 100 gwei per term landed, 400 with four) is published; per-term exposure recomputed (3,470 TAIKO ≤ B_SEAT/2). |
| F7 | Medium | "Nothing voids by clock" was tagged proven while a 2-hour role horizon and the EIP-2935 window did void certified ranges. | Roles are now resolvable for 34 hours (the committee ring) and every landing pins the terms it settles; the claim is restated as "within the landing horizon" (34 h or the EIP-2935 window if shorter) everywhere; the horizon is limitation L14; the level table's locked promise is scoped to it. |
| F8 | Medium | Equivocation keys omitted the opening object, so the design's own replacement procedure made an honest holder and attesters slashable. | Every equivocation key (S1, S3a, S3c, fork choice, gossip dedup, slashing-protection records) includes the view's opening-object hash; a REPLACE or RESUME reopens the same view number with a new opening object. |
| F9 | Medium | Only the next committee could sign a fallback view change, so two consecutive dark committees wedged the term chain until dead mode. | Any later committee within the landing horizon may sign a FALLBACK for an open term, with priority by proximity (10 s per further committee); the landing verifies the VC against the signer term's committee. |
| F10 | Low | Constant drift across pages (rings, header cap, walk gas, slot counts, mode enum). | Numbers aligned to the parameters page: term records 21,600 aliased, committee ring 2,048, header cap 4,096, FI walk ≤ 270k, rights ≤ 290k worst case, 23 appended slots and a 20-slot gap, four holder modes. |
| F2 | refuted | A single seat at a high index could dilute the registry. | Refuted (the array is append-only), but the registration wording now says a named index is either the scheduled length or a recycled hole. |

## What the attackers could not break

Handoff ambush and withholding W1 to W5; seed grinding and entry/exit timing; Sybil monopolization by registration; censoring a registration; making a landing revert through the forced-inclusion queue; forging a checkpoint through a false anchor; opening dead mode on a live chain; burning the shared nonce with Frame Transactions; ePBS Empty slots and 2-second slots; DAO inaction on any liveness path; key theft and rogue-key framing; double-signing griefing; the steal-goal surface as re-read by the judge (no rule pays without a landed proof and a valid certificate).

## Carried to round 2

- Re-run the steal and censor goals with working, incremental report writing.
- The verifier must check F1 and F3 together on the revised pages (committee size and eligibility interact).
- Open questions raised by the revisions: whether the absence bleed should pause for demonstrably online owners; whether no-committee mode should extend up to 16 seats so small registries never advertise a weak "locked" level; whether the landing horizon of 34 hours is the right trade.
