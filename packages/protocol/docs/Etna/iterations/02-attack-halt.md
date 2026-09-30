# ETNA red team, round 2: HALT LIVENESS

## Model

Running as **claude-opus-5-5** (Opus 5.5; opus was requested). Self-reported.

## Method

1. Read the revised design site in full (index, roles, sequencing, preconf, landing, slashing, forced-inclusion, bridge-migration, interfaces, parameters, arguments, l1-dependencies, frame-transactions, limitations, glossary), converted to text, plus `01-threat-model.md`, `README.md`, `iterations/01-round.md` and `iterations/01-judge.md`. Repository code consulted only for today's L2 limits (`packages/protocol/docs/Derivation.md:374`, `docs/zk_gas_spec.md:12`).
2. For every revision made after round 1 (Q(m), absence bleed, FI_SKIP, data posts, four-view landings with R_BLK_MAX = 24, the 34-hour horizon, opening objects in keys, fallback at any depth) I asked: what bound does the revision state, is the bound per attacker or per event, and which quantity is unbounded on-chain.
3. Each candidate was traced with times in seconds against the rules as written; anything needing broken cryptography, a malicious DAO, L1 finality failure or a colluding majority beyond T11 was dropped unless the design's own bound is wrong.
4. Pages were diffed against each other for constants and rules stated two ways.

Findings are appended below as they are completed.

## H1. One oversized certified block stops every landing (absolute at 2-s slots, uneconomic at 12-s)

**Severity:** High. **Affects:** R7, R4 (short slots), P4; TH13, TH2, TH8, TH15.

**Actors.** M: owner of 1 seat (20,000 TAIKO), drawn primary of term t. Honest holders of t+1 and later. Honest committee.

**Trace (2-s slots).**
1. termStart(t)+0 s: M builds block b whose `txListBytes` is 400 KB of incompressible calldata (L2 gas about 16 to 40 gas per byte, well below the 45 M block limit, `docs/Derivation.md:374`; calldata costs no zk-gas beyond the 243,000 intrinsic per transaction, `docs/zk_gas_spec.md:12`). The envelope is under MAX_ENVELOPE = 524,288, and no V1-V6 rule limits bytes. Honest attesters attest; C(b) forms at about +0.7 s. b is locked when b+1 carries C(b).
2. b's canonical record needs ceil(400,300 / 130,044) = 4 blobs. A landing covers whole blocks and all of its blobs travel in one transaction. At 2-s slots, "Max blobs per block ... 3" (l1-dependencies). So no landing can ever contain b. Every later certified block also sits above b, because landing is sequential (L1 `NotNext`).
3. termEnd(t)+2 s: the TERM_END VC locks at or above b, and t+1 extends it. Terms t+1, t+2, ... are certified but unlandable.
4. termEnd(t)+2,100 s: A1 holds (min(+3,600, max(+1,800, lastLanded.at+600)) + 300). The current holder forks a REPLACE from lastLanded and lands about 3 minutes later. About 38 minutes of certified and locked blocks are void.
5. The replacement landing, at about termEnd(t)+2,280 s, falls inside [termEnd(u), termEnd(u)+3,600] for every voided honest term u = t+1..t+38. The outage gate therefore passes, and `reportAbandoned` debits each honest holder 2,000 TAIKO. Anyone can file these reports and collect the 10 % reporter share.
6. M repeats in its next term, about 1.5 times per hour at 1 of 40 seats.

**Trace (12-s slots).** M fills all 60 blocks to 524,288 bytes. Each block then needs 5 blobs, so the term takes 60 landings of about 1.5 M gas each (90 M gas and 300 blobs). The reward stays capped per block: 60 × 24 = 1,440 TAIKO ≈ 0.22 ETH. Paying lander break-even falls to 0.0036 ETH / 1.5 M gas ≈ 2.4 gwei. Above that fee, nobody lands for profit, and steps 4-5 follow.

**Design text exploited.** "Ranges are lander-chosen, so no per-term cap exists on-chain; the caps are per landing: 6 blobs (the per-transaction limit) and 256 blocks. An oversized landing is not includable, never slashable." Also: "MAX_ENVELOPE ... 524,288 | ≈ 2.3 × the per-second blob budget".

**Cost and gain.**
- M pays SLASH_ABANDON of 2,000 TAIKO (0.3 ETH), plus 25 % of the L2 base fee on its own calldata.
- At 2-s slots, honest owners lose about 38 × 2,000 = 76,000 TAIKO and 38 minutes of locked history per event.
- At 12-s slots, honest parties must pay about 1 ETH at 10 gwei (5 ETH at 50 gwei) per stuffed term to avoid those losses.
- An attacker share of about 0.15 produces roughly 2,000 blobs per hour, a large fraction of all L1 blob capacity, so the backlog never clears.

