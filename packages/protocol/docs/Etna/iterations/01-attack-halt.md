# ETNA red team, round 1: goal HALT LIVENESS

Model: Sonnet 5.5 (claude-sonnet-5-5).

## Method
Read all 16 design pages (index, roles, sequencing, preconf, landing, slashing, forced-inclusion, bridge-migration, interfaces, parameters, arguments, l1-dependencies, frame-transactions, limitations, glossary), 01-threat-model.md and README.md. Stripped HTML to text and cross-checked every constant that appears on more than one page. Re-computed the parameter dependency chain (all arithmetic in "Parameters 1" holds). Then traced attacks per liveness rung: rights, committee, certificates, view change, landing, replacement, forced inclusion, bridge/anchor, migration. Scenarios covered: partition, prover failure, L1 congestion, short slots, ePBS Empty slots, no Frame Transactions. No repository file was modified. Findings are against the design as written. Known-findings list was empty. Where the design already lists a limitation (limitations.html L1-L18) I say so and state what is new.

Notation: A = eligible seats, H = honest seats, c = attacker seat share, TAIKO/ETH = 1.5e-4 and V_term = 0.01 ETH as assumed in the design.

---
## F1 (High) Committee smaller than Q makes certification impossible; the cited "widening rule" does not exist
Requirement: R1, R4, P3; TH3, TH5. 

Design text: "Committee dead (fewer than Q live seats). No view changes, so takeovers stop; an absent primary loses its term for everyone; the next primary starts at term end. The certificate page provides the widening rule." (sequencing.html section 13). Also "committeeOf(t): the first K = 32 distinct eligible seats of a second walk ... skipping seats whose owner is in the term's holder list H", "Quorum Q = ⌊2K/3⌋ + 1 = 22", no-committee mode only "while fewer than K_MIN = 4 attester seats are eligible", and the dependency chain "K_MIN + V_MAX + 1 = 9 <= registered seats at activation (recommended 37 ...)".

Trace:
1. A grep of every page finds "widening" once (the sentence above). The certificate page has no such rule. Q stays 22 whatever the committee size.
2. committee(t) = distinct eligible seats not owned by the up to 5 holder owners. With n eligible seats and h seats owned by the holder list, its size is min(32, n - h). The only regime for small n is no-committee mode at n < 4.
3. Launch at the stated minimum, say n = 20 seats (allowed by the "9 seats" chain, the "37" figure is only a pre-T0 checklist item, not enforced by initEtna). h is typically 5 to 8 seats. Committee size 12 to 15 < Q = 22. bitmap popcount >= 22 is impossible: no C(n), no VC (timeouts also need Q), no FALLBACK, and L5 rejects every sortition landing (endCert popcount >= Q).
4. t = 0 to 75 min: leaders produce at most 2 blocks then hold; every term is lost. Nothing lands. At term 76 dead mode opens: any bonded address sequences view 255 and lands; lastLandedTerm resets, so dead mode closes again for 75 terms. The design states no landing rate for this regime; sortition holders' preconfirmations are worthless in it (any bonded party can land a competing view-255 range first, unslashable since it has no seat/key binding).
5. The same state is reached later by attrition: n between 27 and 36 gives committees of 22 to 31 where 10 % offline already fails often. The 1.7e-4 per-term failure figure in preconf section 14 assumes 32 seats. Example n = 30, h = 6, committee 24: P(more than 2 offline of 24 at 10 %) ~ 0.43 per term; at 20 % offline ~ 0.98.
6. Under F3 (strikes) an attacker drives n down at will.

Cost and gain: attacker cost zero at launch (state is reachable by honest under-registration); with F3, cost of a few DDoS bursts. Gain: chain lands about one range per 75 min, bridging and finality effectively halted, preconfs unprotected.

Fix: make Q a function of committee size (Q = floor(2m/3)+1 with m = actual size) and refuse activation/land in sortition mode below m = K_MIN_CERT (say 16) by treating it as no-committee mode; define the widening rule explicitly; enforce the seat minimum in initEtna (registry count >= 37 with >= 8 distinct owners); fix the sequencing sentence "next primary starts at term end" to match V2.

