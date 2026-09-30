# Round 5

Date: 2026-09-30. Design under test: the design site as committed after the round-4 property-first revision (commit "Etna red-team round 4 and the property-first revision it forced").

## Models

| Role | Requested | Self-reported | Report | Findings |
|---|---|---|---|---|
| attacker: steal funds | sonnet | claude-sonnet-5-5 | [05-attack-steal.md](05-attack-steal.md) (complete; eleven could-not-break items) | R5S-1 to R5S-6 |
| attacker: halt liveness | opus | claude-opus-5-5 | [05-attack-halt.md](05-attack-halt.md) (complete; seven could-not-break items) | R5H-1, R5H-2 |
| attacker: censor and monopolize | fable | claude-fable-5-1 | [05-attack-censor.md](05-attack-censor.md) (complete; ten could-not-break items) | R5-C1 to R5-C4 |
| verifier (one per finding) | not recorded by the workflow | not recorded | verdicts embedded in the judge report | 9 confirmed, 3 downgraded, 0 refuted |
| judge | fable (session model at the time) | claude-fable-5-1 | [05-judge.md](05-judge.md) | verdict REVISE |

All three attack goals ran to completion, so round 5 is the first full round since round 3. The steal goal, which produced nothing in rounds 1 and 4, produced three Highs.

## Verdict: REVISE

Unique new defects: Critical 0, High 3 (R5S-1, R5S-2, R5S-5), Medium 3 (R5S-4; R5H-1 and R5-C1, one defect; R5H-2), Low 5 (R5S-3, R5S-6, R5-C2, R5-C3, R5-C4), refuted 0. Requirement verdicts before revision: R1 fail, R2 pass, R3 pass, R4 fail, R5 pass, R6 fail, R7 fail.

The judge's diagnosis: none of the round-4 invariants I1 to I5 was false as a statement, but every High was a rule stated over a broader object than the case it was written for (any landed head instead of reset heads; any later committee with only a signing-time clock gate; "not owner-triggerable" asserted of evidence the offender can submit against itself).

## How the revision was made

1. A written spec (scratchpad, not committed) named, for every decision, the exact objects it covers; three editors applied it on disjoint pages.
2. Two independent verifiers (invariants and cross-page consistency) found 7 blocking and 12 minor issues in the editors' output.
3. The fixer agent failed on an account usage limit before applying anything. The author applied the 19 issues directly, re-derived every dependent figure, and fixed one further defect found while doing so (the redraw staleness waiver below).
4. A second independent verifier, on a different model from the first pass's judge, checked the fix pass; its result is recorded below.

## Findings and the revisions made

