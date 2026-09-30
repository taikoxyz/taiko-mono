# Etna red team, round 2: goal STEAL FUNDS

## Model
claude-sonnet-5-5 (Sonnet 5.5), the requested sonnet model.

## Method
1. Read every design page (index, roles, sequencing, preconf, landing, slashing, forced-inclusion, bridge-migration, interfaces, parameters, arguments, l1-dependencies, frame-transactions, limitations, glossary) converted to text so sentences could be quoted verbatim; read 01-threat-model.md (T-assumptions, section 8), the round-1 report 01-round.md, the judge report 01-judge.md and the round-1 halt/steal/censor reports so no known finding (F1-F10) is repeated.
2. Listed every rule that moves or destroys TAIKO/ETH (lander ramp, attester reward, lander bonus, reporter share, S1-S8, MISS, FI fees, demand fee) and for each asked: (a) can a party that did no work satisfy the trigger, (b) can an honest party be made to satisfy an accusation predicate, (c) is the evidence format, as written, strong enough to enforce the sentence that justifies it.
3. Checked evidence structs and message formats field by field against the equivocation keys the F8 fix requires; checked outage-gate arithmetic against the stated 2-3 minute landing lag; checked cross-page constants; checked repository code only for the legacy forced-inclusion queue layout (cited file:line).
4. Every finding is written below as soon as it was complete. Trace times are L1 seconds; E = termEnd of the first unlanded term t'; X = time of the last landing before a stall.


---
## S1. (High) The S3a certificate-pair rule, as written, slashes honest attesters: it never requires the two certificates to differ, and no certificate/attestation format carries the opening object
Requirement: R6, P6 (no false accusation); TH8. Builds on F8: the F8 fix is prose only and cannot be enforced by the evidence formats.

Trace (no collusion needed; the pair exists in normal operation):
1. Term t, m = 32, Q = 22. Block h is honestly attested by 30 of 32 seats (gossip topic is public). The next block carries certificate C_a (bitmap A, 22 bits) built by the leader; the lander of the range builds the end certificate C_b (bitmap B, 24 bits) from other gossiped attestations and puts it in L1 calldata. Both are valid, same (t, v, vcHash, height), same phHash.
2. Attacker N (no seat, no bond) calls slashCertificatePair(C_a, C_b, committeeProof) at about t+150 s. The row's checks are "root check; popcount >= Q both; two aggregate verifications". Nothing requires phHash_a != phHash_b, and Certificate {termId, view, height, phHash, bitmap, aggSig} carries no vcHash to compare.
3. "every key in both bitmaps ... is slashed", class A: 100 % of each owner's ledger, seats ineligible, exit only. Intersection here is about 16 honest keys. By choosing which two of the 30 available attestation subsets to aggregate, N can make the intersection up to 29 keys.
4. Repeat for every term within the 34 h ring: after a few calls the whole honest registry is burned and the attacker's own seats hold 100 % of sortition.

Design text (verbatim): "two valid certificates at one (t, v, vcHash, height)" with verification "root check; popcount ≥ Q both; two aggregate verifications; every key in both bitmaps (≥ 2Q − K = 12 by pigeonhole) is slashed". The single-attestation row, by contrast, says "different phHash"; the pair row omits it. Also: "Attestation A_i = BLS(sk_i, keccak(DOMAIN_ATTEST ‖ chainId ‖ t ‖ v ‖ height ‖ phHash))" and struct Attestation {termId, view, height, phHash, attesterIdx, sig}: vcHash is in neither, so "every equivocation key includes vcHash" (F8 fix) cannot be checked by the contract.

Cost/gain: about 600k gas (about 0.006-0.012 ETH). Attacker earns min(10 %, 2,000) = 2,000 TAIKO per call (0.3 ETH); honest owners lose 16-29 whole ledgers (each >= 21,000 TAIKO per seat, tens of ETH per call), plus the sybil's route to 100 % of terms (TH9).

Fix: require phHash_a != phHash_b in S3a-pair and S6-certificate forms; add vcHash to Attestation, TimeoutMsg and Certificate messages (sign it) so opening-object equality is checkable on L1; add a test "two valid certificates over one header slash nobody".

