# Etna round 4, censor / monopolize attacker

## Model
claude-sonnet-5-5 (Sonnet 5.5), as requested.

## Method
Read every design page (index, roles, sequencing, preconf, landing, slashing, forced-inclusion, bridge-migration, interfaces, parameters, arguments, l1-dependencies, frame-transactions, limitations, glossary), the learn/ pages, 01-threat-model.md and README.md, from the current working tree (round-3 revision). Attacked the round-3 mechanisms first: timeout/lock-vote split, RESET, recorded REPLACE, eligible list, V10/R_LAND/LAND_RESERVE, FI bond. Re-ran the blank-term simulation of slashing §5 myself (Python, 20,000 terms per row, hypergeometric committee from the pool left after excluding the primary owner and the backup seats; script kept in the scratchpad, not committed). The table's rows reproduce (the table counts cartel-primary terms in "blank"; I count only honest-primary terms, which is what censors users). Then computed the cartel's share of *productive* (certified) term revenue for three owner structures and several H.

## F1 [High] Blank terms convert about a third of seats into most of the revenue; the TH9 cost curve is wrong by 2x to 10x (builds on round-3 C1, whose fix is inadequate)
Requirement: R6 (anti-monopoly parameters), R1, TH9; also P3 block liveness.

Trace (H = 40 honest single-seat owners, the launch figure on slashing §5; cartel = 27 single-seat owners, 540,000 TAIKO, about 81 ETH at the assumed rate; no slashable act anywhere).
1. Committee(t) is public 20 to 80 min ahead. For every term whose committee holds at least 11 cartel seats (m = 32, Q = 22) and whose primary is honest, each cartel attester simply does not attest. t = 0 to 60 s.
2. The honest 21 attest each block (about 0.45 s) and so, by the new rule, sign no TIMEOUT; 21 < Q, so no certificate and no VC forms. The primary HOLDs after two uncertified blocks. At term end only 21 TERM_END timeouts exist; next term's leader waits for the FALLBACK VC (+12 s, +10 s per further blocking committee).
3. Blocks are unlandable and never extended; the term's transactions fall out of the chain. No MISS, no strike, no S-rule applies (all stated).
4. Cartel-primary terms are certified normally (its other owners sit in the committee).

Simulation, honest-primary blank rate and cartel share of productive revenue = p / (p + (1-p)(1-b)):
- 40 honest x1 vs 20 x1 (33 % seats): b = 0.58, revenue 54 %.
- 40 x1 vs 27 x1 (40 %): b = 0.91, revenue 88 %.
- 8 x 8 honest vs 32 x1 (33 %): b = 0.69, revenue 62 %.
- 100 x1 vs 70 x1 (41 %): b = 0.86, revenue 84 %.
- 4 x 8 honest vs 8+4 (44 seats, 27 %): b = 0.56, revenue 45 %.
The design prices 88 % at 360 seats against H = 40; the real price is 27 seats (13x cheaper). Users: 91 % of honest terms dead; ordinary transactions only pass through the cartel's own terms, so the only remedy is FI (0.05 ETH bond, 5 to 102 min).

Design text: "With H = 40 honest seats at launch (200 when mature), 50 % of terms costs 0.8 M (4.0 M) TAIKO and yields exactly 50 % of term revenue." (slashing §5). "T11 fewer than Q colluders per committee" (arguments §7) versus "T11: fewer than 11 committee seats abstain" (arguments §3). 01-threat-model T11 is "fewer than the attester quorum threshold collude": up to 21 of 32 are inside the stated bound, yet liveness needs fewer than 11, so the stated bound is itself wrong for liveness. Also "refusing to attest (loses income, cannot stall a term with an honest majority)": 21 of 32 is an honest majority.

Cost/gain: cost 27 seats plus six-thousand-TAIKO reserves; loses only 0.1 TAIKO per landed block of attester reward; gains 88 % of productive revenue and excludes honest users.
Fix: make a stall observable and self-healing: let attesters that attested a live leader but saw no certificate in TIMEOUT sign a STALL vote at a lower threshold (floor(m/2)+1) whose only effect is to redraw the committee for the same leader (no backup, no MISS); so blanking needs the cartel in consecutive fresh committees. Restate T11 as "fewer than m-Q+1 abstain" for liveness and republish the cost curve from the simulation.

## F2 [High] The landing reserve adds an owner-triggered eligibility write with delay 1,320 s: seed-known grinding of term assignments (breaks the "no grinding" and share claims)
Requirement: R6, TH9; claims "No entry or exit grinding when the seed is fresh" and "Share bound w/A" (sequencing §16).