| Id | Sev. | Finding (one line) | Revision applied to the design |
|---|---|---|---|
| R5S-1 | High | S3b exempted any lock equal to a landed head, so a Q cartel reverted locked blocks with a TIMEOUT VC at a landed lock and no S3b evidence verified. | The landed-head exemption and the landing-ring storage are deleted. The RESET state already makes every mandatory post-reset message a RESUME, which S3b never applies to; an honest TIMEOUT, TERM_END or FALLBACK lock vote cannot sit below a certificate the same key attested, because its lock is at least the carried certificate it verified at V3 and votes are monotone. The level table's "locked" bound (12 provable slashings within one redraw count) is restored with no caveat. |
| R5S-2 | High | Evidence-driven suspension was DELAY_S-dated and owner-triggerable through self-submitted S6 evidence: a post-seed 22-minute grinding lever. | Suspended seats stay in the rank domain: a suspension never changes E_t or any rank. A suspended seat drawn as a holder is a void view; drawn as a committee slot it is an empty slot (m shrinks, Q scales, no re-draw shifts later slots). E_t and ranks change only through DELAY_REG-dated entry and exit, so no owner write changes a committee after the seed is fixed. |
| R5S-5 | High | A later committee could record a FALLBACK VC for a live term with no L1 time gate and no slashable lock lie, voiding honest locked blocks at zero provable cost. | FALLBACK VCs are accepted by `recordViewChange` and L4 only after `termEnd(t) + END_GRACE + VC_FALLBACK × (signerTerm − t)` and only while no live VC of committee(t) is recorded; a landing that consumes one must present a certificate at its lock; committee(t)'s own VC at a higher lock supersedes a recorded FALLBACK until consumed. The fix pass added the duty that makes the gates effective: the next leader and every signer record committee(t)'s view changes on L1, and a FALLBACK can target any view of the term, including one closed mid-term. The residual (a FALLBACK consumed before the honest view change reached L1) is limitation L5. |
| R5S-4 | Medium | Routine self-landing drained the landing reserve because every reward credit went to the withdrawable balance. | Reward-type credits to an owner with seats refill its reserve first; a self-landing skips the lander's debit and credit. The fix pass corrected the claim that a self-landing moves nothing: the attester share (about 6 TAIKO per full term) is still debited and is offset only in expectation by the owner's own attester income (tagged assumed). `ReserveLow` fires once when the reserve crosses below two terms of exposure and is re-armed only when the reserve is back at its required level; the editors' two versions (1.5 and 2.5 terms) were both wrong, one re-firing on every debit and the other never re-arming for a one-seat owner. |
| R5H-1, R5-C1 | Medium | The round-4 liveness signal (any signed header above the lock) was free: a holder kept its view all term by gossiping bodiless headers, so the squatting bleed and the 5-s bound were gone. | Final rule, after the fix pass: an attester signs TIMEOUT only when no new certificate of the view appeared for 5 s **and it holds no block of the view that it attested and that is still uncertified**. The editors' first version restarted a timer on the arrival of an "attestable next block", which the verifiers broke twice: gossip deduplicates the re-sent headers a held leader relies on (so honest attesters timed it out again, the round-4 defect), and "attestable" omitted V5, V8, V9 and V10 (so a squatter with a forged anchor kept its view). Reading the attester's own attestations removes both: a held leader's blocks were attested and stay uncertified, so it is never timed out; a dead, withholding, invalid or bodiless holder gets nothing attested and is timed out and bled. Residual: a partition, or a block published at the edge of the staleness window so that only part of the committee attests it, keeps a view to term end without MISS; that gains a holder nothing that producing empty certified blocks every 4.9 s (an accepted false negative) does not already give it. |
| R5H-2 | Medium | The committee-walk gas bound omitted the mutation-ring term M. | The correction set is gathered once per pin (O(M + 512 × log MAX_SEATS × log M)). The fix pass lowered MUT_PER_SLOT from 8 to 2 because at 8 the worst case (M = 16,384) cost about 35 M gas, which no transaction can carry; at 2, M ≤ 4,096 and the stalest pin costs about 9.2 M gas, inside the 16.8 M EIP-7825 cap. The pin reward became a ramp from 0 at term end to PIN_MAX = 400 TAIKO over LAND_WINDOW, which pays a 0.6 M-gas pin at 100 gwei; the round-5 value of 5 TAIKO paid a pin only below about 1.25 gwei. Per-term exposure is re-derived to 4,561 TAIKO and LAND_RESERVE to 9,200 per seat. An incumbent can delay an entrant's activeFrom by 60 s per 2 seats it registers ahead of it, and cannot prevent the entry. |
| R5S-3 | Low | RESUME had three incompatible L1-reference definitions. | One definition on the certificate page: the L1 block containing the landing resumed from. |
| R5-C2 | Low | The blank-term table understated the one-third cartel against the concentrated honest set the launch condition produces. | Two rows added from simulation; the fix pass replaced pool sizes that did not follow from the table (the pool after excluding an 8-seat primary is about 84 to 88 seats, not 60). |
| R5-C3 | Low | The forced-inclusion bound was 122 minutes, not 112, because an announcement and a recorded REPLACE record each deferred it. | They share one deferral per range; the bound is 112 minutes everywhere, including the forced-inclusion page's own arithmetic, which the fix pass corrected. |
| R5S-6, R5-C4 | Low | Documentation contradictions (attester reward per landing and per block, strikes per offence, DELAY_S inputs, S3a key, launch padding, requestExit granularity, TimeoutMsg without redraw, Holders.mode). | One owner per statement: ATT_REWARD_PER_BLOCK only; one class-B offence is one strike; the S3a key is (t, v, vcHash, redraw, height); TimeoutMsg carries the redraw count; Holders.mode 0 to 3. |

## Found during the fix pass

- **The redraw could not certify anything.** A redrawn committee convenes at least TIMEOUT after the held blocks' timestamps, and the attestation policy refuses blocks more than STALE_MAX = 3 s old, so no redrawn committee could ever attest them; the blank-rate reductions attributed to redraws were therefore unreachable. REDRAW now names the lowest uncertified block its signers attested; the redrawn committee attests that block with the lower staleness bound waived (its timeliness is vouched for by the ⌊m/2⌋ + 1 signers of the previous draw) and starts its timeout window when the redraw forms; the leader then continues at h + 2 carrying C(h).
- **Naming.** `inDomain(i, T)` is what sortition reads and E_t counts; `eligible(i, T)` is inDomain and not suspended, the check after the draw. "Eligible count" is now "domain count" everywhere.

## Verification trace of this revision

Grep over the built pages for every phrasing and figure the fix pass replaced ("attestable next block", "lock + 1 or lock + 2", "re-gossip", "no signed header", "1.5 terms", "2.5 terms", "PIN_REWARD = 5", "4,166", "8,332", "8,400", "16,384", "MUT_PER_SLOT = 8", "102 min", "eligible count", "moves nothing", "debits nothing", "never drains"): zero survivors outside sentences that record the change. Links and anchors in both sites resolve; tag balance holds. Figures re-derived: per-term exposure 60 × 4 + 15 × 1 + 3 × 1,300 + 60 × 0.1 + 400 = 4,561; LAND_RESERVE 9,200 per seat (two terms, 9,122); eight seats 73,600, about 16 terms; a single seat survives one maximum-ramp third-party landing (9,200 − 4,561 = 4,639); honest drain about 210 TAIKO per third-party-landed term at a 150-s lag; worked example balance 63,000 + 27,600 = 90,600 TAIKO; stalest pin 0.6 M + 4,096 × 2.1k ≈ 9.2 M gas.

Independent verification of the fix pass: a second verifier (opus) was still running when this record was first committed; its findings, and any fixes they force, are recorded in the commit that follows.

## Convergence

Round 5 ran all three goals and produced three new Highs, so the two-clean-rounds counter restarts at round 6. Five rounds have now produced new Highs, each inside or at the edge of the previous round's fixes; the Highs have moved from core mechanisms (round 1) to the exemptions, gates and signer sets those fixes introduced (rounds 4 and 5).
