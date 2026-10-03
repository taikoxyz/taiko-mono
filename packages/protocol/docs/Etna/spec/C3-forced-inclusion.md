# C3. Forced inclusion: the hatch

**Owner:** A. **Reviewer:** B (W18 attack). **Independent reviewer:** J (DeepSeek).

**Status [open]:** proposed under D41, replacing C3 at `4aa0299` in full. Written for D39 and recorded as D41; B attacked the head `76c6150` frozen by D56 under W18 (#22191 comment 5951827846: request changes, four Mediums, B-D41-01 to B-D41-04), and this head applies those corrections for review under D56; J's verdict under D6 is requested (#22191 comment 5950161959): D56 records J's partial verdict on `76c6150` (#22191 comment 5951639022: sound in what J verified, J-1 routed to C7), and J's full verdict on the frozen head is pending. A specification, not an implementation.
- No forced-inclusion duty on any block, no waiver, no stall clock, no run cap (D39).
- Kept: D18's per-id irreversible settlement and D17's termId = termOf(ts_0).
- Superseded: the FI parts of D12, D14, D18 and D22. D33 is withdrawn.
- The user signed the product choices in D51 (the landing gate, HATCH_DELAY = 14,400 s, HATCH_BOND = 0, stuffing priced and not bounded, window-hatch voiding) and the limitations found by D41's rounds in D55 (the stuffing price as a function of L_K with a C6 measurement procedure; the poison-adjacent residual; late quorum replay).
- Still open with C4 and the user: the legacy expiry and the LEGACY_BLOB execution promise (D51).
- The rounds that produced this text are summarized in §12 (revision history).

**Tags:** [proven] means argued here, not machine-checked; [assumed] means a proposed rule or premise; [open] means unresolved, with its closure named.

## 1. Vocabulary and premises [assumed]

**Vocabulary:**
- **Entry i:** one queued request. Entries are appended FIFO at the existing queue slots (C4).
- **head / tail:** the first unconsumed id / the next id to assign.
- **s_i:** the save timestamp. For a legacy id, the BlobSlice timestamp (C4-R06).
- **base:** a uint48 stored with head and tail in one word.
- **kind_i:**
  - LEGACY iff i < Q, C4's frozen Shasta tail (C4-R06 already selects the legacy adapter by Q);
  - otherwise the stored kind bit, BLOB or CALLDATA.
- **dataHash_i:**
  - for BLOB and CALLDATA, as stored (C3-R01);
  - for LEGACY, keccak256(abi.encode(versionedHash, offset, codecRevision)), which the inbox computes from the retained BlobSlice and the codec revision C4 commits.
- **Request block:** an L2 block executing exactly one entry. It is kind FI (3) in a holder view or sentinel view 255 (voluntary), or kind FORCED (1) inside a hatch (view 254).
- **Replay block:** a kind-FI request block whose id is below head at the landing that carries it (C3-R05(e)).
- **Consumed:** passed by the head in a landing, either executed (by a request block) or void (no block in that landing). Also passed by `fiClear()` (C3-R06a), always void.
- **Capped:** the C3-R04 walk stopped at E = MAX_FI_PER_LANDING with i < tail.
- **Includer:** the sequencer of the segment holding the request block, or the hatch's `rewardTo`.
- **Maximal hatch:** a hatch executing m entries [head+v, j), with j = head + v + m, such that m = HATCH_K, or j = tail, or s_j + HATCH_DELAY ≥ T + HATCH_RESUME_GRACE (j is **young**: its window cannot open within HATCH_RESUME_GRACE of T). Any other hatch is **non-maximal**: it stops at an **old** entry j (s_j + HATCH_DELAY < T + HATCH_RESUME_GRACE) with fewer than HATCH_K executed entries. An honest party stops at an old entry only at one it cannot prove, a poison. The inbox cannot tell a poison stop from a deliberate one, and does not need to.
- **short:** one bit in the FiQueue word. A hatch writes it: set by a non-maximal hatch, cleared by a maximal one. `fiClear` and a CONFLICT restart clear it. Every other landing (ordinary, sentinel, dead-mode, replacement), whatever it consumes, leaves it unchanged.

**Premises:**
- **T1:** L1 includes a blob-free landing of about 1.2 M gas within one slot (open at C6 MP-34d's worst hatch default of about 1.6 M gas, which C3 re-reads). After Hegotá, FOCIL covers calldata saves and the hatch.
- **T3:** the ZK leaves are sound. A hatch always needs ZK_K leaves (C2-R11).
- **A-PROVER:** one honest party holds the payloads, the L2 state at lastLanded, a prover, and a TAIKO ledger balance of at least HATCH_BOND. The requester can be that party.
- **A-HATCH-LATENCY:** for the current entry c, let S_c be the latest of: open_c; the instant the parent the hatch builds on becomes public on L1 (lastLanded after the landing that last moved it); and the earliest instant C3-R07 (1) and (4a) permit that hatch. That party acquires the payloads and state, proves and submits a hatch of up to HATCH_K blocks within HATCH_WINDOW minus two slots of S_c (1,776 s at a 12-second slot; unmeasured), so that with T1's one-slot inclusion the hatch is included at an L1 timestamp at most S_c + HATCH_WINDOW − 12 s. [proven, from P3, the `short` extension and the parent's stability in an open window (C3-R07 claims)] close_c ≥ S_c + HATCH_WINDOW, checked against each term of S_c: open_c by definition; the parent time P because a landing at P while c's window is open must execute c (the gate), so either P < open_c, or the landing has n > E, or it has n = E and capped(T) at P (C3-R04's base update; c sat behind the capped prefix and was not current, P3), and each of these two landing cases (n > E; n = E and capped(T)) sets base ≥ P − HATCH_GRACE, giving open_c ≥ P; the (4a) wait because after a maximal hatch the base shift gives open_c ≥ hatchAt + HATCH_RESUME_GRACE, after a non-maximal hatch `short` gives close_c ≥ hatchAt + HATCH_RESUME_GRACE + HATCH_WINDOW, a head reached by `fiClear` cannot appear before that (MAX_FI_PER_LANDING expiries are needed after the extended head close), and a CONFLICT restart pushes every open to at least restartTimestamp + HATCH_DELAY (C3-R10). So the hatch lands at least one slot (12 s) before close_c, the first instant at which c is voidable (C3-R04: expired iff T ≥ close). Inclusion at exactly close_c is too late (T35). L_1 and L_K (§9) denote this same interval, from S_c to L1 inclusion, for a one-block and a full HATCH_K-block hatch, so L_1 ≤ L_K ≤ HATCH_WINDOW − 12 s. It also covers a hatch of one LEGACY block at LEGACY_FI_GAS_LIMIT under FI_ZK_GAS_LIMIT (C3-R05(a)); until C6 measures that, a legacy entry it does not cover acts as a poison (L-HATCH-POISON).
- **A-L1LIVE.**
- **A-RETAIN:** blob payloads are retained for at least FI_EXPIRY plus the landing horizon. C2's T2 is about 18 days.
- **A-HONEST-SERVE:** an honest pipeline lands a consumption of every entry it can prove within HATCH_DELAY of its save. It is used only for the backlog statement in C3-R07 and the remark in C3-R06a that an honest pipeline never caps the walk; no [proven] claim rests on it.
- **T11** (C2, cited): fewer than Q colluders in any committee, so a certified chain is VALID_GOSSIP. It is used only for C3-R06's landability claim. The bound, origin progress and at-most-once execution do not depend on it.
- **A-HONEST-RESUME:** after a hatch, a live honest pipeline lands an ordinary landing of resumed blocks in the current term within HATCH_RESUME_GRACE minus one slot, unless another hatch lands first (unmeasured; C6). It is used only for C3-R09's no-griefing claim. After a non-maximal hatch the head's window may already be open, so that landing also executes the head (C3-R11 serves it). The premise does not cover a head the pipeline cannot prove (a poison); see C3-R09.

## 2. Requests, price, settlement

### C3-R01. Requests [assumed]

