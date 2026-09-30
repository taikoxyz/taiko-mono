# Etna red team, round 2: censor and monopolize

## Model

Fable 5.1 (claude-fable-5-1), the requested `fable` model. Self-reported from the session's system context.

## Method

Read in full: `design/index.html` and every linked page (roles, sequencing, preconf, landing, slashing, forced-inclusion, bridge-migration, interfaces, parameters, arguments, l1-dependencies, frame-transactions, limitations, glossary), `01-threat-model.md`, `README.md`, `iterations/01-round.md`, `iterations/01-judge.md`, `iterations/01-attack-censor.md`. Goal: acquire a disproportionate share of sequencing or certification power, exclude an entrant, censor a user or a forced inclusion beyond the stated bound, extract MEV by withholding without slashing, or reorg preconfirmations with attesters. Every rule quoted below was re-read in the HTML text; line numbers refer to the HTML files under `packages/protocol/docs/Etna/design/`. No repository file was modified. Where a probability is claimed I computed it with a throwaway script in the scratchpad (the sortition walk as the sequencing page defines it: uniform seat draws until five distinct owners, committee = the non-holder seats, up to 32, uniformly without replacement), and the script's parameters are stated beside each number so the verifier can reproduce them.

Attack surfaces examined, in order: (1) committee composition under the holder-exclusion rule with heterogeneous seat holdings; (2) the round-1 fixes F3, F5 and F8 as re-stated on the revised pages; (3) forced-inclusion timing with FI_SKIP and four-view landings; (4) registration and exit as exclusion levers; (5) withholding and private MEV under the new equivocation keys; (6) parameter and rule drift between pages.

Findings are written to this file as each one is completed.

## Findings

### F1. Holder exclusion makes committee power depend on owner structure, not seat share: a 20 % single-seat cartel vetoes certification in 92 % of launch-sized terms and holds a full quorum in 12 %; five 8-seat operators have no committee at all

**Severity: High.** R6, R4, P2; TH9, TH6, TH5. The design's stated collusion bound is itself wrong, so in scope.

**Rules.** `committeeOf(t)` is "the first K = 32 distinct eligible seats of a second walk ... skipping seats whose owner is in the term's holder list H" (sequencing.html §8); H is five distinct owners; CAP = 8; Q(m) = ⌊2m/3⌋ + 1; m < 8 is no-committee mode.

**Actors and bonds.** Honest set = the design's launch figure, 40 seats as five 8-seat operators. Cartel: 10 single-seat owners (200,000 TAIKO, share 0.2, called comfortable); variant 20 (400,000, 0.33).

**Trace (per term, t = termStart).**
1. t: the holder walk draws five distinct owners by seat weight; honest owners carry 8 seats each, so in 92 % of terms ≥ 4 honest owners are holders (32 honest seats excluded), in 11.7 % all five (40 excluded).
2. t: committee = the rest: 8 honest + 10 cartel (m = 18, Q = 13, veto at m − Q + 1 = 6) or 0 honest + 10 cartel (m = 10, Q = 7: all cartel).
3. t .. t + 60, veto term: the cartel attests every block except the one carrying the target transaction or due FI block; no certificate; after 5 s honest attesters sign timeouts, the cartel co-signs, a true VC forms, the holder loses the view and 50 TAIKO; the next holder meets the same veto; re-signing the height is S1, so the rational holder drops the transaction. Quorum term: free timeouts of any block (L4); a locked block reverts with 2Q − m = 4 double-signers (80,000 TAIKO), not 12.
4. Cost per term: a share of 6 TAIKO of attester income; nothing provable.

Simulation (scratchpad script; walk per §5, committee = uniform subset of non-holder seats): cartel 10: P(veto) 0.92, P(quorum) 0.117; cartel 20: 0.97 / 0.28, and 0.035 for quorum with a cartel primary (a privately certified, landable term: W2 free). A one-seat entrant as primary is vetoed in 75 % of its terms at c = 0.2. Honest-only 5×8 or 6×7 registries are no-committee in every term; full committees need nine 8-seat owners (72 seats), not 37. In no-committee terms "any address with bond ≥ B_SEAT may sequence with the sentinel view 255 and the first landing on L1 wins" (§6; landing L4): four cartel seats (9 %) turn 37 % of terms into a landing race that voids the holder's sequenced minute, unslashed.

