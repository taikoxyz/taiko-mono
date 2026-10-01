# C2. Landing: propose-with-proof

**Owner:** A. **Reviewer:** B. **Independent reviewer:** J (DeepSeek).

**Status [open]:** proposed section, transcribed from candidate A's verified pages at `b311d1d` (`claude/beautiful-maxwell-8pyecj`), awaiting B's verdict; J's review of #22196 (2026-10-01) is applied under the arbiter's decisions (J-1 in C2-R14, C2-R15 and the new C2-R21; J-2 in C2-R18 and §16 item 10). A specification, not an implementation. Every rule keeps its citation to the page section and the red-team round that produced it; where the pages state a rule two ways or leave a number underived, §16 records it instead of resolving it. B's encoding vectors (decomposition, row C2) are an open appendix obligation (§14).

## 1. Scope, vocabulary and claim convention

**[assumed: section boundary]** C2 owns the one L1 landing action and what it carries; the proof-system set and its rotation; the canonical blob encoding and the journal; the inbox checks and the guest statement; the landing-based arbitration; the L1 checkpoint write with the provisional-finality rule and CONFLICT; the landing rewards as formulas (the seam to S3); the retention duty; and the origin authentication C1 consumes. C1 owns the L2 header profile, oracle, pins and reveals; C3 the forced-inclusion queue, due-ness, stall rule and refunds (C2 names only what a landing reads and writes there); C4 the migration and the shared-contract change table; C5 the frame-transaction gate; C7 the block-validity predicate V1 to V10, which the guest asserts and C2 cites by id; C8 indexes §10; S1 seats, sortition and the committee walk; S2 certificates, view changes and the FALLBACK, TIMEOUT and TERM_END gates; S3 the reserve sizing, slashing and every reward derivation; C6 the threat model, the limitations register and the unmeasured-numbers register. Their text is not repeated here (`00-decomposition.md` §1; D9, D10).

**[assumed: notation]** **Assumed** marks a proposed rule or premise; **proven** an argument made on this page, not a machine check; **open** an unresolved point with its closure condition. `C2-Rnn` has one normative definition. §12 is C2's only register of numbers. "Round n, Rn…" cites candidate A's red-team iterations; "after the #22188 review" cites A's revision on B's review of PR #22184 (2026-10-01).

| Term | Definition [assumed: vocabulary] |
|---|---|
| Landing | One L1 transaction, `land` or `landFor`, carrying a range of certified L2 blocks as blobs plus one proof, accepted by the existing Inbox proxy. |
| Range, segment | The blocks `[lastLanded.height + 1, endHeight]` a landing carries, chosen by the lander; a segment is the part in one view, `(termId, view, sequencer, firstHeight, lastHeight, fiCount)`. |
| lastLanded | The inbox's record of the newest landed block (§10, `LastLanded`). |
| Lander | Any address that sends a landing; no role, bond or registration. |
| Leaf | One ZK proof system among the verifier's ZK_N; a TEE leaf never counts. |
| Journal, record, anchor tip | The proof's public input (§3); one block's canonical bytes in the payload (§2); the newest L1 block any block of the range anchors, checked by the inbox against L1 history. |
| Provisional record, checkpoint | The stored record of a one-leaf landing (§6); the existing L1 SignalService tuple `(uint48 blockNumber, bytes32 blockHash, bytes32 stateRoot)`, whose L2 side and write semantics (C1-R06, C1-R07) C1 defines. |

