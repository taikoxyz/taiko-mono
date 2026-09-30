# Round 3

Date: 2026-09-30. Design under test: the design site as committed after the round-2 revisions (commit "Etna red-team round 2 and the revisions it forced").

## Models

| Role | Requested | Self-reported | Report | Findings |
|---|---|---|---|---|
| attacker: steal funds | fable | claude-fable-5-1 | [03-attack-steal.md](03-attack-steal.md) (complete; eleven could-not-break items) | R3-S1 to R3-S7 |
| attacker: halt liveness | sonnet | claude-sonnet-5-5 | [03-attack-halt.md](03-attack-halt.md) (complete; ten could-not-break items) | R3H-1 to R3H-8 |
| attacker: censor and monopolize | opus | claude-opus-5-5 | [03-attack-censor.md](03-attack-censor.md) (complete; eight could-not-break items) | C1 to C5 |
| verifier (one per finding) | fable (session model) | claude-fable-5-1 | verdicts embedded in the judge report | 16 confirmed, 3 downgraded, 1 refuted |
| judge | fable (session model) | claude-fable-5-1 | [03-judge.md](03-judge.md) | verdict REVISE |

Three distinct models attacked, rotated again (round 1 opus/sonnet/haiku, round 2 sonnet/opus/fable, round 3 fable/sonnet/opus). The steal attacker shares a model family with the verifier and judge; the judge re-derived its findings from the page text and refuted one (R3-S3).

## Verdict: REVISE

Unique new defects: Critical 0, High 7 (R3-S1, R3-S2, R3-S4, R3H-1, R3H-2, R3H-5, C1), Medium 7, Low 5, refuted 1. Requirement verdicts before revision: R1 fail, R2 pass, R3 pass, R4 fail, R5 fail narrowly, R6 fail, R7 fail.

The judge's process finding, repeated from round 2: four of the seven Highs were residuals of round-1 and round-2 fixes stated for one branch of a symmetric race, one kind of a message family or one entry of a stream, and one overturned a round-1 refutation. The revision below therefore enumerated the symmetric cases for every rule naming "forced or replacement landing", "REPLACE or RESUME", "the head entry" or "one view", and re-derived the figures on the slashing, sequencing, landing and forced-inclusion pages (a throwaway committee simulation in the scratchpad produced the new collusion table).

## Findings and the revisions made

