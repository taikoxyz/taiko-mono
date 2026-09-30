# Round 5 STEAL report

Model: Sonnet 5.5 (claude-sonnet-5-5).

Method: stripped-HTML read of all design pages, threat model, README, 04-round; trace attacks against slashing/landing/sequencing rules; findings appended as completed.


## R5S-1 [High] S3b landed-head exemption makes a locked-block revert free (TH5/W1, R6; breaks invariant I4 and the 13 x B credit bound)

Requirement: R6 objective slashing; credit bounds of the confirmation table.

Actors: cartel C holding >= Q = 22 of the 32 seats of committee(t) (p = 0.33: 4e-5 per term by the certificate page table; the committee is computable 20 to 80 minutes ahead, so C only acts on terms it knows it holds); honest leader H = leader(t, 0); a CEX that credits deposits at "locked" (the published level, credit bound 13 x B = 39 ETH); C's lander/prover.

Trace (seconds from termStart(t)):
1. t = 0 to 35: H produces blocks; C attests them normally (they must, to hold Q).
2. t = 10: block h_a is certified. C's lander lands range [lastLanded+1, h_a] (proof pipelined, about 25 s; one L1 block). The Inbox writes h_a into the landing ring.
3. t = 36: C's accomplice deposits X to the CEX in block n > h_a; locked at about t = 38; CEX credits, accomplice trades out off-chain.
4. t = 40: every C seat signs a LockVote(kind TIMEOUT, lock = h_a). Each key also attested headers whose carried certificate is above h_a, which is exactly the S3b lock lie. S3b's verification step "L is not a landed head in the landing ring" now fails for the evidence, so `slashLockLie` reverts for every signer. S3c does not apply (no earlier lock vote by these keys). Q votes form VC(t, 0, TIMEOUT, h_a); leader(t, 1) (or a cartel leader) builds on h_a; the locked block n and everything above is orphaned. MISS (50 TAIKO) falls on H, not on C.

Design text exploited (slashing S3b, verbatim): "L is not a landed head in the landing ring (a vote at a reset lock is mandated, never a lie; round 3, S2)". Preconf §6: "S3b additionally ignores any lock vote whose lock equals a landed head in the inbox's landing ring." The exemption was written for RESET attesters, but the RESET state already forbids TIMEOUT and TERM_END votes under the old object, so the ring test is unnecessary for them and protects every key for any landed head, including heads of ordinary landings, which the lander chooses.

Cost/gain: slashed seats 0 (table row "revert a locked block, one redraw count": 12 seats = 240k TAIKO; "Locked" claim: "needs 12 provable slashings"); cost = one landing's gas (reimbursed by the ramp). Gain = everything any counterparty credited at "locked", unbounded by the published 39 ETH. Also a blank-out weapon: every view of the term can be voided the same way.

Fix: store in the ring only heads of replacement and forced landings (flag) and apply the exemption to RESUME only (already exempt by kind); or delete the exemption, since RESET forbids the votes it was meant to cover. Re-state the locked bound as 0 for any lock equal to a landed head until fixed.

## R5S-2 [High] Evidence-driven suspension is owner-triggerable: a post-seed, 22-minute grinding lever (TH9, R5/R6; breaks R4-C2 "no fast owner-triggered write")

Requirement: R6 (anti-monopoly, collusion bound T11), R5 (no grinding).

Claim under attack, three pages: "DELAY_S ... only for suspensions from evidence against the owner, which the owner cannot trigger" (learn 01); "DELAY_S: never used for an owner-triggerable input" (sequencing §11); "No fast owner-triggered write exists, so RND3 holds for every input" (sequencing §2).

Fact: the owner signs its own evidence. S6 needs only "a signed or attested header whose carried-certificate or VC preimage fails" by a registered key; the owner signs a header naming keccak(garbage) and submits it itself (class B, B_SEAT = 20,000 TAIKO, minus the 2,000 self-challenger share = 18,000 burned, about 2.7 ETH; a minimum-funded owner also drops below the floor, SUSPENDED_OPEN). Effect date is tau + DELAY_S = tau + 1,320 s, chosen by the owner, with tau free inside the 34 h evidence ring.

