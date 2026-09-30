# Etna red team, round 3: HALT attacker

## Model
Claude Sonnet 5.5 (claude-sonnet-5-5), the model requested (sonnet).

## Method
Read all design pages (index, roles, sequencing, preconf, landing, slashing, forced-inclusion, bridge-migration, interfaces, parameters, arguments, l1-dependencies, frame-transactions, limitations, glossary), 01-threat-model.md, README.md and every learn/ lesson, as text extracts. Each candidate was traced with actors, bonds, times and the design sentence exploited; three were also simulated in Python (committee/holder walk under seat-array dilution; committee composition for several owner structures at A = 44..100; scratch scripts in the scratchpad, not committed). Round 1 and 2 items were skipped unless the fix is inadequate (said explicitly). Evidence rules: design AS WRITTEN, no crypto breaks, no majority-of-attesters beyond stated bound, no L1 finality failure.

Findings are appended below as completed.

## R3H-1 [High] FI_SKIP bounds one poison entry to four hours, not the stream: re-armable for about 0.003 ETH per cycle
Requirement: R1 (chain live without the DAO), R7, P5; TH7. Builds on R1-F4; the round-1/2 fix is inadequate because it bounds one entry, not repetition.

Precondition (the design's own residual): a decodable FI payload that the two guests cannot prove within FI_ZK_GAS_LIMIT (a completeness bug in both leaves; only ONE leaf is enough when the landing is uncertified, see R3H-4).

Trace (times in s after T0'):
1. T0': last ordinary landing, lastLanded.anchorTipTimestamp = T0'. Attacker saves calldata entry P1 (fee 0.001 ETH, ~0.002 ETH state gas). Due at T0'+300.
2. From T0'+348 V8 forces every block to include FI(P1) (executes fine on L2, attesters certify). Every landing must consume a due head (L8, T_floor), forced batch and dead mode too. No landing possible after blocks anchored beyond T0'+300.
3. At T0'+14,400 skipped(P1,T) holds; a replacement/forced landing voids P1 (the 4 h of certified blocks above lastLanded are replaced; they contain FI(P1) executed, so they are unprovable).
4. That landing sets lastLanded.anchorTipTimestamp = X. Attacker immediately saves P2 (same payload). Due X+300. Only blocks anchored before X+300 (about 5 min of chain) can land; then the stall repeats for a full FI_SKIP.
Landed duty cycle about 2 percent; each cycle also discards 4 h of locked L2 history. Fees of a void entry go to the includer (the forced lander, so the attacker can recover them).

Design text: "Unprovable head entry (round 1, F4): bounded to four hours. ... stalls every landing path (ordinary, replacement, forced, dead mode all must consume it) until FI_SKIP voids it; cost to the attacker 0.001 ETH plus state gas per four hours of stall, if such a guest bug exists."

Cost/gain: about 0.003 ETH per 4 h (about 0.02 ETH/day); gain: bridging and finalization halted indefinitely until a DAO guest fix, which contradicts "The DAO never needed" (FI page §13).
Fix: require each FI entry to lock a refundable bond that is forfeited (burned) when the entry is skipped, sized above the cost of one 4 h stall; and make a skip raise the fee floor (FI_BASE_FEE x 2^skips in the last 7 days) so a repeated poison stream is priced. Drop "bounded to four hours" from the FI page, L16 and P5, since the bound holds per entry only.

## R3H-2 [High] No consensus bound on per-term data: one cheap seat makes its term unprofitable to land, and sequential landing stalls everyone behind it
Requirement: R7, P4; TH2, TH13. The break-even "about 100 gwei" is also off by a factor of 3 at the design's own target rate.

Trace (12-s slots, assumed L2 base fee 0.01-0.05 gwei, 16 gas per calldata byte):
1. Attacker registers 1 seat with exactly the minimum bond (registration needs 105 % of the floor, so payable balance above the buffer = 0). Cost 21,000 TAIKO, recoverable.
2. It is primary of term t (probability 1/A; 1/44 per minute at launch). It signs 60 blocks each with a compressed record of about 385 KB (V9 allows 390,132 B), incompressible junk calldata, about 6 M L2 gas per block, mostly refunded through its own coinbase (75 % of base fee). Attesters check V1-V6 and V9 only, so every block is certified and locked. 60 blocks = about 180 blobs, more than the whole L1 blob capacity of that minute.
3. Landing cap is 6 blobs per transaction, each landing verifies two ZK leaves (about 1.5 M gas): at least 30 landings, about 45 M gas, for a maximum reward of 60 x 24 + 180 x 1 = 1,620 TAIKO (0.24 ETH), and 0 at all if the holder's balance is at the buffer. Break-even gas price is about 5 gwei (design claims 100).
4. Above that nobody lands t. Landing is sequential (NotNext), so every later honest term is stuck behind it. No S4a (the outage gate needs a strictly later landed term, impossible), so the attacker pays nothing.
5. After replaceableFrom (36-65 min) the current holder forks a REPLACE view; a replacement landing voids term t and up to 65 min of honest certified blocks (void waiver: nobody is penalised). Repeat at the attacker's next draw.

Even honest traffic: the design's target rate (32 KiB/s, about 15 blobs per term) needs 3 landings per term, so the "one-term landing at 100 gwei, four-term landing at 400 gwei" arithmetic cannot hold (4 terms would be 60 blobs, cap 6).

Design text: "Client policy targets 32 KiB/s of compressed output per sequencer (one seventh of L1; about 15 blobs per 60-s term). Ranges are lander-chosen, so no per-term cap on-chain; the caps are per landing: 6 blobs (the per-transaction limit) and 256 blocks." and "Reward-type debits (ramp, blob reward, boost, attester share) stop at the holder's buffer, 1.05 x its floor: below it a third party is not paid from that holder".

Cost/gain: about 0.005-0.02 ETH of L2 fees per term; gain: repeated 36-65 min landing stalls plus reorg of the honest window, for any 1/A share.
Fix: consensus per-term (not per-block) byte and zk-gas budget enforced at V-level and in the guest (for example at most 1.5 x BYTES_PER_SEC_TARGET x TERM), R_BLOB and the ramp indexed to landings actually needed (ceil(blobs/6)), reward capacity required at registration (excess over 1.05 x floor >= 3,626 TAIKO per seat), and restated break-even fees.

## R3H-3 [High at 2-s slots] V9 bound is off by the nine framing bytes: a certified single block can still need four blobs
Requirement: R4, R5, P4; TH13. Round 2 H1 fix is inadequate (same failure, off by 9 bytes).

Trace (2-s L1 slots: at most 3 blobs per L1 block, l1-dependencies table):
1. Attacker is primary (or any backup view) of term t. It builds block b whose canonical record (headerCore || seqSig || VC bytes || txListBytes) is 390,130 bytes by choosing the exact zlib stream length (it owns the stream, padding is free).
2. V9 as written: record <= 3 x 130,044 = 390,132, so every attester accepts and certifies b; the next block carries C(b): locked.
3. Blob payload = 0x03 || u32(numBlocks) || u32(len) || rec = 9 + 390,130 = 390,139 bytes > 390,132: four blobs. One L1 block at 2-s slots carries at most 3, and a landing is one transaction (L6), so b cannot be landed by anyone, alone or in a range (ranges are contiguous and sequential).
4. Every later block, honest terms included, sits above b. After replaceableFrom (36-65 min) a REPLACE view voids b and everything above it. Void waiver and the closed outage gate mean no penalty. Attacker repeats at each draw.

Design text: "V9 size: the canonical record headerCore || seqSig || VC bytes || txListBytes is at most 3 x 130,044 = 390,132 bytes ... so any single certified block is landable alone" versus "payload = 0x03 || u32(numBlocks) || Sigma_i ( u32(len(rec_i)) || rec_i )".

Cost/gain: zero (padding); gain: 36-65 min landing stall plus reorg of the honest window per draw, no slash. Only 2-s regime, which the design lists as supported (R5).
Fix: bound rec_i by 3 x 130,044 - 9 (and account 4 more bytes per further record in every multi-block landing), assert it in V9, the guest and MAX_ENVELOPE; also state that a max-size block consumes 100 % of an L1 block's blob capacity at 2 s.

## R3H-4 [High] Single-proof degradation is disabled exactly in the regimes that have no attesters, so one ZK back-end outage halts them until a DAO upgrade
Requirement: R1 (chain live if the DAO never acts), P3, P4; TH2, TH20.

Trace:
1. Registry is in a certificate-free regime: no-committee mode (fewer than 8 committee seats: launch, mass exit, or R3H-5), open-empty terms, dead mode, or forced batches.
2. One ZK back-end fails for availability, not soundness: its remote verifier contract is paused or deprecated (staticcall reverts), or its proving network is down for days. The other leaf works.
3. Every landing in those regimes needs kRequired = 2 leaves. DEGRADE_AFTER (7,200 s) arms single-proof mode only "for landings with a non-empty certificate"; none exist here. Dead mode after 75 unlanded terms and the forced batch also require two leaves.
4. No landing, no checkpoint, no bridging. The only exit is a DAO upgrade (rotate image, remove the leaf, add a third system). This is the state DEGRADE_AFTER was introduced to prevent.

Design text: "Single-proof mode: if block.timestamp - lastLanded.at > DEGRADE_AFTER (2 h), one leaf suffices until the next landing, only for landings with a non-empty certificate." and "Sentinel-view exception (dead mode, no-committee mode, open-empty, forced): an empty certificate is accepted, and then the verifier is never degraded (section 7)." versus "DEGRADE_AFTER ... one back-end outage must not stall landing until a DAO upgrade (R1)" and roles section 7 "single-proof mode and replacement keep the chain moving unless every ZK system is broken."

Also: the recovery floor says "one honest bonded party and one honest prover" but needs provers for two systems. A one-leaf-unprovable FI payload in these regimes makes R3H-1 need only ONE guest completeness bug instead of both.

Cost/gain: zero for a natural outage; for an attacker the cheapest trigger is an FI entry that exceeds one zkVM's cycle or memory limit.
Fix: allow a k = 1 landing in uncertified regimes after a longer stall (for example 24 h without any landing) with a landing bond forfeited if a later k = 2 proof contradicts it, and label such state "single-proof" in the level table; or state plainly that R1 does not hold in those regimes. Correct roles section 7 and arguments section 3.

## R3H-5 [High, capital-heavy] Recoverable phantom seats dilute the seat array permanently: committees vanish, terms go open-empty
Requirement: R1, R4, R6; TH9, TH10. Builds on R1-F2 (refuted). The refutation ("costs a full B_SEAT locked about 9 days per hole and self-heals because entrants prefer cheap overwrites") is inadequate: the bond is returned, holes are refilled only one per new seat, and the array never shrinks.

Trace:
1. Attacker (capital N x 20,000 TAIKO) uses N/8 addresses (CAP = 8): registerKeys, register(8) (contract-assigned appends, effective 2 h later), and in the same block requestExit for all seats: activeUntil = activeFrom, the seats are never eligible and never slashable.
2. Array length L_t = A + N is permanent (append-only, dense). After activeUntil + 7 days the attacker finalizes exit and withdraws every TAIKO. Cost is gas only (about 2 x 98k state gas per seat) plus 7 days of capital.
3. Holder walk (64 tries) and committee walk (512 tries) draw uniformly over L_t and skip ineligible seats. Simulation (single-seat owners): A = 44: L = 500 gives mean committee 25.5 (never 32); L = 1,000 gives 16.6 and 5 % terms without holder; L = 2,000 gives 9.6, 22 % of terms below K_MIN_CERT and 24 % open-empty; L = 3,000 (2,956 holes, 59 M TAIKO, 5.9 % of supply) gives 64 % no-committee and 39 % open-empty. A = 100 needs L about 6,000-10,000.
4. In no-committee terms there are no certificates, no view changes, no lock, W1 handoff ambush is free, and R3H-4 applies. In open-empty terms "the first landing on L1 wins" (race, no rights).
5. Healing needs one honest registration per hole ("FREE recycled holes first"); the attacker needs nothing further.

Design text: "The array is dense, so its length always equals the number of seats ever claimed" and "expected committee size is therefore min(32, A - seats(primary) - |H| + 1)" (false once L_t >> A: the 512-try walk covers only 1 - e^(-512/L) of the array) and "MAX_SEATS ... filling costs 1.31 B TAIKO, above supply ... exclusion by array-full is impossible".

Cost/gain: about 1,000 seats (20 M TAIKO) already removes full committees at launch; 3,000 (59 M) removes them almost everywhere; capital returned after 7 days; effect lasts until thousands of registrations arrive. Also the committee pin walk at 512 tries is about 2 M gas per term, outside the stated 290k.
Fix: sortition over an eligible list (swap-and-pop with a dated index map, or a Fenwick tree), or cap L_t at c x (eligible seats + pending), and state the committee-size formula as a function of L_t.

## R3H-6 [Medium] Two incompatible forced-inclusion placement rules: V5(e) survives on the certificate page and in lesson 3; read literally it stops the chain
Requirement: R1, R5, P5; TH7. Internal contradiction (rule stated two ways).

Trace: the forced-inclusion page says V8 "replaces V5(e)": an FI block inherits its parent's anchor and the obligation "binds from the next block". The certificate page's validity predicate (the normative V1-V6 list every attester and the guest implement) still says the anchor check includes "if the anchor advanced, every forced inclusion due at L1[a].timestamp is included".
1. Anyone saves an FI entry E at L1 time s (0.001 ETH).
2. A leader that advances the anchor to a with timestamp >= s + 300 makes a block that must, under V5(e), already contain E, but an FI block cannot advance the anchor (F3: anchor = parent's), and a sequencer block cannot be the FI block.
3. So under V5(e) every anchor advance past s + 300 is invalid. Leaders can only anchor blocks older than s + 300; V5 requires the anchor to be at most ANCHOR_MAX_AGE = 1,800 s old, so after about s + 2,100 no valid anchor exists and every block is invalid. One 0.001 ETH entry halts block production, and E can never be included (its FI block would also be invalid). Implementations following V8 and V5 disagree (consensus split).

Design text: certificate page: "if the anchor advanced, every forced inclusion due at L1[a].timestamp is included"; FI page: "Placement rule V8 (F4; replaces V5(e))" and "A sequencer block may advance the anchor freely; the obligation the new anchor creates binds from the next block." Lesson 3 repeats the V5(e) sentence.
Cost/gain: 0.001 ETH; halt (in an implementation that follows the V5 text).
Fix: delete the clause from certificate page V5 and lesson 3, and list V8 in the validity predicate (V1-V6, V8, V9).

## R3H-7 [Low] Restated collusion figures are wrong at launch scale (the committee is drawn without replacement from about 36 seats, the threshold is an absolute 11 seats)
Requirement: R6 (anti-monopoly tables), T11. Re-simulation of the revised walk (primary excluded by owner, backups by seat, 5 owners max, 32 seats, Q = 22, blocking needs m - Q + 1 = 11 abstainers in the committee; 20,000 terms each).

| Owner structure | Cartel | Simulated P(certification and view change blocked in a term) | Design text |
|---|---|---|---|
| 5 honest x 8 seats + 10 single-seat cartel (A = 50) | 10 seats | 0 % (10 seats cannot fill 11 slots) | "holds 11 of 32 slots in about 9 % of terms" (slashing s5, lesson 9) |
| 40 single-seat honest + 10 cartel | 10 seats | 0 % | "in about 4 %" |
| 4 x 8 + 1 honest + 11 single-seat cartel (A = 44) | 11 seats (25 %) | 2.4 % | binomial at c = 0.25: 15 % |
| owners 8,8,8,8,8,4 seats (A = 44), cartel = one 8-seat owner + the 4-seat owner | 12 seats (27 %) | 41 % | binomial at c = 0.27: 24 % |
| 10 owners x 10 seats (A = 100) | 3 owners = 30 seats | 38 % | binomial at c = 0.3: 36 % |
| same | 2 owners = 20 seats | 3 % | 4 % |

So the table is right only for dispersed sets; for two or three large owners the risk swings from 0 to above the binomial figure, and with 44 seats a 12-seat cartel of two owners (240,000 TAIKO) stalls certification, timeouts and view changes in 41 % of terms unslashed (cannot reach Q = 22 honest signatures). MIN_OWNERS = 6 counts a cartel's owners.

Design text: "five 8-seat honest owners leave 32 honest seats plus the backups' remaining seats for the walk, and a 10-seat single-seat cartel holds 11 of 32 slots in about 9 % of terms" and "P[Bin(32, c) >= 11] = 0.04 / 0.36 / 0.79".
Cost/gain: 12 seats = 240,000 TAIKO (recoverable, silence unslashed) at launch.
Fix: publish the hypergeometric table per owner structure and set MIN_OWNERS and the seat minimum so that the largest two owners together leave 22 honest committee seats.

## R3H-8 [Low to Medium] Contradictions between pages (design and learn/), by consequence
1. Learn lesson 2: "No-committee mode. Fewer than four eligible attester seats" versus K_MIN_CERT = 8 everywhere in the design (round 2 H4 "below four" fix was not applied here). An implementer reading it certifies with m = 4..7 (2Q - m = 2 to 3 double-signers behind "locked"). Medium if used as a spec.
2. Learn lesson 4: attestation "BLS signature over (chain, term, view, height, header hash)" omits vcHash, the exact round-2 S1 defect (L1 cannot read the opening object without the header preimage); design: "the struct carries vcHash explicitly". Also "100-byte" certificate versus "about 130 bytes".
3. Learn lesson 6: "the range lies in one view" versus up to four segments per landing (MAX_VIEWS = 4, R1-F6). Lesson 9 repeats the wrong 9 % cartel figure (R3H-7).
4. Void rule: roles section 5 says both "void, fee to the includer, no refund" and "refunded on void"; arguments section 6 says "void with refund after 7 days"; FI page: no refund (round 2 S8 said one rule).
5. S7 remnants: bridge-migration storage notes ("demands, voided certificates"), interfaces storage summary ("demands and answers") and the ETH invariant in slashing section 6 ("Sigma open demand fees") describe a removed mechanism.
6. announceLanding is "payable" (ETH) in interfaces and landing, but the bond is "SLASH_ABANDON" = 2,000 TAIKO (a ledger amount) and appears in neither accounting invariant; if implemented against a gwei constant in msg.value the bond is dust or 2,000 ETH. If dust, S3's priority defence is free.
7. The 102-minute forced-inclusion bound (FI section 9, lesson 10, "proven") omits the 10-minute announceLanding deferral: 112 minutes at a 2,000-TAIKO price.
8. Per-term exposure is 3,626 (landing section 5) versus 3,470 (landing section 11); Holders.mode has 0..2 (sequencing) versus 0..3 (interfaces); landing page LastLanded struct omits anchorTipTimestamp that FI section 2 depends on; the preconf/lesson V5(e) sentence is R3H-6.
Fix: one grep pass per item; parameters page normative.

## What I tried and could not break
1. Indefinite forced-path censorship or replacement stall with announceLanding: deferral is once per lastLanded and replaceableFrom is capped by termEnd(first unlanded term) + 3,600 + 300; refreshing lastLanded needs real landings that advance the first unlanded term. Adds at most 10 minutes (R3H-8 item 7).
2. RESUME V8 exception as a censorship loop: keyed on an opening object containing the forced marker, so once per forced batch; the obligation binds from the second block; the landing count rule only forces range lengths of 3k blocks when many entries are due.
3. FI_SKIP gate refresh through a lander-chosen anchor tip: a higher tip only delays the gate by that landing's latency and makes the next range wait for FI blocks that honest fresh anchors produce within about 50 s; no lasting stall (the tip is not bound to the last anchor, so "no third party can move T_floor" is loosely worded).
4. No-committee holder reservation as a 30-minute landing freeze: the restriction is on the segment's sequencer identity; a third party may still land the holder's gossiped blocks. Outsider replacement after the deadline is the intended S9 behaviour.
5. Abandonment (S4a) of honest holders: sequential landing means no strictly later term lands without a replacement, so the gate stays closed, and the void waiver removes the rest.
6. Partition: Q > 2/3 makes two conflicting certified sides impossible; the minority side times out and the fallback closes the term.
7. Front-running registerKeys by binding a victim's sequencer address: costs the victim one fresh key; BLS keys are protected by the PoP over (pubkey, owner, chainId).
8. Blob-price and race griefing without Frame Transactions: loser cost about 25k gas plus a blob fee against the attacker's own 1.5 M gas landing and proof.
9. Later-committee FALLBACK VC race: known (L5), needs Q colluders in some committee within 34 h.
10. Stuffing of the FI queue for delay: priced and accepted (L8).