Trace. Attacker: k = 4 single-seat owners (4 x (21,000 + 6,200) = 108,800 TAIKO, about 16 ETH) against H = 64 honest seats. Cycle c starts at C; seed(c) is fixed at T_seed = C - 1,200 s and public to all nodes.
1. At tau >= C - 1,200 s the attacker computes, for every term t starting >= tau + 1,320 s, the holder under each of the 15 non-empty subsets S of its owners being in the eligible list (list length E = H + |S|; idx = keccak(seed, t, k) mod E, so every subset is an independent reshuffle).
2. To put owner i out: withdraw the reserve (allowed: the withdrawable amount is only the excess over 1.05 x floor), so reserve < exposure and the owner is ineligible from tau + 1,320 s. To put it back: deposit plus reactivate(), eligible again at tau + 1,320 s. One L1 transaction per flip, scheduled so the effective instant lands before each term.
3. Per term, P(some subset makes an attacker owner primary) = 1 - prod_S (1 - |S|/(H+|S|)) = 39 % for k = 4 (fair share 5.9 %, 6.6x); for k = 8 it is above 99.99 %. Flip cost about 2 to 4 transactions per term, about 0.002 ETH at 10 gwei, against 0.01 ETH per term revenue.
Rule D is satisfied (1,320 s >= LOOKBACK + 2 TERM), so node and contract agree; what fails is the freshness argument, which assumes every roster-affecting write has delay >= 4,740 s.

Design text: "A reserve below the per-term exposure makes the owner ineligible, future-dated by DELAY_S, until topped up;" (landing §5). "Partial withdrawal of any excess over 105 % of the floor at any time." (roles §1). "DELAY_REG > CYCLE + LOOKBACK - TERM = 7,200 s (no grinding when the seed is fresh)" (parameters). "freshFrom(c) = cycleStart(c) - 3660 s, the last instant at which a registry write can affect cycle c" (sequencing RND3). The owner state machine (sequencing §10) has no reserve branch and the two-interval store (s1,e1,s2,e2) is sized only for 36-h suspensions; short toggled intervals either overflow it (a live interval dropped, node and contract disagree about old terms) or the contract silently rate-limits toggles. The design says neither.

Cost/gain: 16 ETH capital plus gas; gain 39 % of terms from 5.9 %, and the same lever steers committee composition (blank conditions of F1).
Fix: reserve-driven ineligibility must not exist as a fast write: make the reserve non-withdrawable while any seat is active, or delay its effect by DELAY_REG; if kept, reserve drops use SUSPEND-length intervals and the store invariant is restated.

## F3 [Medium] A recorded REPLACE VC voids the whole certified backlog with no proof; an outage plus one holder is an unslashable reorg of up to an hour of "locked" blocks (round-3 S4 fix overshoots)
Requirement: R7/P2 (preconf reorg), TH5, R6.

Trace. A prover-fleet outage (or any stall) begins at X; lastLanded.at = X, the first unlanded term t' ends about X + 60.
1. replaceableFrom = min(termEnd(t') + 3600, max(termEnd(t') + 1800, lastLanded.at + 600)) + 300, so A1 holds at about X + 2,160 s (36 min). Certified blocks of terms t'..now (about 36 terms, all honest, all "locked") are still unlanded.
2. The current holder H (any owner, no collusion, no stake change) reopens its view as a REPLACE view with l1Ref = first L1 block after replaceableFrom that is >= 48 s old. Honest attesters cannot tell why nothing landed; the predicate holds, so Q of them sign REPLACE lock votes (no S3b, no S3d: the reference is true). VC forms at about +50 s.
3. H calls recordViewChange. No proof, no landing, no fork block is needed. From that record "the inbox refuses original blocks above lastLanded": the backlog is dead even if a lander finishes its proof one minute later. S4a is waived for every voided holder and H pays nothing.
4. H re-includes the voided transactions in its own order; "re-include in order" is a client duty, not a validity rule, and a Q-signed quarantine list lets it drop transactions it calls unprovable. Users who acted on "locked" blocks (36 min) are reordered; H sandwiches or front-runs them.
Cost: one L1 transaction. Gain: free ordering option over up to 65 min of others' blocks, at the moment it chooses; it can also stay silent with the VC in its pocket while the original tail keeps growing, and record just before a landing completes (a VC signed at an old but true reference stays valid; no maximum reference age is stated).