Trace (cartel C with 1/3 of the seats, k = 13 sybil owners C1..C13; honest owners H):
1. t = cycleStart - 1,200 s: seed(c) is fixed on-chain (RND2). RND3 freshness only covers DELAY_REG writes (freshFrom = cycleStart - 3,660 s).
2. Off-chain, C computes, for every subset U of {C1..C13} suspended (2^13 = 8,192) and every term t* at offset >= 2 in cycle c, the rank walk and committee with U's seats removed from E_t.
3. A subset U* and term t* exist with committee(t*) holding >= 22 cartel seats not in U* (per-draw probability 3.8e-6 at 150 seats, 50 cartel; 8,192 x 55 draws give an expected 1.7 hits, so about 80 % per cycle; 40 % cartel: near-certain).
4. Before termStart(t*) - 1,320 s, C submits self-S6 for the owners in U*. Expected cost |U*| x 18,000 = about 6.5 x 2.7 = 17 ETH.
5. At t* C holds Q of the committee and executes R5S-1 (free locked revert), or certifies private data (L3), at a probability the design prices at 4e-5 per term, known to it in advance.

Design text: "DELAY_S ... (the only DELAY_S-dated eligibility input is an evidence-driven suspension, class A or B, which needs evidence against the owner and is not owner-triggerable" (parameters §1).

Cost/gain: about 17 ETH turns the collusion table's 4e-5 (p = 0.33) per term into about 0.8 per cycle; the T11 bound is an assumption about seat share, but the lever removes the lottery that made one third of the seats safe.

Fix: date every suspension DELAY_REG, or keep suspended seats in the rank domain and skip them when drawn (as void views are skipped), so no owner write changes E_t or any rank.

## R5S-3 [Medium] RESUME has three incompatible L1-reference definitions; S3d as written slashes honest RESUME signers (R6, TH8; I5)

Actors: a stall of 35 to 65 minutes with a due FI entry; a forced batch or replacement landing F lands; the committee (22 honest keys) is in RESET; anyone as challenger.

Definitions that cannot all hold:
(a) Preconf §1: l1Ref for REPLACE and RESUME "is the L1 block (number, hash) at which the replacement predicate held, or the forced or replacement landing being resumed from".
(b) Forced inclusion §7: the RESUME reference is "the forced marker keccak("ETNA_FORCED" ‖ firstHeight ‖ endBlockHash)", a hash that is not an L1 block hash.
(c) Slashing S3d (applies to "a REPLACE or RESUME lock vote"): slash if the reference "names a block at which the replacement predicate did not hold, or a hash that is not canonical at that number"; canonicality "by blockhash or EIP-2935", predicate recomputed "as of that L1 block from the term records".

Trace:
1. t = 0: forced batch lands in L1 block R_F. Every honest attester enters RESET and may sign only RESUME (preconf §6).
2. t = 50 s (reference must be >= ANCHOR_MIN_AGE old): 22 honest keys sign LockVote(kind RESUME, l1Ref = (R_F, marker)) per (b), or (R_F, blockhash) per (a).
3. Under (b), blockhash(R_F) != marker, so S3d's canonicality test fails for every signer. Under (a) after a replacement landing (not a forced one), lastLanded.at := block.timestamp, so replaceableFrom recomputed as of R_F is >= R_F.timestamp + 900 s and "block.timestamp > replaceableFrom" is false at R_F: the predicate "did not hold".
4. Anyone calls slashFalseReplacement per key: 22 x B_SEAT = 440,000 TAIKO debited, each key gets +3 strikes (a 36 h suspension for the whole committee), challenger gets min(10 %, 2,000) per key = 44,000 TAIKO (about 6.6 ETH) for 22 cheap calls (about 200k gas each).
If instead implementers exempt RESUME from S3d, RESUME has no guard at all (S3b "never applies to REPLACE or RESUME kinds"), and Q colluders can sign RESUME lock votes at lastLanded after any past forced landing without slash.

Design text: "S3b ... never applies to REPLACE or RESUME kinds" (preconf §8) and S3d above.

Cost/gain: attacker pays 22 evidence transactions after a rare forced or replacement event (a few per year by L6); gain 44,000 TAIKO plus a committee-wide 36 h suspension (a halt lever at the next handoff).

Fix: define one RESUME reference (the L1 block of the landing, compared by blockhash) and make S3d check for RESUME only canonicality and "landing at that block is a forced or replacement landing in the ring", never the A1 predicate at that block.

## R5S-4 [Medium] Routine self-landing drains the landing reserve: every honest owner lapses in about 25 own terms (R1/R7, I2; contradicts "self-landing costs only L1 gas")

Actors: honest single-owner sequencer H at the launch registry (72 seats, 8 owners), which lands its own blocks as the design says it should. No attacker needed.

Design text: "Before term end the price is the minimum and the sequencer lands its own blocks (debit = credit; net cost L1 gas)" (landing §5); roles §1 "Self-landing costs only L1 gas"; "Reward-type debits ... are drawn from the holder's landing reserve" and the credit goes to rewardTo's ledger entry, which is withdrawable excess, not reserve (landing §5; slashing §1).