---
## F2 (High) One seat at a high index dilutes the registry so almost every term is open-empty and the committee walk has no bound
Requirement: R6 (anti-monopoly), R1, R4; TH9, TH10.

Design text: "register(seats[]) requires bond >= (seatCount + k)·B_SEAT, ... no pending exit, and every named index free" (sequencing section 2), against "in an append-only array of at most 65,535 (a 16-bit index; filling it costs 1.31 billion TAIKO, above the supply)" and "idx(t, k) = keccak(seed(c) ‖ 0x01 ‖ t ‖ k) mod L_t, where L_t is the seat-array length effective at termStart(t)" with "LengthScheduled(uint16 len, uint32 effectiveAt)".

Trace:
1. Registrants name indices. Nothing says an index must equal the current length or be a recycled hole. An attacker calls registerKeys then register([65534]) with 20,000 TAIKO bond (plus ~98k state gas).
2. After DELAY_REG (7,200 s) L_t = 65,535. Honest A = 40 seats gives density rho = 6.1e-4.
3. Holder walk: MAX_TRIES = 64, P(find any eligible seat) = 1 - (1 - rho)^64 = 3.8 %. So 96 % of terms are open-empty ("any address with bond >= B_SEAT may sequence with the sentinel view 255 and the first landing on L1 wins"): no rights, no certificates, no slashing (no seat/key bound), preconfs worthless, sequencing becomes a proof race.
4. Committee walk ("second walk ... m") has no try bound in the text. Finding 32 distinct seats among 40 in 65,535 slots needs about 10^5 draws; on-chain (settlement, recordCommittee, committeeOf at landing) that is beyond any gas cap, so even the 4 % sortition terms cannot land with a certificate.
5. Honest operators earn in 4 % of terms, so entry becomes unprofitable and they exit; the attacker's capital (20,000 TAIKO) is recoverable after 2 h + 7 d and unslashable (silent, no equivocation).

Cost and gain: about 20,000 TAIKO (~3 ETH) locked, recoverable. Gain: convert sortition to open-empty for 96 % of terms, removing the rights and committee layer. If the array is in fact contiguous the sentence "every named index free" is wrong and holes from exits still lower rho over time (RECYCLE_GRACE table says "holes persist").

Fix: registration may only name index == length (append) or an index in the recycled-hole list, hole list consumed lowest first; compute rho and open-empty only from a compacted eligible list; bound the committee walk and say what happens at the bound; add a density floor (sortition over an eligible-seat Fenwick tree or swap-and-pop with a dated index map).

---
## F3 (High) The strike ladder is a weapon: cheap targeted DoS or an 11-slot cartel suspends the honest operators and shrinks the committee
Requirement: R6, R1; TH6, TH8, TH9, TH10, TH3.

Design text: "Every certified absence against a view: 50 TAIKO burned, one strike; three strikes in a week → suspension from τ + 22 min, doubling per strike." and "TH6 targeted preparation: not defended. The assignment is public 20-80 minutes ahead."

Trace A (no stake needed):
1. Assignment for term t is computable 20 to 80 min ahead. Attacker learns owner O primary in terms t1, t2, t3 (600 s apart, the coalesce window).
2. Attacker floods O's sequencer host for about 6 s at each termStart. Committee sees no certificate for TIMEOUT = 5 s, 22 honest timeouts form VC(t, 0), the next landing carries it and the inbox applies "one strike per owner per 600 s".
3. After three strikes in 7 days O is suspended from tau + 1,320 s for 10,800 s x 2^(n-3) (cap 64 h). O also loses 150 TAIKO and every term revenue. Each reactivation needs only one more strike to double the suspension.
4. An honest set of 15 operators (H = 40 seats) costs the attacker on the order of one 6-s burst per operator per suspension period.
5. As suspended seats leave the eligible set, the attacker's own seats (even 3 seats = 60,000 TAIKO) become most of the eligible set and the committee shrinks toward F1.