| Id | Sev. | Finding (one line) | Revision applied to the design |
|---|---|---|---|
| R3-S1 | High | The S3d rule read a REPLACE timeout's L1 reference that was outside the signed bytes, so anyone could attach a false reference to an honest timeout and take one seat per key. | The lock is moved out of the timeout into a separate **lock vote** whose signed preimage includes the L1 reference (number, hash) for REPLACE and RESUME; the reference is also in the ViewChange struct; S3d verifies canonicality by `blockhash` or EIP-2935 and reverts otherwise; attesters accept only references at least ANCHOR_MIN_AGE old. |
| R3-S2 | High | After a forced or replacement landing the mandatory TIMEOUT or TERM_END under the old opening object carried the reset lock, which S3b compared against earlier attestations and slashed the whole committee. | An explicit **RESET** state in the attester machine: under the old object only RESUME timeouts and lock votes are signable (also at term end); S3b ignores any lock equal to a landed head in the inbox's landing ring. |
| R3-S4 | High | A late original landing could void a certified REPLACE fork; the void waiver did not cover that branch, so every honest fork holder was reportable and a waiting lander farmed the escrow. | A **recorded REPLACE VC closes the original tail on L1**: from the record on, the inbox refuses original blocks above `lastLanded`, so a late original can never void a fork; the record is the moment of the void and an L1 fact the S4a waiver and the lock reset read. |
| R3H-1 | High | FI_SKIP bounded one poison entry to four hours, not the stream: a new unprovable entry after each skip re-armed the halt for about 0.02 ETH per day until a DAO guest fix. | Each entry posts FI_BOND = 0.05 ETH, refunded on consumption and burned with the fee on skip; the fee floor quadruples per skip in 24 h (SKIP_ESCALATION), so a stream is bounded by the poster's budget (a two-day stall costs thousands of ETH); L16 restated as a per-entry bound with geometric stream pricing. |
| R3H-2 | High | No consensus bound on per-term data and a per-block price: one seat at its buffer could certify a 180-blob term nobody was paid to land, stalling sequential landing; the published break-even was wrong by 3×. | Validity rule **V10** caps a term at 15 blobs (three landings); a **per-landing reward** R_LAND ramps 0 to 1,300 TAIKO (a 2 M-gas landing at 100 gwei) beside a 0.5 to 4 TAIKO per-block ramp; every owner keeps a **landing reserve** of 6,200 TAIKO above its seat stake at registration, from which rewards are paid, and is ineligible when the reserve cannot fund a term; break-even is 100 gwei per landing whatever the term's size; exposure re-derived (6,161 TAIKO). |
| R3H-5 | High | Sortition walked the whole seat array, so an attacker registering and immediately exiting thousands of seats (bond returned after nine days) diluted the walk until most terms were open-empty or without committee. | Sortition runs over the **eligible list**, a dense future-dated list of eligible seats maintained by swap-and-pop; the density term disappears from every formula; the seat array remains identity only. |
| C1 | High | A timeout was signed on "no certificate for 5 s", so 11 abstaining cartel seats made the honest 21 time out a live primary and hand its term to a cartel backup; a third of the seats captured 63 to 87 % of terms, breaking the linear cost curve. | A timeout is signed **only on leader silence**: an attester that attested a block of the view within the timeout window never signs TIMEOUT. An abstaining minority can now only blank a term's certification (no takeover, no penalty); term share equals seat share; the cost curve and tables are re-derived by simulation. |
| R3-S5 | Medium | VC formation "at the honest maximum in one extra round trip" required a second lock signature that S3c slashed. | Lock votes are monotone: a key may re-vote for a strictly higher extending lock; S3c slashes only two votes at one height with different phHash or a later vote below an earlier one. |
| R3-S6 | Medium | `recordViewChange` was keyed on (termId, view), so a REPLACE VC and the fork's later VC for the same view collided and the term after any replacement could not be opened. | The ViewChange struct names the opening object it closes; records and the L4 match are keyed on (termId, view, closes). |
| R3H-3 | Medium | V9 ignored the nine framing bytes, so a maximal block needed four blobs at 2-s slots. | V9 and MAX_ENVELOPE are 390,123 bytes; the bound is stated on the framed payload. |
| R3H-4 | Medium | Single-proof mode was disabled in every certificate-free regime while three "proven" claims said one back-end outage never needs the DAO. | Stated as limitation L19 (deliberate: no attester-executed root to back a single proof); the roles, arguments, index and parameters pages restate R1's DAO-independence as holding for certified operation. |
| R3H-6 | Medium | The withdrawn V5(e) placement clause survived on the certificate page, in lesson 3 and on the arguments page, contradicting V8. | Deleted everywhere; acceptance is V1 to V6, V8, V9 and V10. |
| R3H-7 | Medium | The restated collusion figures were binomial and wrong at launch scale (a 10-seat cartel can never hold 11 slots; two owners with 12 of 44 seats block 40 % of terms). | The slashing page carries a simulated hypergeometric table per owner structure; the launch condition is 8 owners and 72 seats. |
| C2 | Medium | The round-2 walk fix had not propagated to the certificate, roles and glossary pages, lesson 2 still said "fewer than four", and removed S7 storage survived. | All propagated; the sequencing page is declared the owner of selection rules; demand storage and the ETH invariant term removed; grep list extended. |
| C3 | Low | `announceLanding` was missing from the 102-minute forced-inclusion bound and from L3. | Bounds restated as 112 minutes (one LAND_CHAIN_GRACE); L3 says private blocks land only if the colluders publish them, stall up to 75 minutes. |
| C4 | Low | "MIN_OWNERS enforced by initEtna" was unimplementable (the registry is empty at the upgrade). | A published launch condition the DAO checks before choosing T0; MIN_OWNERS is liveness sizing, not an anti-monopoly bound. |
| R3-S7, R3H-8, C5 | Low | Documentation cluster: "one view" per landing, refund wording, vcHash only on first blocks, announcement bond currency, 3,470 exposure, registration at 100 % vs 105 %. | Every item corrected: vcHash on every block in the anchor calldata and headerCore (A5 now compares with the parent's); the announcement bond is TAIKO on the ledger; registration and reactivation require 1.05 × floor plus the reserve. |
| R3-S3 | refuted | S6 was claimed to slash sentinel-view sequencers. | Refuted (the dead-mode marker is the valid opening object); the S6 row now says so explicitly. |

## Verification trace of this revision

Grep list run before rebuilding (zero survivors outside sentences that describe the corrected rule): "holder list", "term's holders", "four eligible", "demands", "3,470", "3,626", "390,132", "0.5 / 24", "24 TAIKO per block", "L_t", "(1 − ρ)", "two timeouts", "TimeoutMsg calldata _to", "payable; // bond", "for example at launch", "102 min", "refunded on void", "V5(e)", "enforced by initEtna", "MIN_OWNERS = 6", "44 seats". Figures re-derived: the collusion table (nine owner structures, 20,000 terms each), the term-share cost curve, the per-term exposure, the V9 bound, the forced-inclusion bound, L2, L3, L6, L16, L19.

## Convergence

Round 3 produced seven new Highs, so the two-clean-rounds counter restarts at round 4. Three rounds have each produced new Highs in the mechanisms the previous round's fixes introduced; if round 4 repeats this pattern the final report will say so rather than continue to the cap.
