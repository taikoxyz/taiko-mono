# Etna red team, round 3: STEAL attacker

## Model

I am running as Claude Fable 5.1 (model id `claude-fable-5-1`), the model the harness requested.

## Method

1. Read every design page fresh (index, roles, sequencing, preconf, landing, slashing, forced-inclusion, bridge-migration, interfaces, parameters, arguments, l1-dependencies, frame-transactions, limitations, glossary), the threat model (01), the README, and the learn/ site, plus the round-2 iteration files to avoid repeating known findings.
2. Goal: STEAL. For every slashing rule (S1, S3a single/pair, S3b, S3c, S3d, S4a, S6, S8, MISS) I matched the evidence struct on the interfaces page against the message format on the preconf page and asked: (a) can an honest signer be made to satisfy the accept set, (b) can the payout be farmed, (c) does any two-page inconsistency open an accept set the rules page does not intend.
3. Treated the S4a outage gate, the void waiver, `announceLanding`, the forced batch, REPLACE/RESUME and S3d as one state machine and walked it as an attacker who holds one seat (20,000 TAIKO) and a lander address, looking for a transfer of value from honest parties.
4. Walked the reward paths (lander ramp, R_BLOB, RewardBoost, attester share, lander bonus escrow, FI fee credit) for extraction without work.
5. Checked the bridge/checkpoint path for any way to write a false checkpoint.
6. Every finding below is a concrete trace with bonds, messages, times, the design sentence exploited verbatim, cost and gain. Rules out of scope (crypto breaks, malicious DAO, L1 finality failure, more than the stated malicious bound) are not used.

## Findings

### R3-S1. [High] S3d evidence is not covered by the signature: the REPLACE timeout's L1 reference is outside the signed preimage, so any challenger can attach a false reference to an honest attester's timeout and take one seat per key

Requirement: R6, P6 (no false accusation); TH8. Builds on round-2 F3 (S3d was added as the fix) and is the struct-versus-format check duty (a) asked for.

Actors: honest committee(t_c), 22 to 32 attesters with ≥ 1 seat each (20,000 TAIKO); honest current holder H_c; attacker X, no seat, no bond.