Trace B (cartel, no DDoS):
1. Entity buys c = 0.33 of seats: with H = 40, k = X·H/(1-X) = 20 seats = 400,000 TAIKO (~60 ETH, design's own figure).
2. In every committee it holds >= 11 of 32 slots with probability 0.36 (c = 0.3) to 0.79 (c = 0.4). Its members never attest honest leaders (silence is "deliberately never slashed") but do sign the timeouts. 21 honest attestations < Q, no certificate, honest leader holds, timeouts reach 22 with at least one cartel signer, VC forms, honest leader pays 50 TAIKO + strike. Backups 1 to 4 are honest too, so up to 4 owners are struck per term.
3. Within days every honest owner hits 3 strikes. Its own terms (when a cartel member leads, the cartel attests) still run.
4. Bond of the cartel is never at risk; after exit it withdraws in 7 days.

Already-known part: limitations L2, L9 and slashing "open: cap suspensions at 8 h" mention the ladder above the T11 boundary. New: the boundary is 400k TAIKO, recoverable and unslashable, the DoS variant needs no stake, and suspension composes with F1 so the loss is certification and then capture, not "one term".

Fix: strike only when the VC also carries at least Q + 5 timeouts (so 11 abstainers cannot both block certificates and complete a VC alone) or when the leader's blocks were provably unattested by a majority of online attesters; cap suspensions at 8 h with daily decay (the design's own open question); keep a minimum eligible-seat floor by refusing suspension when it would leave fewer than K + V_MAX + 1 seats; add a sortition delay or VRF for the leader's network identity (TH6).

---
## F4 (High) An unskippable forced-inclusion entry that no guest can prove halts every landing; calldata entries never expire
Requirement: R1 (DAO must never be needed), R7, P4/P5; TH7, TH2, TH25.

Design text: "void(i, T) := kind_i = BLOB ∧ savedAt_i + FI_EXPIRY ≤ T", "Calldata entries never void." and "Sequencer block: valid iff no entry is due at the parent's cursor at T_p, or the MAX_FI_RUN = 2 blocks ending at p are all FI blocks." plus the inbox rule "require c >= min(D, ceil(2n/3)) for a range of n blocks" and forced batch "m = min(due entries at T_A, 64) >= 1 and the batch has exactly m blocks, all FI blocks".

Trace (precondition: a decodable manifest whose execution is valid for nodes but which the shared guest cannot prove: a zkVM completeness bug, a precompile edge case, or a cycle/memory cliff within FI_GAS_LIMIT = 5,000,000; the design itself keeps a "common-mode guest bug" as residual, limitation L7, and the FI_GAS_LIMIT row says "proving grief per 0.001 ETH"):
1. Attacker calls saveForcedInclusionCalldata(manifest) with fee >= 0.001 ETH x (50 + pending)/50 (about 0.001 ETH when the queue is empty) at time s.
2. At s + 300 s it is due. Every sequencer block must place it (V8), so every certified chain from the next anchor advance contains the poison FI block; any block skipping it is invalid, unattestable, unlandable.
3. Every ordinary landing must consume it (L8/F5 floor); its proof fails for both ZK leaves. Nothing lands. The forced batch must also contain it (m >= 1 all FI blocks, ZK_K = 2 always). REPLACE view blocks must obey V8 as well (cursor = fiQueue.head), dead mode (view 255) still faces the L8 count. There is no lawful landing that skips it.
4. Landing stops: bridging L2 to L1 stops, finality stops, single-proof mode does not help (needs a landing to exist), DEGRADE_AFTER only lowers the leaf count and the same guest still fails. L2 preconf blocks keep flowing but never land; after 7 days, if the entry is BLOB kind, it derives to an anchor-only block and the queue advances. A CALLDATA entry never voids: the halt lasts until the DAO rotates the guest image, i.e. exactly what R1 says must never be necessary.
5. Attacker cost is the 0.001 ETH fee (refundable to whoever consumes it) plus about 196k state gas (about 0.001 ETH at 5 gwei) and no bond, so nothing is slashable.