**Why replacement does not clear it.** REPLACE re-includes the void blocks' transactions in order "except transactions the fork's sequencer lists in the REPLACE VC as unprovable (a Q-signed quarantine list), which are dropped." b's giant transaction is provable (it executes VALID), so it is not quarantine-eligible; a design-following replacer reproduces b and the chain re-freezes. The only escape is a replacer discretionarily dropping a provable transaction, which no validity or slashing rule sanctions and which is indistinguishable from censoring an honest large exit bundle. So the halt is permanent until someone censors the attacker's transaction outside the rules.

**Cost and gain.**
- M pays SLASH_ABANDON of 2,000 TAIKO (0.3 ETH), plus 25 % of the L2 base fee on its own calldata.
- At 2-s slots, honest owners lose about 38 × 2,000 = 76,000 TAIKO and 38 minutes of locked history per event.
- At 12-s slots, honest parties must pay about 1 ETH at 10 gwei (5 ETH at 50 gwei) per stuffed term to avoid those losses.
- An attacker share of about 0.15 produces roughly 2,000 blobs per hour, a large fraction of all L1 blob capacity, so the backlog never clears.

**Internal contradiction it rests on.** MAX_ENVELOPE = 524,288 bytes is justified as "≈ 2.3 × the per-second blob budget", but a single such block needs 4-5 blobs while a 2-s-slot L1 block holds only 3 (l1-dependencies "Max blobs per block ... 3"; landing robustness "blobs per block 10/7/3 so landers shrink ranges"). A block that gossips (≤ MAX_ENVELOPE) can therefore exceed the blob capacity a landing can spend on it, and "landers shrink ranges" cannot shrink a single block.

**Fix.**
- Make record size a validity rule (V9): a single block's canonical record must fit the L1 per-block blob capacity at the design's minimum supported slot time (≤ 3 blobs), enforced at attestation and in the guest.
- Pay the lander per blob as well as per block.
- Exempt voided holders from S4a when the first unlanded term belongs to a different owner.
- Add a quarantine path for provable-but-unlandable (oversized) transactions so replacement can drop them objectively.

## H2. The F5 data-post answer is capped at 6 blobs, so a demand over a stuck-but-live chain slashes an honest committee (S7)

**Severity:** Medium. **Affects:** R6, TH8, P6. Builds on F5 and H1; F5's fix is incomplete in the H1 transition window.

Round 1 F5 made a demand answerable by a canonical-blob data post so that S7 "protects availability only" and never slashes an honest committee. But the post is one L1 transaction, so at most 6 blobs (about 780 KB), 3 at 2-s slots; the design defines no multi-post accumulation. When the range `[lastLanded+1, cert.height]` exceeds that AND `lastLanded` cannot advance to cover `cert.height`, an honest committee that genuinely holds the data cannot answer. The S7 outage gate ("outage gate as S4a") blocks this during a chain-wide proving outage, but it does not protect the hour after an H1 freeze, when the last ordinary landing is still inside OUTAGE_WINDOW yet no landing can ever reach the stuck height.

**Actors.** D: unbonded demander with 0.05 ETH (refunded on default). The honest committee (up to 23 keys) of a term above the stuck block b from H1.

**Trace.**
1. H1 fires: b is an oversized certified block that no landing can contain, so `lastLanded` freezes at b-1 and every later block is certified above b. The last successful ordinary landing (ending at b-1) is at time L0.
2. At L0 + 5 min the certified tip H is more than 6 blobs above b (about 90 s of chain at the 32 KiB/s target).
3. D calls `demandData(C(H))` (fee 0.05 ETH). DEMAND_WINDOW = 1,800 s starts. This is well inside OUTAGE_WINDOW = 3,600 s of L0, so the S7 outage gate is open: a term landed within the last hour.
4. The honest committee holds the data but cannot answer: a landing "covering the certified height" is impossible (H is above the unlandable b), and the data post of `[b, H]` exceeds 6 blobs in one transaction.
5. At demand + 1,800 s, `slashAvailabilityDefault` fires: class B, one seat each for every bitmap member and the leader; certificate voided; fee refunded. Loss: up to 23 × 20,000 = 460,000 TAIKO plus, per the class table, +3 strikes and a floor check on each honest owner, i.e. suspension. D pays only gas.
6. D can file such demands on every certificate between b and H whose window matures before L0 + 3,600 s (roughly the first half hour of demands), slashing one to two full committees, about 460,000 to 920,000 TAIKO, before the outage gate closes.

