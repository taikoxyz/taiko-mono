# Etna Red Team Round 1: Censor & Monopolize Attack Analysis

**Model**: Claude Haiku 4.5 (claude-haiku-4-5-20251001)

**Method**: Studied the full Etna design specification (index.html through forced-inclusion.html, threat model 01-threat-model.md, and README.md). Focused on threats TH5 (withholding), TH9 (monopolization/Sybil), and TH8 (bond griefing) as primary vectors for censorship and sequencing monopoly. Analyzed sequencing-rights rules, preconfirmation validity predicates, landing binding, slashing catalog, and forced-inclusion mechanics to identify concrete attack traces.

---

## Findings

No Critical or High findings identified. The design appears to successfully defend censorship and monopolization within the stated assumptions and bounds.

### Summary

The Etna design implements a multi-layered defense against sequencing monopoly and censorship through:

1. **Seat cap + Sybil cost**: Max 8 seats per address, future-dated registration (DELAY_REG = 7200s), and a super-linear cost curve for share acquisition (cost = H·X/(1-X) where H = honest seats, X = desired share). To hold 50% of terms at launch (H=40) requires purchasing 40 additional seats = 800k TAIKO. To achieve 90% requires 360 seats = 7.2M TAIKO.

2. **Withholding becomes worthless**: Withheld blocks are unextendable (V3 requires carried certificate) and unlandable (landing binding §6 of landing.html). A block the committee never sees cannot be certified, so private state ≤ 2 blocks and dies within TIMEOUT = 5s. The W1 handoff ambush costs 12 attester keys in double-signing (S3c equivocation slash = class A full ledger).

3. **Attestation quorum is objective**: The 32-seat committee is drawn per term from seats not in the holder list, via keccak(seed ‖ 0x02 ‖ t ‖ m). Q = 22 quorum needed. A cartel with c fraction of total seats has P(11+ seats) = 2·10^-15 / 3·10^-9 / 4·10^-5 at c = 0.2 / 0.3 / 0.33. Refusing attestation costs strikes (MISS_PENALTY = 50 TAIKO burned, one strike per owner per 600s, three strikes → suspension). Refusal without slashing is liveness-only harm, bounded to one term.

4. **Forced inclusion is time-anchored**: Due-ness is evaluated against the L1 block timestamp of an anchored header (not the landing timestamp), pinned to L1 before the block is built (TH17 defense). A malicious sequencer cannot reorg in-flight blocks by making a proven landing's FI entries retroactively due. Inclusion is guaranteed within 102 minutes (s + FI_DELAY + ANCHOR_MAX_AGE + LAND_WINDOW_MAX + ABANDON_GRACE = s + 300 + 1800 + 120 + 3600 + 300) or a permissionless forced batch (sentinel view 254) opens. Forced batches are unpriced (no sequencing rights check, no certificate) and cost 2 distinct ZK systems always.

---

## What I Tried and Could Not Break (Five Concrete Attempts)

### 1. Gradual Monopolization Through Sybil Registration

**Attack**: Register 100 Sybil addresses with 8 seats each = 800 seats (16M TAIKO bonds), accumulate to >50% share, dominate term draw.

**Defense**: The sortition weight is by seat count, but the cost curve H·X/(1-X) is relative to honest seat count H, not total seats. At launch, H ≈ 40 (assumed from 0.01 ETH per-term revenue). To go from 40 honest to 80 total (50% attacker), attacker must buy 40 seats. To go to 140 total (71% attacker), must buy 100 seats. The marginal cost is H/(1-X)², which is 4,000× higher at 90% than at 1%. No seat-cap bypass exists for a Sybil because CAP applies per address and future-dated registration prevents pre-coordination: DELAY_REG = 7200s forces registration decisions 2+ hours before effect, and the snapshot rule S(t) = termStart(t) - LOOKBACK = 20 minutes before term means any write after S(t) takes effect after termEnd(t) (not the intended term). **Defense holds**.

### 2. Attestation Cartel Refusal to Certify (User Censorship)

**Attack**: Accumulate 11 attester seats spread across Sybil owners (cost ≥ 220k TAIKO to avoid slashing one entity), refuse to attest any honest sequencer's blocks (11 < Q = 22, so no slashing for conflicting attestations). Repeat per term to censor any user.