Fix: give the queue a time-based skip: if the head entry has been due for FORCE_SKIP (e.g. 6 h) and no landing consumed it, the inbox may treat it as void (anchor-only block) for calldata too; cap manifest cost by a measured proving-cost budget, not gas; let the guest emit a "manifest unprovable" witness (a bounded fallback that proves only the failure of decoding under a resource limit).

---
## F5 (Medium) Poison content in ordinary blocks: replacement re-includes it, and S7 slashes the honest attesters
Requirement: R1, R6; TH2, TH8.

Design text: "Not defended: poison content (a certified block no guest can prove) is handled by replacement plus a client-side blacklist fed by prover error reports." and "Client duty: re-include the void blocks' transactions in order." and S7 "a recorded demandData and no landing covering the certified height within DEMAND_WINDOW" with "class B for every bitmap member and the leader; demand fee refunded; certificate voided".

Trace (same precondition as F4, but the poison transaction is an ordinary L2 tx):
1. User submits tx P (pays normal fee). Honest leader includes it, 22+ honest attesters execute it (V6 passes) and certify block h.
2. No lander can prove range containing h. Landing is sequential, so nothing above h lands either.
3. Any address calls demandData(C(h)) (0.05 ETH). The outage gate for S7 is "some term landed in the hour before the hard deadline"; landings up to h - 1 occurred minutes earlier, so the gate passes.
4. At demand + 1,800 s: slashAvailabilityDefault slashes every bitmap member and the leader one seat each (23 x 20,000 = 460,000 TAIKO), refunds the fee, voids C(h) and every VC locked on it; a FALLBACK VC re-opens from the previous lock. The victims are honest.
5. The mempool still holds P. The next honest leader includes it again; repeat. The demander's cost per cycle is zero (fee refunded on default) plus gas. Separately, after replaceableFrom the REPLACE view re-includes the void blocks' transactions (including P) and the S4a debit falls on the holder (2,000 TAIKO).
6. Recovery is a client-side blacklist (non-consensus) or a DAO guest fix; an attacker varies P.

Fix: S7 must not slash when the demanded range failed proving (add a proof-failure escape: a proof-of-unprovability is impossible, so instead require that some landing of the same range was attempted with the blobs available, or restrict S7 to demands filed before the 5-s attest+certify would have been over); make replacement drop the transaction that failed proving (a "quarantine" list carried by the REPLACE VC, signed by Q) so re-inclusion is not automatic.

---
## F6 (Medium) The lander reward cap is below landing cost above about 6 to 20 gwei; the "100-gwei hour" claim is arithmetically false with the design's own inputs
Requirement: R7, TH13; P4.

Design text: "the lander reward ramps to a level that exceeds proving and landing cost in a 100-gwei hour assumed" (arguments section 3) and "R_BLK_MIN / R_BLK_MAX ... maximum exceeds proving plus landing in a 100-gwei hour; per term 30 to 240" (landing parameters).

Trace:
1. Landing costs 1.5 to 2.0 M gas (landing section 3). At g gwei that is 0.00175·g ETH (mid estimate), plus two ZK proofs.
2. Max ramp per term is 60 x 4 TAIKO = 240 TAIKO = 0.036 ETH (assumed 1.5e-4 ETH/TAIKO). Break-even for a third party is g ~ 20 gwei, for the holder's own term revenue V_term = 0.01 ETH it is g ~ 5.7 gwei. At 100 gwei one landing costs 0.175 ETH: the cap covers 21 % of it.
3. Every (term, view) needs its own landing ("One view per landing"), so cost scales with terms, not with data.
4. During a fee spike above ~20 gwei (hours) no third party lands; each holder's self-landing loses money; the abandonment penalty (2,000 TAIKO = 0.3 ETH) applies only if some landing occurred in the hour before the hard deadline, so all rational actors wait and the gate closes. Landing, bridging and finality stop until fees fall. After 2 h without a recorded assignment the terms are unlandable (see F7).
5. Attacker cost to create the condition is high (about 0.7 ETH per L1 block at 20 gwei), so this is mostly organic, but the design offers no lever (R_BLK_MAX is a constant; changing it is a DAO upgrade).