**Design text exploited.** "a valid response is either a landing covering the certified height or a data post answerDemand(certHash, blobs): the canonical blobs of the range from lastLanded + 1 to the certified height, attached to an L1 transaction whose hashes the inbox records against the demand". Class table: class B is "+3 strikes; floor check".

**Cost and gain.** D: L1 gas only (~300k per demand, fee refunded). Gain: burns 460k-920k TAIKO of honest bond and suspends the committees above a stuck block during the one-hour window opened by H1, reintroducing the exact F5 harm (S7 slashing honest attesters when data is available) that the round-1 fix was meant to close. Bounded because the outage gate shuts one hour after the last real landing; unbounded if the attacker periodically forces a fresh tiny ordinary landing to keep re-opening the gate (needs a provable sub-6-blob range to land, which stuffing does not provide, so re-opening is not free).

**Fix.** Let `answerDemand` accumulate a prefix across several transactions within the window; or scope a demand to a range no larger than 6 blobs; or require the S7 answer only up to `min(cert.height, lastLanded + 6 blobs)`, so an honest committee is never asked to post more than one transaction can carry.


## H3. Internal contradiction: ROLE_HORIZON is 7,200 s on the slashing page and 122,880 s everywhere else, reopening F7

**Severity:** Medium (High if the implementer builds from the slashing table). **Affects:** R7, P2, TH12/TH13; this is the F7 fix contradicted in place.

The round-1 F7 fix raised the landing horizon to 34 h so that certified/locked blocks are not voided by clock and `recordCommittee`/`recordAssignment` stay callable across the whole landing window. Four pages carry the new value; the slashing parameter table still carries the old one.

**The conflict, verbatim.**
- parameters.html dependency chain: "ROLE_HORIZON = COMMITTEE_RING·TERM = 122,880 s (34 h: the landing horizon; roles pinned for every settled term)"; table row "ROLE_HORIZON | Sequencing, Slashing | s | 122,880 (34 h = 2,048 terms)".
- sequencing.html: "Roles stay computable on-chain for ROLE_HORIZON = 34 h after a term's start".
- landing.html L4: "Rights and committees of a term older than ROLE_HORIZON (34 h) are read from its pinned assignment ... a term older than the horizon that was never pinned is unlandable and therefore replaceable."
- slashing.html parameter table: "ROLE_HORIZON | s | 7,200 | recordCommittee and MISS need exact roles until an hour past the hard deadline". And `recordCommittee(uint32 _termId) // while now ≤ termStart + ROLE_HORIZON`, and the MISS row "applied only within ROLE_HORIZON of the term start".

**Why it halts / voids.** `recordCommittee` and `recordAssignment` share the `termStart + ROLE_HORIZON` guard, and landing L4 makes an unpinned term older than ROLE_HORIZON "unlandable and therefore replaceable." An implementer who takes the slashing page's 7,200 s gets the pre-F7 behaviour: any term not pinned within 2 h of its start is unlandable. Landing is sequential, so one such term at the front of a backlog makes the whole backlog unlandable; the only way forward is a REPLACE/dead-mode/forced landing that voids every certified and locked block above lastLanded, with the outage gate closed so no one is slashed. A proving stall or fee spike of just over 2 h (well inside the 34-h promise, and inside SUSPEND/RECYCLE_GRACE which are sized for 34 h) then destroys hours of locked history and lets S4a fire after the forced replacement. That is exactly F7, which the design says is fixed and tags "proven within the horizon."

**Trace.** t0: chain healthy, lastLanded at term u. t0+0: a two-hour prover outage begins (both ZK back-ends down; DEGRADE_AFTER = 7,200 s has not yet armed single-proof either, and even single-proof needs one working leaf). t0+7,201 s: under the slashing value, `recordCommittee(u+1)` now reverts and u+1 was never pinned (no landing pinned it). t0+7,300 s: proving returns; a lander tries to land u+1..: L4 rejects it as older than ROLE_HORIZON and unpinned. The backlog is now only clearable by a REPLACE from lastLanded, voiding all certified blocks of u+1.. The design's "a global proving outage shorter than the horizon voids nothing" is false under the slashing value for any outage between 2 h and 34 h.

**Cost and gain.** Zero attacker cost; this is a spec defect, triggered by any ordinary >2 h outage. Loss: hours of locked/certified blocks voided, contradicting P2's "locked" promise and R7's minute-level-landing-with-no-clock-void claim.

**Fix.** Set ROLE_HORIZON = 122,880 s on the slashing page and rewrite its rationale to match the 34-h landing horizon; keep `recordCommittee`'s guard equal to `recordAssignment`'s. Add a cross-page constant-consistency check to CI for the parameter tables (this is a recurrence of F10 constant drift on a load-bearing constant).

## H4. Internal contradiction: the roles and arguments pages still carry the pre-F6 lander cap of 4 TAIKO/block