**Defense**: Refusing attestation without actually signing a conflicting object is unprovable on-chain, so S3a/S3b/S3c do not apply. However, the cost is immediate: (1) no certificate forms within TIMEOUT = 5s, so the committee times out the sequencer (a timeout view change, a signed object requiring Q signatures, is the brake); (2) honest attesters of that committee term out the leader and get a takeover; (3) MISS_PENALTY = 50 TAIKO burned per owner per 600s coalesce window (one strike however many of their seats were drawn); (4) three strikes in a week trigger suspension doubling from 3h to 64h. A cartel with 11 of 32 seats and P = 0.04 draw rate (c = 0.2 share) would take ~25,000 terms = 17 days to land all 11 seats in one committee, and even then the timeout is objective (Q honest signers form it). Within the T11 bound (minority of bonded participants), refusal costs strikes and temporary liveness loss (one term) per event. **Defense holds under T11**.

### 3. Sequencer Withholding to Reorg Honest Entrant at Handoff (W1)

**Attack**: Sequencer A holds term t, builds blocks privately (say, n and n+1). Incoming sequencer B builds on the public head (n-1), which gets certified. At term end, A lands n, n+1, reorging B's blocks.

**Defense**: B's first block carries VC(t, v_last, lock) where lock is the height A and B's committee agree on. For B's first block to be valid (V2): "if v ≥ 1 or the first block of t: PH.vcHash names a carried VC closing the previous view, verified against its signer committee, and PH.parentHash is the lock's block". So B's parent must be exactly the lock height. If A tries to land n, n+1 at term end, the landing's end certificate must reference a lock ≥ n+1 (claim 1 of preconf.html§16): "A locked block at height h cannot be below the lock of any later VC unless ≥ 2Q − K attesters are slashable". To get a second VC at the same (t, v) with a higher lock (S3c equivocation), A needs 2Q−K = 12 attester keys to sign both VCs. Each is class A slash (whole ledger per owner). **Defense cost: 12 slashed seats ≥ 240k TAIKO**. The honest VC reaches L1 (via recordViewChange) within seconds; A's landing attempt minutes later must match this recorded VC (landing page §6: "the first VC per (t, v) wins"). **Defense holds**.

### 4. Forced-Inclusion Censoring Through Stale Anchors and Infinite Loops

**Attack**: Sequencer keeps its anchor old (max 1800s behind L1 head per ANCHOR_MAX_AGE). New FI entries become due at the stale anchor's time, but sequencer keeps building sequencer blocks (not FI blocks) by not advancing the anchor, resetting the clock.