Trace (times in L1 seconds):
1. T0: last ordinary landing through height 999 (term t', E = termEnd(t')). A blob-fee spike above the published break-even follows; the design says landing "waits".
2. T1 = E + 2,100: replaceableFrom = min(E+3600, max(E+1800, T0+600)) + 300 has passed. L1 block R (number r, hash h_R) is the first with timestamp > replaceableFrom.
3. T1 + 3: H_c proposes a REPLACE reopening of its view (t_c, v, O1). Each attester checks A1 at R in its own L1 view (holds) and signs TO_i = BLS(keccak(DOMAIN_TIMEOUT ‖ chainId ‖ t_c ‖ v ‖ O1 ‖ REPLACE ‖ 999 ‖ phHash_999)). The TimeoutMsg it gossips carries l1Ref = (r, h_R), which the preimage does not include.
4. T1 + 4: the REPLACE VC forms; X collects the 22+ TimeoutMsgs from the views topic.
5. T1 + 30: X calls slashFalseReplacement(to_i', pubkey_i) for each i, where to_i' is to_i with l1Ref rewritten to (r−1, h_{R−1}), a block whose timestamp ≤ replaceableFrom. The one BLS verification passes (it never covered l1Ref); the recompute "as of that L1 block" says the predicate did not hold; class B fires: B_SEAT debited, 3 strikes (suspension 36 h), floor check. X is credited min(10 %, 2,000) = 2,000 TAIKO per key.

Design text: "Timeout TO_i = BLS(sk_i, keccak(DOMAIN_TIMEOUT ‖ chainId ‖ t ‖ v ‖ vcHash ‖ kind ‖ lockHeight ‖ lockPhHash)), kind ∈ {TIMEOUT, TERM_END, FALLBACK, REPLACE, RESUME}; a REPLACE timeout additionally names the L1 reference (number, hash) at which the replacement predicate held." (preconf §1); "S3d | false replacement | a REPLACE timeout signed by key i naming an L1 reference (number, hash) at which the replacement predicate did not hold | recompute replaceableFrom as of that L1 block from the term records (an L1 fact); one single verification | ≈ 200k | class B, one seat" (slashing §3); "struct TimeoutMsg { ...; Replace l1Ref; uint8 attesterIdx; bytes sig; }" (interfaces §1). The ViewChange struct carries no reference at all, so the REPLACE VC commits to nothing the attesters "checked".

Cost / gain: 22 × 200k gas ≈ 0.05 to 0.2 ETH. Gain 44,000 TAIKO (≈ 6.6 ETH at the assumed rate); honest owners lose 440,000 TAIKO and are suspended, so the committee that just did the design-mandated replacement is gutted. Repeatable at every replacement event.

Fix: put l1RefNumber ‖ l1RefHash into the DOMAIN_TIMEOUT preimage for kinds REPLACE and RESUME (and the forced marker for RESUME), add the reference to the ViewChange struct so L9 and recordViewChange see what was signed, require the reference to be ≥ ANCHOR_MIN_AGE old and canonical (blockhash / EIP-2935) both at attestation and at S3d, and make S3d revert when the named hash is not canonical.

### R3-S2. [High] The lock reset makes every honest attester a "lock liar": after a forced or replacement landing, the next TIMEOUT or TERM_END signature under the old opening object carries the reset lock, which S3b compares against the attester's earlier attestations under that same object

Requirement: R6, P6; TH8. Builds on round-2 F3 and S3 (the fix exempted only REPLACE and RESUME kinds).

Actors: attacker X (no seat; a forced batch needs none); honest holder H_c of the current term t_c; honest committee(t_c).

Trace:
1. T0: last landing through height 999 (term t'). Stall (fee spike or prover outage); the chain keeps certifying. By T0 + 2,400 the head is ≈ 3,400 in (t_c, 0, O), O = the TERM_END VC that opened it. Every attester i attested blocks 3,341..3,400 under O; the header of 3,400 carries C(3,399).
2. T0 − 400: X saved a calldata FI entry (0.001 ETH), due at T0 − 100.
3. T0 + 2,100: replaceableFrom passes. X builds the forced batch (one FI block, anchor A ≥ 48 s old), proves it with two leaves (≈ 3 min), lands at T_F = T0 + 2,400 in L1 block R_F. lastLanded = 1000_F.
4. T_F + 1..3: attesters' L1 clients see R_F. Per preconf §6 each voids every certificate above 1000_F and sets lock_i = 1000_F; they stop attesting H_c's chain (its parent is void). Their certificate timer keeps running.
5. T_F + 6..8: five seconds without a new certificate. The attester machine says TIMING_OUT: each signs TO_i(t_c, 0, O, TIMEOUT, lockHeight = 1000_F, lockPhHash = phHash(1000_F)). (If the term ends first, the same lock goes into a TERM_END at termEnd + 2.) H_c, which saw R_F at T_F + 4 and needs Q RESUME signatures plus a first block, has not yet reopened the view.
6. T_F + 20: X calls slashLockLie(to_i, hdr_3400, att_i(3,400), pubkey_i) for every attester: same (t_c, 0, O); kind TIMEOUT; L = 1000_F; hdr_3400.carriedCertHeight = 3,399 > L; two verifications pass; class A: the whole ledger, seats ineligible, exit only. X is credited 2,000 per owner.

Design text: "Lock reset. When a node observes a landing flagged as a replacement, or a forced landing, every certificate above lastLanded is void for it and every attester's lock resets to lastLanded" (preconf §6); "S3b compares locks only within one opening object and never applies to REPLACE or RESUME kinds" (preconf §8); "S3b | lock lie (W1) | a timeout or VC signature by key i of kind TIMEOUT, TERM_END or FALLBACK with lock L, plus an attestation by i under the same opening object (equal t, v, vcHash) on a header whose carried certificate is above L" (slashing §3); "ATTESTING(v) --timer > TIMEOUT or now ≥ termEnd+END_GRACE--> TIMING_OUT(v): sign TO_i, attest nothing in v" (preconf §10). Nothing tells an attester to sign only RESUME under the old object after a reset, and nothing exempts a lock equal to a landed forced or replacement head.

Cost / gain: 0.001 ETH + ≈ 1.2 M gas + two proofs of one block + 32 × 340k gas. Gain up to 64,000 TAIKO; every honest attester of the committee loses its entire ledger (≥ 640,000 TAIKO) and eligibility, which then pushes the chain toward no-committee or dead mode. The same trap fires after a REPLACE landing and after the late-original case of R3-S4 if the client resets locks there.

Fix: after a lock reset the only timeout kind signable under the old opening object is RESUME (also at term end, where the RESUME VC doubles as the handoff); S3b additionally ignores any timeout whose (lockHeight, lockPhHash) equals a forced-ring entry or a replacement landing's head; the attester machine gets an explicit RESET state.

### R3-S3. [High] S6 slashes every sentinel-view sequencer: the dead-mode / no-committee / open-empty opening object is a marker, not a view change, and the "VC preimage fails" form of S6 accepts it as evidence against the holder's own signed header

Requirement: R6, P6, P3 (the recovery floor); TH8, TH19. Builds on round-2 S9 (which introduced the marker as the opening object).

Actors: honest bonded party P (bond 20,000 TAIKO, code-less key) recovering the chain in dead mode; attacker X, no bond.

Trace:
1. Every registered party is dark; 75 terms pass unlanded; dead mode opens at T_D.
2. T_D .. T_D + 60: P sequences term t_D with view 255 from lastLanded H0. Per preconf §1 every header PH_1..PH_60 carries vcHash = M = keccak("ETNA_DEAD" ‖ H0 ‖ t_D). P proves with two leaves and lands at T_D + 300; the checkpoint is written; the chain is recovered.
3. T_D + 400: X calls slashInvalidNamedObject(hdr = PH_k, preimage = "ETNA_DEAD" ‖ H0 ‖ t_D, parent, ∅, ∅, ∅, ∅) for k = 1..60. Checks as written: keccak(preimage) equals the named vcHash (yes); signatures valid (ecrecover of seqSig = P, yes); preimage fails as a view change (it has no bitmap, popcount 0 < Q, it is not a ViewChange at all: yes). Class B: B_SEAT per lying key, and the duplicate record is keyed on (rule, key, term, height), so up to 60 debits of 20,000 (the first empties P's ledger) plus three strikes. X is credited 2,000 TAIKO.

Design text: "S6 | invalid named object ... | a signed or attested header whose carried-certificate or VC preimage fails (popcount < Q, wrong (t, v), height not in {n−1, n−2}, phHash not on the ancestor line, or aggregate invalid) ... | keccak(preimage) equals the named hash; signatures valid; preimage fails | ≈ 200k to 550k | class B, one seat per lying key" (slashing §3); "Every sentinel-view chain opens with the object keccak("ETNA_DEAD" ‖ lastLanded.blockHash ‖ t)" (sequencing §6); "vcHash is the hash of the object that opened the view and is carried by every block of the view" (preconf §1); "Duplicates are prevented by the owner's slashedAt (class A) or by a record keyed on (rule, key, term, height)" (slashing §3). No sentence exempts views 254/255 from S6.

Cost / gain: 200k gas per call. Gain 2,000 TAIKO per victim; the victim loses its whole bond for having recovered the chain, and every subsequent dead-mode, open-empty or no-committee holder is in the same position, so the recovery floor the liveness ladder ends on is unusable by any rational party (a liveness consequence beyond the theft).

Fix: S6 applies only to views 0..4; for sentinel views the inbox recomputes the marker itself at landing and the evidence rule refuses a header whose view ≥ 254. State on the slashing page that a marker is never a "named object".

### R3-S4. [High] A late original landing voids a certified REPLACE fork without the void waiver: the fork's honest holders pay S4a, and the lander who chose to wait collects the 40 % escrow on top of the maximum ramp

Requirement: R6, R7, P2; TH2, TH8, TH13. Mirror image of round-2 S3; the void waiver added there covers only "a forced or replacement landing" as the voider.

Actors: attacker X, any prover-lander holding proofs of the stalled backlog (the original's own holder is the natural X: it is the reserve bidder the design expects to wait); honest holders H_1..H_120 of the fork terms.

Trace:
1. T0: landing through 999 (term t', E = termEnd(t')). Blob fees rise above the published break-even; nobody lands (design: "above it landing waits"). X proves 1000..1255 etc. with rewardTo = X and holds the proofs.
2. E + 2,100: A1 holds. Current holder H_1 (term t_1 = t' + 36) forks REPLACE (t_1, 0, O_R) from 999; attesters check A1 and the passed deadline of t', attest; 1000'..1040' are certified and locked; users act on them.
3. Terms t_1+1 .. t_1+119: honest holders extend the fork through TERM_END VCs (it is the canonical chain every node follows); each term's blocks are certified and locked; nothing lands while fees stay high.
4. T_R = E + 9,300: fees fall. X lands the original 1000..1255 (four segments of the stalled terms, ramp 24 TAIKO per block up to each holder's buffer), then the further chunks. Permitted: "Until a replacement lands, landing the original stays valid and pays the ramp." Every fork view is now unlandable.
5. T_R + 60: the current holder RESUMEs at 1256''; X (or anyone) lands the RESUME batches; the outage gate reopens for every term whose hard deadline is still ahead.
6. For each fork term t_1+k with termEnd + 3,600 ≥ T_R (about 60 terms), at termEnd + 3,601 X calls reportAbandoned(t_1+k, 0, C(fork block), cp, landedTermRef = t_1+121): certificate above what landed for that term (nothing landed); hard deadline passed; gate passes (a strictly later term landed inside the hour); void waiver does not apply, because the blocks were made unlandable by an ordinary landing, not "a forced or replacement landing". Effect: 2,000 TAIKO debited from H_{1+k}; the reporter share is withheld (the voider was an ordinary landing of an earlier term), 800 escrowed to the next ordinary landing, which X lands one block at a time right after each report.

Design text: "A3 L1 arbitration. Until a replacement lands, landing the original stays valid and pays the ramp. Whichever lands first wins ... If the original lands after a REPLACE view was certified, that view is unlandable and the holder resumes from the original's highest certified block with a RESUME VC." (landing §6); "the void waiver holds: no penalty for a view whose certified blocks were voided by a forced or replacement landing, unless the gate was already open before that landing, and the reporter share is paid only when the view was voided by its own holder's REPLACE or superseded by an ordinary landing of a later term" (landing A4). The forced page exempts the symmetric case explicitly ("a resumer whose fresh certified chain lost the race is not penalized"), the landing page does not.

Cost / gain: 60 × 320k gas of reports. Gain 48,000 TAIKO of escrow on top of the ramp X would earn anyway; honest fork holders lose 120,000 TAIKO for following the design, and 120 terms of locked blocks are reverted with nobody slashable (L6 in the other direction; the "locked" credit bound is void while the label reads "replaceable").

Fix: waive S4a for any view whose blocks became unlandable through a landing by someone other than its own holder (the reporter-share clause already knows how to tell); or end the original's landability ABANDON_GRACE after a REPLACE VC is recorded on L1, which is what "strict priority of a late original" was meant to bound.

### R3-S5. [Medium] Internal contradiction: view-change formation "at the honest maximum in one extra round trip" requires a second lock signature that S3c slashes; a leader can split honest locks for 50 TAIKO, and the outcome is either whole-ledger theft (if clients re-sign) or a per-term stall (if they do not)

Requirement: R6, P6, P3; TH8, TH3. Both sentences are on the certificate page.

Trace (attacker L is the leader of (t, v); no attester colludes):
1. s = 0: C(n−1) forms; L stays silent. Attesters' 5-s timers start within a spread of ≈ 0.3 s (gossip) + up to 1 s (CLOCK_SKEW).
2. s = 4.6: L gossips block n. Attestations at ≈ 5.05; C(n) at ≈ 5.3.
3. s = 5.0..5.3: timers fire in order. Attesters whose timer fires before they hold C(n) sign TO(lock n−1) and, per the machine, "attest nothing in v"; the rest receive C(n) first and sign TO(lock n). A split such as 15 at n−1 / 17 at n is ordinary; neither side reaches Q = 22.
4. Reading A (design sentence 2): the proposer re-proposes at lock* = n; the 15 range-fetch, sign the VC message at n, and now hold two timeouts for (t, v, O, TIMEOUT) with different locks. L submits slashViewChangeEquivocation for each: class A, 15 ledgers (≥ 300,000 TAIKO), 30,000 TAIKO to L. L's cost: one MISS penalty (50 TAIKO) when the VC lands. Repeatable in every term L holds.
5. Reading B (design sentence 1): the 15 refuse ("signed no other lock"), no VC forms, the view is dead until term end (all attesters are TIMING_OUT), then closed by the next committee's FALLBACK at termEnd + 12 s: a 55-s stall per term for 50 TAIKO, again repeatable.

Design text: "Attester j signs iff it holds C(lock*) and every block up to it (range-fetching if needed), lock* ≥ lock_j, and it signed no other lock for (t, v). A higher honest lock arrives as a timeout and the proposer re-proposes; with ≥ Q honest online attesters the VC forms at the honest maximum in one extra round trip (≈ 0.4 s)." (preconf §5); "S3c | timeout / view-change equivocation | one key, two timeouts for one (t, v, vcHash, kind), different locks | two single verifications | ≈ 330k | class A" (slashing §3).

Cost / gain: 50 TAIKO per term; theft of 2,000 per slashed key (reading A) or a free stall (reading B). Severity Medium because the design's own first sentence blocks the theft reading; High if an implementer follows the second.

Fix: separate the lock proposal from the timeout: a timeout carries no lock (only "silence seen"), the VC message carries lock*, and S3c applies to VC messages only; S3b then compares the VC lock with the attester's attestations. Alternatively allow a monotone lock upgrade (a second timeout with a strictly higher lock under the same object is not equivocation) and state it in S3c.

### R3-S6. [Medium] recordViewChange is keyed on (termId, view), but a REPLACE or RESUME reopens the same (termId, view): the opening VC and the later closing VC collide, and whoever records first decides whether the replacement chain can ever be landed

Requirement: R7, P4; TH2. Internal contradiction between "a view is identified by (t, v, vcHash)" and the L1 record.

Trace:
1. Holder H_1 reopens (t_1, 0) with a REPLACE VC (key (t_1, 0)); the fork runs to term end; the fork's TERM_END VC also has key (t_1, 0).
2. Attacker X records the TERM_END VC first (gas only); honest nodes would have recorded the REPLACE VC "within seconds", so X front-runs by watching the views topic.
3. The fork landing must supply the VC chain from lastVCHash: the REPLACE VC (opening) and the TERM_END VC (closing). L4 requires each to equal "the view change first recorded on L1 for that (t, v) if one exists"; the REPLACE VC mismatches; ViewChangeMismatch. The fork is unlandable; the holder must wait for the next replaceable window (35 to 65 min) and REPLACE again, which X breaks the same way. Nothing lands until a forced batch or dead mode; every fork holder's views are voided and, per R3-S4, may be reported.

Design text: "recordViewChange(vc) may be called by anyone at any time and stores the first VC per (t, v); later landings must match." (preconf §6); "A view is identified by (t, v, vcHash), the hash of the object that opened it; a REPLACE or RESUME reopens the same view number with a new opening object" (preconf §1); "function recordViewChange(ViewChange calldata _vc) external; // anyone; first per (termId, view) wins" (interfaces §1).

Cost / gain: gas only; no direct theft, but it converts every replacement into a repeatable stall, which is the precondition of R3-S2 and R3-S4. Severity Medium as a contradiction; the halt attacker should rate its liveness effect.

Fix: key the record on (termId, view, kind) or on (termId, view, vcHash), and state that REPLACE and RESUME VCs are recorded under the object they open.

### R3-S7. [Low] Page contradictions that survived the round-2 pass

- learn/02-seats: "No-committee mode. Fewer than four eligible attester seats (for example at launch)" versus K_MIN_CERT = 8 on every design page ("below four" was on the round-2 grep list; this survivor is worded differently).
- learn/06-landing: "View and rights: the range lies in one view" versus landing §1 "spanning up to MAX_VIEWS_PER_LANDING = 4 consecutive views".
- roles §5: "Cost | The queue fee, doubling with backlog; refunded on void." versus forced inclusion §2/§8 "its fee goes to the includer ... No split, no push, no refund" (round-2 S8 claimed one void rule everywhere).
- sequencing §6 and preconf §13: no-committee mode "(for example at launch)" versus initEtna requiring 44 seats and 6 owners, under which the walk always finds a full committee.
- preconf §1: vcHash "is carried by every block of the view" versus anchor §1: "vcHash ... non-zero only on a view's first block", together with "The Etna fields of PH are also the calldata of the first transaction anchorV5" (preconf §2); headerCore in the blob omits vcHash, so the guest must derive it from the view's first record. Consequence: an implementer of S1 evidence (which keys on vcHash) and of the guest can disagree on what a non-first block's vcHash is.

Cost / gain: none directly; each is a divergence point for two implementers, and the first one under-states the certificate-free regime to learners.

Fix: one grep pass for "four", "one view", "refund", "at launch"; make the anchor carry vcHash on every block or say explicitly that the header's vcHash is derived.

## What I tried and could not break

1. False checkpoint through the bridge path (a fake state root in the anchor, a forged single-leaf proof, single-proof mode): stopped by L5 (the end hash must equal a certificate Q attesters executed) and by ZK_K = 2 for every sentinel-view landing; needs T3 or T11 broken.
2. S3a-pair against honest committees now that phHash_a ≠ phHash_b is required and vcHash is in every attestation and certificate: two certificates over one header or over a REPLACE fork at the same height no longer intersect; stopped.
3. S1 against a dead-mode sequencer that lost a landing race: the marker changes with lastLanded.blockHash, so the reopened chain has a different vcHash (round-2 S9 fix holds).
4. S3d via announceLanding in the reference block: an announcement is refused once replaceableFrom has passed, and every block whose timestamp exceeds it is such a block, so the deferral cannot be inserted at or after the referenced block (the only S3d hole is the unsigned reference, R3-S1).
5. Farming S4a with the outage gate alone (pre-outage landing, forced batch opening the gate): stopped by _landedTermRef > _termId and by forced landings not writing lastLanded.at / lastLandedTerm.
6. Draining a holder's class-A stake through a seatless alter-ego lander, RewardBoost or attester share: stopped at 1.05 × floor; boost capped at R_BLK_MAX.
7. Stealing a lander's reward by copying its proof or transaction: rewardTo is bound into the journal for every landing kind.
8. Forcing an honest holder below the floor with liveness debits to remove it: liveness debits never floor-check; only the 50 % hard floor suspends, after 200 bleeds.
9. Registering someone else's BLS key or a duplicate key to frame it: PoP over (pubkey, owner, chainId) plus key uniqueness; the sequencer key is bound without PoP but an attacker binding a stranger's address only exposes its own ledger to S8.
10. Exiting before evidence lands: every window ends by termStart + 7 d and withdrawal waits 7 d past activeUntil and key retirement.
11. Splitting a range into one-block landings to multiply R_BLOB or the attester share: per-block rewards and ≈ 1.5 M gas per landing make it a loss above ≈ 0.5 gwei.