**Severity:** Low (Medium if an implementer follows the roles page). **Affects:** R7; this is the F6 fix left un-propagated.

Round 1 F6 raised R_BLK_MAX from 4 to 24 TAIKO/block because 4 could not pay a landing above ~20 gwei, making minute-level landing fail at ordinary mainnet fees. landing.html and parameters.html carry 24; two other pages still carry 4.

**Verbatim conflict.**
- landing.html: "r ramping linearly from R_BLK_MIN (0.5 TAIKO) at term end to R_BLK_MAX (24 TAIKO)"; figure "termEnd: r ramps 0.5 → 24 TAIKO/block"; parameters "R_BLK_MIN / R_BLK_MAX | TAIKO per block | 0.5 / 24".
- roles.html §3 Rewards: "Per landed block, a Dutch ramp from 0.5 TAIKO at term end to 4 TAIKO at term end + 30 min".
- arguments.html liveness ladder: "Provers or landers silent → reward ramps 0.5 → 4 TAIKO per block over 30 min → anyone with the data lands".

**Consequence.** The roles page is the canonical per-role duties/rewards reference and roles.html §1 already cites the correct "24 TAIKO per block" for the sequencer's landing duty, so the page contradicts itself internally as well as against landing. An implementer or operator sizing the lander economics from the roles/arguments value reintroduces F6: at 4 TAIKO/block the maximum per-term reward is 240 TAIKO ≈ 0.036 ETH, which does not cover a 2 M-gas landing above ~18 gwei, so third-party landing stops being profitable at ordinary fees and the chain leans on self-landing plus the outage gate, i.e. degraded landing liveness (R7). No attacker needed.

**Fix.** Replace "4 TAIKO" with "24 TAIKO (R_BLK_MAX)" on roles.html §3 and in the arguments.html liveness ladder; add the parameter tables to a cross-page constant-consistency check (this and H3 are both stale-constant drift on liveness-load-bearing values, the F10 class recurring on the round-1 fixes themselves).

## What I tried and could not break

1. **Handoff ambush / withholding (W1).** Tried to land withheld blocks above the recorded TERM_END lock. Stopped by: a second VC for one (t, v) needs 2Q(m)−m double-signers (12 at full committee), all class-A slashable (S3c), and "the recorded honest VC beats A's landing (minutes of proving) to L1" (preconf §7 W1). No cheaper path exists because the batch seal IS the committee VC, so there is nothing sequencer-signed to withhold.

2. **Wedge the term chain with two consecutive dark committees.** Tried to exploit the old one-deep FALLBACK. Stopped by the F9 fix: "the committee of any later term t' within the landing horizon may sign a FALLBACK VC for t ... once termEnd(t) + END_GRACE + VC_FALLBACK·(t'−t) has passed" (preconf §5). Every later committee within 34 h can close the term, so persistent abstention only delays, at 10 s per dark committee, never wedges.

3. **Make a proven landing revert or an in-flight block reorg through the FI queue.** Stopped by the anchored-time clock: "due(i, T) ... T is always the timestamp of an L1 block whose hash is pinned" and "an entry becoming due while blocks are in flight is a non-event for them (their parents' anchors are older)" (forced-inclusion §2, §4). T_floor is storage plus the chain's own term id; no third-party input moves it.

4. **Open dead mode on a slow-but-live chain to seize sequencing.** Stopped by DEAD_TERMS·TERM = 4,500 s > LAND_WINDOW_MAX + ABANDON_GRACE = 3,900 s (parameters dependency chain): a chain that lands at all never reaches 75 unlanded terms.

5. **Slash an honest committee under S7 during a genuine chain-wide proving outage.** Stopped by the outage gate: S7's verification is "outage gate as S4a" (slashing S7 row) and the false-positive table reads "all Q+1 honest holders unable to land or post ... while other landings happen" (preconf §14). With no landing in the last hour the demand cannot mature into a slash. (H2 is exactly the residual case the gate leaves open: a stuck-but-recently-live pipeline.)

6. **Grind the seed to fix future holders.** Stopped by RND3 freshness plus DELAY_REG = 7,200 s > CYCLE + LOOKBACK − TERM: grinding needs 41 minutes of total L1 censorship of Etna transactions (poke() is permissionless), after which the lever is "a few bits of seat placement" (sequencing §4).

7. **Suspend honest operators out of eligibility with timeouts (the F3 surface).** Stopped by the F3 fix: "A timeout never changes eligibility: it adds no strike and triggers no floor check" (sequencing §7); only structural class-B offences (the offender's own signed lie) strike. The residual bleed to the 50 % hard floor over ~a week above the T11 boundary is the accepted L2 limitation, not repeated here.