Trace per own term, H lands at +150 s (proofs take 2 to 3 minutes): r = 0.5 + 3.5 x 150/1800 = 0.79 x 60 blocks = 47; R_BLOB 15; r_land = 1,300 x 150/1800 = 108; attester share 6 (real, to others). Total about 176 TAIKO leaves the reserve per term; 170 of it lands in H's own withdrawable balance.
- Reserve 8,400 is already below the ReserveLow line (8,322) after the first term.
- The lapse line is 4,161: (8,400 - 4,161) / 176 = 24 own terms. At 1 seat of 72 that is about 29 hours; an 8-seat owner (67,200) lapses at the same elapsed time (8 times the terms, 8 times the reserve).
- Lapse: ineligible DELAY_REG later for at least 36 h (SUSPEND(3)), until it deposits again and calls reactivate() (effective 2 h later), for a stake it never lost.
Nothing in the interfaces moves a self-paid credit back into Operator.reserveGwei; `deposit` takes new tokens.

Consequence: the reserve exists for third-party landers but is consumed by the default honest path, so L20's "the owner can bring the lapse about at will" is in fact the default, every honest owner is cycled through 36-hour suspensions unless it automates withdraw-and-redeposit, and every lapse is a mutation-ring entry (M grows with honest churn, not only paid churn). Conversely an attacker gains the ability to pre-plan: the set of owners currently in ReserveLow is public, and each of their drawn terms inside DELAY_REG is an unfunded term (landers refuse, R4-C2 residual).

Cost/gain: none to the owner except operations and lost revenue (36 h of about 1/72 of terms); gain to the free-riding attacker: which terms are unfunded is a public function of Landed events.

Fix: when lander and holder share an owner, skip the reserve debit and credit (net zero by construction), or credit self-landing rewards back to the reserve first.

## R5S-5 [High] A later committee can record a FALLBACK VC for a live term: no L1 time gate and no slashable lock lie, so W1 and locked reverts cost 0 seats (TH5/W1, R6; contradicts P2 and the collusion table)