---
## S2. (Medium) The outage gate is satisfied by the last pre-outage landing, so a chain-wide outage slashes the lagged holders; the "proven" claim is false
Requirement: R6, R7; TH8, TH13. Builds on round-1 F5/F6 (which assumed the gate "closes"); not repeated, the gate itself is the flaw.

Trace: steady state, landing lags blocks by 2-3 minutes (landing page: "Happy-path 'landed' latency ≈ 2 to 3 minutes").
1. t = 0: landing L0 lands through height b. The first unlanded block is about 120 s old, in term t' that ended at E ≈ -60 s. Then the proving fleet (or blob market above the break-even fee, TH13) stops; nothing lands for over an hour.
2. Hard deadline for t' = E + 3,600 = 3,540 s. The gate asks "some term landed within OUTAGE_WINDOW (60 min) before the hard deadline", i.e. in [E, E+3,600] = [-60, 3,540]. L0 at t = 0 is inside.
3. t = 3,541 s: anyone calls reportAbandoned(t', v, cert, cp, landedTermRef = t'-1). All conditions hold (certificate above landed, deadline passed, bit clear, gate passes). Holder of t' is debited 2,000 TAIKO (also t'+1, whose end coincides with X): reporter 200, 800 escrowed to the next ordinary lander, 1,000 burned.
4. The chain-wide outage slashed honest holders; the gate closes only if the outage begins before E, i.e. with zero landing lag.

Design text: "the outage gate passes: some term landed within OUTAGE_WINDOW (60 min) before the hard deadline, so a chain-wide proving or L1 outage slashes nobody" (landing A4) and "proven A chain-wide outage slashes nobody: S4a and S7 require a landing inside the outage window" (slashing §15). The glossary states a third wording ("a landing within the previous hour"), and the worked example implies a LATER term landed.

Cost/gain: reporter about 200 TAIKO per view plus, if first to land after recovery, 800 per view; victims lose 2,000 each (about 2 per outage, more with backups). No attack cost beyond gas 320k per report.

Fix: gate on a landing of a strictly later term than the reported one (only possible after a replacement), matching the worked example: require _landedTermRef > t. Restate the glossary.

---
## S3. (High) An outsider can reorg a stalled backlog of locked blocks with a forced batch, put its own transaction first, and farm the S4a payouts; L6's "replacer gets no share" mitigation does not hold
Requirement: R6, R7, P2; TH2, TH7, TH13. Builds on L6/L14 (accepted) and F6; the additions are the outsider trigger, the ordering, and the payouts.

Trace (stall of at least 35 minutes: prover outage, or a blob/fee spike above the published break-even where the design says landing "waits"):
1. Backlog: certified and "locked" L2 blocks above lastLanded for ≥ 35 min (about 2,100 blocks). Attacker A (no seat, no bond, no committee role) deposits 100 ETH-equivalent on L2 to a merchant/CEX in that backlog (tx1); the counterparty credits at "locked". A also files saveForcedInclusionCalldata(tx2: send the same funds elsewhere), fee ≥ 0.001 ETH, due after 300 s.
2. At E + 2,100 s: A1 holds (min(E+3600, max(E+1800, X+600)) + 300). A lands a forced batch: block.timestamp > replaceableFrom(), m = 1 anchor+FI block, rewardTo = A, ZK_K = 2 proofs of one block, ≈ 1.2 M gas. No rights, certificate or holder involvement.
3. Every certified block above lastLanded is void; tx2 executes first on the pre-stall state; the resumer's re-inclusion of tx1 fails. Double spend.
4. Reports: the forced landing does not waive terms whose deadline had passed. About the first 5-6 views (end < E+300) are reportable after their hard deadlines; the first ordinary landing after the forced batch opens the gate (S2). A files the reports (10 % each) and lands the resumed chain's next ordinary batch, collecting the 40 % escrow: about 50 % of 6 × 2,000 = 6,000 TAIKO.