**[assumed: named premises]** T1: L1 includes and orders transactions; total L1 censorship is outside the design (L12, L13). T2 (arguments page): L1 retains blob data for about 18 days (l1-dependencies page: the duration is preserved under shorter slots by EIP-8198, EIP-7782 is silent), and nodes derive within that window. A-ARCHIVE: bytes of landed ranges older than the T2 window are held by archive operators (archive and RPC nodes, anyone who derived them in the window); nothing enforces or rewards it, and a node syncing after the window needs such a holder (as C1's A-ARCHIVE). T3 (arguments page): ZK soundness of the leaves that accept a journal. A-L1HIST: `blockhash` within 256 blocks and the EIP-2935 contract within 8,191 return canonical L1 hashes at landing time; keccak is collision resistant (an L1 fact the pages fold into L7; named here, not a page premise id). T11: fewer than Q colluders in any committee (S2); C2 relies on it only in single-proof mode and for "certified implies executed by Q attesters" (V6). A3: the ZK leaves are independent implementations; a TEE attests nothing about soundness; a common-mode guest bug is outside A3 (L7). A-CERT: a certificate passing L5 is Q(m) signatures of the committee S1 pins for the term over the end header hash (S2). A-FI: C3 defines due-ness at the anchored time, the stall clock, the void set and the status bits L8 reads and writes. A-EXEC: builder, importer and guest implement the same C7 predicate and C1 profile.

## 2. The landing action and the canonical encoding

### C2-R01. One action, lander-chosen ranges, no seal

**[assumed: proposed rule]** `land(LandInput)` (anyone; `rewardTo` in calldata) or `landFor(rewardTo, LandInput)` (only the frame gate G_LAND, C5) carries a range of certified blocks as blobs attached in range order plus one proof, and is the only L1 action that advances `lastLanded`. There is no propose step and no sequencer seal: the batch commitment is the digest every party computes from the certified chain (C2-R02), and the committee's view change pins where a view ends (S2). Anyone may land any certified prefix spanning at most MAX_VIEWS consecutive views, MAX_BLOCKS blocks and MAX_BLOBS blobs; several landings may sit adjacent in one L1 block; an oversized landing is not includable, never slashable. Deadlines are economic only: nothing voids by clock inside the horizon (C2-R10) and no rule penalizes a holder for not landing (invariant I5, S3). Checks run cheapest first and the proof last, so a race loser exits within about 25k gas without the gate and the proof's revert rolls back every write. (Landing §1, §3, §8; round 4, D9; the no-seal design from the judge synthesis of the B4 round.) **Adversary schedule:** a withheld seal (none exists); range splitting for reward (C2-R16); a stale copy after the parent moved (`NotNext`, free under the primary shape, C2-R20).

### C2-R02. Canonical blob encoding

**[assumed: proposed rule]**

```text
payload = 0x03 || u32(numBlocks) || Σ_i ( u32(len(rec_i)) || rec_i )
rec_i   = headerCore_i || seqSig_i (65 B) || [viewChangeBytes_i if first block of a view] || txListBytes_i
FI rec  = headerCore_i || seqSig_i || [viewChangeBytes_i]            (no txListBytes)
```

`headerCore` is the non-derivable subset of the signed header PH and the block header: timestamp, coinbase, gasLimit, anchorNumber, anchor hash (the header's `parentBeaconBlockRoot`), carried certificate height and hash, termId, view, kind, vcHash, txListHash. Every block carries `vcHash` here and only here, so the guest rebuilds PH from this record and the block header. `txListBytes` are the exact compressed bytes whose keccak is `txListHash` (the sequencer's own zlib stream, never re-compressed). An FI block's record stops before `txListBytes`: its transactions derive from the queue entry's payload witness, which hashes to the entry's `dataHash` (C3), so the record is about 250 bytes and no FI block adds a blob. Packing is today's blob coder, 130,044 usable bytes per blob, zero-padded, split in order. `||` here is byte concatenation of fixed-width fields; every protocol hash elsewhere is keccak256 over `abi.encode` of typed fields (interfaces page, convention adopted from PR #22188). (Landing §2; FI record without payload, round 6 fix pass; `kind` added, L1 state root and seat dropped, issue #22147.)

**[proven: encoding determinism, conditional on V1 and C3's payload witness]** No byte of the payload is the lander's choice: framing is fixed, each record's fields are signed by the sequencer (PH, seqSig), fixed by the committee (viewChangeBytes) or committed by `txListHash`. So two landers of one range produce bit-identical blobs, the versioned hashes are a function of the certified block set and the range, and any prover's proof is usable by any lander. A misencoded landing yields an end hash different from the certificate and fails L5, self-harm only.

**[assumed: bounds consumed]** C7's V9 bounds every record to 130,035 bytes, so a framed single block (nine framing bytes) fits one blob and any certified block is landable alone at every slot time; further records add 4 framing bytes each. C7's V10 bounds a term's sequencer-block records to TERM_BYTES_MAX = 5 × LANDING_UNIT; FI blocks and forced batches (view 254) are exempt from V10, bounded by MAX_FI per landing. MAX_ENVELOPE on the P2P layer equals V9 (S2). (Round 2, H1; round 3, H3; round 4, R4H-6; round 6, R6H-3.)

## 3. Proof systems and the journal

### C2-R03. The proof-system set, image sets and rotation

**[assumed: proposed rule]** The verifier holds ZK_N leaves (RISC0 and SP1 at launch, a third the target) and accepts a landing in normal mode only when ZK_K = 2 distinct ZK leaves accept the same `journalHash`; a TEE leaf never counts in any mode. Each leaf keeps today's staticcall shape plus `require(remote.code.length > 0)` and an image set `{current, previous, previousValidUntil}`; a DAO rotation moves the old set to `previous` with `previousValidUntil = now + ROTATION_OVERLAP`, or zero when flagged emergency. `verify(journalHash, proof, kRequired)` reverts unless `kRequired` distinct ZK leaves accept; `kRequired` is ZK_K except in single-proof mode (C2-R12). (Landing §7; TH1, TH20.) **Adversary schedule:** one forged proof (needs a second independent leaf, A3); a retired image trusted for ROTATION_OVERLAP after a non-emergency rotation (accepted, landing §14).

### C2-R04. The journal and what the guest proves

**[assumed: proposed rule]**

```text
Journal { chainId, protocolParamsHash,
          parentBlockHash, parentStateRoot, firstHeight,
          endHeight, endBlockHash, endStateRoot, endPhHash,
          blobHashesRoot, segmentsRoot, vcHashOfFirstBlock,
          l1AnchorTipNumber, l1AnchorTipHash, l1AnchorTipTimestamp,
          fiHeadBefore, fiHeadAfter, fiConsumedHash,
          fiClearTipBefore, fiClearTipAfter, fiStallMask, fiStallClock, fiNotDueAt,
          rewardTo }
journalHash = keccak256(abi.encode(Journal));  leaf input = hashPublicInputs(journalHash, leaf, address(0), chainId)
```

`protocolParamsHash = keccak256(abi.encode(params))` over every guest-visible constant published by `protocolParams()` on the inbox (TH25; Anchor page §8): a mismatched guest yields no valid proof, a liveness failure, never a soundness one. `parentBlockHash` and `parentStateRoot` are `lastLanded`'s, from storage. `blobHashesRoot = keccak256(hashes)` over the blob versioned hashes the inbox reads with `blobhash(i)`; `segmentsRoot = keccak256(segments[])` as L4 resolves them; `vcHashOfFirstBlock` is 0 when the range continues an open view; `rewardTo` is bound for every landing kind, so proofs are per lander (round 2, S6: a copied proof with a swapped reward address would otherwise land identically). The stall fields and `fiNotDueAt` are C3's, bound so the inbox reads no mutable storage into the consumed-entry hash (round 6, R6H-1). `deadline` is calldata only.

The guest proves, over blobs whose recomputed versioned hashes match `blobHashesRoot`: decoding yields blocks `firstHeight..endHeight`; each rebuilt PH's `seqSig` recovers to the view's leader and each header's `extraData` carries that PH's `(termId, view)`, the block's kind and the fee-sharing byte (C1-R03, H1); each `parentBeaconBlockRoot` is non-zero and equals the keccak of the witnessed L1 header numbered `PH.anchorNumber` (H2, V5); the first block of a view carries `vcHashOfFirstBlock`; every block executes VALID from the parent state to exactly its `blockHash` (V6); hashes chain from `parentBlockHash` to `endBlockHash`, whose header carries `endStateRoot`; every anchored L1 header lies on a parent-hash chain ending at the journal's tip (a chain of at most MAX_L1_HEADERS_PER_LANDING headers, intermediate non-anchored headers counted; a lander splits a range whose anchor span exceeds the cap, so liveness is unaffected), anchor numbers monotone from the parent's, V5's age bounds; timestamps obey V4; the FI blocks are exactly the consumed queue entries in order, derived from their own payload witness at C3's placement, every entry due at a stall's cut derived as the empty FI block and marked in `fiStallMask`, with the other stall fields as C3 defines them. Sequence, rights, certificate, blob hashes, anchor tip, queue state and deadlines stay outside the proof (C2-R05); execution, derivation, the anchored L1 headers, FI contents and per-block signatures are inside it. (Landing §4; round 6, R6H-1; issue #22147.)

**[proven: binding, conditional on T3 (ZK soundness of the accepting leaves), A3 and A-L1HIST]** No state root is finalized without valid proofs over a journal binding the parent root (storage), the blob hashes (`blobhash`), the anchor tip (`blockhash` or EIP-2935, L7), the consumed entries and stall clock (storage), an inequality on the first unconsumed entry's save time (L8) and the certified end hash (L5). An entry saved after the proof was made has a save time later than every anchor of the range and passes L8, so saving an entry cannot make a proven landing revert.

## 4. What the inbox checks

### C2-R05. Inbox checks L1 to L11, in order

**[assumed: proposed rule]** (Landing §3.)

- **L1 sequence.** `firstHeight == lastLanded.height + 1`, else `NotNext`; at least one block (`endHeight >= firstHeight`) and at most MAX_BLOCKS blocks; no one-per-L1-block rule.
- **L2 deadline** (degraded shape only, C2-R20). `deadline == 0 || block.timestamp <= deadline`.
- **L3 parent link.** `parentBlockHash == lastLanded.blockHash`; the journal's parent hash and root come from storage, never calldata.
- **L4 segments, views and rights.** `segments[]` lists up to MAX_VIEWS consecutive segments; `viewChanges[]` is the VC chain from `lastVCHash` through every boundary, each VC's lock equal to the previous segment's last block, at most V_MAX per term, each equal to the first live VC recorded on L1 for its `(t, v, closes)` if one exists (a REPLACE or RESUME record is dead once `lastLanded.height > vc.lockHeight`, C2-R09), each verified against the committee of its signer term at its redraw count under the FALLBACK gate, precedence and certificate-record rules S2 owns (round 5, R5S-5; round 6, R6S-3). Each segment's sequencer satisfies `isHolder(t, v, sequencer)` as S1 computes it from the domain version effective at `termStart(t)` (round 4, R4H-1), or, with sentinel view 255, the term is open-empty, the chain in dead mode and the sequencer bonded, or the term in no-committee mode and the sequencer its sortition holder, any bonded address after the economic deadline (round 2, S9); sentinel segments open with `keccak256(abi.encode(bytes32("ETNA_DEAD"), lastLanded.blockHash, uint32 t))`. Committees are the inbox's own pinned walk `committeeRoot[t]`, pinned by `recordAssignment(t)` or by the first landing that settles `t` (an unpinned term inside the horizon is walked in the same transaction); the committee proof's key hashes are checked against that root, never taken from calldata. A term older than ROLE_HORIZON is read from its pin; never pinned, it is unlandable (C2-R10).
- **L5 end certificate.** `endCert.height == endHeight`, `endCert.phHash == endPhHash`, `popcount(bitmap) >= Q(m)` for the last segment's committee of size `m` at the certificate's redraw count, aggregate signature valid (one pairing). Intermediate segments ended by a TIMEOUT, TERM_END, REPLACE or RESUME VC need no certificate; one ended by a FALLBACK VC needs a certificate of committee(t) at the FALLBACK lock, or the lock equals `lastLanded` (round 5, R5S-5). Sentinel views and forced batches: an empty certificate, and the verifier never degraded (C2-R11). Verified on L1, not in the guest, so the withholding defence never rests on ZK soundness.
- **L6 blobs.** `blobhash(i) == blobHashes[i]` for `i < n <= MAX_BLOBS`, `blobhash(n) == 0`; `blobHashesRoot = keccak256(hashes)`.
- **L7 anchor tip.** `l1AnchorTipNumber < block.number` and `>= lastLanded.anchorTipNumber`; the hash equals `blockhash` within 256 blocks, else the EIP-2935 contract within 8,191; older is refused, `AnchorTooOld` (TH17).
- **L8 forced inclusion.** `fiHeadBefore` equals the queue head; the consumed count meets C3's anchored-time floor (T_floor the start of the first segment's term, capped at the stall's cut for a void-by-stall landing; at most MAX_FI), stall-voided entries counting as consumed; `fiConsumedHash` over the consumed entries; the stored entry at `fiHeadAfter`, if any, has `savedAt + FI_DELAY > fiNotDueAt`; each consumed entry's fee less its surcharge is credited to the includer's ETH pull ledger and its status written into its kind byte (C3's formulas); `fiClearTip` set from the journal. (Round 6, R6H-1 and fix pass.)
- **L9 replacement** (only if `replace` is set). C2-R08: `block.timestamp > replaceableFrom`.
- **L10 effects.** C2-R06.
- **L11 proof.** `verifier.verify(journalHash, proof, kRequired)` per C2-R03 and C2-R12.

**Adversary schedule:** a skipped due forced entry (L8, TH7); uncertified blocks (L5); a stale parent (L1, L3); a non-canonical tip (L7); a committee or holder from calldata (L4); a replacement before A1 (L9).

### C2-R06. Landing effects

**[assumed: proposed rule]** On acceptance: `lastLanded = {endHeight, endBlockHash, endStateRoot, endPhHash, termId, view, at: block.timestamp, l1AnchorTipNumber, l1AnchorTipTimestamp}`; the term record of every settled term (at most SETTLE_MAX); the forced-inclusion head, `fiClearTip`, escalation run and status bits (L8); `lastLandedTerm` (read by S1's dead-mode rule); the assignment digest and committee root of every settled term not yet pinned; the L1 checkpoint or provisional record (C2-R15); lander and attester rewards (C2-R16); MISS once per `(t, v)` per TIMEOUT-kind VC consumed (S3); the `prevrandao` mix (S1); `Landed`. S2's lock reset triggers on a landed replacement or forced batch only, never on a record. (Landing §3 L10; round 4, R4H-5.)

## 5. Arbitration, replacement and the horizon

### C2-R07. Deadlines are economic

**[assumed: proposed rule]** `deadline(t) = termEnd(t) + LAND_WINDOW` is where the ramps of C2-R16 reach their maximum for a term landable from its end; LAND_WINDOW_MAX caps the lag chained late landings build inside A1. The clock voids nothing and no rule penalizes a term for not landing (invariants I4, I5). Round 4 removed the abandonment penalty with its evidence deadline, outage gate, void waiver and escrow (R4H-5, R4-C3): a certified view is landable by anyone and paid from the holder's reserve, so a holder cannot abandon a provable view; the only unlandable certified content is a guest bug, a false positive for any abandonment rule, handled by replacement. (Landing §6.)

### C2-R08. A1, replaceability, and the landing announcement

**[assumed: proposed rule]** With `t'` the first unlanded term,

```text
replaceableFrom = min( termEnd(t') + LAND_WINDOW_MAX,
                       max( termEnd(t') + LAND_WINDOW, lastLanded.at + LAND_CHAIN_GRACE ) ) + REPLACE_GRACE
```

A replacement landing or a forced batch (C3) is accepted iff `block.timestamp > replaceableFrom`; inputs are inbox storage and the block timestamp. Anyone with a TAIKO ledger balance may call `announceLanding(firstHeight, endHeight)` with `firstHeight = lastLanded.height + 1` while `replaceableFrom` has not passed, locking ANNOUNCE_BOND on the ledger; it defers `replaceableFrom` by LAND_CHAIN_GRACE once per range, through a single flag keyed on `lastLanded` spent by whichever of an announcement and an accepted REPLACE or RESUME record comes first (round 5, R5-C3; C3's 112-minute bound relies on this being one deferral). An ordinary landing covering `firstHeight` returns the bond; a forced or replacement landing first forfeits it, 40 % to that lander and 60 % burned. An announcement is refused once the head forced entry has been due at the first unlanded term's T_floor for longer than LAND_WINDOW (round 3, C3). Nodes label confirmations above `lastLanded` "replaceable" from `replaceableFrom` (S2). (Landing §6 A1; round 2, S3; round 4 renamed ABANDON_GRACE to REPLACE_GRACE.) **Adversary schedule:** a fake announcement costs ANNOUNCE_BOND and delays the forced path by at most one grace period; a landable backlog is never reorged while someone bonded is landing it.

### C2-R09. A3, landing-based L1 arbitration

**[assumed: proposed rule]** Until a replacement or forced batch lands, landing the original stays valid and pays the ramp; whichever lands first wins, and the loser is invalid and free under the trailing-VERIFY shape (C2-R20). A recorded REPLACE or RESUME VC has no closing effect: `recordViewChange` accepts one only if `vc.lockHeight == lastLanded.height`, `vc.lockPhHash == lastLanded.phHash` and `block.timestamp > replaceableFrom` at record time, and the record serves only (i) as the first-recorded VC for `(t, v, closes)` that the fork's landing must match under L4 and (ii) as priority evidence for the forced path, spending the single deferral of C2-R08. The record is dead once `lastLanded.height > vc.lockHeight`: the first-recorded rule ignores it, so the original view's own TIMEOUT or TERM_END VC can still be recorded or landed, and it is no longer priority evidence. The fork's opening object (a REPLACE VC carrying an L1 reference) and the attester conditions are S2's (A2); a RESUME lock vote's `l1Ref` is the `(number, hash)` of the L1 block containing the landing resumed from (S2; the `forcedRecord(uint8)` ring of the interfaces page keeps FORCED_RING forced landings for S3d, §12). Dead-mode landings (view 255, no certificate) are replacements and obey A1. (Landing §6 A3; round 4, R4H-5 removed round 3's recorded-REPLACE close, a proof-free void, and R4-C3 restored "a proving outage voids nothing".)

**[proven: replacement is locally decidable]** A1 is a predicate on inbox storage and the block timestamp; attester disagreements resolve by L1 ordering of landings, since only a landing moves `lastLanded`. **[proven: why descendants are void]** Every certified block above `lastLanded` was built on a state L1 will never hold once a replacement lands; its proof asserts a parent root the inbox does not store.

### C2-R10. The landing horizon, the one time-based void

**[assumed: proposed rule]** The landing horizon is the smaller of ROLE_HORIZON (S1, 34 h) and L1's EIP-2935 window (8,191 L1 blocks: 27 h at 12-s slots, 4.55 h at 2-s slots). A range whose first term is older than ROLE_HORIZON and was never pinned, or whose anchor tip has left the window, can no longer be landed (L4, L7) and is replaceable; its certified and locked blocks are lost without a slash (L14; round 1, F7 found "nothing voids by clock" overstated). Nodes label confirmations "outage" once no landing has happened for DEGRADE_AFTER (S2). A proving outage shorter than the horizon voids nothing; landing after it resumes is conditional on someone still holding the bytes, which C2-R18 guarantees only for RETAIN_SECONDS (a limitation, §16).

### C2-R11. Certificate-free landings always need two leaves

**[assumed: proposed rule]** A landing whose last segment is a sentinel view (dead, no-committee, open-empty) or a forced batch is accepted with an empty certificate and never in single-proof mode: `kRequired` stays ZK_K. One back-end outage in such a regime stalls it until the DAO rotates images or adds a leaf (L19; round 3, H4): without an attester-executed state root, one proof system would carry state safety alone.

### C2-R20. Landing shapes and confirmation levels

**[assumed: proposed rule]** Primary shape, direct to builder: an expiry VERIFY frame, the lander's own nonce, the SENDER frame calling `land`, a trailing status VERIFY; any revert (lost race, `NotNext`, bad proof, rotated image, out of gas) makes the transaction invalid, no gas and no blob fee. Public-mempool fallback: the shared-nonce gate G_LAND calling `landFor`, deployed once EIP-8141 is Final, inert while its immutable address is zero, free only against same-nonce losers. Without EIP-8141: a type-3 transaction with `deadline` (L2); a loser reverts for about 25k gas plus its burned blob fee. C5 owns the gate. Levels, none in slots: **landed** = in an L1 block the node has, checkpoint written, or "landed (provisional)" while an unfinalized provisional record is on its chain; **L1-safe** = LANDED_CONFIRM_DEPTH descendants; **L1-final** = finalized per the node's beacon client, reported, never consumed by a contract; **void** = replaced or removed by an L1 reorg, inbox state reverting with L1, the range returning to CERTIFIED, no penalty. An ePBS Empty slot leaves the transaction unexecuted; the expiry frame makes the stale copy free. (Landing §8; frame-transactions page; after the #22188 review.)

## 6. Checkpoint write, single-proof mode and provisional finality

### C2-R12. Single-proof mode

**[assumed: proposed rule]** If `block.timestamp − lastLanded.at > DEGRADE_AFTER`, a landing with a non-empty certificate is accepted with `kRequired = 1` (`SingleProofMode(true)`); if it is accepted with one leaf, it is provisional (C2-R13). Any landing ends the mode; the next landing needs ZK_K leaves until DEGRADE_AFTER has passed again, so one-leaf landings are at least DEGRADE_AFTER apart. (Landing §7, §10; round 3, H4; made provisional after the #22188 review.) **Adversary schedule:** nobody can trigger the mode while any leaf works, since any landing resets the clock; an idle chain enters it harmlessly, its one-leaf landing being provisional.

### C2-R13. Provisional records, confirmation and finalization

**[assumed: proposed rule]** A one-leaf landing advances `lastLanded`, pays rewards and runs every deadline as a normal landing, but writes no checkpoint. It stores a `ProvisionalRecord` (§10) in a ring of PROVISIONAL_RING slots keyed `k % PROVISIONAL_RING`; the start fields are `lastLanded` and the forced-inclusion head at the landing (fix pass of 2026-10-01: what a checkpoint and a rollback are taken from). The record becomes CONFIRMED when anyone presents, through `confirmProvisional(k, journal, proof)`, a valid proof of the same journal from another leaf (no reward; the lander was paid at landing), and finalizable when DEGRADED_FINALITY elapse after `landedAt` with no conflict. Finalization, run first by every landing and by `finalizeProvisional(k)` alone, passes the records in order from the oldest while each is CONFIRMED or older than DEGRADED_FINALITY and writes one checkpoint: the start of the oldest record still unfinalized, or `lastLanded` when none remains; `ProvisionalFinalized(k, confirmingLeaf)` carries leaf 0 for the time rule. A record behind an unfinalized one waits; a pass that finalizes no record writes nothing. A later landing from a provisional end state, with one leaf or two, confirms nothing: a sound proof "from S to S′" says nothing about whether S was true. Checkpoints are written in order. (Landing §7; after the #22188 review and its fix pass.)

**[proven: ring bound]** One-leaf landings are at least DEGRADE_AFTER apart (C2-R12) and a record older than DEGRADED_FINALITY without conflict is finalizable, so at most DEGRADED_FINALITY / DEGRADE_AFTER = 12 records are unfinalized at once, the oldest finalizable before a thirteenth is appended; conditional on finalization running, which every landing does first.

**[proven: why the record stores its start]** With a record's own end as the checkpoint, a two-leaf landing just after record k − 1 waited for record k (up to 23 h later) to finalize, about two windows, and a conflict on k rolled back two windows, beyond ROLE_HORIZON. With the start stored, the newest checkpoint is the start of the oldest unfinalized record: a two-leaf landing waits at most one DEGRADED_FINALITY, a conflict voids at most one (C2-R14), the two-leaf landings between records are covered by the next record's start, and a newer checkpoint proves every signal an older one did.

### C2-R14. CONFLICT and the DAO resolution

**[assumed: proposed rule]** A conflict is a valid proof from a leaf other than the record's over a journal equal to the record's in every field but `endBlockHash`, `endStateRoot` and `endPhHash`, presented through `confirmProvisional`. The inbox records it, emits `ProofConflict(k, leafA, leafB)` and enters CONFLICT: no landing of either mode, the forced batch included, and no checkpoint write except by `finalizeProvisional` of records preceding the conflicting one, which writes at most that record's start, until a DAO upgrade names the sound leaf. That upgrade's reinitializer sets `lastLanded` to the newest L1 checkpoint as `initEtna` does (C4), by C2-R13 the start of the oldest unfinalized record; restores the forced-inclusion head from that record's `fiHeadAtStart`; sets `fiClearTip` to the restart time (as C4's M3 sets it to `drainedAt`); clears the ring. The chain restarts dead-mode style (S1): the blocks built on the voided landing and the two-leaf landings between the restored checkpoint and the conflicting record are replaced, and the entries those landings consumed are due again on the stall clock from the restart. Fees credited for those entries, rewards paid and term records settled by the voided landings are not clawed back, a bounded leak (L-PF). The upgrade's effect on the L1 checkpoint map is C2-R21's obligation on C1, C4 and C8. (Landing §7, §10; interfaces §1; after the #22188 review and its fix pass; the restart claim below after J's review of #22196 (2026-10-01), J-1.)

**[proven: the restart writes no height already holding a record, by C2-R13 and C2-R15]** The restored checkpoint is the newest one written, the start of the oldest unfinalized record (C2-R13). Above it lie only one-leaf landings, which write no checkpoint (C2-R13), and two-leaf landings covered by that unfinalized record, which write none (C2-R15); so every height the restarted chain re-lands was never written, each re-landing write meets an empty height, and C1-R06's conflict case (C1-R07 on L1) is never reached. This is the property the restart relies on. J's review of #22196 (2026-10-01) named the collision it avoids: "C1-R06 is first-write-wins ... C4's rollback re-lands L2 blocks from an earlier finalized point, producing different block hashes at the same heights ... those writes revert and the rollback cannot checkpoint progress past the first previously written height"; the restart is conflict-free only because the rolled-back heights hold no record, and C2-R21 binds the rollback upgrade so that this does not depend on C2-R13 and C2-R15 staying as written.

**[proven: rollback bound]** The rollback stops at the parent of the conflicting record once every earlier record is final, otherwise at the start of the oldest unfinalized record: by the ring bound at most one DEGRADED_FINALITY of landings, whose terms lie inside ROLE_HORIZON (§12), so the restart needs no role of an older term.

**[proven: what the mode buys, conditional on T11]** A false root in single-proof mode needs one ZK bug, a colluding quorum (L5 ties the journal's end hash to a certified header whose state root Q attesters executed, V6) and no honest proof of the other leaf over the same journal for DEGRADED_FINALITY. When that leaf is unusable for so long, the premise of the mode, the window adds delay, not evidence, and safety rests on T11: elapsed time is why the landings are provisional, not why they are safe. This is the one place attester execution carries part of state safety, and only after DEGRADE_AFTER of stalled landing.

### C2-R15. The L1 checkpoint write

**[assumed: proposed rule]** From the upgraded Inbox proxy (the immutable `_authorizedSyncer` of the L1 SignalService, address unchanged), the inbox calls

```solidity
_signalService.saveCheckpoint(ICheckpointStore.Checkpoint({
    blockNumber: uint48(endHeight), blockHash: endBlockHash, stateRoot: endStateRoot }));
```

exactly: once per landing accepted with ZK_K leaves unless an unfinalized provisional record precedes it on its chain (then none: the landing stores no record, needs no confirmation of its own and is subsumed by the checkpoint written when the newest record it follows is finalized); and once per finalization pass of C2-R13, with the tuple that pass selects. In transaction order the call precedes `verifyProof` and is rolled back by its revert. `ICheckpointStore` is unchanged, and so is the SignalService's storage until a C2-R21 rollback, which adds only the epoch floor list in the reserved gap and keeps every epoch-1 slot; the inbox enforces strictly increasing heights, which the SignalService does not check (it already rejects zero hashes with `SS_INVALID_CHECKPOINT`, `SignalService.sol:176-177`; the Anchor page's "checks none" is a misstatement, §16 item 9). C1 owns the L1 write semantics: C2's writes obey C1-R06 as C1-R07 applies it on L1 (a different tuple at an existing height reverts with `EtnaCheckpointConflict`, an exact duplicate is a silent no-op), and C2 does not weaken either case. A landing never triggers either case: the inbox's L1 sequence check (`firstHeight == lastLanded.height + 1` with `endHeight >= firstHeight`, a range holding at least one block, C2-R05) makes every landing's `endHeight` exceed `lastLanded.height`, so end heights are strictly increasing, and no height is written twice (proven below). On the landing path the rule is therefore defensive, reachable only through a bug or through an L1 reorg, which reverts inbox state together with the write (C2-R20), so a re-landing after a reorg meets an empty height again. Under EIP-8037 the two fresh words cost about 196k state gas per write, paid by the lander, unavoidable under R2. (Landing §8; Anchor page §3; after the #22188 review; the deferral to C1-R06 after J's review of #22196 (2026-10-01), J-1, which found that "a normative rule cannot both govern the write and be disclaimed by the section that produces the writes".) **Adversary schedule:** publication of a retractable root (never before confirmation or the window; after it, C2-R14's residual); Shasta prove and Etna land writing in one interval (C4 proves none exists); a write at an occupied height (unreachable from a landing or a pass, below; a rollback is C2-R14 and C2-R21).

**[proven: no height is written twice, conditional on C2-R13's in-order finalization]** C2 writes heights of two kinds. A two-leaf landing with no unfinalized record ahead writes its `endHeight`, above `lastLanded.height` by L1 and so above every earlier write, each of which lies at or below `lastLanded`. A finalization pass that finalizes at least one record writes the start of the oldest record left unfinalized, or `lastLanded` when none is left; a pass that finalizes nothing writes nothing (C2-R13). A record's start is the end of the landing before it: if an unfinalized record preceded that landing it wrote nothing (this rule), and otherwise it wrote its end, in which case no record older than the one in question is unfinalized at any later pass, so no later pass selects that start. `lastLanded` is selected only after a record is finalized, so it has advanced past every earlier write of it. Every write therefore lands on an empty height, and C1-R06's conflict and duplicate cases are unreachable from C2's writes.

### C2-R21. Rollback floors in the checkpoint map

**[assumed: proposed rule, placed as an obligation on C1 (owner of C1-R06), C4 (owner of the rollback upgrade) and C8 (owner of the layout)]** A rollback (C4's forward upgrade after CONFLICT, C2-R14) must leave no record of the rolled-back history readable above the restored checkpoint and must let the re-landing write at those heights, without overwrite semantics and without resetting the map. Shape: the SignalService's checkpoint mapping is `mapping(uint256 => mapping(uint48 => CheckpointRecord))` at slot 254, the record C1-R10 keeps at its original location, whose outer key is today the constant `VERSION = 1` (B's C1 draft §4, `SignalService_Layout.sol`). The rollback upgrade turns the outer key into an epoch: it appends `(epoch + 1, floorHeight = the restored checkpoint's height)` to a list of rollback floors stored in the reserved gap (slots 255 to 300); a write at a height above the newest floor goes to the newest epoch; a read at height `n`, including the internal getter signal proofs use (C1-R06), uses the epoch in force for `n`, that of the newest floor below `n`, found by a walk bounded by the number of rollbacks, each a DAO event; reads below the oldest floor see epoch 1; C1-R06's conflict and duplicate cases hold within one epoch. So no record of the rolled-back history is reachable above the floor, nothing is overwritten, and storage stays compatible (an amendment C1-R10 must adopt: it currently fixes the version key and the gap, and lists "shift the mapping version" as an attack, §16): epoch-1 records keep their slots and the gap is the only new storage. Under C2-R14's restart claim no record exists above the restored checkpoint on the C2 path as written, so the rule has no reachable trigger today; it binds the upgrade so that the restart's correctness rests on the map's shape rather than on C2-R13 and C2-R15 staying unchanged. (J's review of #22196 (2026-10-01), J-1; the arbiter's decision; rejected alternatives in §15.) **Adversary schedule:** a reader asks for a rolled-back height (the epoch in force returns the re-landed record or none, never the voided one); a rollback upgrade that overwrites, resets or exempts heights (§15); a read made costly by many rollbacks (the walk grows by one per DAO event, not per write).

## 7. Landing rewards and the reserve seam

### C2-R16. The reward formulas

**[assumed: proposed formulas; every TAIKO amount is a formula on inputs S3 marks unmeasured, limitation L15]** The lander is paid in TAIKO on the existing L1 bond ledger from the landing reserve of the sequencer whose blocks it lands (C2-R17). For a landing at L1 time `τ`:

```text
landableFrom(t) = max(termEnd(t), lastLanded.at)      fixed in t's term record by the first landing that reaches t
ramp(x, τ, t)   = x_min + (x_max − x_min) · clamp((τ − landableFrom(t)) / LAND_WINDOW, 0, 1)
r(τ, t)         = ramp over [R_BLK_MIN, R_BLK_MAX]      per block
r_land(τ, t)    = ramp over [0, R_LAND_MAX]              per paid landing
PIN_REWARD(τ,t) = ramp over [0, PIN_MAX]                 to the first pinner of t
reward          = Σ_segments blocks · r(τ, t) + R_BLOB · min(blobs, 15 − blobsPaid(t))
                  + r_land(τ, t) · [k ≤ ⌈bytesLanded_after(t) / LANDING_UNIT⌉]
attester share  = ATT_REWARD_PER_BLOCK per landed block, debited from each block's holder, split equally among the end certificate's signers
```

`k` counts the landings whose first segment belongs to `t`; `bytesLanded` is the term's sequencer-block records landed so far (what V10 bounds); `blobsPaid` counts blobs already paid for the term; FI records earn nothing. A sequencer that knows its prover is down may shortcut the block ramp with a signed `RewardBoost{termId, minRewardPerBlockGwei, seqSig}`, capped at R_BLK_MAX. For a self-landing (`rewardTo` resolves to the holder) the lander's debit and credit are both skipped. `lastLanded.at` in `landableFrom` is the landing the first range reaching `t` builds on, so every landing of a term ramps from one origin and no term is charged for time in which nothing could land; a `recordAssignment(t)` pin is paid only for a term at or below the first unlanded term. (Landing §5; round 3, H2; round 4, R4H-7; round 5, R5H-2 and fix pass; round 6, R6H-2, R6H-3 and fix pass; round 2, S6.)

**[proven: every greedy landing is paid, conditional on V9, on C3's MAX_FI_RUN and on the FI record size, open until E02]** Every record fits one blob, so a greedily packed landing that is not the term's last carries more than LANDING_BYTES − 130,044 = 260,088 bytes even at 2-s slots, and with the record that did not fit it more than 390,132; at most about 12,500 bytes of a term go uncounted (framing, at most 40 FI records of about 250 bytes, the view changes they open). The 40 is MAX_FI_RUN = 2 of every 3 blocks over the term's 60 (quoted from C3, forced-inclusion page §5); the about 250 bytes is the page's figure for a payload-free FI record and is not bounded until E02 fixes the `headerCore` widths (§14, §16). So after the k-th greedy landing `bytesLanded` exceeds (k − 2) × 260,088 + 377,000 > (k − 1) × 254,000 for every k ≥ 2, and every greedy landing is paid. A cap term takes at most five greedy landings at 2-s slots, two at 12-s slots, and any lander is paid at most ⌈1,270,000 / 254,000⌉ = 5 × r_land; splitting earns nothing beyond that. (Round 6, R6H-3.)

**[assumed: the per-term exposure, consumed by S3]** The most a term can debit is 60 × R_BLK_MAX + 15 × R_BLOB + 5 × R_LAND_MAX + 60 × ATT_REWARD_PER_BLOCK + PIN_MAX = 240 + 15 + 6,500 + 6 + 400 = 7,161 TAIKO, realised only at the maximum ramp; with R_BLOB capped at 15 blobs per term and r_land at five landings the sum bounds every landing pattern (sixty one-block landings would otherwise have earned 60 × R_BLOB, and two such terms would exceed LAND_RESERVE; round 6 fix pass). The break-even L1 fee at which a third party is paid in full is about 100 gwei per landing whatever the term size and slot time, since every greedy landing is paid and R_LAND_MAX prices one 2 M-gas landing at 100 gwei at the assumed rate; above it landing waits for the fee to fall or the holder to land at its own cost, and nothing is penalized meanwhile. (Landing §5, §11; round 4, R4H-8.)

### C2-R17. The reserve as the funding source

**[assumed: interface to S3]** Reward-type debits (ramps, blob reward, boost, per-landing reward, attester share, PIN_REWARD) are drawn from the holder's `reserveGwei`, LAND_RESERVE per seat required at registration and reactivation; MISS never touches it; a reward-type credit to an owner with seats refills that owner's reserve first, up to `seats × LAND_RESERVE`; the reserve leaves the ledger only through `requestExit + EVIDENCE_WINDOW`; an owner below one term of exposure per seat lapses (S1's suspension store) until a top-up plus `reactivate()`, and `ReserveLow` fires once per crossing below `(seats + 1) × 7,161`. C2 relies on invariant I2 as S3 states it: a drawn term's lander reward exists at landing time whatever the owner does, short of a class-A slash of itself and of the self-directed drain S3 costs as the residual (L20). Sizing, lapse line, hysteresis, outage arithmetic and residual are S3's. (Landing §5; round 4, R4H-3, R4-C2, R4-C4; round 5, R5S-4; round 6, R6S-2, R6H-2, R6H-3.) **Open (landing §5):** whether to index R_BLK_MIN to `block.basefee` through a DAO-set rate constant.

## 8. The retention duty

### C2-R18. Who retains which bytes for how long

**[assumed: proposed rule]** The bytes of a certified block (signed header, sequencer signature, carried certificate or view change, assignment digest, execution payload, anchor hash) and its certificate are retained and served over `blocks_by_range` by every attester whose bit is in a certificate of that block, and by RPC nodes, for RETAIN_SECONDS after the block's timestamp; every attester that attested a block executed it (V6) and holds its bytes. Older landed blocks come from L1 blobs within the T2 window and from archive holders after it (A-ARCHIVE). The design adds no L1-accountable publication duty: a failure to serve is unprovable on L1, and an L1 duty would cost what the bonded-fragment path of #22188 costs (decomposition §4). What a failure means: if fewer than the Q attesters that certified a range serve it and nobody else holds it, the range never lands and after A1 is replaced from `lastLanded` with no penalty (limitation L3: Q + 1 silent colluders can certify data only they hold, an unslashable stall until the replacement window opens, outside T11); if anyone serves it, any party rebuilds the canonical blobs (C2-R02) and lands. Rate limits and request authentication are S2's. (Roles page §2; certificate page §7 W3, §9; after the #22188 review.) **Adversary schedule:** certify then delete (L3); a prover cartel (anyone with the bytes may prove, TH2); an archive that withholds (A-ARCHIVE is named, not enforced).

**[assumed: chosen above the derived floor of 4,500 s]** RETAIN_SECONDS ≥ LAND_WINDOW_MAX + REPLACE_GRACE + LAND_CHAIN_GRACE = 4,500 s, the latest replaceable moment with the deferral measured from `termEnd(t')`; 7,200 s is a choice with unspecified slack above that floor, and this rule is the one normative statement of the duty (the source page's wording is superseded, §16 item 10; J's review of #22196 (2026-10-01), J-2). **Limitation [assumed]:** a landing stays possible after `replaceableFrom` until a replacement lands (C2-R09) and inside the horizon (C2-R10), up to about 34 h, but the duty to serve lapses at RETAIN_SECONDS; a prover returning from an outage longer than 2 h after the range's blocks depends on the holder, an RPC node or any other voluntary holder still having the bytes. Raising RETAIN_SECONDS to the landing horizon is the alternative not taken.

## 9. Origin authentication consumed by C1

### C2-R19. A-ORIGIN, A-ORIGIN-CHAIN, A-ORIGIN-PROGRESS

**[assumed: what C2 exports]** C1-R01 names A-ORIGIN: every selected origin `O_b` is authenticated against the intended L1 history and bound to L2 block `b`. For every block of a landed range: (a) binding, the hash sits in the L2 header, hence in `blockHash`, which PH names under the sequencer's signature (V1) and the guest proves by execution (V6), and its number is the signed `PH.anchorNumber`; (b) authentication, the guest witnesses the RLP of every distinct anchored L1 header, checks `keccak256(rlp) == parentBeaconBlockRoot` and `number == PH.anchorNumber` for each block anchoring it, chains them by parent hash to the journal's tip, and asserts C7's V5 (`L1[a].timestamp` within `[PH.timestamp − ANCHOR_MAX_AGE, PH.timestamp − ANCHOR_MIN_AGE]`, `anchorNumber` monotone, the genesis child's floor at C4's drain block); the inbox checks the tip against L1 history (L7). No L1 state root is checked: L2 receives one only through C1's reveal, which re-checks keccak over the full header. (Anchor page §1, §2; certificate page V5; issue #22147; TH17.)

**A-ORIGIN-CHAIN [proven, conditional on A-L1HIST and T3]:** all headers anchored by blocks of landed ranges lie on one parent-hash chain, L1's canonical chain at the newest landing, and equal numbers imply equal hashes. Within a range every anchored header chains to the tip, canonical at landing (L7). Across ranges each tip is at least the previous one and canonical when its landing is included; an L1 reorg replacing a block at or below an earlier tip also removes the L1 block containing that landing, which lies above its tip, and inbox state reverts with L1 (C2-R20). So in any L1 history containing both landings every anchored block is canonical and one number maps to one hash, which C1-R06's conflict case and the former Anchor rule A3 rest on.

**A-ORIGIN-PROGRESS [proven for the landed chain, conditional on V5 and C3's inclusion bound]:** V5 makes every landed block's origin at most ANCHOR_MAX_AGE older than the block and V4 makes L2 timestamps strictly increase, so a signal in the state of an L1 block with timestamp `s` is in the origin's state of every landed L2 block with `PH.timestamp ≥ s + ANCHOR_MAX_AGE`; a producer that keeps a pre-signal origin longer fails V5 at every honest attester and is timed out (S2). A `pinCurrentOrigin()` forced through C3 therefore executes in a block whose origin contains every signal older than ANCHOR_MAX_AGE plus C3's inclusion bound. An L1 stall longer than ANCHOR_MAX_AGE halts honest L2 production until L1 resumes (a consequence of V5). Before landing, a fake origin (possible only if Q attesters skipped V5) exists on an unlanded chain only, chains to no canonical tip, cannot land and is replaced; bridge withdrawals wait for "landed" and the Bridge quota bounds the residual (Anchor page §2, §13).

**[assumed: profile exported]** `l1AnchorTipNumber` is `uint48` and `anchorNumber` `u48`, matching C1's P-NUMBER. **Open (§16):** the guest's L1 header profile must equal C1's reveal parser profile (P-HEADER-BYTES, P-HEADER-FIELDS) so every landed origin is revealable; the pages state no guest header size bound.

## 10. Interface sketches

**[assumed: interface declaration]** The landing surface of the upgraded Inbox implementation behind the existing proxy; C8 indexes it. Registry, slashing, forced-inclusion and migration functions of the same interface belong to S1, S3, C3 and C4; the S2 structs `Certificate`, `ViewChange`, `RedrawProof`, `Replace` are referenced, not redefined.

```solidity
/// @custom:security-contact security@taiko.xyz
interface IEtnaInbox /* landing surface */ {
    struct Segment { uint32 termId; uint8 view; address sequencer; uint64 firstHeight; uint64 lastHeight; uint16 fiCount; }
    struct RewardBoost { uint32 termId; uint64 minRewardPerBlockGwei; bytes seqSig; }
    struct LandInput {
        uint64 firstHeight; uint64 endHeight; bytes32 parentBlockHash; bytes32 endBlockHash; bytes32 endStateRoot; bytes32 endPhHash;
        Segment[] segments; Certificate endCert; ViewChange[] viewChanges; RedrawProof[] redraws; bytes32[] blobHashes;
        uint48 l1AnchorTipNumber; bytes32 l1AnchorTipHash; uint48 l1AnchorTipTimestamp;
        uint48 fiHeadBefore; uint48 fiHeadAfter; uint48 fiClearTipAfter; uint64 fiStallMask; uint48 fiStallClock; uint48 fiNotDueAt;
        RewardBoost[] boosts; Replace replace; uint48 deadline; address rewardTo; bytes proof; }
    struct LastLanded { uint64 height; bytes32 blockHash; bytes32 stateRoot; bytes32 phHash; uint32 termId; uint8 view;
                        uint48 at; uint48 anchorTipNumber; uint48 anchorTipTimestamp; }
    struct TermRecord { uint64 landedThrough; uint8 lastView; uint8 missBits; uint8 landingsPaid; uint8 blobsPaid;
                        uint32 bytesLanded; uint48 landedAt; uint48 landableFrom; uint8 flags; } // 29 bytes, one word
    struct ProvisionalRecord { uint64 startHeight; bytes32 startBlockHash; bytes32 startStateRoot; uint48 fiHeadAtStart;
                               uint64 endHeight; bytes32 endBlockHash; bytes32 endStateRoot; bytes32 journalHash;
                               uint8 leafId; uint48 landedAt; uint8 status; } // six words; PROVISIONAL, CONFIRMED, FINAL
    struct Journal { /* the fields of C2-R04 in that order */ }

    function land(LandInput calldata _in) external;                              // anyone; C2-R05, C2-R06
    function landFor(address _rewardTo, LandInput calldata _in) external;        // msg.sender == G_LAND (C5)
    function recordViewChange(ViewChange calldata _vc) external;                 // REPLACE, RESUME per C2-R09; others per S2
    function announceLanding(uint64 _firstHeight, uint64 _endHeight) external;   // C2-R08
    function recordAssignment(uint32 _term) external;                            // S1's pin; PIN_REWARD per C2-R16
    function confirmProvisional(uint32 _k, Journal calldata _journal, bytes calldata _proof) external; // C2-R13, C2-R14; no reward
    function finalizeProvisional(uint32 _k) external;                            // C2-R13; callable in CONFLICT for earlier records
    function lastLanded() external view returns (LastLanded memory head_);
    function lastLandedTerm() external view returns (uint32 term_);
    function termRecord(uint32 _term) external view returns (TermRecord memory record_);
    function replaceableFrom() external view returns (uint48 at_);
    function rewardPerBlock(uint32 _term, uint48 _at) external view returns (uint64 gwei_);
    function provisionalRecord(uint32 _k) external view returns (ProvisionalRecord memory record_);
    function provisionalCursor() external view returns (uint32 first_, uint32 next_, bool conflict_);
    function protocolParams() external view returns (bytes memory encoded_);     // keccak256 of it is protocolParamsHash

    event Landed(uint32 indexed termId, uint8 view, uint64 firstHeight, uint64 endHeight, address indexed lander,
                 bytes32 endPhHash, bytes32 endBlockHash, uint32 certBitmap, uint64 rewardGwei, uint8 zkLeavesUsed, bool replaced);
    event LandingAnnounced(uint64 firstHeight, uint64 endHeight, address indexed announcer, uint48 replaceableFrom);
    event AnnouncementForfeited(uint64 firstHeight, address indexed announcer, address indexed to, uint64 gwei);
    event SingleProofMode(bool active);
    event ProofConflict(uint32 indexed k, uint8 leafA, uint8 leafB);
    event ProvisionalFinalized(uint32 indexed k, uint8 confirmingLeaf); // 0 when final by the time rule
    // AttestersRewarded is S3's event, emitted inside land
}
interface IEtnaVerifier { // replaces ComposeVerifier / ZkRequiredVerifier (C2-R03)
    function verify(bytes32 _journalHash, bytes calldata _proof, uint8 _kRequired) external view returns (uint8 zkLeaves_);
    function imageSets(uint8 _leaf) external view returns (bytes32[] memory current_, bytes32[] memory previous_, uint48 previousValidUntil_);
}
```

**[assumed: errors, storage, P2P]** Landing-path errors: `NotActive, NotNext, DeadlineExceeded, RangeTooLarge, NotHolder, BadCertificate, ViewChangeMismatch, FallbackBelowCertificate, AnchorTooOld, FiCountTooLow, FiNotDue, NotReplaceable, ProvisionalPending, NotFinalizable, ProofConflicted`. Storage after the Inbox proxy's 43-slot gap: `lastLanded` (3 slots), the term-record ring aliased onto Shasta's proposal-hash slot 254 keyed `termId % TERM_RING`, recorded view changes with the highest recorded certificate per key, pinned assignment digests and committee roots, the provisional ring (12 records of six words) and its cursor word with the CONFLICT flag; C4 and C8 hold the layout table (interfaces page §5). P2P: `LandingIntent {firstHeight, endHeight, lander, etaSeconds, sig}` (advisory; B's landing-intent discovery, decomposition §2), `Proof {firstHeight, endHeight, journalHash, leafId, proofBytes}` (fungible; two leaves' proofs may come from different provers), `RewardBoost`; S2 owns topics and envelope bounds.

## 11. State machines

**[proven: projections of the rules, not additional transitions]**

```text
Per certified block
  SEALED --cert, ≥ Q--> CERTIFIED --land() covering h in L1 block N--> LANDED --N+1 exists--> L1-SAFE --beacon finality--> L1-FINAL
  CERTIFIED --replacement or forced batch lands, τ > replaceableFrom--> VOID (no penalty; C2-R08, C2-R09)
  CERTIFIED --first term older than ROLE_HORIZON and never pinned, or anchor tip out of the EIP-2935 window--> UNLANDABLE, replaceable (C2-R10)
  LANDED --L1 reorg drops N--> CERTIFIED (re-land; no penalty; C2-R20)
Global proof mode
  NORMAL --τ − lastLanded.at > DEGRADE_AFTER--> SINGLE-PROOF (kRequired = 1 for certified landings; sentinel and forced stay at ZK_K)
  SINGLE-PROOF --any landing--> NORMAL
  NORMAL | SINGLE-PROOF --ProofConflict(k)--> CONFLICT --DAO upgrade names the sound leaf, rolls back if needed--> NORMAL
Provisional record k
  PROVISIONAL --other leaf, same journal--> CONFIRMED ;  PROVISIONAL --DEGRADED_FINALITY, no conflict--> FINALIZABLE
  CONFIRMED | FINALIZABLE --every earlier record FINAL--> FINAL (one checkpoint per pass)
  PROVISIONAL --other leaf, same inputs, other end state--> CONFLICT (k and everything after it void)
Lander (any address)
  IDLE --cert(L) seen, r ≥ cost--> PROVE --proofs (own or gossiped)--> SUBMIT (expiry frame) --Landed(me)--> PAID
  SUBMIT --Landed(other) | expiry--> IDLE (cost 0 under the primary shape)
```

Other objects: `lastLanded` advances only by an accepted landing and reverts only with L1 or by the CONFLICT reinitializer; the deferral flag goes unspent → spent and resets with `lastLanded` (C2-R08, C2-R09); a REPLACE/RESUME record goes absent → live → dead (C2-R09); an image set goes current → previous → retired (C2-R03).

## 12. Numeric register

**[assumed: rule-owned register]** C2's sole numeric definitions; C6 indexes them. Units: seconds, bytes, gas, TAIKO (formulas on assumed inputs: a term's revenue about 0.01 ETH, 1 TAIKO about 1.5·10⁻⁴ ETH, limitation L15) or counts; nothing in L1 slots. "Quoted" marks a value another section owns that a C2 rule reads.

| ID | Value / unit | Derivation, rationale and status |
|---|---|---|
| MAX_BLOCKS / MAX_VIEWS / MAX_BLOBS | 256 / 4 / 6 per landing | **assumed:** bounds guest work; four views amortize fixed gas; six is L1's per-transaction blob cap. |
| MAX_FI | 64 per landing | **quoted (C3):** queue walk ≤ 270k gas under a backlog; `fiStallMask` is `uint64`, so cap and mask agree. |
| Blob usable bytes | 130,044 | **open:** stated as today's coder's figure; the page's "31 bytes per field element" gives 4,096 × 31 = 126,976, while 130,044 equals 254-bit packing of 4,096 elements less a 4-byte header. Fix before the vectors (§16). |
| V9 record bound | 130,035 bytes | **quoted (C7), derived:** 130,044 − 9 framing bytes (round 6, R6H-3). |
| V10 = TERM_BYTES_MAX | 1,270,000 bytes | **quoted (C7), derived:** 5 × LANDING_UNIT; about 9.8 blobs per 60-s term, about 20 KiB/s, one eleventh of L1's about 224 KiB/s blob budget. |
| LANDING_BYTES | 390,132 bytes | **derived:** 3 × 130,044, one L1 block's blobs at 2-s slots. |
| LANDING_UNIT | 254,000 bytes | **assumed, chosen:** any U ≤ 260,088 with U < 390,132 − 12,500 = 377,632 makes (k − 2) × 260,088 + 377,000 > (k − 1) × U for all k ≥ 2 (C2-R16); 254,000 leaves a 6,088-byte margin under the first bound. |
| MAX_L1_HEADERS_PER_LANDING | 4,096 | **derived:** span ≤ ANCHOR_MAX_AGE + TERM + LAND_WINDOW_MAX + REPLACE_GRACE = 5,760 s = 2,880 headers at 2-s slots. **Open:** omits the LAND_CHAIN_GRACE deferral (600 s) C3's bound includes; 6,360 s = 3,180 headers still fits. |
| LAND_WINDOW / LAND_WINDOW_MAX | 1,800 / 3,600 s | **assumed:** ≥ 10 × happy-path landing, covering a fee spike and a prover restart; the maximum caps chained lag, with LAND_WINDOW_MAX + REPLACE_GRACE < DEAD_TERMS × TERM (3,900 < 4,500 s; S1); with the one LAND_CHAIN_GRACE deferral the deferred `replaceableFrom` is `termEnd(t') + 4,500 s` while dead mode opens at `termEnd(t') + 4,440 s`, 60 s earlier, harmless because dead-mode landings are replacements and obey A1 (parameters page §1; landing §11). |
| LAND_CHAIN_GRACE / REPLACE_GRACE | 600 / 300 s | **assumed:** ten minutes for a child after a late parent; priority of a late original over a replacement. |
| ANNOUNCE_BOND | 2,000 TAIKO | **assumed, unmeasured input:** 40 % to the forced or replacement lander, 60 % burned. |
| DEGRADE_AFTER / DEGRADED_FINALITY | 7,200 / 86,400 s | **assumed:** one back-end outage must not stall certified landing until a DAO upgrade (R1); the provisional window, smaller gives a recovering leaf less time to contradict a false root, larger delays bridge withdrawals; DEGRADE_AFTER < DEGRADED_FINALITY < ROLE_HORIZON. |
| PROVISIONAL_RING | 12 | **derived:** DEGRADED_FINALITY / DEGRADE_AFTER. |
| ROTATION_OVERLAP | 7,200 s | **derived:** ≥ LAND_WINDOW_MAX + REPLACE_GRACE + proving, so a rotation never orphans an in-window proof (TH20); 0 on emergency. |
| ZK_K / ZK_N | 2 / 2, target 3 | **assumed:** no single system finalizes in normal mode (TH1). |
| R_BLK_MIN / R_BLK_MAX | 0.5 / 4 TAIKO per block | **assumed, unmeasured:** marginal proving cost per block. |
| R_LAND_MAX; break-even fee | 1,300 TAIKO; about 100 gwei | **derived from assumed inputs:** a 2 M-gas landing at 100 gwei, about 0.2 ETH. |
| R_BLOB, cap | 1 TAIKO per blob, 15 per term | **assumed:** blob-fee share at low fees; the cap is five paid landings at three blobs (round 6 fix pass). |
| PIN_MAX | 400 TAIKO | **derived from assumed inputs:** pays a launch-registry pin (about 0.8 M gas) up to about 75 gwei and a 4,096-seat pin (about 5.4 M) up to about 11 gwei (round 5 fix pass). |
| ATT_REWARD_PER_BLOCK; LAND_RESERVE | 0.1 TAIKO; 14,400 TAIKO per seat | **quoted (S3):** 6 TAIKO per full term; ≥ 2 × 7,161, ≤ B_SEAT. |
| Per-term exposure | 7,161 TAIKO | **derived:** 240 + 15 + 6,500 + 6 + 400 (C2-R16). |
| RETAIN_SECONDS | 7,200 s | **assumed: chosen above the derived floor of 4,500 s** = LAND_WINDOW_MAX + REPLACE_GRACE + LAND_CHAIN_GRACE (C2-R18); below the landing horizon, a limitation. |
| T2 blob retention | about 18 days | **quoted (C5, l1-dependencies page; arguments page T2):** the L1 network's retention; **unmeasured** under short slots (EIP-8198 preserves the duration, EIP-7782 is silent). |
| FORCED_RING | 8 records | **quoted (C3; parameters page):** ≥ 30 min of forced-landing records S3d checks a RESUME `l1Ref` against (round 5, R5S-3). |
| ANCHOR_MIN_AGE / ANCHOR_MAX_AGE; ROLE_HORIZON | 48 / 1,800 s; 122,880 s | **quoted (C7; S1):** ≥ 2.5 × ePBS canonical-at-N+1, staleness inside L1's EIP-2935 window; 2,048 terms. |
| EIP-2935 / blockhash windows; landing horizon | 8,191 / 256 L1 blocks; min(ROLE_HORIZON, EIP-2935 window) | **assumed (L1 fact), derived:** 16,382 / 512 s at 2-s slots; 27 h at 12-s slots, 4.55 h at 2 s (C2-R10). |
| TERM_RING; SETTLE_MAX | 21,600 terms; 4 walks per landing | **assumed:** equals Shasta's ring so aliased keys match; **quoted (S3, slashing page S3/S1):** SETTLE_MAX = 4, bounding landing gas to four committee walks; its rationale is at most MAX_VIEWS terms per range, so 4 = MAX_VIEWS. The parameters page omits the constant (§16). |
| LANDED_CONFIRM_DEPTH; EXPIRY_TTL / REORG_MARGIN; LANDING_GAS_BUDGET | 1 L1 block; 60 / 60 s (client); 10,000,000 gas | **assumed:** ePBS payload confirmed by the next block; stale attempts expire; fits a 2-s-slot block. |
| LAND_CALLDATA_MAX | 8,192 bytes | **quoted (C5), unmeasured:** the gate's SENDER-frame data bound. |
| Gas per landing | two ZK leaves about 600k; certificate or VC verification about 165k each (EIP-2537, 32 keys); rights ≤ 290k; FI walk ≤ 270k plus 2.9k per entry; stores about 100k; attester credits about 160k; checkpoint about 196k; total about 1.5 M typical, under 2.7 M worst for a pinned term (26 % of a 10 M block) | **unmeasured** except the checkpoint and provisional record, derived as 2 × 97,920 and 6 × 97,920 under EIP-8037 (record about 588k, first lap); mainnet RISC0 and SP1 gas must be measured before freezing. |
| Gas: committee walk when a landing pins; race loser | about 1 M at 128 seats, 5.4 M at 4,096, 10.1 M at 65,535; about 25k plus one blob fee | **unmeasured:** the round-6 simulation of the persistent tree. |
| Happy-path landed latency | 2 to 3 min after a block | **unmeasured:** block proofs ≤ 20 s pipelined, aggregation ≤ 90 s, one to two L1 blocks. |
| Checkpoint delay in degraded mode | up to 24 h | **derived:** DEGRADED_FINALITY (L-PF). |

## 13. Argument and adversary coverage

**[proven: landed equals certified, conditional on A-CERT and A-EXEC]** L5 binds the end hash to a certificate and the guest chains every signed header from `lastLanded` to it (C2-R04): V7 of C7 by construction (TH4). **[proven: no state root without the required proofs, conditional on T3, A3 and A-L1HIST]** By C2-R04 and C2-R15. **[proven: nothing voided without a landed replacement inside the horizon]** By C2-R07, C2-R09, C2-R10, with S2's FALLBACK gates (round 5, R5S-5; round 6, R6S-3); beyond the horizon, void by time (L14); after a one-leaf landing, a DAO resolution can void it and its descendants (L-PF). Finality lag under sequencer collusion is bounded by LAND_WINDOW_MAX + REPLACE_GRACE + LAND_CHAIN_GRACE = 4,500 s after the first unlanded term's end, the deferral being spendable at most once per range (C2-R08; L3's "up to 75 minutes with a landing announcement"). **[proven: no accusation object on the landing path]** The only debit is MISS, once per `(t, v)` by a Q-signed TIMEOUT VC the landing consumes (S2, S3); no rule infers fault from a missing landing (I5; TH8). **[proven: no third party can make a winner revert after payment]** Every check depends on readable state and the winner's calldata; FI fees and refunds are pull-based; an entry saved after the proof passes L8 (TH11).

| Attack trace [assumed: adversarial schedule] | Result under the cited rules, or explicit limit |
|---|---|
| TH1: a forged proof from one leaf. | Two leaves in normal mode (C2-R03); in single-proof mode also a colluding quorum and no honest proof of the other leaf for a day; a different end state halts landing (C2-R14). Not defended: a common-mode guest bug (L7). |
| TH2, W6: a prover cartel refuses to prove. | The holder lands itself; otherwise the ramp attracts anyone with the certified data (C2-R18); an outage delays, never voids (C2-R07). Past RETAIN_SECONDS this is conditional on a voluntary holder of the bytes (C2-R18 limitation). |
| TH5, W1/W3/W5: withheld blocks or seal. | Uncertified blocks are unlandable (L5); provers rebuild blobs from committee-held data (C2-R02, C2-R18); no seal object. Residual: withholding inside the window costs latency only. |
| TH7: a landing skips a due forced entry. | L8 reverts; blocks unlandable and replaceable, no penalty; the forced batch bypasses rights after escalation (C3). |
| TH11, TH13: landing races, L1 congestion. | A race is free under the primary shape, about 25k gas plus a blob fee without it (C2-R20); windows in seconds; under 2.7 M gas for a pinned term; pinning paid up to §12's fees, else carried by the first landing; a third party paid in full up to about 100 gwei, above which the wait costs no bond. |
| TH12: an L1 reorg drops a landing or an anchored block. | The range returns to CERTIFIED and is re-landed (C2-R20); a reorg deeper than ANCHOR_MIN_AGE makes an honest range unlandable, replaced after A1, the holder losing that range's revenue (L11). |
| TH16, TH17, TH20, TH25. | The gate shapes fail closed (C5); the tip is checked on L1 (L7); image overlap in seconds (C2-R03); a mismatched guest is unlandable, liveness only (C2-R04). |
| Reorg of a landable backlog after a stall (round 2, S3; round 4, R4-C3). | Bounded, not prevented: once A1 holds the holder may fork and any bonded party may land a forced batch; first to land wins. Defences: no penalty; one bonded deferral per range (C2-R08); a false L1 reference is class B (S3d). Residual: one backlog reorg per stall (L6); poison content no guest can prove is likewise replaced (client blacklist open, landing §18). |
| Degraded mode: a false root checkpointed after 24 h. | Needs one ZK bug, a colluding quorum and the other leaf unusable for the window; the checkpoint is then as final as any other (L-PF residual; §16 to C1). |
| CONFLICT and the DAO never acts. | Every landing path waits (L-PF, beside L19); no objective rule between two valid proofs exists. Outside CONFLICT nothing waits for the DAO. |
| J-1 (#22196): the rollback re-lands a height holding a record, and C1-R06's first-write-wins reverts it. | Unreachable: the heights above the restored checkpoint were never written (C2-R14's restart claim, by C2-R13 and C2-R15), and no landing or pass writes a height twice (C2-R15); the rollback upgrade's epoch floors (C2-R21) keep it unreachable if those rules change. Residual: a bug in the inbox's sequence check, or a rollback upgrade that ignores C2-R21. |

**[assumed: failure profile]** All sequencers offline: anyone lands certified ranges; nothing voided without a landed replacement. All attesters offline: nothing landable, no deadline runs. All provers and landers offline: ranges accumulate CERTIFIED; the first returning prover clears the backlog at the maximum ramp only for the terms its first landing reaches (round 6, R6H-2), provided the bytes are still held, which C2-R18 guarantees only for RETAIN_SECONDS (a limitation, §16); past the horizon the backlog is replaced. L1 builders boycott: landing stalls without the gate, voids nothing (L13). Accepted false positives (landing §14): a guest bug costs the holder the term's revenue; a prover two hours behind a release is refused; an idle chain degrades harmlessly.

## 14. Examples and test-vector obligations

**[proven: arithmetic examples]** (a) A record of 130,035 bytes gives a payload of 1 + 4 + 4 + 130,035 = 130,044 bytes, one blob. (b) At 2-s slots four greedy landings of a cap term carry more than 4 × 260,088 = 1,040,352 of at most 1,282,500 bytes, so a fifth is needed at most, and ⌈1,270,000 / 254,000⌉ = 5 pays all. (c) A1 with `termEnd(t') = T`, `lastLanded.at = T − 1,500`: `max(T + 1,800, T − 900) = T + 1,800`; `min(T + 3,600, T + 1,800) + 300 = T + 2,100`; with the deferral spent, T + 2,700.

**[open: test-vector obligations]** Required by the readiness checklist, absent at `b311d1d`; B contributes the encoding vectors.

| Vector | Content | Status |
|---|---|---|
| E01 payload; E02 headerCore | one NORMAL block with a view change, one without, one FI record: exact bytes, blob split, versioned hashes; field order, widths and endianness of `headerCore` (the pages name the fields, not their widths) | **open**, pending the coder decision of §12 |
| E03 journal; E04 L1 to L11 | `abi.encode(Journal)` for a two-view range, `journalHash`, leaf inputs for leaf 0 and 1; one accepted landing and one revert per check, with state before and after | **open** |
| E05 A1; E06 provisional | the four cases of the formula, with and without the deferral (arithmetic in (c)); a one-leaf landing, a two-leaf landing behind it, confirmation, time finalization, a conflict and the rollback state, with the L1 checkpoint map before and after each step showing every write at an empty height (C2-R15) and the rollback writing nothing above the restored checkpoint while appending one epoch floor (C2-R21) | **open** |
| E07 rewards | r, r_land, R_BLOB, PIN_REWARD at τ = landableFrom, + LAND_WINDOW / 2, + LAND_WINDOW, self and third-party landing | **open** |
| E08 origin chain and identity (C1's V10 obligation) | a range anchoring two L1 headers with RLP witnesses, the chain to the tip and the inbox check; one execution hash under two `vcHash` envelopes, showing two records, blob hashes and journals | **open** |

## 15. Limits and rejected alternatives

| Choice | Reason and residual |
|---|---|
| One action, not propose then prove; no data-only landings in an outage | **Proven (C2-R04):** nothing on L1 references unproven data; a stopped prover voids nothing inside the horizon; data-only landings reintroduce the split. |
| Derived batch commitment, not a seal | **Proven (C2-R02):** no withholdable object on the landing path. |
| Landing-based arbitration, not a recorded REPLACE close | **Proven (C2-R09):** a closing record voided locked blocks with no proof (round 4, R4H-5, R4-C3). |
| No penalty for not landing; certificates verified on L1 | **Proven (C2-R07, L5):** a time rule cascades, an evidence rule has a guest bug as a false positive; in-guest certificates would rest the withholding defence on T3. |
| Two leaves degrading to a provisional one, not hard 2-of-2 or permanent single proof | **Assumed (C2-R12 to C2-R14):** hard 2-of-2 halts until a DAO upgrade; permanent single proof puts the ZK-bug case on attesters; an immediate one-leaf checkpoint was as final as two. Residual: L-PF, L19, L7. |
| Lander-chosen ranges, per-landing caps, per-lander proofs | **Proven (C2-R01, C2-R04, C2-R16):** no slot coupling (R5); splitting earns nothing beyond ⌈bytesLanded / LANDING_UNIT⌉ landings; a swapped reward address cannot land a copied proof (round 2, S6). |
| No prover role, auction or L2-fee pool; no L1 publication duty; no calldata DA fallback | **Assumed:** an assignee is a liveness dependency, a fee pool a second treasury; a failure to serve is unprovable on L1 (L3); calldata is six times dearer and not FOCIL-protected. |
| The horizon as the one time-based void | **Assumed (C2-R10):** unbounded role history costs state every term; the EIP-2935 window is an L1 fact (L14). Open: whether 34 h is the right trade (landing §18). |
| Rollback floors as epochs in the checkpoint map, not an overwrite, a reset or an exemption | **Assumed (C2-R21):** the three alternatives J listed in its review of #22196 (2026-10-01) were not taken: restoring overwrite semantics reopens the same-height conflict C1-R06 exists to close; resetting the map under an authenticated transition loses the inherited records below the floor; exempting heights above the floor from C1-R06 leaves the rolled-back records readable. Residual: one walk per read, growing by one per DAO rollback; the rule has no reachable trigger while C2-R13 and C2-R15 stand. |

## 16. Integration dashboard and requirement impact

**[open: answers to C1's §10 obligations on C2, by rule id]**

| C1 obligation | C2 answer |
|---|---|
| O_b membership and ancestry; age, stall and reorg policies; A-ORIGIN-PROGRESS; the private-header attack row | C2-R19 (progress conditional on C3's inclusion bound); age and monotonicity are C7's V5, asserted by the guest (C2-R04); an L1 stall over ANCHOR_MAX_AGE halts production; a reorg below the tip removes the landing (C2-R20); a fake header chains to no canonical tip. |
| Bind every origin and the removed Anchor metadata; P-B-C1-01 identity; full-header and V10 vectors | C2-R02 carries `vcHash`, the carried certificate, termId, view and kind in `headerCore` under the sequencer's signature; the journal binds the blobs and `vcHashOfFirstBlock` (C2-R04): two envelopes for one execution hash are two records, two blob strings and two journals, and L4 decides which lands. The seat is not carried: it is implied by (termId, view, redraw count) and the pinned assignment L4 checks against `committeeRoot[t]` (bridge-migration page §1). Vector E08 **open**. |
| Header-fork profile for the reveal parser | **Open:** C2 commits the guest's L1 header profile equals C1's P-HEADER-BYTES and P-HEADER-FIELDS; closure by a joint C1/C2/C5 pin of the supported L1 fork. |
| Exact Inbox interface and the proof status permitting the custody write; irreversible Bridge effects from a degraded result | C2-R15 and §10: the SignalService receives a checkpoint only for a two-leaf landing with no unfinalized record ahead, or from a finalization pass; before that no L1 Bridge effect; after the time rule C2-R14's residual holds and the checkpoint is irreversible (L-PF). A provisional root is never immediately spendable. |

| Owner / obligation | Status and closure condition |
|---|---|
| C1: the L2 side of every checkpoint and the EIP-4788 record each landed block writes; C1-R06 as the write semantics C2-R15 obeys; the epoch outer key and floor list of C2-R21 as a C1-R06 and C1-R10 change | **Open** on C1's text; C2 supplies C2-R19 and proposes C2-R21. |
| C3: due-ness, the floor rule L8 reads, the stall clock, void set and status bits, `fiNotDueAt`, the forced batch under A1, the single deferral (C2-R08, C2-R09), the inclusion bound of C2-R19 | **Open**; L8 cites C3. C3 must keep the one-deferral rule (round 5, R5-C3) or re-derive its 112-minute bound. |
| C4: the initial `lastLanded` from the newest L1 checkpoint, the drain block as first anchor tip and V5 floor, `fiClearTip = drainedAt`, the CONFLICT reinitializer reusing initEtna's shape, the unchanged syncer immutable, the proof that Shasta prove and Etna land never both write, the rollback upgrade appending one epoch floor and never overwriting, resetting or exempting (C2-R21) | **Open**; Anchor page §5, §6 are the input. |
| C5: G_LAND, its pins, LAND_CALLDATA_MAX, the degradation without EIP-8141 (C2-R20). C8: index §10, the errors, storage and P2P additions; the floor list in the SignalService gap (slots 255 to 300) and the epoch outer key of slot 254 (C2-R21) | **Open**. |
| C7: V1 to V10 as the guest asserts them; V9 at 130,035 and V10 at 5 × LANDING_UNIT, else C2-R16's exposure is re-derived; V5 as C2-R19's age rule | **Open**. |
| S1: `isHolder`, the domain version at `termStart(t)`, `committeeRoot[t]`, `recordAssignment`, the sentinel regimes L4 accepts, DEAD_TERMS × TERM > LAND_WINDOW_MAX + REPLACE_GRACE (4,500 > 3,900 s) with dead mode allowed to open 60 s before a deferred `replaceableFrom` (§12), the lapse store of C2-R17 | **Open**. |
| S2: certificates, Q(m), redraw proofs, the VC chain, the FALLBACK gate and certificate record (L4, L5), the REPLACE fork's attester conditions, the RESUME `l1Ref`, the levels "replaceable", "outage", "landed (provisional)", RETAIN_SECONDS as a gossip duty, MAX_ENVELOPE = V9 | **Open**. |
| S3: the reserve sizing and invariant I2 (C2-R17), every constant of C2-R16, MISS as the only class-C debit | **Open**; S3 must accept the 7,161 exposure as the hard bound C2-R16 proves or change the caps. |
| C6: index §12 with statuses, the limitations L3, L6, L7, L11, L13, L14, L19, L20, L-PF, the unmeasured list below; the RETAIN_SECONDS erratum of item 10 carried into the parameter index | **Open**. |
| B's verdict; J's review | B **open**: not yet received. J's review of #22196 (2026-10-01) **applied**: J-1 (High) in C2-R14, C2-R15, C2-R21, §13, §15; J-2 (Medium) in C2-R18 and item 10. |

**[open: unmeasured numbers an implementation must measure first]** Mainnet gas of the RISC0 and SP1 leaves; the EIP-2537 aggregate path for 32 keys; the registry walk at launch size; the forced-inclusion walk; the full landing under the selected L1 fork's repricing (EIP-7709, EIP-8037); the guest cost of 64 KZG versioned hashes and a 4,096-header chain; block-proof and aggregation latency; the calldata of a maximal landing; a term's revenue and the TAIKO rate behind every reward constant (L15).

**[open: statements the pages make two ways or leave underived]** (1) Blob usable bytes: "31 bytes per field element" versus 130,044 (§12). (2) The 5,760-s anchored-block span omits the LAND_CHAIN_GRACE deferral that C3's 6,720-s bound includes. (3) SETTLE_MAX = 4 is given on the slashing page but omitted from the parameters page. (4) The checkpoint write is "in the same transaction" (landing intro), after the proof (landing §3) and "before verifyProof" (Anchor page); they agree only as transaction order with revert rollback, which C2-R15 states. (5) `headerCore` field widths are not given (E02). (6) The page has L11 (proof) where the brief names L1 to L10. (7) Whether `Landed.rewardGwei` is the lander's total or the sum of all debits across settled terms is unstated. (8) Whether one landing pinning several terms collects several PIN_REWARDs is implied, not stated. (9) The Anchor page (bridge-migration §3) says the SignalService "checks none" of the checkpoint invariants; the deployed `saveCheckpoint` rejects zero hashes (`SS_INVALID_CHECKPOINT`, `SignalService.sol:176-177`) and checks nothing about heights; C2-R15 follows the code. (10) **Superseded.** Candidate A's parameters page says attesters "serve data until any landing is possible"; the normative duty is C2-R18's RETAIN_SECONDS = 7,200 s, above the derived 4,500-s floor, and the page's phrase is an erratum against that page, to be carried into C6's parameter index; the limitation past RETAIN_SECONDS stays as C2-R18 states it. J's review of #22196 (2026-10-01), J-2, found that "two normative pages state different duties for the same bytes"; the converged section is the normative text. (11) Landing §16 bounds the collusion finality lag by LAND_WINDOW_MAX + REPLACE_GRACE, omitting the deferral that C2-R08 and L3 ("up to 75 minutes with a landing announcement") include; §13 follows the latter. (12) Landing §7 says a confirmed record "becomes final, and its checkpoint is written", then that finalization passes records in order writing the start of the oldest unfinalized one; C2-R13 follows the in-order rule through the CONFIRMED/FINAL split. (13) The horizon void reads "first term older than the horizon" (landing §6) and "older than ROLE_HORIZON and never pinned, or anchor tip out of the window" (L14); C2-R10 and §11 follow L14. (14) **Closed.** The first draft of C2-R15 disclaimed C1-R06 while B's C1-R07 applies it to the same L1 `saveCheckpoint` call (J-1); C2-R15 now defers to C1-R06, proves the landing path never reaches its conflict or duplicate case, and C2-R21 carries the rollback obligation.

| Requirement | C2 contribution, not a whole-design pass |
|---|---|
| R1 | **Proven conditionally (C2-R01, C2-R12):** anyone lands; no prover whitelist; one back-end outage degrades, never halts, certified operation. **Fails in two compound cases:** an uncertified regime plus a back-end outage (L19) and CONFLICT (L-PF), both DAO-only. |
| R2 | **Proven (C2-R15):** one unchanged call; SignalService address unchanged; storage unchanged except C2-R21's rollback floors in the reserved gap; the live audit is C4's. |
| R3 | **Assumed (C2-R01, C2-R18, §13):** the lander is an unbonded role with no entry or exit, and no registry; anyone with the bytes and a proof lands; all landers offline leaves ranges CERTIFIED and voids nothing inside the horizon (failure profile, §13); the bonded roles are S1's. |
| R4 | **Not C2's:** landing is decoupled from the 1-s block cadence (lander-chosen ranges, C2-R01; no C2 value in slots, §12); the cadence itself is S2's. |
| R5 | **Proven (§12):** no C2 value in slots; the block-denominated windows are L1's own (C2-R10). |
| R6, R7 | **Proven for the landing path:** no accusation object (MISS is S2/S3's; anti-monopoly S1/S3's); one L1 action with explicit DA and the proof, finalizing at once in normal mode (C2-R01 to C2-R06). |
| D1, D2 | **Not C2's / assumed scope:** a landing is not the user confirmation, C2 only bounds when a "locked" block can be voided (C2-R09, C2-R10, C2-R14); sketch-level interfaces with every unmeasured value marked, vectors open. |

## 17. Evidence and credit

**[assumed: sources]** Candidate A's branch `claude/beautiful-maxwell-8pyecj` at `b311d1d` (2026-10-01), `packages/protocol/docs/Etna/design/`: `landing.html` §1 to §18; `interfaces.html` §1, §3 to §5; `parameters.html` §1 to §3; `bridge-migration.html` §1 to §3, §5 (M3), §6, §8, §12, §13, §17; `limitations.html` L3, L6, L7, L11, L13, L14, L19, L20, L-PF; `roles.html` §2; `preconf.html` §7, §9; `slashing.html` (SETTLE_MAX); `arguments.html` (T2, T3). Rounds are cited per rule; the anchor-free revision is issue #22147 with taiko-geth#601; the revision after the #22188 review (fix pass 2026-10-01) covers provisional finality and the retention statement.

**[assumed: credit]** The one-action landing, derived batch commitment, ramp with the sequencer as reserve bidder, two-leaf verifier with degradation and landing-based arbitration are candidate A's (judge synthesis of its B4 round, revised through round 6). C2-R13, C2-R14 and C2-R18 answer candidate B's review of PR #22184 (a one-leaf checkpoint as final as a two-leaf one; no stated publication duty). The hashing convention, C1's pin and parser bounds and the current-root guard are B's (PR #22188); the landing-intent object (§10) and the encoding vectors (§14) are B's. The deferral of C2-R15 to C1-R06, the restart claim of C2-R14, C2-R21 and the retention erratum (§16 item 10) answer J's review of #22196 (2026-10-01), J-1 and J-2, under the arbiter's decisions. Decision-log entries: D9, D10, DL-1, DL-2, DL-3.