Fix: index R_BLK to block.basefee (open question in the landing page) with a cap tied to the bond lock, or pay the lander from a ramp that scales with observed gas; state break-even fee in the parameter table; batch several views per landing.

---
## F7 (Medium) Contradiction: "nothing voids by clock" is claimed proven, but three time-based voids exist
Requirement: P2, R7; TH12, TH13.

Design text: "Nothing voids by clock. A global proving or L1 outage leaves every certified block certified; the outage gate prevents any abandonment penalty; the first landing after the outage clears the backlog." (arguments section 3) versus "a landing of a term older than that verifies rights and certificates against the record, and a term with no record is unlandable and therefore replaceable" (sequencing section 10, ROLE_HORIZON = 2 h) and "A batch whose landing slips past the window (an outage longer than 4.55 h at 2-s slots) is unlandable and replaced." (bridge-migration section 2).

Trace: a landing stall of 2 h (F6 fee spike, prover outage): each certified term older than 2 h whose assignment nobody pinned with recordAssignment (about 100k+ gas x 60 terms/h, during the very spike that made landing uneconomic) becomes unlandable; the next holder's REPLACE landing voids up to hours of certified and locked blocks with no slashing evidence (limitations L14 admits it). At 2-s slots the 2935 window makes the same true at 4.55 h. The "proven" tags on landing section 16 ("Nothing is voided without a landed replacement") are false as stated.

Cost and gain: no attacker needed; an adversary who can stall landing for 2 h (F4 blob variant is 7 days) reorgs "locked" blocks for free.

Fix: retain roles for terms as long as the certificate is landable (ring of 2,048 terms already exists) or make recordAssignment implicit in every landing/poke; correct the claims.

---
## F8 (Medium) Contradiction between REPLACE/RESUME dedup and S1/S3a evidence keys
Requirement: R6, R1; TH4, TH8.

Design text: "Attestation dedup keys on (term, view, opening object, height), so a REPLACE fork by the same holder is not equivocation." (preconf section 6) versus S1 "one sequencer key, two signed headers, equal (chainId, term, view, height), different phHash" and S3a "one attester key, two attestations, equal (t, v, height), different phHash" (slashing section 3), both class A (whole ledger).

Trace: a holder O in (t', v') has certified blocks up to height x on the original chain. After replaceableFrom, O forks a REPLACE view: A2 says its first block has parentHash = lastLanded.blockHash and carries a VC of kind REPLACE. The REPLACE blocks occupy the same heights (lastLanded+1 ... x) under O's own (t', v') (no new view number is defined for a REPLACE fork and the view v'+1 belongs to another owner). Anyone submits O's original-branch header and REPLACE-branch header at one height: S1 accepts (fields equal, hashes differ) and debits 100 % of O's ledger. Each attester who attested both (allowed by dedup) is class A under S3a. If the original then lands (A3), RESUME repeats the pattern. Result: either honest replacement is slashable, or attesters refuse the REPLACE view and the design's only exit from an unprovable head fails.

Fix: put the opening-object hash into S1, S3a and S3c keys and define view numbering for REPLACE/RESUME.

---
## F9 (Medium) Fallback view change is one committee deep; two consecutive dark committees wedge block production
Requirement: R1, R4; TH3, TH5.

Design text: "Fallback: if committee(t) produces no TERM_END VC by termEnd(t) + END_GRACE + VC_FALLBACK (at least 11 dead or abstaining), committee(t+1) signs a FALLBACK VC for the highest (v, lock) it holds" and V2 "if v >= 1 or the first block of t: PH.vcHash names a carried VC closing the previous view".