Design text: "Mitigations: the replacer gets no penalty share; landing the backlog pays the maximum per block and is more lucrative" (landing §12); "Waiver: ... an abandoner, whose deadline passed before the forced landing, stays reportable" and "a forced batch never opens the gate" (forced inclusion §7); level table: locked is revertible "by batch replacement at the landing deadline".

Cost/gain: FI fee 0.001 ETH + forced landing ≈ 0.02-0.05 ETH + proving; gain ≈ 0.9 ETH reporter/bonus plus the double-spend up to what counterparties credit at "locked" (the published 39 ETH bound covers only the slashing route). Victims: about 6 honest holders (12,000 TAIKO) plus every user in the backlog.

Fix: forbid forced batches (and REPLACE) while any certified range above lastLanded is landable with a proof attempt in flight; give the reporter share only for views voided by a REPLACE by their own holder; order the resumed chain's re-inclusion before forced entries older than the void; publish the "unpunished revert" bound beside "locked".

---
## S4. (Medium) A "canonical-blob data post" cannot be checked on L1, so any Q+1 colluders answer an S7 demand with junk blobs and keep their 23 seats
Requirement: R6; TH5, W3. Builds on F5: its fix (data post answers a demand) is inadequate.

Trace (needs Q+1 = 23 colluders in one committee, the case S7 exists to price, priced at 460,000 TAIKO):
1. Leader L and 22 attesters certify blocks h+1..h+k that only they hold; a VC locks on them. Honest attesters cannot sign a VC at that lock; the next leader cannot extend it.
2. Honest D calls demandData(C(h+k)) paying 0.05 ETH at t = 0.
3. t = 12 s: a colluder calls answerDemand(certHash, firstHeight) with any 1-6 blobs (random bytes, cost about 0.001 ETH). The inbox "records" the blob hashes against the demand; it has no way to know what the canonical bytes are (the certificate names only phHash), and there is no dispute step.
4. At t = 1,800 s slashAvailabilityDefault reverts: a data post exists. The demander's 0.05 ETH is not refunded (refund only on default). The certificate is never voided, so no FALLBACK VC at a non-voided lock; the term stays wedged until A1 lets the holder REPLACE (35-65 min after the term ended), not 30 min, and the colluders pay at most SLASH_ABANDON 2,000 instead of 23 × 20,000.
5. Repeat whenever they again hold Q+1 seats in a committee.

Design text: "a valid response is either a landing covering the certified height or a data post answerDemand(certHash, blobs): the canonical blobs of the range ... attached to an L1 transaction whose hashes the inbox records against the demand (no proof needed ...)". Contradiction: preconf §17 lists as rejected "availability response as a DA post (the inbox cannot check derivation)", and the glossary still says S7 is "answered only by a landing within 30 minutes".

Cost/gain: colluders save 460,000 TAIKO (about 69 ETH) of exposure per stall for ≈ 0.001 ETH; the demander loses 0.05 ETH.

Fix: a post answers only if its blobs' versioned hashes are committed by something the certificate binds (add blobHashesRoot of the range to the signed header, or require a KZG-checkable link); otherwise require a proof-carrying landing and instead handle the unprovable-honest case by suspending S7 while a replacement is pending.

---
## S5. (Medium) Bond erosion to the 50 % hard floor is free (self-directed lander/attester payments), halving every published credit bound; "Sybil invariance" and the 13 × B figure are false
Requirement: R6; TH4, TH9. 

Trace: cartel owner X holds s seats, ledger 1.05 × s × 20,000.
1. X (as holder in its drawn terms) does not land; its alter ego Y (a seatless address or a second owner) lands X's blocks at term end + 30 min: reward 60 × 24 = 1,440 TAIKO per term, debited from X, credited to Y's ledger (withdrawable at once: "Credits to addresses with no seats and no key history are withdrawable immediately").
2. Liveness debits "never trigger that check", so X stays eligible until the ledger touches 0.5 × floor: it moves 0.55 × s × 20,000 = 11,000 TAIKO per seat to Y for only the gas Y would pay anyway (reward 0.216 ETH per term vs 0.015-0.05 ETH gas). About 5 h at launch (40 seats, 8 seats owned), about a day at 200 seats. Faster: X signs a RewardBoost (no cap is stated), or self-reports S4a (net loss 1,000 of 2,000).
3. Later X's 12 colluding seats revert a locked block: class A takes "the whole ledger" = 0.5 B per seat, so the cost is 13 × 10,000 = 130,000 TAIKO (19.5 ETH), not 260,000; S7 costs 230,000 not 460,000.