Design text: "Replacement needs a landed proof, so it cannot be triggered by an outage." (arguments §3) and "this design bounds when: only when a replacement lands, never by time within the landing horizon." (landing §6) versus "A recorded REPLACE VC is therefore the moment of the void" (landing A3). Also "Rarity. A replacement needs A1 ... and a working proof system", but no rule checks the second half; attesters check only A1.
Partial answer to the duty question: a false-reference or premature record needs Q REPLACE signers (each S3d class B, B_SEAT), so it is out of T11; a stale-but-true record, as above, needs none.
Fix: a REPLACE record closes the original tail only together with the fork's first landing (keep the record as priority evidence; resolve the old S4 by waiving the fork holder, not by voiding early), bound l1Ref age to a few minutes, and state L6 accordingly.

## F4 [Medium] The reserve margin is 39 TAIKO: one 50-TAIKO timeout or seven held terms make a minimum-funded entrant ineligible (entry barrier; contradicts "a timeout never changes eligibility")
Requirement: R1 (entry), R6 (TH8/TH10 griefing), TH9.

Numbers: registration requires 1.05 x floor + LAND_RESERVE = 6,200; per-term exposure = 6,161; margin 39 TAIKO. A holder pays ATT_REWARD 0.1 x 60 = 6 TAIKO per held term from the same reserve and has no TAIKO income (its revenue is L2 ETH).
Trace (new entrant E, one seat, funded exactly to the requirement, 27,200 TAIKO).
1. E registers, becomes eligible at tau + 2 h. Its first term: the attester share debits 6 TAIKO (reserve 6,194). After 7 held terms (about 8 hours at A = 72) the reserve is 6,158 < 6,161: E is ineligible from +1,320 s until it tops up and calls reactivate() (+1,320 s again): at least 44 minutes of lost draws per lapse, with no slash and no warning rule.
2. Attack variant: attacker floods E's leader at a public term start for >= 5 s (design: "a stakeless network flood ... costs its target one view and 50 TAIKO"). The 22 attesters that saw nothing sign TIMEOUT, the VC is carried by the backup's landing, the inbox burns 50 TAIKO from E: reserve 6,150, below the exposure: E is ineligible although only a timeout occurred. One flood per E-primary term (about 1 per 72 min) keeps a minimum-funded entrant permanently in the top-up / reactivate cycle; the attacker's cost is bandwidth.
3. Multi-term gap: the reserve funds one term, but an owner with w of A seats is primary in about 30 w/A terms of any 30-min backlog (2.4 terms for 8 of 72) and ineligibility is future-dated by 1,320 s. A lapsed owner that certifies and goes dark leaves the second and third terms with zero funded reward (rewards stop at the buffer), so honest later holders must land them for gas only or wait for replacement (F3).

Design text: "A timeout never changes eligibility" (sequencing §7); "Eligibility is never removed by a timeout." (slashing §5); "Liveness debits (absence, abandonment) and reward debits never trigger that check; ... only the 50 % hard floor suspends for liveness bleed" (sequencing §7) versus "A reserve below the per-term exposure makes the owner ineligible" (landing §5); "so every certified term has a funded lander reward by construction" (landing §5). The owner state machine lists no reserve state.
Cost/gain: attacker bandwidth; entrant loses 44+ min plus 50 TAIKO per burst; Sybil incumbents (funded 2x) are unaffected, so it is an entrant-only barrier.
Fix: reserve = per-held-term exposure x concurrent terms (or debit only the excess and charge attester share to the lander pool), a margin of several exposures, reserve lapse warns for one term before it bites, and reconcile the three sections.

## F5 [Low] The launch condition counts seats, not honest seats, and is a one-time off-chain check of a revocable quantity
Requirement: R1 (launch), TH9.

Trace 1 (satisfy, then thin). Attacker registers 72 seats across 9 owners (about 1.57 M TAIKO incl. buffers and reserves, 235 ETH) before the DAO's check; the condition "at least 8 distinct owners and 72 seats with activeFrom <= T0" passes; DAO fixes T0 (>= 7 days out, MIGRATION_LEAD). The attacker calls requestExit (effective +2 h, well before T0); its bond is locked only 7 days and nothing is slashed. First term is after drainedAt (up to 25 h after T0): the chain starts with whatever honest seats exist, possibly in no-committee mode (sequenced level only, landings certificate-free, two ZK systems always, L19).
Trace 2 (pad the honest set). Honest set 8 owners x 4 seats (32). Attacker adds 40 seats (10 owners): the condition passes (18 owners, 72 seats), cartel share 55 %, H = 32: by F1's simulation all honest terms are blank (b = 1.0 above 40 %).
Cost: trace 1 is interest on 235 ETH for about 9 days; trace 2 is the F1 price at launch (40 seats, 0.8 M TAIKO).
Design text: "at least 8 distinct owners and 72 seats with activeFrom <= T0, so that a full committee exists with the primary owner excluded and a small cartel blanks no term (slashing page §5 table)" (bridge-migration §5), "checked by the DAO before it chooses T0 and never by the contract". The table's "near zero" holds only for the honest compositions listed, which the condition does not enforce, and "distinct owners" is an address count.
Fix: honest seats are unverifiable, so evaluate the condition at the first term rather than at T0 (count only seats active through the first term plus DELAY_REG), and publish the F1 price curve next to it.