Trace: cause committee(t) and committee(t+1) each to have >= 11 non-signers (cartel c = 0.3: probability 0.36^2 = 0.13 per adjacent pair; or a cloud-region outage of 11+ attesters lasting > 2 minutes). Then no VC for term t exists, leader(t+1, 0) cannot produce a valid first block (V2), and no rule lets committee(t+2) sign a FALLBACK for term t. Sequencing 13 says "the next primary starts at term end" (contradicts V2). Recovery is only dead mode at 75 unlanded terms, discarding all certified but unlanded blocks. Under sustained cartel c = 0.4 (0.79 per term) wedges are the normal state.

Fix: allow any later committee within ROLE_HORIZON to sign FALLBACK for an open predecessor (signerTerm already exists in the VC struct); write the rule explicitly.

---
## F10 (Low/Medium) Parameter contradictions across pages
- TERM_RING: parameters.html "21,600 (15 d, aliased) / 2,048 (34 h)" vs landing.html "TERM_RING ... 2048 (≈ 34 h)" vs bridge-migration "key termId % 21,600". Evidence horizon and ring aliasing disagree.
- Header chain: bridge-migration figure "parent-hash chain to the tip (≤ 2048 headers)" vs MAX_L1_HEADERS_PER_LANDING 4,096 vs "about 2,880 headers at 2-s slots". If the cap is 2,048, valid ranges landing after about 37 min at 2-s slots are unprovable (design window is 60 min + 5 min), so honest holders are replaced and pay SLASH_ABANDON.
- FI queue walk: landing says "≤ 50k gas", parameters says "≤ 270k gas"; sequencing isHolder worst case 290k vs landing "rights <= 100k": the 1.5 to 2.0 M budget omits worst cases (about 2.4 M).
- Inbox gap: interfaces "gap after 20 / 23 slots" vs bridge-migration "22 slots ... gap becomes 21". Holders.mode has 3 values in sequencing, 4 in interfaces.
- README baseline "Frame Transactions will be live on L1 before Etna launches" vs l1-dependencies "Hegota date undecided, launches on Fusaka".
- Roles: "get every certified block ... landed by termEnd + LAND_WINDOW (30 min)" vs landing hard deadline 60 min.
Consequence low individually; the header cap one can cause false replacements.

---
## What I tried and could not break
1. Handoff ambush and withholding (W1-W5): stopped by V2/V3 certified-lock parent rule, recorded VC on L1 (recordViewChange) and S3c needing 12 double-signers; a private lock needs Q+1 colluders, bounded by S7 (30 min).
2. Grinding the seed or entry/exit timing: Rule D (DELAY_REG 7,200 s > CYCLE + LOOKBACK - TERM 4,740 s) and the freshness window; I recomputed DELAY_S, ROLE_HORIZON, SUSPEND(3), DEAD_TERMS x TERM (4,500 s > 3,900 s), ANCHOR windows (5,760 s < 16,382 s): all consistent.
3. Censoring or front-running a registration by incumbents: registration is a plain future-dated L1 write; no roster vote; only FOCIL/T1 dependence.
4. Making a landing revert through a forced-inclusion entry (racing an entry that becomes due): stopped by anchored T_floor due-ness and pull-based fees.
5. Forging a checkpoint through a false anchor (TH17): guest header chain, blockhash/EIP-2935 tip check, monotone A3 rule.
6. Opening dead mode on a slow live chain: 75 terms (75 min) exceeds LAND_WINDOW_MAX + ABANDON_GRACE (65 min).
7. Burning the shared nonce or landing slot with Frame Transactions: two-shape gate; without EIP-8141 losers pay ~25k gas + blob fee only.
8. ePBS Empty slots and 2-s slots: all deadlines in seconds; the Empty slot only delays inclusion by one slot.
9. DAO inaction: no owner-gated function on any liveness path (excluding guest-image completeness, see F4).
10. Key theft framing and rogue-key BLS framing: proof of possession and the capped challenger share.