**Design text (verbatim).** "committee slots are drawn per seat, so the probability column is indexed by seat share, not address count." (preconf.html:217); "recommended 37 = K + V_MAX + 1 seats at activation for full committees" (parameters.html:30).

**Cost / gain.** 200,000 TAIKO that also earns 20 % of revenue, nothing at risk: censorship in ~92 % of terms, free attested reorgs in ~12 %, a 4-seat locked bound, a 75 % entrant bleed rate. Fades with registry size (25×8 honest: veto 7 %, still double the binomial).

**Fix.** Exclude only the current leader's seat from the committee; state the collusion table by owner structure; enforce a distinct-owner floor in `initEtna`; in no-committee terms reserve landing to the sortition holder until its deadline.

### F2. The round-1 F5 fix lets any blobs "answer" an availability demand, so S7 no longer prices a private certificate: Q + 1 colluders withhold, stall and extract MEV at zero slashing cost

**Severity: Medium** (F5's fix is inadequate). R6, P6; TH5 (W2), TH6, TH8. L3's "priced at 460,000 TAIKO" no longer holds.

**Rules.** `answerDemand(certHash, blobs)` answers `demandData` with "no proof needed"; the inbox only records blob hashes; no rule checks the blobs decode to the certified chain and none slashes a false post. The rejected list still says why: "availability response as a DA post (the inbox cannot check derivation)" (preconf.html §17).

**Actors.** Leader L plus Q attesters of committee(t): 22 seats at m = 32, 7 at m = 10 (F1). Nothing at risk.

**Trace (t = termStart).**
1. t .. t + 60: L builds h+1..h+60 privately; the Q colluders certify privately; honest attesters time out after 5 s but cannot reach Q.
2. t + 62: the cartel signs and records TERM_END VC(t, 0, lock h+60). leader(t+1, 0) must build on h+60 (V2), which it lacks: pending-parent, PENDING_TTL. Stall.
3. t + 65: anyone calls demandData(C(h+60)), 0.05 ETH.
4. Before t + 1,865: a cartel member calls answerDemand(certHash, h+1) with six blobs of arbitrary bytes. Recorded; slashAvailabilityDefault reverts forever; the certificate is never voided; the fee is kept.
5. L lands the private range within LAND_WINDOW (it holds the data), keeping a full minute of stale-state MEV on transactions users submitted blind (W2), or never lands: replacement opens at ≥ 35 min and needs Q of the current committee, refused whenever the cartel holds Q again.

"in which case nobody transacted on private state" (preconf.html:89) is wrong: users' transactions were ordered against state they could not see, the TH6 amplification the design claims to remove.

**Design text (verbatim).** "a valid response is either a landing covering the certified height or a data post answerDemand(certHash, blobs): the canonical blobs of the range from lastLanded + 1 to the certified height, attached to an L1 transaction whose hashes the inbox records against the demand (no proof needed: availability, not validity, is what S7 protects ...)" (preconf.html:89).

**Cost / gain.** One blob transaction per demand, no bond. The 23-seat price becomes zero; the stall grows from 30 min to a replacement window per cartel term; a term of private MEV whenever L is in the cartel. Needs Q colluders, reachable at a 20 % share per F1.

**Fix.** Bond the data post and slash it on a guest decoding proof that the posted bytes' end header hash ≠ cert.phHash (no execution needed); or accept posts only from bitmap members' keys with the same offence; or suspend S7 while a lander has announced an attempt.

### F3. The round-1 F8 fix is nominal: the opening object is in no signed object except a view's first header, and S3b was left out of the key list, so honest replacement is still class-A slashable with a 2,000-TAIKO bounty per victim

**Severity: Medium** (F8's fix is inadequate). R6, P6 (TH8). Consequence: no rational attester signs a REPLACE, so an unprovable or withheld head range stalls to the 34-hour horizon or dead mode instead of ~35 minutes.

**Rules.** The revised keys read "(chainId, term, view, vcHash, height)" (S1), "(t, v, vcHash, height)" (S3a), "(t, v, vcHash, kind)" (S3c). The signed objects carry no such field: `A_i = BLS(sk_i, keccak(DOMAIN_ATTEST ‖ chainId ‖ t ‖ v ‖ height ‖ phHash))`, `TO_i = BLS(sk_i, keccak(DOMAIN_TIMEOUT ‖ chainId ‖ t ‖ v ‖ kind ‖ lockHeight ‖ lockPhHash))` (preconf.html §1), and `PH.vcHash` is "non-zero only on a view's first block". For later blocks the contract reads vcHash = 0 in both tail and fork; the keys collapse to (t, v, height). S3b names no opening object.

**Actors.** Honest holder H of view (t, v); honest attesters; challenger X (anyone).

**Trace.**
1. t + 0..40 s: H produces ℓ+1..ℓ+40 under VC_0; attesters attest; ℓ+40 carries C(ℓ+39). A guest bug makes ℓ+5 unprovable; nothing lands.
2. termEnd + 2,100 s: A1 holds. Per landing A2, H reopens (t, v) with a REPLACE VC, lock = lastLanded = ℓ; attesters sign TO_i(t, v, REPLACE, ℓ, phHash_ℓ); H signs fork headers ℓ+1', ℓ+2'; attesters attest them.
3. termEnd + 2,110 s: X submits `slashLockLie(TO_i(REPLACE, lock ℓ), header ℓ+2, attestation_i(ℓ+2))`: "a timeout or VC signature by key i with lock L, plus an attestation by i on a header of the same term at a view ≤ v whose carried certificate is above L" holds verbatim. Class A; X credited 2,000 TAIKO; repeat for all ≥ Q signers.
4. Same block: `slashSequencerEquivocation(header ℓ+2, header ℓ+2')`: equal (chainId, t, v, vcHash = 0, ℓ+2), different phHash: H loses its ledger; `slashAttesterEquivocation` likewise.
5. Each step is the accused's own signature; a cartel attester co-signs the REPLACE and self-reports its honest co-signers first.

**Design text (verbatim).** "a REPLACE or RESUME reopens the same view number with a new opening object, so every equivocation key below includes the opening object." (preconf.html:27) against "vcHash: keccak of the view change ... that opened this view; non-zero only on a view's first block." (bridge-migration.html:26) and the S3b row (slashing.html:44).

**Cost / gain.** Gas only. 2,000 TAIKO per honest key, up to 23 per replacement, plus ≥ 460,000 TAIKO of honest bonds burned; then replacement is dead and a withholding cartel (F2) or poison range holds the chain behind lastLanded.

**Fix.** Put the view's vcHash in the attestation and timeout domains and in every PH; compare S3b locks within one opening object only, or exempt REPLACE/RESUME and slash a REPLACE timeout iff A1 did not hold at its L1 reference.

### F4. Round-1 fixes F3 and F7 were not propagated to every page: five sentences still make a timeout a strike and one table still sets ROLE_HORIZON to two hours

**Severity: Medium** (internal contradiction; if the un-revised sentences are implemented, F3 (High) returns). Requirements R6, R1; threat TH8, TH9.

**Contradictions, verbatim.** Strikes from timeouts: "Every certified absence against a view: 50 TAIKO burned, one strike; three strikes in a week → suspension from τ + 22 min, doubling per strike." (sequencing.html:86, the takeover figure); "TH3 absent holder: defended. Replacement within TIMEOUT per dark view, void views free; 50 TAIKO burned and a strike per event." (sequencing.html:188); "the inbox burns 5·10^19 wei from A and adds one strike" (slashing.html:104, worked example MISS); "Holders all offline. A VC per view, 50 TAIKO plus a coalesced strike, suspension within a week" (slashing.html:195); "TH3 silent sequencer: defended. ... cost is forfeited rewards and a strike" (preconf.html:175); "Cost: the absence penalty and a strike." (forced-inclusion.html:142) and "pays 50 TAIKO plus a strike" (forced-inclusion.html:172). Against: "A timeout never changes eligibility: it adds no strike and triggers no floor check" (sequencing.html:92) and the parameters page. The `MissPenalised` events on three pages still carry a `strikes` field. Horizon: "ROLE_HORIZON | s | 7,200 | recordCommittee and MISS need exact roles until an hour past the hard deadline" (slashing.html:171) and "recordCommittee(t) within two hours of the term's start" (slashing.html:26) against 122,880 s everywhere else; K_MIN: "below four eligible attesters" (index.html:67) against K_MIN_CERT = 8. Also the anti-monopoly sentence "the honest 21 then time out honestly, a true VC forms" (slashing.html §5) is arithmetically impossible: a VC needs Q = 22 signatures, so the 11 abstainers decide whether the victim bleeds (they co-sign) or the term is simply dark and closed by a penalty-free FALLBACK.

**Consequence.** An implementer reading the takeover figure, the TH3 lines or the worked example builds the strike-from-timeout ladder that round 1 showed hands an 11-of-32 minority (or, per F1 above, a 20 % cartel in most launch-sized terms) a removal power over honest operators; an implementer reading the slashing table pins committee evidence to two hours, reopening F7's time-based void.

**Suggested fix.** Make the parameters page normative and delete or hyperlink every duplicated number and rule; a one-line grep for "strike" and "7,200" on each revision.

### F5. FI_SKIP ages due-ness, not head position, so under a backlog it voids every forced inclusion that waited four hours while landings continue: L8's "bounded delay" becomes deletion and the proven "only after four hours without any landing" claim is false

**Severity: Medium** (priced griefing that turns the censorship guarantee from delay into loss; builds on F4's fix). R7 / P4, P5; TH7.

**Rules.** `skipped(i, T)` holds "for the head entry of either kind when it has been due for FI_SKIP = 14,400 s (4 h) of anchored time without being consumed" (forced-inclusion.html §2); due-ness starts at savedAt + FI_DELAY, not on reaching the head. Entries drain at 2 of 3 one-second blocks (2,400 per hour), so an entry with > 9,600 ahead is void on becoming head whatever landed meanwhile. §12 prices that depth as "a bounded delay".

**Actors.** Stuffer S (optionally a cartel with seat share c, whose sequencers receive consumed fees); victim V, a forced-inclusion requester (a bridge exit). No bond.

**Trace (relative to V's save).**
1. −4 h .. 0: S posts calldata entries until 9,600 are pending: Σ 0.001 × (50 + p)/50 ≈ 931 ETH plus ≈ 1.9 B gas.
2. 0: V saves entry i (≈ 0.19 ETH at that depth); due at +300.
3. 0 .. +4 h: the chain lands normally; V8 forces two FI blocks in three; the head advances 2,400 per hour; S adds 2,400 per hour (≈ 460 ETH/h) so i still has ≥ 9,600 ahead. Every landing consumes a due head entry, so the design's stated precondition holds throughout.
4. +4 h + 300 s: i becomes head at a parent with anchored time T_p ≥ savedAt_i + 14,700. skipped(i, T_p): anchor-only block, payload never executed, fee to the includer (S's sequencer with probability c). V must notice and re-post at the back of the backlog; a relayer bot with a fixed retry budget does not.
5. Every other user's entry in the window is voided the same way; the forced path is dark while S pays and includers collect the fees.

**Design text (verbatim).** "it can only fire while no landing of any kind has happened for four hours, because any landing must consume a due head entry." (§2); "proven FI_SKIP can fire only after four hours without any landing, because every landing path must consume a due head entry; so it never skips an entry a live chain could have included." (forced-inclusion.html:189).

**Cost / gain.** ≈ 931 ETH plus ≈ 460 ETH/h, minus the share c recouped; comparable to the ≈ 2,100 ETH the design accepts for six hours of delay, but P5 ("included by a bounded L1 time regardless of sequencer behaviour") now fails for every user in the window. Without stuffing: any four-hour landing stall (a fee spike above the 400-gwei break-even, F1's no-committee race) voids the whole queue's content on resumption, since ANCHOR_MAX_AGE forces the resuming holder to anchor within 30 min of now.

**Fix.** Age the skip from when the entry became head-and-due (store headSince), or gate `skipped` on `T − lastLanded.anchorTipTimestamp ≥ FI_SKIP`, which is what the claim says.

## What I tried and could not break

1. **Excluding an entrant by front-running its `register(seats[])`.** The entrant must name an index "equal to the scheduled array length" (sequencing.html:45), so an incumbent that appends one seat in the same L1 block makes the entrant's transaction revert. Stopped by cost: each front-run locks a fresh 20,000 TAIKO for 2 h + 7 d (exit lock), the entrant retries every block for gas only, and it can submit through a private relay or FOCIL. A wording fix (register by count, index assigned by the contract) would remove the race entirely; recorded here, not as a finding.
2. **Seed grinding or exit timing to keep an entrant out of a cycle.** Rule D (DELAY_REG = 7,200 s > CYCLE + LOOKBACK − TERM) and RND3 freshness: no write after freshFrom(c) affects cycle c, and a stale seed needs 41 minutes with no landing and no `poke()`, which anyone can call.
3. **Handoff ambush (W1) under the revised opening-object keys.** Still needs a second VC for the same (t, v, kind) with a higher lock, i.e. 2Q(m) − m S3c double-signers, and the honest TERM_END VC is recorded on L1 within seconds; F3 only weakens the keys against honest replacement, not in the attacker's favour, because the attacker's second VC has the same kind and the same (zero) vcHash.
4. **Deferring a forced inclusion with four-view landings.** L8's T_floor is taken from the landing's term id; a lazy censor landing four terms at once shifts the mandatory consumption by at most three terms (3 min), inside the 102-minute argument. Whether termId means the first or last segment should be stated (LandInput has a top-level termId on the landing page and only segments[] on the interfaces page), but no trace exceeds the bound.
5. **Absence bleed as an exclusion lever below the T11 boundary with a dispersed honest set.** With 40 single-seat honest owners the veto probability at c = 0.2 is the binomial 4 % the design states; 200 draws at that rate is months and the victim can top up. The lever only becomes fast when honest seats are concentrated (F1).
6. **Opening dead mode or the sentinel-255 race on a live chain with a full committee.** DEAD_TERMS × TERM = 75 min > LAND_WINDOW_MAX + ABANDON_GRACE, and view 255 is refused unless the term is open-empty, no-committee or dead (landing L4). The race exists only in no-committee terms (F1).
7. **Using S4a or S7 against a holder or committee I censored.** S4a needs a quorum object above what landed, the hard deadline and the outage gate; S7 needs a certificate the victims signed and a demand nobody answered. A cartel can only spend its own seats to certify garbage and thereby cost an honest leader one seat, at 22:1 against itself.
8. **Voiding a specific forced inclusion through the forced batch's lander-chosen anchor.** After a real four-hour landing stall the forced-batch lander can pick a fresh anchor (content skipped) or an old one (content kept), but a four-hour stall cannot be manufactured by the attacker: the requester itself lands a forced batch at replaceableFrom (≈ 40 min).
9. **Premature view change with fewer than Q colluders.** A VC needs Q(m) signatures; below Q the colluders can only abstain (F1's veto), never form a VC alone. Above Q it is the accepted L4.

Nothing in the steal surface was re-examined here beyond what F1 to F3 imply; the steal goal has its own report this round.