## F6 [Low] Stale or contradictory statements left by the round-3 pass (consequence: auditors implement the old rule)
1. Slashing §8 interface still declares slashLockLie(TimeoutMsg ...) and slashViewChangeEquivocation(TimeoutMsg, TimeoutMsg ...) for S3b/S3c, while the Interfaces page types them on LockVote and TimeoutMsg "carries no lock": a timeout cannot evidence a lock lie.
2. Slashing §11 false-positive table: "MISS via VC: ... or >= 11 colluders refuse to attest: 50 TAIKO" contradicts slashing §5 ("The absence bleed is no longer reachable by a minority at all") and the C1 fix.
3. Glossary "Timeout ... carrying its lock" versus the next row "timeouts carry no lock"; sequencing §7 "VC ... stating that no certified block above the lock was seen for TIMEOUT" (a VC is now Q lock votes).
4. Forced inclusion TH7: "no certificate forms, the committee replaces the holder within TIMEOUT" is false with 11 abstainers (21 timeouts < Q): the FI-skipping holder keeps the term, blank.
5. Arguments §6 Replacement row: "whichever lands first wins" versus landing A3 (recorded VC is the void); arguments §3 "Replacement needs a landed proof" (see F3).
6. Preconf TIMEOUT row: "leader partitioned from >= 11 attesters > 5 s loses the view's reward" versus "partitioned from >= 22 attesters" on slashing §11; only the 11-abstainer case blanks, the 22 case takes the view.
7. Sequencing §17 lists "swap-and-pop seat arrays (index reuse changes computed terms)" as rejected, while §5 adopts future-dated swap-and-pop on the eligible list; §16 claims "array length" is a pure function of L1 data; the pinned-digest mechanism for old terms needs the list order at termStart(t), which lazy application overwrites, and the page does not say how it is reconstructed.
8. Part of F1: arguments states T11 two ways (fewer than 11 abstain / fewer than Q colluders).
Fix: one pass of search-and-replace against the round-3 change list, and list the eligible-list history rule explicitly.

## What I tried and could not break
1. Term takeover by an abstaining minority (old C1): the timeout is signed only by attesters that attested nothing for TIMEOUT, so 11 abstainers cannot create Q timeouts; the result is only blanking (F1), not a takeover.
2. Lock-vote slashing trap (make honest attesters sign a low lock vote on a proposal, then attest a higher block, S3b): an attester casts a lock vote only at a lock not below its own (the highest certificate it holds) and enters TIMING_OUT ("attest nothing in v"); S3b compares only the same opening object, and REPLACE and RESUME kinds are exempt. I found no sequence that makes an honest key sign both.
3. Post-reset lock lie via TIMEOUT or TERM_END under the old object: the RESET state allows only RESUME messages; S3b ignores locks equal to landed heads.
4. False-reference or premature REPLACE record voiding honest work: needs Q REPLACE lock votes, each S3d class B with the reference inside the signed bytes and canonicality checkable by blockhash or EIP-2935; beyond T11. (The stale-but-true record is F3.)
5. Handoff ambush and private-block MEV: a locked prefix needs 12 double signers (S3c); honest VC recorded within seconds.
6. Dilution of sortition by phantom seats: the walk is over the eligible list, P(no holder) = 0; exits never dilute.
7. FI stream re-arming and skipping a user's entry cheaply: FI_BOND burned on skip and the fee floor x4 per skip within 24 h; FI_SKIP is gated on the last landing's anchor time, so backlog delay never voids an entry; FI bound (102 min) survives F1 because V8 forces cartel terms to consume FI.
8. Exclusion of a registrant by sequencer-key squatting (registerKeys carries no proof of control of the secp256k1 key, so a front-runner can bind a victim's announced key): costs the victim one retry with a fresh key; the BLS key is protected by the PoP over (pubkey, owner, chainId). Bounded griefing only.
9. V10 as a censorship lever: a spammer fills a term's 15-blob budget only by paying L2 fees and the leader chooses the blocks; no validity conflict with V8 is stated (FI record bytes are not specified, so I could not construct a V8/V10 deadlock).
10. announceLanding as an indefinite replacement delay: one deferral per lastLanded and the min(termEnd + 3600, ...) cap bound it to 65 min plus one grace.