Actors: honest leader A = leader(t, 0) and honest committee(t); cartel C holding >= Q = 22 of the 32 seats of committee(t+1) (committees are known 20 minutes ahead, so C chooses the term; 4e-5 per term at p = 0.33 by the design's own table, about 20 per year); CEX crediting at "locked".

Design text: "the committee of any later term t' within the landing horizon may sign a FALLBACK VC for t ... once termEnd(t) + END_GRACE + VC_FALLBACK · (t' − t) has passed" (preconf §5: a signer policy) and, on L1, "a FALLBACK VC may be signed by any later committee within the landing horizon" (landing L4, no time condition); "first recorded per (t, v, closes) wins" (preconf §5; landing A3); S3b needs "an attestation by i under the same opening object", which keys of committee(t+1) never produced; S3c is keyed on "(t, v, vcHash, kind)" so a TERM_END vote and a FALLBACK vote by one key do not collide.

Trace (seconds from termEnd(t) = termStart(t+1)):
1. t - 40: C's accomplice deposits X at the CEX in block n of term t; locked at about t - 38; CEX credits, accomplice trades out.
2. t = 0: committee(t+1) seats are live; recordAssignment(t+1) pins their root. C's 22+ keys (none of which attested (t, v, vcHash) above L_low, or only keys that did not) have pre-signed LockVote(kind FALLBACK, lock = L_low, the last block before n).
3. t = 0.5: C calls recordViewChange(VC{t, v, closes = vcHash_t, kind FALLBACK, signerTerm = t+1, lock L_low}). Nothing on L1 checks that termEnd + 12 s has passed or that no VC exists. The record is first.
4. t = 2 to 2.5: honest committee(t) signs TERM_END at lock h; an honest node calls recordViewChange; it is refused (already recorded for the same (t, v, closes)).
5. L4: landing must match the recorded VC, so any range containing the honest t+1 blocks (parent h, vcHash = honest VC) fails the guest's "first block's vcHash equals the last VC's hash". The honest chain cannot land. Blocks n..h, locked at preconf level, never land; after replaceableFrom (35 to 65 minutes) a REPLACE from lastLanded voids them. Slashings: 0 (S3b n/a, S3c n/a, S3d n/a).

Cost/gain: C pays one recordViewChange (about 165k gas) and signs; gain = X, bounded by what counterparties credit at "locked" (the published bound is 13 x B = 39 ETH, real bound 0). Variant: C signs the lock at h + m of a private chain (W1 handoff ambush) with no slashing, because W1's "12 VC double-signers (S3c)" assumes both VCs come from committee(t).

Fix: on L1 accept FALLBACK only if block.timestamp >= termEnd(t) + END_GRACE + VC_FALLBACK x (t' - t) and no VC is recorded; require the FALLBACK lock to carry a verified certificate C(lock) and forbid a lock below any block of (t, v) that a TERM_END VC or landing already bound; restate P2 and the W1 row for cross-committee VCs.

## R5S-6 [Low] Internal contradictions that change a slashing or reward outcome (R6, R7)

1. Attester reward unit. Slashing §6, roles §2, learn 07: "0.1 TAIKO per landed block (6 per full term) ... per block so range splitting earns nothing". Landing §11 and parameters: "ATT_REWARD_TOTAL | TAIKO per landing | 6 | fixed total keeps the holder indifferent to bitmap size". Under the per-landing reading a term split into 60 one-block landings pays attesters 360 TAIKO from the holder's reserve, not 6, and the 4,161 exposure (8,400 reserve, 78 margin) no longer bounds it.
2. Strikes. Slashing §2 class B: "+3 strikes; floor check"; sequencing §7 and parameters: "three structural strikes in a week" and STRIKE_THRESHOLD = 3. One S6 or S3d is either one strike or an immediate suspension; R5S-2 and R5S-3 cost differ by a factor of three.
3. DELAY_S inputs. Parameters §2: "DELAY_S ... class-B suspensions only"; sequencing §2 and glossary: "class A or B"; all three claim "not owner-triggerable", which R5S-2 refutes.
4. S3a key. Slashing S3a single: "equal (t, v, vcHash, height)" (no redraw). Preconf §1 and §4: the redraw count "enters ... every equivocation key". If S3a ignores redraw, cross-redraw double attestation is slashable (the 6e-7 path costs more than stated); if it includes it, L16's "a key in both committees ... is still slashed" holds only through S3b, which needs a lock vote.
5. Accounting. Slashing §6: "announcement bonds and landing reserves are ledger entries inside Σ balance"; learn 08: "sum of ledger balances plus pending burn plus announcement bonds not yet refunded or forfeited" (double count).
6. S3d scope. Slashing S3d: "REPLACE or RESUME lock vote"; learn 08 lists only REPLACE.
7. FALLBACK preconf §5 (policy: "once ... has passed") versus landing L4 (no condition): see R5S-5.
Fix: one owner per constant; grep the pages after the edit for each item above.

## What I tried and could not break

1. Copying another lander's proof to take its reward: journal binds rewardTo for every landing kind ("proofs are per lander"); a swapped address yields a different journal hash.
2. Draining an honest holder's reserve through third-party landings: the lander must supply a valid proof and pays gas; r_land starts at 0 at term end and needs k <= ceil(bytes/780,264); at realistic fees the reward does not exceed cost, and the holder can self-land first. (Only the holder's own routine drain works: R5S-4.)
3. Profit from withholding or abandoning after S4a's removal: withheld blocks have no certificate and die in TIMEOUT; a certified view is landable by anyone, so the holder gains nothing by not landing and pays nothing; MISS is burned, so a false VC pays no one.
4. Announcement-bond theft: the forced lander takes 40 % of 2,000 TAIKO (800, about 0.12 ETH) against about 1.2 M gas plus two proofs and a stall of 35 minutes it cannot create; refused once the head FI entry is due longer than LAND_WINDOW; negative expected value.
5. A recorded REPLACE or RESUME VC to void fresh locked blocks: accepted only with lock == lastLanded and after replaceableFrom, dead once lastLanded moves, no closing effect (A3).
6. Pinning a committee of my choosing after a redraw: landing L4 derives the redrawn committee by the inbox's own walk keccak(seed ‖ 0x03 ‖ t ‖ n ‖ m), justified by 17 REDRAW signatures of committee n - 1; calldata key hashes are not trusted (gas is the open cost, not soundness).
7. Mutation-ring ordering and lazy application: entries at exactly termStart(t) are kept (activeFrom <= T < activeUntil), entries after are undone, and recordAssignment reverts before termStart; I could not build a divergence between node and inbox.
8. Forged state root through journal bindings: parent root from storage, blob hashes from blobhash, anchor tip against blockhash or EIP-2935, FI queue from storage, end hash bound by an L1-verified certificate; only a ZK break (out of scope) works. Single-proof mode after 2 h still needs a quorum certificate.
9. Attester-reward skimming by bitmap choice or by signing only the last block of a landing: real but the whole pool is 6 TAIKO per term (about 470 ETH per year across the chain), and a lander must still produce Q valid attestations; immaterial.
10. FI fee farming by self-request: fees go to the sequencer of the segment holding the FI block, bonds burn on skip, cost is quadratic; self-stuffing is zero-sum at best.
11. Challenger loops: each debit pays 10 % capped at 2,000 and duplicates are keyed, so self-reporting always loses at least 90 % of the debit.