Design text: "A safety or structural debit below the floor triggers open-ended suspension until top-up. Liveness debits (absence, abandonment, reward payments) never trigger that check; ... a hard floor at 50 % is the backstop." and "Sybil invariance. Class A takes the whole ledger and the floor is seatCount × B, so an owner with m committee slots loses ≥ m × B whatever the seat split." and "≥ 13 × B = 260,000 TAIKO ≈ 39 ETH ... the published credit bound for 'locked'".

Cost/gain: no cost; the cartel halves the price of the attack the bound protects against.

Fix: make eligibility require ledger >= floor for reward-type debits too (reward debits cap at the buffer, above the floor), or publish the bound as 13 × 0.5 B; cap RewardBoost at R_BLK_MAX.

---
## S6. (Medium) rewardTo is not bound to the proof, so a free rider or the L1 builder copies a landing and takes the lander reward; "copying a mempool proof steals nothing" is false
Requirement: R7, R6; TH2, TH11 (extract lander reward without doing the work).

Trace: holder H's prover is down; the ramp reaches 24 TAIKO per block.
1. Prover P (paid nothing unless it lands) spends GPU time on two ZK proofs for a 60-block term and submits land(LandInput{..., rewardTo = P, proof}) (public type-3 today; direct-to-builder frame shape later).
2. Free rider F (or the builder that sees the transaction) reads calldata and the blob sidecar, resubmits identical calldata with rewardTo = F and a higher tip. No proving is needed; blob bytes are "a pure function of the certified chain".
3. F's landing is first: reward 1,440 TAIKO (0.216 ETH) is debited from H and credited to F; P's transaction is NotNext (invalid and free under frames, 25k gas plus a blob fee without). P earns nothing. In equilibrium nobody proves for the reward; only holders self-land, so R7's third-party landing path collapses.

Design text: "The journal names no lander; proofs are fungible, so copying a mempool proof steals nothing." and leaf input "hashPublicInputs(journalHash, leaf, address(0), chainId)" (the address slot is unused). The forced-batch page does bind it: "Binding rewardTo into the forced journal means a mempool copy of the proof cannot redirect the fees."

Cost/gain: F pays 1.5-2.5 M gas (0.015-0.05 ETH); gains up to 0.216 ETH per term, minus nothing for proving; P loses proving cost plus 25k gas.