- `saveForcedInclusion(BlobReference)`: exactly one blob, kind BLOB, dataHash = the versioned hash.
- `saveForcedInclusionCalldata(bytes manifest)`: at most FI_CALLDATA_MAX bytes, kind CALLDATA, dataHash = keccak256(manifest). It is FOCIL-eligible.
- Both require msg.value ≥ FI_BOND + FI_FEE (C3-R02).
- FI_FEE is burned in the saving transaction (S3-R20's sink, a push that cannot revert). bountyWei = msg.value − FI_BOND − FI_FEE.
- One entry word: requester (20 bytes), bountyWei (uint88), kind (1 bit), status (2 bits), replayable (1 bit; 252 bits used). Plus dataHash and s_i.
- Legacy ids (i < Q) keep C4's layout and get no entry word. Their kind_i and dataHash_i are derived as in §1, never stored. Every hash that names an entry uses the derived pair, so a legacy entry's offset and codec revision are bound: fiConsumedHash, fiReplayHash and the DOMAIN_FI txListHash.
- Saves are refused while C4's intake is closed (C4-R04).
- The queue is unbounded.
- After the save, nothing is rewritten except the status and replayable bits, or for a legacy id, C4-R06's flags and fee word.
- Every payout is pull. An overpayment is a bounty.

### C3-R02. Price [assumed]

- FI_FEE = FI_BASE_FEE × (FI_FEE_THRESHOLD + (tail − head)) / FI_FEE_THRESHOLD, fixed at save.
- No escalation and no surcharge.
- `getForcedInclusionFee()` returns FI_BOND + FI_FEE.

### C3-R03. Settlement, per id and irreversible [assumed]

Status values: 00 unsettled; 01 executed, bond claimable; 11 final. Status 10 is retired; status governs money only. Only the consuming landing (or `fiClear`) settles, only from 00, in the same step.

**The replayable bit** (legacy: `legacyReplayable`, beside legacySettled), separate from money:
- every void sets it: a first void, a re-void after a CONFLICT restart, or `fiClear`;
- every execution clears it: a consuming execution, a re-execution after a restart, or a replay;
- C3-R06 step 1 checks it for every fiReplayIds id.

Settlement:
- **Executed** (content, or empty by expiry, C3-R05(a)):
  - bountyWei goes to the includer's pull ledger (`withdrawFiFees(to)`);
  - status becomes 01;
  - `withdrawFiRefund(id)` (requires 01 and msg.sender == requester) pays FI_BOND and writes 11.
- **Void:** FI_BOND + bountyWei are burned; status becomes 11, and replayable is set in the same write.
- **Legacy ids** in [initialEtnaFiHead, Q):
  - the first Etna consumption captures feeInGwei × 10^9, sets legacySettled and zeroes the fee in one masked write;
  - executed credits the captured fee to the includer, void burns it;
  - void sets `legacyReplayable` in the same masked write; an execution clears it;
  - a requeued id at fee zero moves nothing.
- **Replay after a CONFLICT rewind** re-executes or re-voids and settles nothing: no money moves. It still writes the replayable bit (set on re-void, cleared on re-execution), one entry-word or masked legacy write per re-consumed id.
- **Replay block** (C3-R05(e)): settles nothing. The burned deposit and any legacy fee word stay as its consuming landing left them, and no includer is credited. It requires replayable (legacy: legacyReplayable) and clears it, moving no money.
- [proven: at most one settlement per deposit] D18's argument, unchanged. Replay blocks and re-consumptions never reach a settling step; the replayable bit moves no money and `withdrawFiRefund` still requires 01.

## 3. Windows and the gate

### C3-R04. The schedule [assumed]

For an L1 time T, computed from the stored (head, base):
```text
b ← base; i ← head; E ← 0
while i < tail and E < MAX_FI_PER_LANDING:
    open_i ← max(s_i + HATCH_DELAY, b + HATCH_GRACE); close_i ← open_i + HATCH_WINDOW
    if short and i = head: close_i ← max(close_i, hatchAt + HATCH_RESUME_GRACE + HATCH_WINDOW)   (whatever entry is head)
    if T < close_i: break
    b ← close_i; E ← E+1; i ← i+1          (i is expired at T)
current(T) ← i if i < tail and E < MAX_FI_PER_LANDING
windowOpen(T) ← current exists and T ≥ open_current
R(T) ← E + (windowOpen(T) ? 1 : 0)        (the gate)
capped(T) ← E = MAX_FI_PER_LANDING and i < tail
```
When capped, no entry is current, windowOpen is false and R = E; the gate is unchanged. The cap is cleared by any landing with n ≥ E or by `fiClear()` (C3-R06a).

Update after a landing (or `fiClear`) at T that consumes n entries:
- base ← the walk's b after its first min(n, E) entries;
- if n > E, or n = E and capped(T), base ← max(base, T − HATCH_GRACE);
- if it is a maximal hatch (§1), base ← max(base, T + HATCH_RESUME_GRACE − HATCH_GRACE), so no window opens before T + HATCH_RESUME_GRACE (C3-R09). A non-maximal hatch takes no shift: the next entry opens on the natural schedule, max(s + HATCH_DELAY, T) for an old entry.
- if it is a hatch, short ← (it is non-maximal); if it is `fiClear`, short ← false; otherwise short is unchanged.

The shift is binding only for a full hatch (m = HATCH_K). For a maximal hatch that stops at tail or at a young j, every remaining entry already has open ≥ s_j + HATCH_DELAY ≥ T + HATCH_RESUME_GRACE (FIFO, P2), so the shift changes no open. It is kept for all maximal hatches so that the rule reads the same for all of them.

The `short` extension holds the head after a non-maximal hatch open for at least HATCH_WINDOW after the non-maximal gate lifts (C3-R07 (4a)). The head's open is unchanged, so the gate binds from its natural open. It holds every later head too until the next hatch: a head reached by an ordinary landing before hatchAt + HATCH_RESUME_GRACE still closes no earlier than hatchAt + HATCH_RESUME_GRACE + HATCH_WINDOW. [proven] The extension is inert for any head whose open is at or after hatchAt + HATCH_RESUME_GRACE (its natural close is already later), so a stale `short` changes nothing: a head reached by a landing at T_L ≥ hatchAt + HATCH_RESUME_GRACE with n > E opens at or after T_L, and one reached through voids opens at or after an extended close plus HATCH_GRACE (P2). It only lengthens a head window whose open is unchanged, and the gate forces execution inside it, so it buys a censor nothing; a poison head's halt stays within hatchAt + HATCH_RESUME_GRACE + HATCH_WINDOW, the figure already in L-HATCH-POISON.

`hatchStatus()` returns (current, open, close, E, R, capped, short) at block.timestamp.

Proven properties:
- **P1** [proven]: the schedule is a function of storage and T only.
- **P2** [proven]: open and close never decrease along the queue, so the expired entries form a prefix.
- **P3** [proven]: every entry gets a full HATCH_WINDOW after it becomes current. The `short` extension only lengthens a window. A head after a non-maximal hatch has at least HATCH_WINDOW after hatchAt + HATCH_RESUME_GRACE, the earliest time a non-maximal hatch can execute it. This covers every head before the next hatch, including one reached by an ordinary landing before hatchAt + HATCH_RESUME_GRACE, because `short` survives that landing (T33). An entry behind a capped walk is not current; it becomes current once the capped prefix is consumed, and the "n = E and capped" base rule gives it its full window from no earlier than that moment, so a late clear never makes it expire unseen.
- **P3a** [proven]: the walk is capped only when MAX_FI_PER_LANDING entries are expired and unconsumed, and from then `fiClear` is permitted to anyone. Cleared at T ≤ close_last + HATCH_GRACE, the next entry's open is the same as the uncapped chain would give (max(s + HATCH_DELAY, close_last + HATCH_GRACE)), so the bound's arithmetic is unchanged.
- **P4** [proven]: no front-running. An entry saved beside a poison P opens at close_P + HATCH_GRACE.
- **P5** [proven]: a poison never blocks an entry ahead of it, because the gate reaches only through current.

## 4. Request blocks

### C3-R05. Request blocks [assumed]

**(a) Content, both kinds:**
- The decoded manifest's transactions, in order. An invalid transaction is skipped. A transaction exceeding the remaining gas limit (FI_GAS_LIMIT, or LEGACY_FI_GAS_LIMIT for LEGACY) or the remaining FI_ZK_GAS_LIMIT is skipped, never invalidating the block (G7). An undecodable payload yields no transactions.
- FI_ZK_GAS_LIMIT is 20 % of BLOCK_ZK_GAS_LIMIT (zk_gas_spec, 100 M), an absolute zk-gas cap that is the same for every request block of every kind, LEGACY included. It caps a legacy block's proving work at a BLOB or CALLDATA block's, whatever its 45 M EVM gas limit [assumed; part of the LEGACY_BLOB promise still open with C4 and the user].
- **Expiry (G4):** an entry of kind BLOB or LEGACY whose s + FI_EXPIRY ≤ the block's anchor timestamp executes with no transactions, and its payload is not read. It counts as executed.
- **Legacy (LEGACY_BLOB):** the BlobSlice at its offset under the Shasta codec revision C4 commits; gasLimit LEGACY_FI_GAS_LIMIT; zk gas FI_ZK_GAS_LIMIT. The Etna block fields replace Shasta's timestamp, anchor, coinbase and gas-limit inheritance [assumed; a changed service promise, open for C4 and the user].

**(b) Kind FI (voluntary):** a sequencer block exactly like a NORMAL one (own timestamp under V4, own anchor under V5, signed, inside V9 and V10), except:
- PH.txListHash = keccak256(abi.encode(DOMAIN_FI, uint48 i, dataHash_i)), with dataHash_i as derived in §1;
- its record is headerCore ‖ seqSig ‖ [viewChangeBytes] ‖ u48 i, with no txListBytes;
- in the L1 state at the block's anchor A_b, i < tail(A_b), hence s_i ≤ T_anchor; the guest asserts s_i ≤ T_{A_b} (C3-R08), which is equivalent because entries are FIFO and s_i is fixed at save;
- **contiguity:** i = max(head(A_b), j + 1), where j is the id of the latest request block on the block's chain above lastLanded(A_b). If there is none, i = head(A_b).

No rule requires a request block at any position. Contiguity constrains which id a request block may carry. It obliges no block to carry one. This is C3-R11's former attester policy, made validity so that every gossip-valid chain is landable (C3-R06, landability claim).

**(c) Kind FORCED:** only inside a hatch (C3-R07).

**(d) Pin (G1):** every request block runs C1-R05's pin of its own origin as a system operation, after the EIP-4788 and EIP-2935 operations and before its transactions. It creates no transaction, nonce or receipt. It writes the pin bit only if absent.

**(e) Replay block:** a kind-FI request block for an id i < fiHeadBefore of the landing that carries it.
- This arises only when a landing after A_b voided i, which C3-R06 allows whenever i has expired and the voiding range holds no block for i.
- It executes its content per (a) and (d), expiry-empty where (a) applies, exactly as at gossip time.
- On L1 it settles nothing (C3-R03).

Claims:
- [proven: origin progress, conditional on T3 alone] A landed request block's anchor is at or after its entry's save: the guest asserts s_i ≤ T_{A_b} for every kind-FI block, executed or replay (C3-R08), and the inbox checks C3-R07 check (5) for a hatch. No committee premise is used. So any request saved after a signal pins an origin containing that signal, and no signed transaction carries the pin, so there is nothing to replay.
- [proven] Content is independent of the includer.
- [proven: each id executes at most once on the landed chain, restarts included, conditional on T3 alone; landings rewound by a restart are not on the landed chain]
  - A consuming landing executes id i only from head ≤ i, and head is monotone between restarts. A restart resets head to r.fiHeadAtStart, and only the consumptions in [r.fiHeadAtStart, headBefore), which were in rewound landings, are re-consumed. So the landed chain consumes each id once.
  - A replay needs the replayable bit, which only a void sets, and every execution (consumption, re-execution or replay) clears it. The bit therefore reflects the id's last consumption or replay, whatever the status says. An id whose landed consumption executed it is never replayed; a voided id is replayed at most once, since the replay clears the bit and no later void of it occurs on the landed chain.
  - Hence each id executes at most once: by consumption, or, if voided, by at most one replay.
  - (Gossip level.) On a certified chain, contiguity also admits at most one block per id; that half is gossip validity and is not needed for the landed claim.

## 5. Consumption at every landing

### C3-R06. Consumption (C2's L8; applies to ordinary, sentinel, dead-mode, replacement and hatch landings) [assumed]

LandInput carries the following, all fixed journal inputs; n = fiHeadAfter − head:
- fiHeadAfter;
- fiVoidCount v;
- fiReplayIds, a list of ids.

At T = block.timestamp:
1. Range checks. Any failure reverts with `FiRange`:
   - fiHeadAfter ≤ tail;
   - n ≤ MAX_FI_PER_LANDING;
   - v ≤ n.
   - fiReplayIds:
     - at most MAX_FI_PER_LANDING ids;
     - strictly increasing;
     - every id < head (the stored head before this landing);
     - every id has the replayable bit set (legacy: legacyReplayable);
     - empty for a hatch.
2. Walk C3-R04 at T. Require v ≤ E, else `FiVoidNotExpired`. Require n ≥ R(T), else `FiGateUnmet`.
3. The inbox computes both hashes from storage, with (kind_i, dataHash_i) derived per §1:
   - fiConsumedHash = keccak256(abi.encode(chainId, head, n, v, (i, kind_i, dataHash_i, s_i)…));
   - fiReplayHash = keccak256(abi.encode(chainId, (i, kind_i, dataHash_i, s_i) for i in fiReplayIds)).
4. The proof shows that the range's request blocks are exactly as follows, in chain order:
   - the replay blocks for fiReplayIds;
   - then one block per entry of [head+v, fiHeadAfter), in id order.
5. Settle per C3-R03: [head, head+v) void; the rest of [head, fiHeadAfter) executed; the replay ids nothing, each with its replayable bit cleared. Ids re-consumed after a restart move no money but still write the bit.
6. head ← fiHeadAfter; base and short per C3-R04.
7. If hatchL1 == block.number (a hatch already landed in this L1 block), write hatchTip[block.number] = keccak256(abi.encode(endHeight, endPhHash)) of this landing. hatchL1 sits in the FiQueue word that step 2 already reads.

**The gate in words:** once the current entry's window is open, lastLanded moves only through a landing that executes it. After it expires, lastLanded moves only through a landing that consumes it.

Claims:
- [proven] Two sound journals with equal fixed inputs are equal:
  - fiHeadAfter, v and fiReplayIds are lander inputs that the guest and inbox check;
  - for a given range, fiReplayIds is the range's request-block ids below fiHeadBefore, so it is unique;
  - hence C2-R04's partition and C2-R14(c) hold.
- [proven] No third party can make a proven landing revert through the queue, provided the landing lands within HATCH_DELAY of its proof and consumes every entry saved before the proof and every entry that expires by its landing. All opens and closes are fixed in advance by storage. A landing between proof and inclusion can turn an executed id of the range into a replay. The stale journal then fails, and the lander re-proves with that id moved to fiReplayIds. This is the same free revert as any race (C3-R09). A `fiClear` between proof and inclusion is the same free revert; it is possible only while capped, that is with MAX_FI_PER_LANDING expired entries unconsumed. A non-maximal hatch can lengthen the head's close through `short`. It moves lastLanded anyway, so a landing proved before it already reverts for free at the range start. `short` changes only at a hatch, a `fiClear` or a restart, each already a free revert of a stale proof, so the extended closes are fixed in storage for every other landing.
- [proven: landability of a VALID_GOSSIP chain, which a certified chain is under T11] Every prefix range of a VALID_GOSSIP chain above lastLanded satisfies steps 1, 3 and 4 for some (fiHeadAfter, v, fiReplayIds). Only the gate (step 2) and the two MAX_FI_PER_LANDING bounds can refuse it.
  - head is monotone between restarts, so for every request block, head(A_b) ≤ fiHeadBefore.
  - By contiguity, every jump in the chain's id sequence goes to some head(A_b) ≤ fiHeadBefore. So the ids ≥ fiHeadBefore form one run [fiHeadBefore, e], and the ids < fiHeadBefore are strictly increasing.
  - Take fiReplayIds = the ids < fiHeadBefore.
  - Each such id i has the replayable bit set. It was unconsumed at A_b (i ≥ head(A_b)) and consumed since. A block executing it on this chain at or below lastLanded(A_b) would give head(A_b) > i, and one above it would give j ≥ i against contiguity; a block on another chain means this chain is voided and lands nothing. So i's last consumption since A_b, a re-consumption after a restart included, was a void, which set the bit; and no other replay of i is on this chain, so nothing has cleared it. Each block also has s_i ≤ T_{A_b}, by i < tail(A_b).
  - If the run is non-empty: v = 0 and fiHeadAfter = e + 1 ≤ tail(A_b) ≤ tail.
  - If it is empty: any v ≤ E.
  - If more than MAX_FI_PER_LANDING ids fall on either side, the range lands in pieces cut at block boundaries.
  - Hence C2-R07's "the only unlandable certified content is a guest bug" holds, up to the gate, which is D39's stated restriction (G6, C2-R10).

### C3-R06a. Clearing a capped walk [assumed]

`fiClear()`, permissionless, no proof, no bond:
1. Walk C3-R04 at T = block.timestamp. Require capped(T), else `FiNotCapped`. Refused during CONFLICT.
2. Void [head, head + E) per C3-R03 (burn, status 11, replayable set; legacy per C4-R06). No includer.
3. head ← head + E; base per C3-R04 (the "n = E and capped" rule); short cleared.
4. lastLanded, hatchAt, hatchL1 and hatchTip are untouched. Certified blocks are not voided; a certified request block for a cleared id lands later as a replay (C3-R05(e), L-HATCH-DEPOSIT).

Gas: the walk (about 134k) plus one entry write per id, about 64 × 2.9k.

Claims:
- [proven] `fiClear` voids only entries that every landing at T must already consume (R = E) and may already void (v ≤ E). It removes only a late execution of an expired entry, which any lander could have voided, and a proven landing with the old head reverts for free (C3-R06 race claim). An honest pipeline under A-HONEST-SERVE never lets the walk cap.
- [proven, conditional on A-PROVER and T1] Behind any run of consecutive poisons, the entry that follows becomes current on the uncapped schedule: the honest party sends `fiClear` within HATCH_GRACE of each MAX_FI_PER_LANDING-th poison's close (P3a). Without it, the walk left the next entry unreachable by every hatch (v ≤ E = 64 and m ≥ 1 force executing the 64th poison), and a cartel's late v = 64 landing then voided it and up to 63 more per landing.
- Rejected alternative: a capped hatch that executes the entry after the cap (v ≤ 64, m ≤ HATCH_K) fixes exactly 64 poisons but wedges at 65: the target is then itself a poison, and no hatch or ordinary landing by an honest party can move the cap.

## 6. The hatch, the guest, races, restart and policy

### C3-R07. The hatch [assumed]

A landing through `land` with:
- view FORCED = 254;
- an empty certificate, no view changes and no blobs;
- ZK_K leaves;
- an empty fiReplayIds.

Its journal is domain-separated and binds `rewardTo`. Accepted at T iff, cheapest first:
1. windowOpen(T), or T > replaceableFrom (C2-R08, the A1 disjunct, G5) and T ≥ hatchAt + HATCH_RESUME_GRACE. Else `HatchNotPermitted`.
2. rewardTo's TAIKO ledger balance is at least HATCH_BOND. Nothing is locked or slashable. Else `HatchNotBonded`.
3. The range starts at lastLanded.
4. C3-R06 holds, with m = n − v executed entries, 1 ≤ m ≤ HATCH_K.
   - (4a) Maximality, one read: if m < HATCH_K and j = head + v + m < tail, read s_j (legacy: the BlobSlice timestamp). The hatch is maximal iff m = HATCH_K, or j = tail, or s_j + HATCH_DELAY ≥ T + HATCH_RESUME_GRACE. A non-maximal hatch also requires T ≥ hatchAt + HATCH_RESUME_GRACE on either disjunct of (1), else `HatchNotPermitted`.
   - Why the test uses T and not T_A. "Stops at an entry saved after T_A" is not enough, because check 5 bounds T_A only from below and V4's upper bound is skipped for view 254. A censor that saves its entries one L1 block apart picks T_A between s_k and s_{k+1}. Every one-entry hatch is then "maximal", and the per-hatch shift's price returns. The test above asks only what the shift needs: that j cannot open within HATCH_RESUME_GRACE anyway. An honest hatch passes it whenever it includes every entry saved by its anchor (up to HATCH_K). Its anchor is at most one hatch latency old, so s_j > T_A ≥ T − HATCH_WINDOW > T + HATCH_RESUME_GRACE − HATCH_DELAY.
5. Anchor A (number in LandInput; hash by blockhash or EIP-2935; at or above lastLanded's anchor tip, L7):
   - T_A ≥ s of the last executed entry, else `HatchAnchorBeforeSave`;
   - T_A ≥ ts_0 + m − 1 − ANCHOR_MAX_AGE, where ts_0 = max(fiParentTimestamp + 1, T_A + ANCHOR_MIN_AGE), else `HatchAnchorTooOld`;
   - fiParentTimestamp is a forced LandInput and journal field that the guest asserts against lastLanded's header.
6. The proof.

**Content** is a pure function of (lastLanded, A, entries). Block j executes entry head+v+j per C3-R05(a) and (d), with:
- kind FORCED, view 254, termId = termOf(ts_0) in every block;
- ts_j = ts_0 + j;
- parentBeaconBlockRoot = hash(A) and anchorNumber = A in every block;
- coinbase 0 and no seqSig.

The guest skips V1, V2, V4's upper bound and V10 for view 254.

**Effects:**
- lastLanded's height, hashes, roots, PH fields and anchor tip are updated. lastLanded.at and lastLandedTerm are untouched.
- hatchAt ← block.timestamp and hatchL1 ← block.number, in the FiQueue word {u48 head, tail, base, hatchAt; u63 hatchL1; 1 bit short} (256 bits, written anyway by step 6 of C3-R06). Every hatch sets them, window or A1.
- If the hatch is maximal, base ← max(base, T + HATCH_RESUME_GRACE − HATCH_GRACE) (C3-R04), in the same word: no window opens within HATCH_RESUME_GRACE of a maximal hatch. A non-maximal hatch instead sets short (C3-R04). The head's window then opens naturally, and its close is at least T + HATCH_RESUME_GRACE + HATCH_WINDOW.
- `hatchTip[block.number] = keccak256(abi.encode(uint64 endHeight, bytes32 endPhHash))`, where endPhHash is the hatch's end phHash, the value written to lastLanded.phHash (G2). It is a permanent mapping, overwritten within the same L1 block by any later landing in that block (C3-R06 step 7).
  - It is keyed on the same pair that a RESUME vote signs as (lockHeight, lockPhHash) and that `recordViewChange` compares to lastLanded (S2-R09, S2-R15). An attester or S3d therefore tests it with one storage read and no preimage.
  - An encoding over endBlockHash could not be tested from a vote's bytes.
- Settlement per C3-R06, with includer rewardTo.
- The C2-R15 checkpoint, or the provisional status inherited per C2-R13.
- S2-R15's reset.
- A bonded announcement covering the voided range is forfeited (C2-R08).
- Refused during CONFLICT.

Claims:
- [proven] V5 holds at every hatch block at its own timestamp: T_A ≤ ts_0 − 48 ≤ ts_j − 48, and T_A ≥ ts_{m−1} − 1,800. No block of any kind inherits a V5 verdict, so DRIFT_MAX = 0.
- [proven, conditional on A-L1LIVE] The hatch is constructible in every open window: take A = the latest L1 block once L1 is m seconds past the parent's anchor.
- [proven] The parent is stable during an open window, because only a landing that executes current moves it. Without the gate, a cartel starves the hatch forever (T-A).
- [proven] A window hatch voids certified blocks only after a deadline that is public from L1 storage: HATCH_DELAY ahead of it, or HATCH_GRACE after an expiry, or HATCH_RESUME_GRACE after a maximal hatch. After a non-maximal hatch, a maximal hatch may follow as soon as the head's natural window opens, which storage also fixes. A non-maximal hatch waits HATCH_RESUME_GRACE. Under A-HONEST-SERVE, an honest pipeline's ranges consume each entry before its open. Window-hatch voiding is the route the user signed in D51(4).
- [proven] If a hatch lands in L1 block N, then at the end of N, hatchTip[N] = keccak(lastLanded.height, lastLanded.phHash): the hatch writes it and sets hatchL1 = N, and every later landing in N, of any kind, rewrites it (C3-R06 step 7). An honest RESUME with l1Ref = N locks on that lastLanded, so the hatchTip disjunct covers it whatever A1 is. It does not use "A1 cannot change within N", which fails because C2-R08's deferral flag is keyed on lastLanded.

### C3-R08. The guest [assumed]

- **Ordinary ranges:** the kind-FI blocks are exactly the following, in chain order:
  - the replay blocks for the ids of fiReplayHash's preimage;
  - then one block per id of [fiHeadBefore + v, fiHeadAfter);
  - each per C3-R05(a), (b)'s record and txListHash, (d) and (e).
- No other kind-FI block appears.
- For every kind-FI block, executed or replay, the guest asserts s_i ≤ T_{A_b}. s_i is in the preimage of fiConsumedHash or fiReplayHash, and T_{A_b} is the anchor timestamp the guest already authenticates for V5. One comparison per block, no L1 state read.
- Contiguity against head(A_b) stays gossip validity, which the guest does not assert. Outside T11, a cartel holding a quorum that breaks contiguity may certify and land a replay block for **any id whose replayable bit is set, at any later time**. That includes an id that had no certified block when it was voided, with a fresh anchor A_X and head(A_X) > i. Three things still hold:
- **[proven: coupling, J's D6 verdict, D57]** Contiguity can stay out of the guest only because the landing gate (C3-R06) consumes through the current request: no landing passes an id without executing or voiding it in order. Any later change that weakens the gate, for example a landing that consumes a later id while the head is unexecutable, must make contiguity a guest-asserted validity rule in the same change.
  - the id executes at most once on the landed chain, because the replay clears the bit (C3-R05 claim);
  - its anchor is at or after s_i (the s_i assertion above);
  - a BLOB or LEGACY id executes empty once s_i + FI_EXPIRY ≤ T_{A_X} (C3-R05(a)). A CALLDATA id runs its content whenever it is replayed.

  Apart from this late replay and the fresh out-of-order execution stated below (D60 (2)), a contiguity-breaking cartel strands only its own certified blocks, and the hatch and A1 routes recover. Under T11 a replay carries only an id i whose request block is anchored at an L1 view A_b in which i was eligible (i ≥ head(A_b), i < tail(A_b), contiguous), so A_b precedes the void (C3-R06 landability claim). The block need not exist or be certified before the void: an honest holder may create it after the void on such an anchor, and honest attesters certify it (T37). [proven, conditional on T11 and no CONFLICT restart] Its L2 timestamp is below T_V + ANCHOR_MAX_AGE (1,800 s), where T_V is the L1 time of the void: T_{A_b} < T_V because head(A_b) ≤ i, and V5 bounds its anchor age by ANCHOR_MAX_AGE. This honest-validity replay exposure is not the late quorum replay that D55(3) signed; D55 does not cover it, and it is [open] for the user (§11). The inbox's step-1 checks, the order above and the s_i assertion are what the guest and inbox enforce at landing. The user signed the late quorum replay outside T11 as a limitation in D55(3) (L-HATCH-DEPOSIT).
- **[assumed: the fresh form of the contiguity gap, D60 (2); C7-R01, C7-R15 and vector C7-T10 at `0f0a2f0`]** The gap above has a second form beside the late replay. Outside T11, a quorum that breaks contiguity may certify a kind-FI block carrying an id above head(A_b) and land it with an empty replay list and a void count v that voids the ids it skipped, so that the order [fiHeadBefore + v, fiHeadAfter) and s_i ≤ T_{A_b} pass and the id executes fresh, not as a replay (B's W8 verdict on C7 at `06cae6c`, #22199 comment 5952455406, item 2). It stays within C3's queue accounting (C3-R06's v ≤ E and n ≥ R over C3-R04's walk; each id executes at most once), and no evidence object exists for it. Its scope is outside T11 only. D55(3) covers only the late replay: the fresh form is not signed, and it is on the D50 completion list for the user (D60 (2)).
- **Hatch:** C3-R07's derivation.
- No clock and no due answer is a guest input.

### C3-R09. Races and resumption [assumed]

- A hatch voids every certified block above lastLanded (C2-R09). Nodes enter S2-R15's RESET.
- The holder, or a sentinel sequencer, resumes with a RESUME. Its l1Ref names the L1 block containing the landing resumed from, whether a replacement, dead-mode or hatch landing.
- **The one RESUME predicate.** S2-R09, S2-R15 and S3d all use it. With l1Ref = (number, hash), a RESUME is attestable iff:
  - (i) the hash is canonical at that number; and
  - (ii) either A1 held at l1Ref, evaluated on the inbox state before that block's landings, or `hatchTip[l1Ref.number] == keccak256(abi.encode(lockHeight, lockPhHash))`, both taken from the signed vote.
- S3d slashes a RESUME lock vote iff (i) fails, or both disjuncts of (ii) fail.
- A REPLACE keeps A1 only: it is attestable iff (i) holds and A1 held, and is slashable otherwise.
- Races between an original range, a REPLACE fork, a sentinel landing and a hatch: the first included wins and the loser pays nothing beyond a free revert. Nobody is penalized.
- A hatch leaves lastLanded.at and lastLandedTerm untouched, so after a window hatch replaceableFrom can pass within minutes. A further A1 hatch waits HATCH_RESUME_GRACE after any hatch (C3-R07 (1)), so the resumed pipeline gets one honest landing latency before its blocks are A1-hatchable again. A further window hatch waits the same after a maximal hatch, because a maximal hatch moves base so that no window opens before hatchAt + HATCH_RESUME_GRACE (C3-R04). After a non-maximal hatch, only a maximal hatch may come sooner (C3-R07 (4a)). Replacement and dead mode keep C2's A1 unchanged. This stays inside S2-R18's "replaceable" label and L-HATCH-ROUTE.
- [proven: no hatch griefing, conditional on A-HONEST-RESUME alone] After any hatch H at time τ, at most one further hatch can land before a live honest pipeline's ordinary landing, and only when H is non-maximal and the further hatch is maximal. After a maximal hatch, none can.
  - An A1 hatch is refused before τ + HATCH_RESUME_GRACE (C3-R07 (1)). So is a non-maximal hatch on either disjunct (C3-R07 (4a)).
  - After a maximal H, a window hatch is refused before τ + HATCH_RESUME_GRACE: H set base ≥ τ + HATCH_RESUME_GRACE − HATCH_GRACE, so every unconsumed entry has open ≥ τ + HATCH_RESUME_GRACE (P2), and windowOpen is false until then. This holds however old the entries are, so it does not need A-HONEST-SERVE, which the post-outage schedule falsifies (each hatch on a 4 h-old griefer entry voided the resumed pipeline before it could serve).
  - After a non-maximal H, the head's window may be open at once. Only a maximal hatch H′ can use it, at τ′ ≥ τ. H′ executes every old entry from head, up to HATCH_K, and moves base. From τ′ the previous bullet applies, so no third hatch lands before τ′ + HATCH_RESUME_GRACE. T29's griefer therefore pays a run of all its old entries (up to 32) for each second hatch, and then waits HATCH_RESUME_GRACE.
  - Scope: if the head after a non-maximal hatch, or any later head reached by an ordinary landing before τ + HATCH_RESUME_GRACE, is a poison, the gate halts every ordinary landing until the head's close (at most τ + HATCH_RESUME_GRACE + HATCH_WINDOW when it opened before τ + HATCH_RESUME_GRACE), and A-HONEST-RESUME does not apply. No hatch can execute that head either. The first landing after its expiry consumes it, which is the L-HATCH-POISON halt, lengthened by up to HATCH_RESUME_GRACE (§9).
  - The pipeline lands by τ + HATCH_RESUME_GRACE minus one slot under A-HONEST-RESUME. Until then R = E counts only entries already expired, so the gate does not refuse it beyond consuming those.
  - That ordinary landing lands blocks of the current term, so by C2-R08's formula replaceableFrom ≥ T + LAND_CHAIN_GRACE + REPLACE_GRACE: A1 is false. While the pipeline keeps landing, only a window hatch can void it, and each such hatch buys the pipeline another HATCH_RESUME_GRACE in which it lands. The chain makes ordinary progress between any two hatches.
  - Hence the pre-proved A1-hatch schedule (one A1 hatch per honest landing latency) and the post-outage schedule (a window hatch every D < honest resume latency on post-outage entries) are both refused from their second hatch, or from their third when the first is non-maximal and the second is maximal. An honest requester wallet that hatches whenever permitted is limited the same way.
  - Cost: after a maximal hatch the next entry opens up to HATCH_RESUME_GRACE later. After a non-maximal hatch the head may close up to HATCH_RESUME_GRACE later. So the §9 bound gains at most HATCH_RESUME_GRACE per hatch ahead of a request. The shift binds only for a full hatch, and the extension delays a provable head only when the honest hatch from it is itself non-maximal, which needs a poison close behind (§9).
  - The dead-pipeline exit stays: the first A1 hatch about 65 min after the last landing, then HATCH_K entries per HATCH_RESUME_GRACE while no ordinary landing follows.
- `recordViewChange` keeps its A1 gate for RESUME records. A record is optional priority evidence (C2-R09). A RESUME after a pre-A1 window hatch lands through the view-change chain unrecorded.

### C3-R10. Activation and restart [assumed]

- **Activation:** head ← initialEtnaFiHead; base ← activationTimestamp + HATCH_DELAY − HATCH_GRACE.
- **CONFLICT restart:** head ← r.fiHeadAtStart; base ← restartTimestamp + HATCH_DELAY − HATCH_GRACE; status bits, legacySettled and fee words untouched; the replay settles nothing. The re-consumption of [r.fiHeadAtStart, headBefore) does write the replayable bit (legacyReplayable): set on a re-void, cleared on a re-execution (C3-R03). So a re-voided id whose honest request block was certified on the restarted chain lands as a replay, and a re-executed id that was void before the rewind cannot be replayed.
- hatchAt and hatchL1 start at 0 at activation and are untouched by a restart. short starts at 0 and is cleared at a restart (one of its writers besides a hatch, with `fiClear`), whose base already pushes every open to restart + HATCH_DELAY.
- A replay in a rewound landing of an id i < r.fiHeadAtStart cleared its bit, and i is not re-consumed. Its content then runs zero times on the landed chain. No block of the restarted chain can carry i: every anchor after i's void has head > i, so contiguity refuses it [assumed: the restarted chain has no anchor older than i's void, by V5's ANCHOR_MAX_AGE and the CONFLICT halt; reachable only through CONFLICT, which needs an unsound leaf].
- [proven] No window opens before epoch + HATCH_DELAY, and no derived clock can regress at the restart edge.
- A settled replayed head is windowed and hatched like any other entry. This avoids design 1's restart break.

### C3-R11. Serving policy (recommended, not validity) [assumed]

- Sequencers include request blocks for the contiguous provable prefix from head, in id order, at the first block whose anchor state holds the entry.
- They stop at the first entry they cannot prove. After it expires, they void it in the landing and continue.
- A sequencer does not include a request block for an entry already expired at its reference. Such a block is valid, but a lander may void the entry first, and the block then lands as a replay with the deposit burned.
- There is no attester skip policy: contiguity is validity (C3-R05(b)).
- Landers consume every entry saved before their proof and every entry expiring by their landing.

### C3-R12. FOCIL, retention, what is not defended [assumed]

- FOCIL-protected legs: calldata saves, the hatch (blob-free) and withdrawals. Blob saves are not protected (L12). Before Hegotá the floor is T1.
- A calldata entry never expires. Blob and legacy entries execute empty after FI_EXPIRY.
- Not defended:
  - sandwiching of public payloads (L18);
  - pre-execution of a non-idempotent request transaction by an includer in a context of its choosing (L-HATCH-REPLAY);
  - a voided entry whose request block is anchored at a view where it was eligible before the void still executes on L2 as a replay, with its deposit burned, even when that block is created and certified after the void, at an L2 timestamp below the void's L1 time plus ANCHOR_MAX_AGE under T11 with no CONFLICT restart (L-HATCH-DEPOSIT; T37; [open] for the user, not covered by D55); and, outside T11, a cartel holding a quorum may replay any voided id whose replayable bit is set at any later time, even one with no certified block at its void. It still runs at most once, from an anchor at or after s_i, and a BLOB or LEGACY id runs empty past FI_EXPIRY (C3-R08). The outside-T11 case is signed by the user in D55(3).

## 7. Register (C3's only numbers)

| ID | Value | Status |
|---|---|---|
| HATCH_DELAY | 14,400 s | assumed; the user's value (D51(2)). It must exceed the honest serve-and-land latency of 4,188 s. 7,200 s is the shorter admissible choice |
| HATCH_WINDOW | 1,800 s | assumed, unmeasured; at least a HATCH_K-block hatch's acquisition, proof and submission plus two slots: one for inclusion (T1) and one of margin before close (A-HATCH-LATENCY, T35). It is also the landing halt per poison; **procedure:** [C6-measurement-plan](C6-measurement-plan.md) MP-08. |
| HATCH_GRACE | 1,800 s | assumed; at least one honest landing after an expiry |
| HATCH_K | 32 | assumed; also the length at which a hatch is maximal whatever follows it (C3-R07 (4a)); it sets the full-hatch stuffing rate HATCH_RESUME_GRACE / HATCH_K, about 2.2 min per entry (§9). Its latency L_K (from S_c to L1 inclusion, A-HATCH-LATENCY; unmeasured, at most HATCH_WINDOW − 12 s = 1,788 s) sets the stuffing price: a censor can force E to full hatches, so each stuffed entry buys up to about L_K (§9; D55(1)); **procedure:** [C6-measurement-plan](C6-measurement-plan.md) MP-09. |
| MAX_FI_PER_LANDING | 64 | assumed; walk gas about 134k plus about 2.9k per entry. It also bounds fiReplayIds; about 2.9k gas per replay id, plus about 2.9k for its replayable-bit write; plus about 2.9k per entry re-consumed after a CONFLICT restart (bit write). It is also `fiClear`'s batch |
| HATCH_BOND | 0 TAIKO | assumed; the user's value (D51(3)), which supersedes D39's "bonded" |
| FI_BOND | 0.05 ETH | assumed |
| FI_BASE_FEE / FI_FEE_THRESHOLD | 10^15 wei / 50 | assumed; D51's values. A higher FI_BASE_FEE is D55(1)'s remedy if L_K is slow |
| FI_CALLDATA_MAX | 4,096 bytes | assumed; C1's 1,636-byte reveal fits |
| FI_GAS_LIMIT / FI_ZK_GAS_LIMIT | 5 M / 20 % | assumed, unmeasured; FI_ZK_GAS_LIMIT = 20 % of BLOCK_ZK_GAS_LIMIT (100 M, zk_gas_spec) = 20 M zk gas for every request block, LEGACY included; **procedure:** [C6-measurement-plan](C6-measurement-plan.md) MP-10. |
| HATCH_RESUME_GRACE | 4,200 s | assumed, unmeasured; at least the honest hatch-to-first-landing latency (ANCHOR_MIN_AGE for the RESUME's l1Ref, RESUME formation, the first segment's certificate and proof L_1, one landing slot), taken at the honest serve-and-land figure of 4,188 s (TERM + LAND_WINDOW_MAX + REPLACE_GRACE + ANCHOR_MIN_AGE + a landing) and rounded up. A maximal hatch delays the next window open to hatchAt + HATCH_RESUME_GRACE, and a non-maximal hatch extends the head's close to hatchAt + HATCH_RESUME_GRACE + HATCH_WINDOW (C3-R04). It is therefore also the bound's cost per hatch ahead (§9). The young threshold s_j + HATCH_DELAY ≥ T + HATCH_RESUME_GRACE needs HATCH_DELAY − HATCH_RESUME_GRACE (10,200 s) above an honest hatch's anchor age (at most HATCH_WINDOW). It holds with margin; **procedure:** [C6-measurement-plan](C6-measurement-plan.md) MP-11. |
| LEGACY_FI_GAS_LIMIT | 45 M | quoted (Derivation.md:373); zk gas capped at FI_ZK_GAS_LIMIT; proving time of such a block is unmeasured (C6); **procedure:** [C6-measurement-plan](C6-measurement-plan.md) MP-12. |
| FI_EXPIRY | 604,800 s | assumed; FI_EXPIRY + horizon < T2 |
| FORCED / DOMAIN_FI | 254 / C8 tag | assumed |

Deleted from the register: FI_DELAY, FORCED_RING, MAX_FI_RUN, FI_SKIP, DRIFT_MAX (now 0), FI_ANCHOR_LAG, FI_DUE_MAX, SKIP_ESCALATION, ESCALATION_DECAY. D41 adds one parameter, HATCH_RESUME_GRACE. FI_BASE_FEE and FI_FEE_THRESHOLD keep D51's values, and a rescaling alternative is withdrawn (§9). Hatch gas gains one cold read of s_j (about 2.1k) for a hatch with m < HATCH_K that stops below tail.

## 8. Vectors

**Carried from design 2:**
- T01 front-run;
- T02 poison behind current;
- T03 starvation, refused from open_c;
- T04 void too early;
- T06 hatch timing;
- T07 replay after a CONFLICT rewind;
- T08 legacy;
- T09 base after content;
- T10 FI existence.

**Grafts and repairs:**
- **T11 (G1):** the cartel copies a pin request's transaction into a pre-signal ordinary block. The request block still pins a post-save origin.
- **T12 (G2):** a window hatch lands in L1 block N at T < replaceableFrom, so A1 is false at N.
  - hatchTip[N] = keccak(endHeight, endPhHash).
  - The honest RESUME votes (lockHeight, lockPhHash) = (endHeight, endPhHash) with l1Ref = (N, hash N).
  - It matches in one read, and S3d does not slash.
- **T13 (G3):** two consecutive poisons on a dead chain. A dead-mode landing voiding P1 in (close1, close1 + GRACE) is accepted.
- **T14 (G4):** a BLOB entry with s + FI_EXPIRY ≤ T_A in a hatch executes empty with no witness.
- **T15:** a restart with the replayed head settled. The window opens at restart + HATCH_DELAY, and a hatch executes it with no money moving.
- **T16 (G6):** a proving outage longer than HATCH_DELAY, with request c early in it. Ordinary landings are refused from open_c. A dead-mode or hatch landing carrying c lands.
- **T17 (B1, negative):** a RESUME vote with l1Ref = N, where A1 is false at N and hatchTip[N] ≠ keccak(lockHeight, lockPhHash). S3d slashes. Two variants:
  - hatchTip matches but the hash is not canonical: slashed;
  - a REPLACE vote with A1 false at N and hatchTip[N] matching: slashed, because REPLACE ignores hatchTip.
- **T18 (B2, the compose schedule):**
  - Entry 7 is saved; head = 7, tail = 8.
  - At T ≥ close_7, B1..B50 lands in block N with v = 1 and no request blocks. Entry 7 is voided and its bond burned.
  - X = B101, a kind-FI block for id 7 anchored at N−1, is valid by contiguity at N−1 and is certified.
  - The range B51..B120 lands with fiHeadBefore = 8, fiReplayIds = [7] and v = 0. X executes 7's content, and 7's status stays 11 with no credit.
  - Negative: the same range with fiReplayIds = [] has no valid proof.
- **T19 (contiguity):** with head(A_b) = 7 and no request block above lastLanded(A_b), a kind-FI block for id 8 is invalid (C7-R11). After a request block for 7 on the chain, id 8 is valid and id 9 is invalid.
- **T20 (legacy hash):** two journals for one legacy id that differ only in the BlobSlice offset have different fiConsumedHash values. Only the stored offset proves. The DOMAIN_FI txListHash of a voluntary legacy request block uses the same dataHash_i.
- **T21 (replay bound):**
  - fiReplayIds that is unsorted, holds an id ≥ head, has more than MAX_FI_PER_LANDING ids, or is non-empty on a hatch: `FiRange`.
  - A range with 65 replay blocks lands as two pieces.
- **T22 (origin progress):** a cartel-certified kind-FI block for id i with T_{A_b} < s_i, executed or listed as a replay, has no valid proof (RE-1 schedule 1).
- **T23 (replay status):** fiReplayIds naming an id without the replayable bit (unconsumed, or executed by consumption), or a legacy id without legacyReplayable, reverts with `FiRange`. A second landing replaying an id after its replay cleared the bit reverts too (RE-1 schedule 2).
- **T24 (A1 rate limit):** A1 holds; G lands A1 hatch H_1 and submits pre-proved H_2 on end(H_1) one L1 block later.
  - Before hatchAt + HATCH_RESUME_GRACE: `HatchNotPermitted`, unless windowOpen.
  - After it: accepted.
  - An honest RESUME and an ordinary landing within the grace close A1, and H_2 is then refused.
- **T25 (same-block landing on a hatch):** a hatch and then an ordinary landing on its end in one L1 block N. hatchTip[N] equals the ordinary landing's end, and an honest RESUME with l1Ref = N locking on it is attested with A1 false.
- **T26 (legacy zk cap):** a legacy block whose transactions exceed FI_ZK_GAS_LIMIT in total within 45 M gas skips the over-budget transaction (G7) and stays valid.
- **T27 (capped walk):** P1..P64 poisons, then provable CALLDATA t, all saved at about s; no landing.
  - From close_64: capped, no current, R = 64; any hatch reverts (`HatchNotPermitted`, or no proof since it must execute P64).
  - `fiClear()` at close_64 + 1: voids P1..P64 (status 11, replayable set), lastLanded unchanged; t opens at close_64 + HATCH_GRACE, and a window hatch executes t by close_t = s + D + 65W + 64G.
  - `fiClear()` before close_64: `FiNotCapped`.
  - A cartel landing with v = 64 at T ≥ close_t: base ← T − HATCH_GRACE, so t opens at T with a full window and is not voidable at T.
  - With 65 poisons, `fiClear` at close_64 and P65 then windows normally; t is executed by s + D + 66W + 65G.
- **T28 (restart re-consumption):** a landing executes i (01); CONFLICT restart to head ≤ i; an honest kind-FI block for i is certified on the restarted chain; a landing after close_i voids i (status stays 01, replayable set). A later range with fiReplayIds = [i] lands. Mirror: i voided (11, replayable) in a rewound landing, re-executed after the restart (bit cleared): a range listing i as a replay reverts with `FiRange`.
- **T29 (post-outage window-hatch griefing):** an outage of about 2.8 h; G saves e_0, e_1, … every 600 s. G lands one-entry window hatch H_0 at open_0 = τ_0. e_1 is old (s_1 + HATCH_DELAY = τ_0 + 600 < τ_0 + HATCH_RESUME_GRACE), so H_0 is non-maximal: no shift, short set.
  - G's pre-proved one-entry H_1 at τ_0 + 600 is non-maximal: `HatchNotPermitted` before τ_0 + HATCH_RESUME_GRACE.
  - A maximal H_1 at τ_0 + 600 must execute e_1 to e_7 (all entries with s + HATCH_DELAY < τ_0 + 600 + HATCH_RESUME_GRACE). It is accepted and moves base to τ_0 + 600 + HATCH_RESUME_GRACE − HATCH_GRACE. A third hatch is refused before then.
  - The honest pipeline's ordinary landing at τ_1 + L_r (L_r ≤ HATCH_RESUME_GRACE − slot), consuming e_8…, is accepted. A later hatch is then a race lost to an already-landed range.
  - Variant: with H_0 maximal (G saves nothing old behind it), H_1 is refused before τ_0 + HATCH_RESUME_GRACE, because H_0 shifts base.
- **T30 (maximality; stuffing price at the K-block latency):** the censor saves provable c_1..c_20 one L1 block apart, then victim t. At open_1 it lands a one-entry hatch on c_1 with T_A between s_1 and s_2.
  - c_2 is old, so the hatch is non-maximal whatever T_A is. There is no shift, and c_2's window opens at once.
  - E's maximal hatch (c_2..c_20, t: 20 entries, stopping at tail or at a young entry) lands one honest-hatch latency later and executes t. That latency is a 20-block hatch's, not L_1: E's one-block hatch of c_2 is non-maximal and refused until τ + HATCH_RESUME_GRACE. With 32 or more old entries it is L_K (T34).
  - The censor's ordinary landings in between must execute c_2 (the gate), one entry per parent move.
  - A second one-entry censor hatch before τ + HATCH_RESUME_GRACE: `HatchNotPermitted`.
  - Negative: the same one-entry hatch with c_2 saved young (s_2 + HATCH_DELAY ≥ T + HATCH_RESUME_GRACE) is maximal and shifts, and c_2 opens at s_2 + HATCH_DELAY either way.
- **T31 (poison residual):** c_1 (censor, provable), then t (provable), then P (old poison). The censor's one-entry hatch on c_1 at τ stops at t, which is old, so it is non-maximal. E's hatch on t must stop at P, so it is non-maximal too: `HatchNotPermitted` until τ + HATCH_RESUME_GRACE. short keeps t open until τ + HATCH_RESUME_GRACE + HATCH_WINDOW, and E's hatch then executes t. A landing that voids t before that close fails `FiVoidNotExpired`. This holds however t became head before τ + HATCH_RESUME_GRACE: directly by the hatch, or by later ordinary landings (T33).
- **T32 (late quorum replay, outside T11):** CALLDATA id i is voided at T_L with no certified block anywhere (replayable set). Days later a quorum cartel certifies X for i with a fresh anchor (head(A_X) > i, contiguity broken). The range lands with fiReplayIds = [i]; X runs i's content and clears the bit. A second such range reverts `FiRange`. Variant: a BLOB id replayed with s_i + FI_EXPIRY ≤ T_{A_X} executes empty.
- **T33 (short survives an ordinary landing):** c1, c2 (censor, provable), t (provable CALLDATA), P (old poison within HATCH_K − 1 of t), all saved around s; hatchAt old. At τ_0 = open_c1 the censor lands a one-entry hatch on c1 (non-maximal, c2 old): short set, hatchAt = τ_0. At τ_0 + X (X ≤ HATCH_RESUME_GRACE − HATCH_WINDOW) it lands an ordinary landing executing c2 (n = 1).
  - short stays set, so close_t = max(T_L + HATCH_WINDOW, τ_0 + HATCH_RESUME_GRACE + HATCH_WINDOW) = τ_0 + HATCH_RESUME_GRACE + HATCH_WINDOW.
  - A landing with v = 1 at T_L + HATCH_WINDOW reverts `FiVoidNotExpired`.
  - E's non-maximal hatch on t (stopping at P) reverts `HatchNotPermitted` before τ_0 + HATCH_RESUME_GRACE, and is accepted at τ_0 + HATCH_RESUME_GRACE, executing t.
  - Negative (a rule where the ordinary landing clears short): the void at T_L + HATCH_WINDOW is accepted and t is burned.
  - Inertness: an ordinary landing at T_L ≥ τ_0 + HATCH_RESUME_GRACE with short still set gives the next head the same open and close as with short clear.
- **T34 (full-hatch latency, stuffing price):** the censor holds Q ≥ 33 old provable entries ahead of t. It lands an ordinary landing O_0 and, one block later, a one-entry non-maximal hatch H_0 on O_0's end (hatchAt old).
  - Within τ_0 + HATCH_RESUME_GRACE, E's one-block hatch on the head reverts `HatchNotPermitted`; E's 32-block hatch is accepted if it lands on the current parent.
  - Each ordinary landing by the censor executes exactly the head (R = 1) and turns E's stale 32-block proof into a free revert.
  - Measure: censor entries spent per 24 h of delay, as a function of L_K. §9's ceiling is max(L_K, (HATCH_RESUME_GRACE + L_K)/HATCH_K) per entry.
  - Rejected-rule check: with "also permitted once lastLanded.at > hatchAt", the censor's hatch one block after its own ordinary landing still refuses E's one-block hatch until the next ordinary landing, which the censor withholds.
- **T35 (endpoint equality, B-D41-01):** 12-second slots, an active chain, no poison, no CONFLICT. Censor entry c, then provable CALLDATA t, saved at 0. The censor keeps moving the parent until an ordinary landing at 14,400 executes only c; t opens at 14,400 and closes at 16,200, and S_t = 14,400.
  - Equality (outside A-HATCH-LATENCY): E submits at 16,188 and its hatch would be included at 16,200 = close_t. A pre-proved ordinary landing ordered first at 16,200 with n = v = 1 and no request block is accepted (E = R = 1) and voids t (bond burned); E's hatch is a free revert on a stale parent, and the permissionless hatch cannot list t as a replay. Inclusion at close is too late.
  - Under A-HATCH-LATENCY: E submits by 16,176 and is included by 16,188 < close_t. Any landing at T < 16,200 has E = 0, so v = 0 and the gate (R = 1) makes it execute t; E's hatch either lands and executes t, or loses to a landing that already executed it.
- **T36 (activation baseline, B-D41-02):** a retained provable legacy entry saved at s = 0 with N = M = H = 0; activation at 86,400. R10 sets base = 86,400 + 14,400 − 1,800 = 99,000; the entry opens at 100,800 and closes at 102,600 = close_e. The save-time formula's 16,200 does not apply (s < e). The entry is below FI_EXPIRY at 102,600, so its content runs if proven. The same check after a CONFLICT restart at r: an entry saved before r and unconsumed after it opens no earlier than r + HATCH_DELAY.
- **T37 (honest replay created after the void, B-D41-03):** u is a term start; an entry's close is u + 48. Canonical anchor A at timestamp u − 12 shows it as head, unexpired. A sound ordinary landing at u + 48 voids it with no request block and advances to a prefix X of the ongoing certified chain; no request block lies above the older anchored lastLanded.
  - After the void, the holder creates B at u + 49 on A (anchor age 61 s, inside V5's 48 to 1,800 s) and the next certified parent. Contiguity at A passes (the id is head(A)); honest attesters certify B; no cartel or false certificate is used.
  - The next range lands B with the id in fiReplayIds; its content executes once, and its deposit stays burned.
  - Bound: B's timestamp is below T_V + ANCHOR_MAX_AGE (here u + 49 < u + 48 + 1,800). A block for the id on an anchor after the void fails contiguity (head > id).

## 9. The censorship bound

**Claim** [proven, conditional on the premises below]. Take a request saved at time s in the active epoch: s ≥ e, where e is the epoch start (activationTimestamp, or the restartTimestamp of the latest CONFLICT restart), and no CONFLICT restart occurs after s before the request is consumed. Let N be the unconsumed requests ahead of it at s, M of which no hatch can execute within their window (a guest completeness bug, or a legacy entry beyond A-HATCH-LATENCY). Let

`close = s + HATCH_DELAY + (N + 1) × HATCH_WINDOW + M × HATCH_GRACE + H × HATCH_RESUME_GRACE`

H is the number of hatches that land after s and execute entries ahead of the request; H ≤ N (each hatch executes at least one entry ahead). H is not capped by N − M: an A1 hatch can execute an M-counted legacy entry before that entry's window opens. The formula holds with H the actual count, because such an entry's HATCH_WINDOW and HATCH_GRACE terms are then counted without being spent. A maximal hatch delays the next window to its own time plus HATCH_RESUME_GRACE. A non-maximal hatch keeps the natural schedule but can hold the head open until its own time plus HATCH_RESUME_GRACE + HATCH_WINDOW (C3-R04, C3-R09); this applies to every head reached before its own time plus HATCH_RESUME_GRACE, until the next hatch, and is inert after. Either way it adds at most HATCH_RESUME_GRACE, so the formula and H ≤ N are unchanged. H = 0 when the entries ahead are executed by ordinary landings. The arithmetic assumes the walk reaches the request's predecessor; behind MAX_FI_PER_LANDING consecutive expired poisons, the honest party restores this with `fiClear` within HATCH_GRACE (C3-R06a, P3a).

**Inherited entries and restarts** [proven, conditional on the same premises]. The save-time formula does not cover an entry saved before its epoch starts: a legacy or other entry already queued at activation (s < e = activationTimestamp), or an entry saved before a CONFLICT restart and unconsumed after it (e = restartTimestamp, head rewound to r.fiHeadAtStart). For such an entry, with N, M and H counted from e (N = the unconsumed entries ahead of it at e, after the rewind),

`close_e = e + HATCH_DELAY + (N + 1) × HATCH_WINDOW + M × HATCH_GRACE + H × HATCH_RESUME_GRACE`

C3-R10 sets base = e + HATCH_DELAY − HATCH_GRACE and clears `short`, and every entry ahead has s_k ≤ s < e (FIFO), so the first open is max(s_head + HATCH_DELAY, e + HATCH_DELAY) = e + HATCH_DELAY, and the schedule from e is that of a request saved at e behind the same N entries. A restart does not preserve a deadline computed before it: close_e replaces it, and can be later than it (for example whenever e > s with the same N, M and H) or earlier (N counted after the rewind can be smaller than N at s). The in-epoch formula is the case s ≥ e, where the initialized base gives e + HATCH_DELAY ≤ s + HATCH_DELAY and binds nothing beyond the formula (T36). Everything below about close applies to close_e for these entries, except the §9 Numbers, which are offsets from s for in-epoch requests; for an inherited entry they are offsets from e, and close_e − s is unbounded in s (T36).

- **If it can be proven,** it is executed on L1 at an L1 timestamp at most close − 12 s, strictly before its first voidable instant. Under A-HATCH-LATENCY the honest hatch on its parent is included by S_c + HATCH_WINDOW − 12 s ≤ close_c − 12 s ≤ close − 12 s, and any earlier landing that moves that parent executes it (the gate). Inclusion at exactly close_c is too late: a landing ordered first at close_c may void it (T35). This needs `short` to survive ordinary landings: if an ordinary landing cleared it, a censor's ordinary landing inside a non-maximal hatch's wait could void a provable request next to an old poison before E could hatch (T33). For a BLOB or LEGACY request, its content runs only if its request block's anchor is before s + FI_EXPIRY (7 days); otherwise it executes empty (G4). That holds whenever close < s + FI_EXPIRY. A CALLDATA request always runs its content.
- **Otherwise,** it is voidable from close. It is consumed (void) by the first landing at or after close, because from close the gate (R ≥ E ≥ 1) makes every landing consume it. A landing is guaranteed only by the routes the premises give: the hatch for later entries, or dead mode and replacement under A1.

This holds whatever every sequencer, committee and lander does, at any cartel share, and whatever is saved later. It uses no committee premise: origin progress and at-most-once execution are guest and inbox checks under T3. FIFO means the bound is fixed at save time for every request saved in the active epoch, not only the oldest; for an inherited entry, and for every entry saved before a CONFLICT restart and unconsumed at it, it is fixed at the epoch start instead (close_e). The landing gate that makes it hold is the reading of D39's "no per-block duty" that the user accepted in D51(1).

The bound is about L1 consumption. A request that is voided while a request block for it, anchored at a view where it was eligible before the void, is already certified, or is created and certified after the void on such an anchor, still executes on L2 as a replay (C3-R05(e)). Under T11 and with no CONFLICT restart, that block's L2 timestamp is below the void's L1 time plus ANCHOR_MAX_AGE (C3-R08, T37); this exposure is [open] for the user and not covered by D55. Outside T11, a cartel holding a quorum may also replay any voided request not yet replayed at any later time, even one that had no certified block when it was voided (C3-R08; signed by the user in D55(3), with L-HATCH-DEPOSIT). It still executes at most once, from an anchor at or after its save, and a BLOB or LEGACY request executes empty past FI_EXPIRY. None of this changes the bound or the deposit outcome (burned).

**Numbers** (offsets from s for a request saved in the active epoch; from e for an inherited entry; HATCH_DELAY = 4 h; proving latency unmeasured):
- **Empty queue:** at most 4 h 30 min. Typically 4 h plus a few minutes.
- **Each provable request ahead:** at most +30 min, plus 70 min (HATCH_RESUME_GRACE) for each hatch landed ahead: the formula's worst case is +100 min per provable request if every one is hatched alone. That worst case needs a poison. The 70 min binds only after a full hatch (32 entries), or after a non-maximal hatch whose stop the honest party cannot pass with a maximal hatch, which happens only with an old poison within 32 entries. Away from poisons, a cartel's one-entry hatch is non-maximal: it moves no window, and the honest maximal hatch follows one honest-hatch latency later. For HATCH_RESUME_GRACE after the cartel's non-maximal hatch, the honest party's own non-maximal hatches are refused too, so with 32 or more old entries ahead it must answer with a full 32-block hatch. The cartel gains up to one full-hatch latency L_K per entry (unmeasured, at most about 30 min), and about +3 min per entry only if L_K is about 3 min (D51's model; D55(1)).
- **Each poison ahead:** +60 min, and it halts all landings for 30 min; up to 100 min when it becomes head right after a non-maximal hatch, or by an ordinary landing within 70 min of one (the `short` extension; the extra 70 min is that hatch's H term). Every 64th consecutive expired poison caps the walk until someone calls `fiClear` (free, no proof).
- **Signal recovery (C1):** the first request's bound, plus the gap to retrieve the pinned header and prepare and save the reveal, plus the second request's bound (each by the formula above, with its own N, M and H). The two empty-queue ceilings sum to exactly 9 h (2 × (14,400 + 1,800) s) only with zero intervening gap; any gap, request ahead, poison or hatch adds to it, so no universal under-9 h figure holds. It is conditional on the reveal executing successfully (a non-idempotent transaction's success is not guaranteed, below) and on both requests' premises.
- **Dead pipeline:** the A1 hatch exits about 65 min after the last landing, as before. While no ordinary landing follows, a further A1 hatch is possible every 70 min (HATCH_RESUME_GRACE), up to 32 entries each. Window hatches are limited the same way: no window opens within 70 min of a hatch. This holds after a maximal hatch. After a non-maximal one, only a maximal hatch may come sooner, and after that, nothing for 70 min.

**Premises:**
- L1 includes the hatch transaction within a slot (FOCIL after Hegotá).
- Both ZK proof systems are sound and running. A one-system outage stalls the hatch until the DAO acts (L19).
- One honest party has the payload, the L2 state and a prover, and proves and submits a hatch within 30 min minus two slots (1,776 s) of S_c, so it lands at least one slot before close (A-HATCH-LATENCY). The requester can be that party. It also sends `fiClear` within HATCH_GRACE of a capped walk (an L1 transaction under T1, no proof). For a legacy entry, this includes one legacy block at 45 M gas under the 20 M zk-gas cap (unmeasured); a legacy entry that fails it counts in M.
- L1 is live.
- Blob requests are served within 7 days, or they execute empty.
- No CONFLICT halt is in progress.
- For the void case only: a landing occurs at or after close. Any later hatch, any dead-mode or replacement landing under A1, or any ordinary landing supplies it.
- T11, for C3-R06's landability claim only: a certified chain never strands behind a request block, so the gate, not validity, is the only landing restriction. The bound itself does not use T11.

**What it does not cover:**
- **Stuffing is priced, not bounded** (signed by the user in D51(4)), at a price that is a function of L_K (signed by the user in D55(1)); D51(4)'s figure is [assumed: L_K ≈ 3 min, unmeasured]. The setting is D51's. The censor holds every sequencing and lander slot and wins L1 ordering. Its stuffed entries are its own provable entries, saved before victim t. One honest party E re-proves a hatch on a new parent: one block within L_1, a full HATCH_K-block hatch within L_K (each measured from S_c to L1 inclusion; L_1 ≤ L_K ≤ HATCH_WINDOW − 12 s, A-HATCH-LATENCY). [proven, conditional on no old poison within HATCH_K entries behind any stop ahead of t] Each stuffed entry buys the censor at most max(L_K, (HATCH_RESUME_GRACE + L_K) / HATCH_K):
  - (i) Ordinary landings. Once the head's window opens, every ordinary landing executes it (the gate). So each move of E's parent costs the censor one entry and buys at most one honest-hatch latency, at most L_K. This is D51's case.
  - (ii) A non-maximal hatch: a one-entry hatch with old entries behind it, whatever its T_A (C3-R07 (4a)). It moves no window, and the head's window opens at once. For HATCH_RESUME_GRACE every non-maximal hatch is refused, E's included, so E's permitted answer is a maximal hatch: up to HATCH_K entries, landing within L_K. With 32 or more old entries ahead it must be a full hatch, so the censor can force L_K (T34). E's hatch lands unless the censor moves the parent again, which is (i), (iii) or (iv), because a second non-maximal hatch waits HATCH_RESUME_GRACE. So it buys at most L_K for at least one entry.
  - (iii) A maximal hatch that stops at tail or at a young entry. Its shift changes no open (C3-R04), so it buys nothing beyond the natural HATCH_DELAY.
  - (iv) A full hatch, by either side. It buys HATCH_RESUME_GRACE per HATCH_K entries, plus one L_K.

  The censor can realize about HATCH_RESUME_GRACE·L_K / (HATCH_RESUME_GRACE + L_K) per entry (T34): every HATCH_RESUME_GRACE an ordinary landing plus a one-entry hatch on its end, then one ordinary landing per L_K that executes exactly the head and stales E's 32-block proof. Prices to keep new requests about 24 h behind, D51's fees, all burned (FI_BONDs refunded because every stuffed entry is executed):

  | L_K | ceiling per entry, entries, price | T34 schedule per entry, entries, price |
  |---|---|---|
  | about 3 min (D51's model) | 3 min, 480, ≈ 2.78 ETH + ≈ 5.1 ETH/day (**D51(4)'s figure**) | about 2.9 min, about the same |
  | 600 s | 600 s, 144, ≈ 0.35 ETH + ≈ 0.56 ETH/day | ≈ 525 s, 165, ≈ 0.44 ETH + ≈ 0.71 ETH/day |
  | 1,800 s (A-HATCH-LATENCY's bound of 1,788 s, rounded up; the price at 1,788 s is slightly higher) | 1,800 s, 48, ≈ 0.07 ETH + ≈ 0.09 ETH/day | ≈ 1,260 s, 69, ≈ 0.12 ETH + ≈ 0.16 ETH/day, plus about 21 hatches a day (≈ 0.25 ETH/day of L1 gas at 1.2 M gas and 10 gwei, assumed) |

  [proven] The ceiling equals D51's per-entry figure iff L_K ≤ about 3 min; below HATCH_RESUME_GRACE / HATCH_K (about 131 s), (iv) caps it at about 2.2 min. [assumed] D51(4)'s figure therefore holds only if a 32-block hatch proves in about 3 min (for example with parallel provers); C6 must measure L_K. At A-HATCH-LATENCY's bound the price is roughly 20 to 50× under D51(4)'s figure. The user accepted the price as a function of L_K (D55(1), "Accept, measure later"): C6 carries a measurement procedure for L_K, and if L_K is slow the remedy is a higher FI_BASE_FEE or parallel proving before launch. No further design round.
  - Rejected alternative: also permitting a non-maximal hatch once an ordinary landing follows the last hatch (lastLanded.at > hatchAt). The censor lands its ordinary landing in one L1 block and its one-entry hatch in the next, so hatchAt > lastLanded.at again and E is still forced to a full hatch until the censor's next ordinary landing, which it withholds: about L_K per two entries, still far under D51's figure. It also lets a griefer reset the pipeline after every honest landing, weakening C3-R09. A restoring mechanism is [open]; D55(1) orders no further design round for it.
  - **Poison-adjacent residual** [proven, user]. Take an old poison P (a live guest completeness bug, or a legacy entry beyond A-HATCH-LATENCY). For a request t within HATCH_K − 1 entries ahead of P, E's hatch from any stop at or before t must stop at P, so it is non-maximal and waits HATCH_RESUME_GRACE after the censor's hatch (T31). The censor wins each race at the gate's lift, so it buys up to HATCH_RESUME_GRACE per one-entry hatch, for each of up to 31 entries ahead of P. That is up to about 36 h per poison. It costs about 31 own entries (about 0.04 ETH of fees), about 31 hatch landings (about 0.37 ETH of L1 gas at 1.2 M gas and 10 gwei, assumed) and the poison (0.051 ETH plus the bug). `short` keeps t's window open, so t is still executed by the formula's close (H counts these hatches). This holds whichever way t becomes head before the censor's hatchAt + HATCH_RESUME_GRACE, because `short` survives ordinary landings (T33); if an ordinary landing cleared `short`, the censor could instead void t (about one victim per HATCH_RESUME_GRACE, up to about 10 per poison). Legacy poisons give the residual only inside the finite legacy range, once. Closing the residual would need the inbox to tell a poison stop from a deliberate one, which it cannot. The same indistinguishability is why a non-maximal hatch must wait (T29). The user signed it with L-HATCH-POISON (D55(2), "Accept both").
  - Rejected alternatives: applying the shift to every hatch gives the censor HATCH_RESUME_GRACE per entry without a poison. "Maximal" defined by T_A alone is gamed by an old anchor (C3-R07 (4a)). A non-maximal hatch that shifts, plus an exception for a following maximal hatch, leaves ordinary landings ungated during the shift, so the censor moves E's parent for free. Rescaling FI_BASE_FEE as the only answer raises the honest save price about 23 to 33×.
- **Poison** needs a live guest completeness bug and costs 0.051 ETH each. Or a legacy entry no hatch proves within the window, until measured; those exist only from Shasta-era saves.
- **Stuffing past about 7 days** turns blob and legacy requests behind it into empty executions (G4). Calldata requests are unaffected.
- **Success of a non-idempotent transaction is not guaranteed:** an includer can pre-execute it in a context of its choosing.

## 10. Obligations on other sections

Each row is **open** until that section adopts it. The C2 and C4 rows are follow-up PRs on merged sections; the others are consumed at each section's next synchronization (D41).

| Section | Edit owed | Status |
|---|---|---|
| C1 | (1) C1-R05's pin runs as a system operation in every request block, after the EIP-4788 and EIP-2935 operations and before its transactions; it creates no transaction, nonce or receipt and writes the pin bit only if absent (C3-R05(d), G1). (2) Origin progress: a landed request block's anchor is at or after its entry's save (C3-R05 claim), so a request saved after a signal pins an origin containing it. (3) Signal recovery is the first request's §9 bound, plus the retrieval and save gap, plus the second request's bound; the two empty-queue ceilings sum to exactly 9 h only with zero gap, conditional on the reveal executing successfully and both requests' premises (no universal under-9 h figure). (4) C1's 1,636-byte reveal against FI_CALLDATA_MAX, and its gas against FI_GAS_LIMIT and FI_ZK_GAS_LIMIT. Derived from D41's consumer list; not in the D41 candidate's edit list. | **Open** until C1 adopts it. |
| C2 | (1) C2-R02: the FI record gains a u48 id trailer and no txListBytes; request records, replays included, count toward V10. (2) C2-R04: the journal FI fields are fiHeadBefore, fiHeadAfter and fiVoidCount (fixed, LandInput), fiConsumedHash (fixed, inbox), **fiReplayHash** (fixed, inbox, over LandInput fiReplayIds) and fiParentTimestamp (forced journal); the guest asserts C3-R08's order (the replay blocks, then [fiHeadBefore + v, fiHeadAfter)); the guest asserts s_i ≤ T_{A_b} for every kind-FI block (C3-R08); the inbox requires the replayable bit for each fiReplayIds id and clears it, and re-consumption after a restart writes the bit (C3-R03); (kind_i, dataHash_i) follow C3 §1, including the legacy derivation; the partition claim cites C3-R06 (fiReplayIds is unique per range); otherwise as in the D41 synthesis. (3) C2-R07: keep "the only unlandable certified content is a guest bug" and add "up to C3-R06's gate; VALID_GOSSIP request blocks are landable (C3-R06 landability claim)". (4) C2-R09: "until a replacement or hatch lands"; the ring becomes `hatchTip`, keyed (endHeight, endPhHash); the RESUME l1Ref is "the L1 block containing the replacement, dead-mode or hatch landing resumed from"; attestable per C3-R09's single predicate; `recordViewChange` keeps A1 for RESUME records; a window hatch voids before A1; a hatch's A1 disjunct also needs T ≥ hatchAt + HATCH_RESUME_GRACE (C3-R07 (1)), while replacement and dead mode keep A1 as is; hatchTip[N] is rewritten by every landing later in N (C3-R06 step 7); a maximal hatch moves base so that no forced-inclusion window opens before hatchAt + HATCH_RESUME_GRACE (C3-R04), and a non-maximal hatch waits HATCH_RESUME_GRACE after any hatch on either disjunct and extends the head's close instead of moving base (C3-R07 (4a)), so after a maximal hatch every hatch waits HATCH_RESUME_GRACE, and after a non-maximal one only a maximal hatch may come sooner. (5) Premises: C3 cites T11 only, for landability; C3 no longer cites A-CERT. (6) §10: LandInput gains fiHeadAfter (u48) and fiVoidCount (u16), **fiReplayIds (u48[], at most MAX_FI_PER_LANDING)**, and for a hatch the anchor number and fiParentTimestamp. | **Open** until C2's follow-up PR adopts it. (C2-R14 sync, from B's review of #22217) C2-R14 and the LandInput/Journal fields drop fiClearTip and fiRun, which the hatch has no use for; the restart sets base, hatchAt, hatchL1 and short per C3-R10. Open until C2 adopts it. |
| C4 | C4-R06, added bullet: the legacy entry's C3 identity is kind LEGACY, derived from i < Q; dataHash_i = keccak256(abi.encode(versionedHash, offset, codecRevision)), computed by the inbox from the retained BlobSlice and the committed codec revision; no stored kind byte (consistent with the Inbox layout row: "no kind byte is fabricated"); every void (first consumption, re-void after a CONFLICT restart, or `fiClear`) sets a one-bit `legacyReplayable` flag, and every execution (first consumption, re-execution after a restart, or replay) clears it. Both are masked writes moving no money; the restart retention rule ("retaining legacy settled flags") must allow this one bit to change on re-consumption. The legacy expiry and the LEGACY_BLOB promise stay open with C4 and the user (D51). | **Open** until C4's follow-up PR adopts it. |
| C5 | FOCIL-protected legs are calldata saves, the blob-free hatch and withdrawals; blob saves are not protected (L12); before Hegotá the floor is T1 (C3-R12). The hatch's anchor hash is read by blockhash or EIP-2935 (C3-R07 check 5). Derived from D41's consumer list; not in the D41 candidate's edit list. | **Open** until C5 adopts it. |
| C6 | (1) L-HATCH-DEPOSIT: "a request nobody executes forfeits its deposit; a voided request whose request block is anchored at a view where it was eligible before the void still executes on L2 as a replay, at most once, deposit burned, even when that block is created and certified after the void (under T11, no restart: L2 timestamp below the void's L1 time plus ANCHOR_MAX_AGE; [open] for the user, not covered by D55). Outside T11, a cartel holding a quorum may replay any voided request not yet replayed at any later time, even one with no certified block when it was voided. It still runs at most once, from an anchor at or after its save, and a BLOB or LEGACY request runs empty past FI_EXPIRY" (the outside-T11 replay signed, D55(3)). (2) L-HATCH-POISON: "needs a live guest completeness bug, or a legacy entry that no hatch can prove within HATCH_WINDOW (until C6 measures a legacy block at LEGACY_FI_GAS_LIMIT under FI_ZK_GAS_LIMIT). Legacy entries are a finite set, [initialEtnaFiHead, Q), seeded only by Shasta-era saves before activation."; add "a run of MAX_FI_PER_LANDING expired poisons caps the walk; anyone clears it with `fiClear`, which voids them without moving lastLanded"; add "a poison that becomes head after a non-maximal hatch halts landings for up to HATCH_RESUME_GRACE + HATCH_WINDOW rather than HATCH_WINDOW. An old poison within HATCH_K entries behind a request lets a censor buy up to HATCH_RESUME_GRACE per one-entry hatch for the up to HATCH_K − 1 entries ahead of it (§9)" (the residual signed, D55(2); the halt still open, §11). (3) L-HATCH-ROUTE: add "any further hatch, A1 or window, waits HATCH_RESUME_GRACE after a maximal hatch; after a non-maximal hatch, only a maximal hatch may come sooner, and then none for HATCH_RESUME_GRACE". (4) L-HATCH-STUFF: "priced, not bounded. Each stuffed entry buys at most about L_K, the interval from S_c to L1 inclusion of a full HATCH_K-block hatch (A-HATCH-LATENCY; unmeasured, at most about 30 min), because a censor's one-entry hatch forces the honest party to full hatches for HATCH_RESUME_GRACE. D51(4)'s figure (about 3 min per entry, about 2.8 ETH plus about 5 ETH/day for 24 h) holds only if L_K is about 3 min; at L_K = 30 min the price is about 0.1 ETH up front plus about 0.2 to 0.4 ETH/day. Next to a poison, see L-HATCH-POISON" (signed as a function of L_K, D55(1)). (5) Unmeasured register: a legacy block's proving time at LEGACY_FI_GAS_LIMIT under FI_ZK_GAS_LIMIT against HATCH_WINDOW minus two slots (acquisition, proof and submission, measured from S_c; A-HATCH-LATENCY); A-HONEST-RESUME (hatch to first ordinary landing) against HATCH_RESUME_GRACE; and D55(1)'s measurement procedure for L_K, the full HATCH_K-block hatch's interval from S_c to L1 inclusion (the interval L-HATCH-STUFF prices), with the remedy (a higher FI_BASE_FEE or parallel proving before launch) if it is slow. (6) D54's carried hatch items: remove the bonded-hatch premise, and treat the queue costs as illustrations, not measurements. Derived from D54; not in the D41 candidate's edit list. | **Open** until C6 adopts it. |
| C7 | (1) C7-R11: the rule becomes "V8, request blocks (C3-R05(b), with contiguity)", evaluated at step 12 on the L1 state at the block's anchor; add the statement "request-block validity is landable (C3-R06), up to the gate". (2) Vectors: delete the C7-T08 inheritance and C7-T10 waiver cases; add C3-T10, T11 and T19. | **Open** until C7 adopts it. |
| C8 | (1) Storage: FiQueue {u48 head, tail, base, hatchAt; u63 hatchL1; 1 bit short} (256 bits); the entry word for ids ≥ Q, with its `replayable` bit (status 10 retired; void writes 11) and the legacy `legacyReplayable` bit beside legacySettled (C4-R06); `mapping(uint64 => bytes32) hatchTip`, value keccak256(abi.encode(uint64 endHeight, bytes32 endPhHash)); delete FiStall and the ring. (2) Interface: `fiClear()` (C3-R06a), error `FiNotCapped`; `hatchStatus()` gains `capped` and `short`; a non-maximal hatch inside hatchAt + HATCH_RESUME_GRACE reverts `HatchNotPermitted`. (3) The DOMAIN_FI txListHash encoding includes the legacy dataHash_i derivation and the u48 trailer. | **Open** until C8 adopts it (D49 item 4). |
| S1 | D52's carried hatch synchronization: S1-R16's waiver sentence goes (D39: no waiver), and sentinel view-255 ranges may carry kind-FI request blocks (§1, request block). Derived from D52; not in the D41 candidate's edit list. | **Open** until S1 adopts it. |
| S2 | (1) S2-R09: l1Ref for RESUME names "the L1 block containing the replacement, dead-mode or hatch landing resumed from"; clause (2), the verified L1 landing record, is C3-R09's predicate (A1 held at l1Ref on the state before that block's landings, or `hatchTip[l1Ref.number] == keccak256(abi.encode(lockHeight, lockPhHash))`); remove "which S3d recomputes against C2's forced ring". (2) S2-R15: REPLACE is attested only when A1 holds at the signed L1 reference; RESUME is attested only under C3-R09's predicate, the reference meeting S2-R09's staleness rule in both cases; RESET fires "on a landed replacement or hatch"; `recordViewChange` is unchanged. (3) S2-R18: the "replaceable" label adds "an A1 hatch waits HATCH_RESUME_GRACE after any hatch (read hatchAt at the node's reference)"; a window hatch waits the same, through base, after a maximal hatch only; after a non-maximal hatch, only a maximal hatch (C3-R07 (4a)) may come sooner, so a node reads short and hatchAt. (4) Add vectors: **S2-V17′:** a RESUME after a dead-mode or REPLACE landing in N, hatchTip[N] = 0, A1 true at N: attested, no S3d. **S2-V17″:** a RESUME after a pre-A1 window hatch in N, matched through hatchTip on (lockHeight, lockPhHash): attested, no S3d; this mirrors C3-T12. **S2-V17‴:** A1 false and hatchTip mismatched: not attested; S3d slashes; this mirrors C3-T17. | **Open** until S2 adopts it. |
| S3 | S3d: evidence is a REPLACE or RESUME lock vote whose signed l1Ref is non-canonical, or, for REPLACE, names a block at which A1 did not hold, or, for RESUME, names a block at which A1 did not hold **and** `hatchTip[l1Ref.number] ≠ keccak256(abi.encode(lockHeight, lockPhHash))`, with both values from the signed preimage. Check: canonicality by `blockhash` or EIP-2935; `replaceableFrom` recomputed as of that L1 block from the term records; for RESUME, one more storage read of hatchTip. One single verification. COMMITTEE_RING no longer needs a forced-ring bound. | **Open** until S3 adopts it. |
| S4 | S4-R10 becomes C3 §9 (the reworded consumption). D53's carried items: zero hatch bond, the landing gate and delay, and the signed stuffing and window-hatch limitations (D51), now with D55's limitations. | **Open** until S4 adopts it. |

## 11. Open items

- The anchor-exemption alternative to G6, which needs its own round.
- A confirmation red-team of G1 to G7 and of the replay and contiguity rules. D41 records confirmation rounds R2 to R7 with an independent verifier; the final round found no real break; J's D6 verdict is outstanding.
- The unmeasured latencies L_1 and L_K, and hatch gas. C6 carries the measurement procedure for L_K (D55(1)).
- The proving time of a legacy block at LEGACY_FI_GAS_LIMIT under FI_ZK_GAS_LIMIT, and A-HONEST-RESUME against HATCH_RESUME_GRACE. A-HONEST-RESUME against HATCH_RESUME_GRACE also sets the bound's per-hatch cost (§9).
- RE-2 Low 2 (not addressed): an honest announcer whose backlog lacks current loses ANNOUNCE_BOND to a pre-A1 window hatch (C2-R08).
- A confirmation red-team of `fiClear`, the replayable bit and the post-hatch window shift.
- A confirmation red-team of the maximal / non-maximal split, the young threshold and `short`, under the censor and compose lenses. Answered for whether a mix of non-maximal and maximal hatches buys more than one honest-hatch latency per stuffed entry away from poisons: it buys up to L_K per entry (T34). The persistent `short` (R7) was attacked under the censor, honest and compose lenses in the round after it (wf_f159a384-30a, round 2) with no real break; B's W18 attack and J's D6 verdict remain the merge gates.
- A mechanism that restores D51(4)'s price at L_K > L_1 without reopening T29, one that lets E's short (non-maximal) hatch answer a censor's non-maximal hatch inside HATCH_RESUME_GRACE. "Also permit after an ordinary landing" is rejected (§9). D55(1) accepts the L_K-dependent price and orders no further design round.
- The honest-hatch latencies behind D51's "about 3 min per entry" are unmeasured. The price depends on L_K, the full HATCH_K-block hatch latency, not on L_1 (T34). D51(4)'s figure holds iff L_K is about 3 min (for example by parallel proving); C6 must measure L_K.
- The honest-validity replay of a voided id whose request block, anchored before the void, is created and certified after it (C3-R08, T37, B-D41-03): under T11 and with no CONFLICT restart, its L2 timestamp is below the void's L1 time plus ANCHOR_MAX_AGE. It is distinct from D55(3)'s outside-T11 replay, is not covered by D55, and stays [open] for the user.
- The poison-adjacent stuffing residual is signed (D55(2)). The lengthened poison halt (up to HATCH_RESUME_GRACE + HATCH_WINDOW instead of HATCH_WINDOW, §9) goes with L-HATCH-POISON; it is not named in D55's question and stays [open] for the user.
- The legacy expiry and the LEGACY_BLOB execution promise, with C4 and the user (D51); FI_ZK_GAS_LIMIT on legacy request blocks is part of it.
- Every row of §10 until its section adopts it.

## 12. Revision history and sources

### Revision history

D39 replaced the per-block obligation with a minimal hatch. Three designs were red-teamed in wf_5daabb24-e28; all six attacks stood, and trace T-A showed that every hatch needs a landing gate. The synthesis adopted design 2 (a windowed FIFO with a landing gate through the current request) with grafts G1 to G7: the pin as a system operation (G1), `hatchTip` for RESUME in place of FORCED_RING (G2), no A1 amendment (G3), empty execution past FI_EXPIRY (G4), the hatch after A1 (G5), honest-outage stranding accepted (G6), over-budget transactions skipped (G7). Confirmation rounds R2 to R7 then ran in wf_7faaf509-d42, wf_bd75ec48-7b9 and wf_f159a384-30a, with an independent verifier on every claimed break (D41):
- **R2:** one RESUME predicate for C3-R09, S2-R09, S2-R15 and S3d; `hatchTip` keyed on (endHeight, endPhHash); replay blocks; request-block contiguity as validity (closing C3-R11's attester-skip item); the legacy kind and dataHash.
- **R3:** the guest's s_i ≤ T_{A_b} assertion; T11 in place of a misquoted A-CERT; HATCH_RESUME_GRACE after any hatch for the A1 disjunct (stored hatchAt); hatchTip rewritten by every later landing in the hatch's L1 block; FI_ZK_GAS_LIMIT for legacy blocks.
- **R4:** `fiClear()` for a capped walk; the `replayable` bit in place of status 10; every hatch shifting base by HATCH_RESUME_GRACE (against post-outage window-hatch griefing).
- **R5:** re-priced stuffing for R4's shift (about 100× below D51(4)); withdrawn by R6, as were its "+70 to 100 min per entry" figure and its FI_BASE_FEE rescaling.
- **R6:** only a maximal hatch shifts base; a non-maximal hatch waits HATCH_RESUME_GRACE and sets `short`; the scope of a quorum cartel's late replay is stated (T32).
- **R7:** `short` persists until the next hatch, `fiClear` or restart (R6 cleared it on every landing that advanced head, letting a censor void a provable request next to an old poison, T33); the stuffing price is restated as a function of the full-hatch latency L_K (R6's "+3 min per entry, D51(4) restored" assumed a one-block answer, T34). The user then signed that price and the residuals in D55.
- **W18 (B, #22191 comment 5951827846, on `76c6150` frozen by D56):** request changes, four Mediums, applied in this head, which is the next head for review under D56. B-D41-01: A-HATCH-LATENCY now ends inclusion at least one slot before close, measured from S_c; L_1 and L_K use that interval; inclusion at close is too late (T35). B-D41-02: the save-time bound is scoped to the active epoch, with close_e for inherited entries and after a CONFLICT restart (T36). B-D41-03: the T11 replay is stated by an eligible pre-void anchored view, bounded by ANCHOR_MAX_AGE after the void, and left open for the user (T37). B-D41-04: signal recovery is the two bounds plus the gap, with 9 h only as the sum of two empty-queue ceilings at zero gap.
- **Synchronization (D59, D60, D62):** on C3 as merged at `c0b5267` (D59): B's L40 note applied (A-HATCH-LATENCY's sketch names the `n == E && capped` branch beside n > E); the fresh out-of-order form of the contiguity gap (D60 (2)) stated beside C3-R08, citing C7 as merged at `0f0a2f0` (D62).

### Sources

**[assumed: sources]** The D41 candidate C3 text at round R7 (C3-cur: §1 the section, §2 the edits owed by other sections, §3 the bound in plain words, §4 the D41 row), which replaces C3 at `4aa0299` in full. Decision-log entries: D39 (scope), D41 (the design and its rounds), D51 (the user's product choices), D55 (the user's signed limitations), D17 (termId = termOf(ts_0)), D18 (per-id irreversible settlement), D12, D14 and D22 (FI parts superseded), D33 (withdrawn), D49, D52, D53 and D54 (synchronization items carried for C8, S1, S4 and C6).

**[assumed: credit]** The windowed FIFO with a landing gate is design 2 of the D41 synthesis; the grafts and repairs are the red-team rounds' findings, each verified independently before it was repaired.