**Defense**: V8 placement rule (forced-inclusion.html §4) states: "a sequencer block: valid iff no entry is due at the parent's cursor at T_p, or the MAX_FI_RUN = 2 blocks ending at p are all FI blocks." If an entry is due at T_p (parent's anchor timestamp) and T_p is stale, the sequencer can either (1) build an FI block or (2) advance the anchor to a newer time (which would then make entries due at the new time). If the sequencer tries to loop without advancing, it hits the MAX_FI_RUN = 2 limit: at most 2 FI blocks in a row. After 2 FI blocks, the sequencer must build a sequencer block. If that sequencer block doesn't advance the anchor past any due entry's save time + FI_DELAY, it's valid. But the FI entries due at the stale anchor are still not consumed, so they remain due at the next block (they're a prefix of the due queue). After 2 more blocks (one FI, one sequencer), the cycle repeats. However: (1) attesters have a policy (recommended, not enforced) to withhold if the anchor is >FI_ANCHOR_LAG = 20 blocks stale, causing a takeover within TIMEOUT; (2) a user can escalate to forced-inclusion at replaceableFrom (termEnd + LAND_WINDOW + ABANDON_GRACE ≈ 1 hour 42 min), which requires no sequencer approval; (3) the landing page's S4a (abandonment) slash applies if the term's view closes without landing by DEADLINE_HARD. **Defense holds; forced inclusion is bounded to 102 minutes**.

### 5. Double-Signing Griefer (Capture Just Enough Committee to Force Slashing)

**Attack**: Attacker stakes 12 seats across Sybil owners (240k TAIKO), gets drawn into committee, signs conflicting attestations or VCs with honest committee members to trigger S3a/S3c slashing, then exits before losing all bonds (spread across 12 owners, each loses only partial bond in one slash).

**Defense**: When an attacker initiates S3a/S3c evidence, they must provide two conflicting signatures. The evidence function (slashing.html§3) verifies both and slashes "every key in both bitmaps (≥ 2Q − K = 12 by pigeonhole)". So the attacker must coordinate with 11 other signers to both sign conflicting messages. If the attacker is one of the 12, it provides one signature; the 11 others must be co-conspirators. But: (1) initiating the slash reveals the attacker's key publicly; (2) the slash is class A (whole ledger per owner); (3) any of the co-conspirators can also be independently slashed if they sign a third conflicting message; (4) an owner below the bond floor (seatCount × B_SEAT) is suspended open-ended. The attacker's incentive to self-slash is zero (they lose their ledger). A better attack is to *trick* honest committee members into double-signing, but that requires forging signatures (cryptographic break, out of scope). **Defense holds; cost ≥ 240k TAIKO full loss**. 

---

## Internal Design Consistency

No contradictions found between pages. Key parameters are consistent:
- TERM = 60s, CYCLE_TERMS = 60 → seed fixed per hour ✓
- LOOKBACK = 1200s > DELAY_REG = 7200s / 6, allowing snapshot = 20 min before term ✓
- LAND_WINDOW = 1800s (30 min) < LAND_WINDOW_MAX = 3600s (60 min) ✓
- FI_DELAY = 300s (5 min) < FI_EXPIRY = 604,800s (7 days) ✓
- MAX_FI_PER_LANDING = 64 entries ≤ 65,535 MAX_SEATS ✓
- Q = 22 > K/2 = 16 (Byzantine resilience) ✓
- R_BLK_MIN = 0.5 < R_BLK_MAX = 4 (Dutch ramp) ✓

All numerical constants are either derived from stated assumptions (B_SEAT = 300 × V_term, where V_term ≈ 0.01 ETH ≈ 200 TAIKO) or marked as `open` (assumed from devnet measurement pending).

---

## Residual Risk Assessment

**In Scope, Accepted Limitations** (acknowledged by design as defended-but-not-prevented):
- **Ordinary sequencer MEV** within a public attested block stream (§8 of threat model; fair ordering is not in scope).
- **Cartel liveness griefing above T11 boundary** (c ≥ 0.33 seat share): refusal to attest is unprovable and costs only strikes + liveness loss (design says "not defended" explicitly; accepted residual above p=0.2).
- **Premature view change**: Q colluders can time out an honest leader early; cost zero, bounded by rotation + strikes; harm = one view + ≤2 sequenced blocks (design says "not defended").
- **Replacement griefing after outage**: Certified blocks may be voided if a REPLACE fork lands before the original; cost ≤ SLASH_ABANDON = 2,000 TAIKO, no strike, mitigated by lander incentive to land the original and by the replacer earning no penalty share.

**Out of Scope** (design states §8 of 01-threat-model.md):
- Cryptographic breaks (secp256k1, BLS12-381, KZG, ZK soundness).
- Malicious DAO upgrades (R1 freezes liveness from DAO, upgradeability is a governance choice).
- L1 consensus failures beyond stated reorg-safety window (T1 assumed).
- Bridge application-level bugs (R2 freezes Bridge and Vault logic).

---

## Conclusion

The Etna design successfully defends sequencing monopoly and user censorship within the stated threat model and assumptions (T1-T13, A1-A8). No concrete attack breaks the intended properties P1-P8. The three primary attack vectors (Sybil monopoly, attestation refusal, withholding) are all bounded and priced at economically prohibitive levels given the assumed per-term revenue and TAIKO denomination. Forced inclusion guarantees inclusion within 102 minutes against all sequencer and attester behaviors short of the T11 bounds (fewer than Q collusive attesters). The design is ready for Phase 5 (revision and loop).

**Verdict: NOT READY to declare complete** until:
1. Devnet measurement confirms TIMEOUT = 5s honest false-positive rate (T9, gossip ≤ 300ms, newPayload ≤ 200ms actual).
2. Mainnet measurement of per-term revenue (G8) confirms B_SEAT = 20,000 TAIKO is correctly sized (assumed 300 × V_term).
3. ZK guest cost for forced-batch KZG verification is benchmarked (open question §12 of landing.html).
4. Strike ladder parameters (SUSPEND doubling, STRIKE_DECAY = 7 days) are re-tuned after testnet griefing measurement (open question §1 of slashing.html).

These are engineering (not design) open items.