Fix: bind rewardTo into the journal (or the leaf's address slot) for ordinary landings as for forced ones; accept that proofs become per-lander.

---
## S7. (Medium) Contradiction: the F3 fix ("a timeout never strikes, never floor-checks") is contradicted in eight places, and implementing the wrong ones re-arms the F3 weapon
Requirement: R1, R6; TH3, TH8, TH10. Consequence rated by what an implementer following the stale text builds (High if built).

Stale statements: slashing §7 worked example "the inbox burns 5·10^19 wei from A and adds one strike"; slashing §12 "50 TAIKO plus a coalesced strike, suspension within a week"; sequencing §12 "50 TAIKO burned and a strike per event"; preconf §12 "cost is forfeited rewards and a strike"; forced-inclusion §12 and §14 "the absence penalty and a strike" / "50 TAIKO plus a strike"; the events MissPenalised(..., uint8 strikes, bool coalesced) in both interfaces; and sequencing §7 "Bond floor: after an absence or evidence debit, a bond below seatCount·B_SEAT means open-ended suspension until top-up plus reactivate()", with slashing's BUFFER_BPS rationale "20 misses before the floor". Against: "A timeout never changes eligibility: it adds no strike and triggers no floor check" (sequencing §7) and "Liveness debits ... never trigger that check" (slashing §1).

Trace if the strike/floor reading is implemented: 11 abstaining committee seats (inside T11) time out a one-seat honest owner at 105 % buffer 20 times (about 20 of its drawn views); its ledger is below the 100 % floor, so it is SUSPENDED_OPEN until top-up. With strikes: three coalesced strikes suspend in three views. Cost to the cartel: its own attester income only. This is exactly F3.

Cost/gain: griefing that removes honest share; the cartel's share of terms rises.

Fix: delete every strike/coalesced reference to MISS, drop the strikes field from MissPenalised, make sequencing §7 read "structural or safety debit", and fix the BUFFER row to say 220 misses to the hard floor.

---
## S8. (Medium) Contradiction: the forced-inclusion queue is "kept with the same struct" but FiEntry is a different two-slot layout; legacy requests decode to garbage and lock their ETH
Requirement: R2 (in-place upgrade), R6; TH7 across the cut-over; M4 ("Forced inclusions keep their save time and fee").

Trace: pending Shasta requests exist at cut-over. Legacy layout (IForcedInclusionStore.sol:10-15, LibBlobs.sol:21-28, LibForcedInclusion.sol:28): mapping value = {uint64 feeInGwei; BlobSlice{bytes32[] blobHashes; uint24 offset; uint48 timestamp}} = slot k: feeInGwei; slot k+1: array length (1); slot k+2: offset|timestamp; hash in the array's data slot. Etna FiEntry {bytes32 dataHash; uint48 savedAt; uint96 feeWei; kind; uint24 offset} "// 2 slots" read at the same keys gives dataHash = the fee in gwei, savedAt = 1 (the array length), feeWei = 0, kind BLOB. Such an entry is void at once (savedAt + FI_EXPIRY ≤ T), derives to an anchor-only block, fee 0 "to the includer".

Design text: "255-256 the forced-inclusion queue, kept with the same struct so pending requests survive; per-entry extras in a parallel mapping" versus interfaces "struct FiEntry { bytes32 dataHash; uint48 savedAt; uint96 feeWei; FiKind kind; uint24 offset; }   // 2 slots"; and "pnpm layout must show slots 251-257 byte-identical".

Cost/gain: no attacker gain; each pending requester loses its request and its escrowed ETH stays in the Inbox (the ETH invariant "balance = Σ unconsumed FI fees" breaks). A second, related contradiction: roles §5 "void with refund after seven days ... refunded on void" versus forced inclusion §8 "No split, no push, no refund" and §2 "its fee goes to the includer".

Fix: keep the legacy struct type at slots 255-256 and migrate lazily through a version tag in the parallel mapping, converting feeInGwei × 1 gwei; state one refund rule.

---
## S9. (Medium) Sentinel-view (255) sequencers have no opening object that can change, so a landing race silences or equivocation-slashes the loser; any bonded address may sequence a no-committee term
Requirement: R1, R6; TH4, TH9. Builds on F8 (the fix covers committee views only).

Trace (no-committee mode, e.g. at launch with fewer than 8 non-holder seats; the same holds in open-empty and dead mode):
1. Sortition holder A signs blocks h+1..h+30 in (t, 255, marker O), certificate-free.
2. Attacker B (bonded 20,000 TAIKO, code-less key, no seat) signs one block h+1' in (t, 255) on lastLanded and lands it with two ZK proofs (about 1.5 M gas). L4 accepts it: "with the sentinel view 255, the term must be open-empty, in no-committee mode, or the chain in dead mode, and the sequencer bonded". Nothing checks isHolder.
3. A's blocks are void. To continue A must sign height h+2 again with the same key and the same (t, 255, O): S1's key (chainId, term, view, vcHash, height) matches, phHash differs. A's slashing-protection record refuses (A silent for the rest of term t); a client without it loses 100 % of its ledger to B's S1 call (B nets 2,000 TAIKO).
4. Anchor A5 "(termId, view) changes iff vcHash ≠ 0 ... within a view none" forbids a fresh marker inside the same (t, 255), so no reopen exists; the "dead-mode marker" is never defined.

Design text: sequencing §6 "the holder is still chosen by sortition, but no certificates exist, landings are accepted with an empty certificate under the same rules as dead mode" versus landing L4 above; glossary "No-committee mode ... sortition holders".

Cost/gain: B pays about 0.015 ETH per term to displace the sortition holder from all no-committee terms (revenue V_term ≈ 0.01 ETH per term, plus S1 loot 2,000 TAIKO when the client lacks protection). A also affects the REPLACE case where the parent is in the same (t, v): A5 then rejects the REPLACE first block.

Fix: define the marker as keccak(lastLanded.blockHash, t) so a fork after a landing is a new opening object, allow it in A5, and require isHolder for view 255 in no-committee terms.

---
## S10. (Low) Internal contradictions between pages (constants and signatures)
- ROLE_HORIZON: slashing §10 "ROLE_HORIZON | s | 7,200" and §1 "recordCommittee(t) within two hours" versus parameters "ROLE_HORIZON 122,880 (34 h)". If implemented per slashing, committee-dependent evidence for terms older than 2 h is unattributable, silently weakening S3a-pair, S4a and S7 for exactly the long-stall cases.
- 2Q(m) − m at m = 8 is 4, not 2 (Q(8) = ⌊16/3⌋ + 1 = 6): preconf §1, sequencing §8, parameters and K_MIN_CERT's rationale ("2Q − m = 2 at m = 8") are wrong (conservative); "2" occurs at m = 4.
- Frame page "landFor(address actor, bytes32 packedInput)" with a 68-byte SENDER frame versus landing page "landFor(address _rewardTo, LandInput calldata _in)": the public-mempool shape cannot carry the proof; the frame page also requires "An expected batch id in the input", while the anchor page states a batch id is "deliberately absent".
- Parameters chain line "DEAD_TERMS·TERM > LAND_WINDOW_MAX + ABANDON_GRACE = 4,500 s": the sum is 3,900 s; 4,500 s is DEAD_TERMS·TERM.
- Glossary "Availability escalation ... answered only by a landing" versus the data-post answer (S4).
Severity Low: no direct loss, but each is a place where two implementers diverge.

---
## What I tried and could not break
1. False finalization via single-proof mode (arm it after 2 h, forge one leaf): stopped by L5, the end block hash must equal a certified header whose state root Q attesters executed; a forged leaf cannot change the certified root (T11 needed).
2. Redirecting FI fees of a forced batch by copying a mempool proof: stopped, rewardTo is bound into the forced journal (forced inclusion §6).
3. Making a proven landing revert through the FI queue or stuffing: stopped by anchored due-ness and pull fees; stuffing is quadratic and bounded.
4. Skipping a due FI entry via FI_SKIP: stopped, every landing path must consume the head, so skip fires only after four hours without any landing (under T11).
5. Griefing S1 by replaying a valid signed header: stopped, S1 needs the accused key's own two signatures; committee views are covered by vcHash in the header (but see S1/S9).
6. Stealing a bond by exiting before evidence: stopped, every evidence window ends by termStart + 7 d and exit waits 7 d past activeUntil; S3a-pair's 34 h ring is shorter than the lock.
7. Draining the attester reward by splitting a range into 1-block landings: stopped only by the gas floor (6 TAIKO per landing against 1.3-1.5 M gas); profitable below about 0.5 gwei, so it is a latent lever, recorded here rather than as a finding.
8. Rogue-key framing: stopped by proof of possession; residual (not a theft): the PoP is not bound to the owner and no uniqueness is stated, so registerKeys can be front-run from the mempool by a bondless address (a censorship item for the censor goal).
9. Forging a checkpoint through a false anchor: stopped by the guest's header chain to the tip and the L1 blockhash/EIP-2935 check.
10. Claiming the challenger share by self-reporting: stopped by the 10 %/2,000 cap against class A/B debits (net loss).
11. Unpunished pair-slashing across owners with shared keys: not pursued, the key-owner map is single-valued.
