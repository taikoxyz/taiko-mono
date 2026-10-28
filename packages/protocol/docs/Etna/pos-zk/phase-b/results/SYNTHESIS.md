# Phase B public-data — cross-spike synthesis

**Status:** synthesis of the Phase B public-data substitution reports (no hardware, no testnet; the
substitution is defined in [../README-public-data.md](../README-public-data.md)). **Date:** 2026-10-07
(UTC). **Incorporated:** S1 [proving-throughput.md](./proving-throughput.md), S2
[round-timing.md](./round-timing.md), S3 [l1-cost-fee-flow.md](./l1-cost-fee-flow.md), S4
[blob-binding.md](./blob-binding.md) — its public-data half only; the measurement and cryptographic-review
half is named in (d). S5 is the recovery-repair design pass, not one of the four measurement spikes, and
appears here only where it consumes S3 inputs. *(S4 landed after this synthesis was first written; its
figures were appended in place to (a), its parameter entries to (b), its mismatches to (c) and its
remaining quantities to (d), and the gate note in (e) was updated — no other section was restructured.)*

**Labels are the gate.** Every figure carries exactly one label of the README-public-data ladder:
`[on-chain measured]`, `[third-party reported]`, `[bounded]`, `[not establishable]`. A label may carry
a scope qualifier or be written as a compound of two ladder labels; the ladder now defines those forms
and caps every compound at its weaker half, so `[on-chain measured] / [derived]` may bound only and
`[on-chain measured, third-party network]` cannot fix a parameter of this design (README-public-data.md,
"Compound and qualified labels"). A lower label is never presented as a higher one: an achieved network
rate is not a per-machine capability, a third-party benchmark is not this design's guest, and a design
target is not a result. Nothing below was invented; every number is taken from an incorporated report,
cited as its source. *(PB-L-05: the ladder text now defines the compound and qualified forms; the
`[derived]` row in this table is `[bounded]`.)*

**Headline.** **No specification parameter moves to FIXED.** The strongest outcome public data reaches
is **BOUNDED**, and the two tensions in (b) are now recorded in the specification as one **disclosed**
inherent limit (the one-transaction blob ceiling at the DA-bound rate) and one **Open** premise (D1's
2 s cadence at n = 50–200, falsifier **F-CADENCE-1**).

---

## (a) Strongest figures across the spikes

| Figure | Value | Label | Source |
|---|---|---|---|
| Live Taiko L2 block time | 2.023 s mean, mode 2.000 s | [on-chain measured] | S1 §3.4 |
| Achieved live L2 rate | 60,476 gas/s = 0.52% of the implied DA bound; backlog ≈ 0 (demand-limited) | [on-chain measured] / [derived] | S1 §3.4, §3.6 |
| Live inbox cadence | proposal interval p50 384 s; proof interval p50 1,932 s; 5 proposals per proof | [on-chain measured] | S1 §3.1 |
| Proposal → proof latency (30 d, last covered) | p50 684 s, p90 1,896 s, p95 2,580 s, max 6,972 s | [on-chain measured] | S1 §3.2 |
| Live bytes per L2 gas | b_payload blended 0.00207 B/gas (median-of-blocks 0.00195); marginal user 0.00745–0.00804; b_billed 0.00561 B/gas | [on-chain measured] / [derived] | S1 §3.5 |
| One-transaction blob bound at the DA-bound rate | K ≤ 21 two-second L2 blocks (21 blobs = 2,752,512 B = 42 s); deployed K ≈ 190, viable only at ≈0.5% of its own DA bound | [bounded] | S1 §3.7 |
| Third-party proving (ethproofs.org) | 0.96–12.64 Mgas/s across **2–16× RTX 5090** cluster medians (eight 5090 clusters; record-level 0.94–16.20), single L1 blocks 4.2–51.3 Mgas; cycles/gas spreads 2.37–14.91 across teams for the same workload class | [third-party reported] | S1 §3.8 |
| Vendor cluster bound | ≥ 1.30 Mgas/s per 16× RTX 5090 cluster (≥ 0.081 Mgas/s per GPU) [bounded]; vendor's "99.7% of L1 blocks < 12 s" is the unverified premise [third-party reported] | [bounded] / [third-party reported] | S1 §3.9 |
| Ethereum L1 block interval | p50 12.000 s, mean 12.046 s, p99.9 24 s, max 36 s (n = 19,999, 66.92 h) | [on-chain measured] | S2 F1 |
| Live Taiko L2 cadence | 2.000 s for 19,998/19,999 intervals, max 4.000 s; exactly two block producers | [on-chain measured] | S2 F2 |
| Shipped CometBFT production cadences | 0.616 s at n = 21 (dYdX), 2.867 s at n = 95 (Celestia), 5.696 s at n = 180 (Cosmos Hub) | [on-chain measured, third-party network] | S2 F4 |
| Controlled Tendermint round latency | 2.14 s at n = 16 → 2.53 s at n = 128, including a 1 s commit wait (derived consensus portion 1.14–1.53 s) | [third-party reported] | S2 F5 |
| Controlled crash tail at n = 128 | 42/128 validators down: ~64% of blocks near 2.65 s, tails to ~30 s and ~39 s | [third-party reported] | S2 F5 |
| Live batch landing cost | p50 0.0000861 ETH ≈ $0.233 per batch (75,594 gas, 1 blob, 164 B calldata); week total 0.1634 ETH ≈ $431.31 | [on-chain measured] | S3 F1 |
| Landing cost decomposition | 72.9% priority fee, 24.7% burned L1 base fee, 2.4% blob data (all 1,575 batches) | [on-chain measured] | S3 F2 |
| On-chain proving cost | 399,414 gas per prove transaction (5 proposals per proof); 0.0001084 ETH amortised per batch; zero on-chain reward or bond events (minBond = 0, livenessBond = 0) | [on-chain measured] | S3 F7 |
| Cost per L2 gas | landing p50 4,014,700 wei (0.00401 gwei); with amortised on-chain proving ≈ 0.0088 gwei | [on-chain measured] | S3 F5 |
| D-8 coverage in the sampled hour | all L2 fees 1.135×, base fee only 1.075×, proposer's own share 0.867×; break-even 1.567 gwei (all fees) | [bounded] | S3 F8 |
| Live batch length | 192 L2 blocks for 446/451 proposals; the live Inbox stores no MAX_BATCH_BLOCKS constant | [on-chain measured] | S3 F4, N5 |
| S4: Shasta production DA mode (full census) | all 40,473 blob-carrying proposals carry ≥1 blob (100%; 40,465 exactly 1, and 4/2/2 with 2/4/5); the census holds 40,474 `Proposed` logs, one of them the non-proposal genesis log; 40,491 blobs; 5.31 GB published over 2026-04-02 → 2026-10-07 (blocks 24,792,175–26,140,714) | [on-chain measured] | S4 F1 |
| S4: carried-path check exercised in production | 40/40 sampled real proposals are type `0x3`; each transaction's `blobVersionedHashes` equal the event's recorded `blobHashes` element-wise and in order; `blobGasUsed = 131,072 × n_blobs`; calldata constant 164 B | [on-chain measured] | S4 F1 |
| S4: blob base fee over the proposal blocks | price min 1,668,134 / median 6,991,223 / p90 33,430,313 (artifact index rule `sorted[int(0.9n)]`; nearest-rank 33,158,382) / max 675,350,452 wei per blob gas; one-blob cost ≈ 2.19e-7 – 8.85e-5 ETH (systematic sample: **2,020 of the 2,024 every-20th proposal blocks**, ending 26,137,748, ≈9.9 h before the era's last block; re-running the committed `blob_price_stats.py` gives n = 2,162) | [on-chain measured] | S4 F3 |
| S4: base-fee formula in force | 18/18 sampled blob-bearing blocks match `fake_exponential(1, excessBlobGas, 11,684,671)` (BPO2); 0 match the Cancun, Prague or BPO1 fractions | [on-chain measured] | S4 F3 |
| S4: EIP-4844 parameters in force over the window | post-BPO2: target 14 / max 21 blobs per block, base-fee update fraction 11,684,671 (live beacon config and EIP-7892; Electra's 6/9 superseded 2025-12-09 and 2026-01-07); the S4 pin "6/9" and S3's 9-blob sweep ceiling were stale by two forks and the re-base has since been applied — spec/04 L1-01 and spec/09 row 120 now read 21 hard / 14 sustainable, and the S1/S3 sweeps carry 14 and 21 (see item 18 and (c) 12) | [third-party reported] | S4 F6 |
| S4: KZG commitment checks from the public beacon endpoint | 15/15 versioned-hash matches and 15/15 recomputed-commitment matches over 5 blocks; the served `kzg_proof` is the point-at-infinity placeholder (0/15 verify) while a freshly computed proof verifies 15/15; the `0x0A` precompile returns `abi.encode(4096, BLS_MODULUS)` on a real Taiko blob | [on-chain measured] | S4 F4 |
| S4: production blob path | the deployed `MainnetInbox` has zero hits for `pointEvaluation`/`0x0A`/`KZG`/`verifyKzgProof` in its 42 verified source files, no `publish` entry point, and only `blobhash(i) != 0` with the hashes recorded — the carried path without the design's on-chain opening check | [third-party reported] | S4 F5 |
| S4: DA-mode history (sampled 10,000-block windows) | blobs carry the batch data in every sampled era; the calldata path is rare pre-Pacaya (12 of 5,460 proposals in the one window where it appears, ≈0.2%) and absent from deployed Shasta | [on-chain measured] | S4 F7 |
| S4: blob occupancy | in the four most recent proposals only 2,350–6,350 of 131,072 bytes are non-zero (1.8–4.8%); the highest non-zero 32-byte word is index 75/125/200/148 of 4,096, so the used prefixes are ≤ 2,432 / 4,032 / 6,432 / 4,768 B and the remainder is zero, while the commitment covers the whole blob | [bounded] | S4 F8 |
| S4: blob retrievability | sidecars served at ages 0.1, 5.7, 25.1 and 39.2 days (4/3/5/3 sidecars); probes at 62.7 and 86.2 days returned HTTP 403 (rate limiting, not conclusive) | [on-chain measured] | S4 F9 |
| S4: DA-03(iii) reduction-bias arithmetic | `BLS_MODULUS/2^256 = 0.4528450563462822 = 2^-1.142910586952811 ≈ 2^-1.14`, not the stated `2^-127`; the union bound over ≤ 4095 roots (≈ 2^-243) is unchanged — the sentence is wrong | [bounded] | S4 F10 |

*Blob-bound row above: re-based — K ≤ 21 combines the design's own DA-bound rate (one 131,072 B blob per 2 s L2 block) with the measured BPO2 per-L1-block maximum of 21 blobs (target 14 / max 21 / base-fee update fraction 11,684,671, S4 F6). 14 is the design's chosen planning length — the BPO2 target, publishable by construction — and 21 the hard edge; the design baseline rates themselves are unchanged.*

*DA-03(iii) row above: the earlier `≈ 0.731 ≈ 2^-0.45` took the value of `2^-0.45` as if it were the ratio; `0.731` is not the ratio, `0.4528450563462822 = 2^-1.142910586952811` is. The wrong figure propagated into a lead brief before recomputation caught it, and the pre-registered [S4-blob-binding-review.md](../S4-blob-binding-review.md) §7 had `2^-1.14` right all along.*

*PB-L-02 (blob-occupancy row above): the earlier "element 148 or lower, prefix ≤ 4,768 B" took the last sample's maximum as the maximum of the four. The four highest non-zero 32-byte word indices are 75, 125, 200 and 148, so the used prefix reaches 6,432 B (element 200 of 4,096); re-derived from the four beacon sidecars by [`raw/s4-blob-binding/sidecar_word_prefix.py`](./raw/s4-blob-binding/sidecar_word_prefix.py). The earlier value had no supporting artifact.*

*PB-L-01 (ethproofs row above): "3.4–12.6 Mgas/s on 4–16×" did not reproduce from the cited raw file — its eight RTX-5090 cluster medians run 0.958–12.644 Mgas/s and include four 2× clusters. Re-derived by [`raw/s1-public-data/thirdparty/ethproofs_5090_medians.py`](./raw/s1-public-data/thirdparty/ethproofs_5090_medians.py).*

*PB-L-03 (landing-cost-decomposition row above): the earlier 71.4/24.1/2.4 summed to 97.9% because base and priority covered only the 1,542 of 1,575 batches whose block headers were cached; with the 33 missing headers backfilled the full-population decomposition is 72.9/24.7/2.4. Re-derived by [`raw/s3-l1-cost-fee-flow-public/fee_decomposition.py`](./raw/s3-l1-cost-fee-flow-public/fee_decomposition.py).*

*PB-L-13 ((a) S4 DA-mode row above): the earlier "40,473/40,474 proposals" divided the proposal count by the log count; 40,474 is the `Proposed` log census including the non-proposal genesis log, and all 40,473 proposals carry ≥1 blob. Corrected in place; S4 F1 always had it right.*

*PB-L-07 (EIP-4844 row above): the row said the pin and sweep ceiling "are stale"; they were, and the re-base has since been applied (item 18, (c) 12). The tense is corrected to match.*

*PB-AR-05 (S4 blob-base-fee row above): the sample is 2,020 of the 2,024 every-20th proposal blocks and ends at 26,137,748, ≈9.9 h before the era's last proposal block (26,140,714); the quoted p90 uses the artifact's `sorted[int(0.9n)]` index (nearest-rank 33,158,382), and re-running the committed `blob_price_stats.py` gives n = 2,162, p50 6,838,873, p90 32,784,583. Re-derived by [`raw/s4-blob-binding/f3_sample_and_probe.py`](./raw/s4-blob-binding/f3_sample_and_probe.py).*

*PB-AR-01 (S3 F8; see (c) item 7): the break-even blob base fee is 243,041,212 wei = 0.2430 gwei once the amortised on-chain proving cost is included, not 1,069,729,806 wei; the window's observed maximum blob fee (0.4274 gwei) is 1.76× the corrected break-even, so at the observed peak the blob line alone consumes the fee margin. Re-derived by [`raw/s3-l1-cost-fee-flow-public/blob_breakeven_corrected.py`](./raw/s3-l1-cost-fee-flow-public/blob_breakeven_corrected.py).*

*PB-AR-08 (S1 rows below): "72.6% anchor-only" is the `== 112,068 gas` subset only; 90.88% of L2 blocks sit at one of the two anchor-only gas values and 94.07% carry exactly one transaction. Re-derived by [`raw/s1-public-data/anchor_only_share.py`](./raw/s1-public-data/anchor_only_share.py).*

**S4 (blob binding) — in.** Its report [blob-binding.md](./blob-binding.md) landed on 2026-10-07; the rows
above are its figures under the README ladder. What it could not reach — the in-guest evaluation cost, the
10,000-journal differential test, the rejection matrix and the independent cryptographic review of the
binding — is named in (d), and its parameter consequences are the (b) entries below.

---

## (b) Parameter and rule ledger

Each entry names the specification parameter or rule, quotes the rule that reads it, and states what the
evidence now supports. The verdict vocabulary is FIXED / BOUNDED / STILL UNMEASURED; **no entry is
FIXED**. No value was changed anywhere: every unmeasured value stays tagged and unmeasured, and the two
newly recorded bounds travel with their assumptions.

1. **`BATCH_BLOCKS` (K)** — 09's own row: *"There is no canonical batch length. The range length is
   chosen by the submitter of each `land(data, proof)`, bounded by `MAX_BATCH_BLOCKS` (L1-05 row 7), by
   the blob-quantisation bound below and by the single-epoch rule (PRF-05)."* — **BOUNDED, not measured.**
   Live: 192 L2 blocks per batch (446/451 proposals, S3 F4; ≈190 by cadence arithmetic, S1 §3.3). At the
   DA-bound rate the blob ceiling gives K ≤ 21 at 2 s blocks (S1 §3.7). The live K is a proposer policy
   exercised at ≈ 0.5% of the DA bound, not a measurement of what the design can carry. *(Re-based: the 21-blob ceiling is the measured BPO2 per-L1-block maximum — target 14 / max 21 / base-fee update fraction 11,684,671, S4 F6; 14 is the design's chosen planning length and 21 the hard edge, while the 65,536 B/s DA-bound rate itself remains the design baseline.)*
2. **`MAX_BATCH_BLOCKS`** — L1-05 row 7: *"MUST satisfy `firstBlockHeight <= lastBlockHeight <=
   firstBlockHeight + MAX_BATCH_BLOCKS - 1`; proof-bound over the whole range."* — **BOUNDED; the value
   stays STILL UNMEASURED.** The bound and its derivation: at the DA-bound rate (65,536 B/s — the design
   baseline, unchanged) one `land` transaction of at most 21 blobs carries at most 42 s of L2 data, so
   K ≤ 21 at 2-second blocks; the
   deployed K ≈ 190 is viable only because it sits at ≈ 0.5% of its own DA bound, and the deployed K is
   **not** evidence that a larger K is safe at the design point (S1 §3.7). Tagged
   `unmeasured-but-bounded` in 09 row `MAX_BATCH_BLOCKS` and carried **Disclosed** in LIM-01. *(Re-based: 21 is the measured BPO2 per-L1-block maximum — target 14 / max 21 / update fraction 11,684,671, S4 F6 — and 14 is the design's chosen planning length; the design baseline rates are not re-derived.)*
3. **Blob-quantisation bound on batch length** — 09: *"`R × blobs_per_block ≤ 21` (hard ceiling) and
   `R ≤ 14` (sustainable at the target rate)"*; L1-01: *"at the DA-bound rate one 2-second L2 block is one
   131,072-byte blob (EIP-4844), so `BATCH_BLOCKS × blobs_per_block ≤ 21` (hard) and `BATCH_BLOCKS ≤ 14`
   (sustainable at the target …)"*.
   — **BOUNDED; confirmed by measured inputs, no value fixed.** The measured live inputs reproduce the
   derivation and show the registered placeholder 32 is not publishable at that rate (S1 §3.7). *(Quotes
   re-based, not marked superseded: the current spec/04 L1-01 and spec/09 row 120 read 21 hard / 14
   sustainable, so the quotations above were taken from the current spec; the previously quoted 9/6 was the
   superseded EIP-7691 set (S4 F6), and 14 is the design's chosen planning length with 21 the hard edge.)*
4. **D1 — one L2 block every 2 s** — index: *"One L2 block every 2 s under stated operating assumptions.
   Cadence is not finality, proof, settlement or withdrawal latency."*; GEN-02: *"D1–D7 are constraints.
   A design element that conflicts with one of them is a defect, not a tradeoff."* — **BOUNDED BUT NOT
   CONFIRMED at n = 50–200; a design target with a measured bound attached, carried Open as
   F-CADENCE-1.** S2: L1 quantises L1-anchored steps at 12 s (p99.9 24 s, max 36 s); the live 2.000 s
   Taiko cadence is produced by two permissioned preconfers, so it is no evidence about a BFT set;
   shipped CometBFT-class sets commit at 0.62 s (n = 21), 2.87 s (n = 95) and 5.70 s (n = 180); a
   controlled study puts a 128-validator round at 2.53 s including a 1 s commit wait; the three
   production points nearest n ≈ 100 were observed at 2–3 s, but they are three uncontrolled cross-chain
   configurations, not an n-sweep — S2 F4's own warning that the row order is not a validator-count
   scaling law applies here. Public data neither confirms nor falsifies D1 at the intended n, and D1 is
   not restated as a result. *(PB-L-14: the "region where 2–3 s is observed" phrasing read three
   uncontrolled points as a scaling law; the caveat is stated at the point of use.)*
5. **`N_MAX`** — MEM-14(1): *"Every published set version MUST satisfy `n_k ≤ N_MAX`"*; MEM-14(3):
   *"`N_MAX` MUST be fixed at or below the largest `n` at which S2 ... shows one round completing inside
   the 2 s cadence with the declared delay bound"*. — **STILL UNMEASURED.** S2 supplies production
   observations at n = 21/95/180 and a 2020 controlled study, not the largest n at which 2 s holds for
   this design.
6. **`TIMEOUT_MIN`, `TIMEOUT_MAX`** — CONS-07(2): *"`TIMEOUT_MIN ≥ 2·round_trip`"* with
   *"`round_trip = 4·Δ_max + X_max`"*, and *"Both `TIMEOUT_MIN` and `TIMEOUT_MAX` are therefore
   unmeasured in practice."* — **STILL UNMEASURED; bounded only.** S2's published crash trace reaches
   ~30 s and ~39 s after 5–6 rounds with 42/128 validators down, under v0.33.8 defaults with 3 s/1 s
   initial timeouts — a different engine version, so it cannot fix the ladder.
7. **`Δ_max`, `X_max`** — CONS-07(2): *"`Δ_max` (advisory one-way delay between correct validators)
   and `X_max` (local execution time for one block) are UNMEASURED"*. — **STILL UNMEASURED / not
   establishable from public data.** No public dataset measures node-pair p99 for a future permissionless
   set, and nothing measures Taiko's execution client on the fixed 131,072 B payload (S2 §5).
8. **LIVE-03's three inequalities** — 10-assurance: *"The proving pipeline is sustainable if and only if
   three inequalities hold ... (i) rate ... (ii) concurrency ... (iii) data"*. — **STILL UNMEASURED.**
   (i) needs `R_gas`; (ii) needs per-proof latency at the design K; (iii) holds trivially for the live
   system (0.52% of its own implied DA bound) but is not evaluable at the design point because `b` is
   unmeasured.
9. **`T_PROOF_ENVELOPE`** — 09: *"1,800 (30 min) — Fixed by D6 as a planning assumption, explicitly not
   a worst-case bound."* — **UNCHANGED; not a measurement.** The measured end-to-end latencies (S1 §3.2
   p50 684 s / p95 2,580 s; S2 F3 p50 1,488 s / p99 2,796 s / max 4,968 s) are system-level and contain
   batching, queueing and L1 inclusion; they are not `T_proof` at K ∈ {8, 32, 128} and neither fix nor
   bound this parameter.
10. **`T_PROOF_MAX_PERMITTED`** — 09: *"Unset; the single registered name for the maximum proving
    latency the protocol permits a batch to consume. It MUST NOT be fixed below D6's planning envelope
    `T_PROOF_ENVELOPE` (1,800 s = 900 L2 blocks at 2 s)"*. — **STILL UNMEASURED.** No public source
    reports K-specific proving latency for this design's guest.
11. **`REWARD_QUOTE`** — 09: *"`rewardPaid = min(REWARD_QUOTE, proverReward_before + msg.value)`"*. —
    **BOUNDED FROM BELOW, not fixed.** Measured floor for the L1-side cost of one live batch:
    0.0002146 ETH (landing 0.0001063 + on-chain proving 0.0001084; ≈ $0.57–0.59 at the in-window hourly
    closes of $2,661–2,755, and $0.569–0.597 for the 8 sampled batches at their own hours). It omits
    `C_prove`, `C_bridge_ops` and `C_ops` (S3 F8/F9). *(PB-L-11: the earlier $0.55–0.58 quoted a
    minimum close 13 h outside the window; re-derived in `raw/s3-l1-cost-fee-flow-public/kraken_window_stats.py`.)*
12. **D-8 — security funded from L2 fees** — decision log. — **BOUNDED, not settled.** In the measured
    week L2 fees cover landing plus on-chain proof submission 1.135× (base fee alone 1.075×); the
    proposer's own share (75% of base + priority) covers 0.867×; coverage crosses 1.0× at 1.567 gwei L1
    effective price on all fees (1.196 gwei on the proposer's share). The off-chain prover fee — which
    the protocol's own documentation says exists — is excluded and unmeasured (S3 F8, N1). On the data line the corrected break-even blob fee is 0.243 gwei while the window's observed maximum is 0.4274 gwei, 1.76× that: at the observed peak the blob line alone consumes the margin once the proof is paid (PB-AR-01, S3 F8).
13. **D-9 — penalties to the treasury, no burn** — decision log. — **INFORMED, not measured.** The live
    L2 base fee is not burned (100% split coinbase/treasury), matching the fee-revenue rule; the deployed
    `prove()` burns 50% of a late liveness bond when the whitelist is off (currently inactive because
    `livenessBond = 0`) — a rule-text question, not a measurement (S3 §5).
14. **FI capacity relation / `L2_BLOCK_GAS_LIMIT`** — 09: *"`FI_MAX_PER_BATCH × FI_MAX_TX_PER_RECORD ×
    FI_RECORD_GAS_MAX ≤ MAX_BATCH_BLOCKS × L2_BLOCK_GAS_LIMIT`"*. — **STILL UNMEASURED.** The live chain
    shows a constant 46,000,000 gas limit with blocks 0.28% full (S3 F4/F8): the live regime, not the
    designed gas-limit schedule.
15. **`BLOCK_ZK_GAS_LIMIT`** (first-party deployed value; not a registered spec id) — **STILL
    UNMEASURED.** The 100M zk-gas-per-block placeholder rests on a 4-GPU, 1 s L2, 384-block, ~12 h model
    implying 1.0M zk gas/s on 4 GPUs (0.25M/GPU); S1 names it as the assumption S1 was meant to replace
    (S1 §3.10).
16. **Fee-vault credit check and sweep** (S3's rule-level deliverable; S5 §8) — **STILL UNMEASURED.** No
    fee vault or in-guest credit predicate exists in the live protocol; L2 fees are credited by the
    execution client (S3 N3, N4).
17. **`gas_per_new_storage_slot`** (S3 → S5 input) — **STILL UNMEASURED** (S3 N10).
18. **Batch-length blob ceiling (`BATCH_BLOCKS`/`MAX_BATCH_BLOCKS`; 09 row 3, L1-01)** — S4 F6: the
    per-block maximum in force over the measured window is 21 blobs post-BPO2 (target 14 / max 21, update
    fraction 11,684,671; a 400-block sample observed at most 21 in one block, a lower bound on the enforced
    maximum), so the spec's 9-blob hard ceiling and 6-blob "sustainable" figure — and S3's `n_blobs` sweep
    ceiling of 9 — are **stale by two forks**. — **BOUNDED, not fixed; no parameter value changed here.** S4 said the
    constants must be re-based; that re-base has since been applied — spec/04 L1-01 and spec/09 row 120 now
    read 21 hard / 14 sustainable, and the S1 and S3 spike sweeps carry 14 and 21 (S1 §4.1/§4.4, S3 §2/§4;
    [S1](../S1-proving-throughput.md), [S3](../S3-l1-cost-and-fee-flow.md)) — so the K ≤ 21 bound in item 3
    now stands against the in-force set, with 14 the design's chosen planning length and 21 the hard edge;
    the batch-length consequence still depends on S3's measured `land` gas and the one-transaction atomicity
    rule (S4 §5 row 1).
19. **DA-03(i) carried path — `blobhash(i) != 0` and ordered hash recording; L1-01** — S4 F1/F2: exercised
    in production on 40,473 proposals; every sampled proposal's transaction hashes equal the event's
    recorded hashes element-wise and in order. — **BOUNDED (implementability confirmed in production); the
    design's referenced-publication path (DA-07/DA-08, D-11) has no production counterpart and stays STILL
    UNMEASURED** (S4 F1, F5).
20. **DA-03(ii) on-chain `0x0A` opening check** — S4 F4/F5: absent from the deployed `MainnetInbox`; the
    precompile itself returns `abi.encode(4096, BLS_MODULUS)` on a real Taiko blob and a freshly computed
    proof verifies. — **BOUNDED ONLY; unexercised.** The design's challenge/transcript binding is not
    exercised anywhere and remains for the cryptographic review (S4 §5 row 4).
21. **DA-03(iii) reduction-bias sentence** — S4 F10: `BLS_MODULUS/2^256 = 0.4528450563462822 =
    2^-1.142910586952811 ≈ 2^-1.14`, not the stated `2^-127`; the union bound over ≤ 4095 roots
    (≈ 2^-243) is unchanged. — **BOUNDED; sufficient to fix the text by arithmetic, pending the reviewer's
    independent recomputation.** No parameter value moves (S4 §5 row 8). *(The earlier `0.731 ≈ 2^-0.45`
    was a ratio mistaken for an exponent — `0.731` is the value of `2^-0.45`, not of the ratio — and the
    wrong figure propagated into a lead brief before recomputation caught it; the pre-registered
    [S4-blob-binding-review.md](../S4-blob-binding-review.md) §7 had `2^-1.14` right all along.)*
22. **DA-07(1) retrievability; `PUB_RECORD_RETENTION`, `T_PROVE_DEADLINE`, `ARCHIVE_REQUIREMENT`** — S4 F9:
    sidecars served at ages 0.1, 5.7, 25.1 and 39.2 days; probes at 62.7 and 86.2 days returned HTTP 403
    (rate limiting, not conclusive about retention); the beacon p2p retention constant is 4096 epochs
    ≈ 18.2 days and pre-Shasta blobs are gone. — **BOUNDED; every value stays unmeasured.** Any retention
    window the design assumes must fit inside the measured retrieval window it is willing to pay for
    (S4 §5 row 6).
23. **DA-03(0) whole-blob commitment including the unused remainder** — S4 F8: production pays for a full
    131,072-byte blob per proposal while only 2,350–6,350 bytes are non-zero, and the commitment covers the
    whole blob — consistent with the rule. — **BOUNDED; the data-budget consequence for `b` and K needs the
    payload sizes, which public data only bounds** (S4 §5 row 7).

### The two tensions, as now recorded in the specification

**(i) `MAX_BATCH_BLOCKS` / K — a bound, recorded as disclosed.** The tension is that the spec's
admission bound is unset while the deployed network runs K ≈ 190. Recorded now at the definition sites
(L1-01's batch-length consequence; L1-05 row 7), in the parameter register (09 row `MAX_BATCH_BLOCKS`,
tagged `unmeasured-but-bounded`), and in LIM-01 as a **Disclosed** row with its derivation and source
(S1 §3.7). The register class follows the LIM-01 preamble: the per-L1-transaction blob ceiling at the
DA-bound rate is a limit *inherent to the design*, not a premise no rule closes, so it is disclosed, not
Open. What the disclosure says plainly: the deployed K is not evidence that a larger K is safe at the
design point.

**(ii) D1's 2 s cadence at n = 50–200 — a design target with a measured bound attached, recorded as
Open.** Recorded at D1's row in the fixed-decisions table (index) and in LIM-01's Performance row as
**Open (F-CADENCE-1)**, with what would falsify it: an S2 stage-1/2 G-CADENCE run at the pinned engine
release and real geography in which a round cannot complete inside 2 s at the registered `N_MAX` —
which would be a defect against fixed decision D1 and would move `N_MAX`, the cadence or the timeout
policy. The class follows the LIM-01 preamble: whether a BFT set of 50–200 commits every 2 s is a
premise no rule closes, and its falsification is a defect. D1 is not weakened and not restated as a
result; the S2 bound is attached to it.

---

## (c) Mismatches: where the evidence sits awkwardly against the specification

1. **K versus one-transaction publication.** The spec's illustrative `BATCH_BLOCKS = 32` needs 32 blobs
   against a maximum of 21 at the DA-bound rate (L1-01, 09 row 120: 21 hard / 14 sustainable under the
   measured BPO2 set, S4 F6), and `MAX_BATCH_BLOCKS` is unset.
   The deployed network runs 192-block batches with 1 blob and a 164-byte call — a completely different
   data regime, and it stores no such constant at all (S3 N5). The live figure is a policy at 0.5% of the
   DA bound, not a publishable K (S1 §3.7). *(Corrected: this item earlier read "a maximum of 9"; the
   per-transaction maximum in force is the measured BPO2 21, with 14 the sustainable value and the design's
   chosen planning length, so 32 blobs remains unpublishable.)*
2. **D1 versus the shipped cadence evidence.** The only live 2.000 s cadence measured is produced by two
   permissioned preconfers (S2 F2); the production CometBFT sets observed nearest the target region
   commit at 2.87 s (n = 95) and 5.70 s (n = 180) in their shipped configurations (S2 F4), and the
   controlled study's 2.53 s at n = 128 is a 2020 engine version with a 1 s commit wait (S2 F5). The
   design's 2 s at n = 50–200 therefore sits at or below the bottom of what production configurations
   near n ≈ 100 demonstrate — the premise is open, not merely unmeasured.
3. **The L1 quantisation clock.** Any step anchored to Ethereum L1 has a p99.9 opportunity gap of 24 s
   and a maximum of 36 s in the measured window (S2 F1); 12 s is the floor, not the mean. L1-anchored
   steps cannot be paced at 2 s granularity, and the spec's L1-side clocks (epoch schedule, append
   obligations) are L1-block-denominated rather than second-denominated — the evidence confirms the
   separation but makes any implicit seconds-based expectation on the L1 side wrong.
4. **`b`'s spread is exactly the unresolved sensitivity.** The blended live ratio is 0.00207 B/gas
   because the live workload is near-empty — 90.88% of L2 blocks sit at one of the two anchor-only gas values and 94.07% carry exactly one transaction (S1 §3.4; PB-AR-08, corrected from the `== 112,068` subset's 72.6%); the marginal user ratio is 0.00745–0.00804 B/gas, against
   the spec's illustrative 0.006 and 0.02 (S1 §3.5). The spec's mandatory workload-sensitivity add-on is
   not satisfied by public data, so neither the blended nor the marginal figure can be promoted.
5. **The proving envelope versus measured end-to-end latency.** D6's 30-minute normal-operation planning
   assumption (09 row `T_PROOF_ENVELOPE`) is compared in the evidence with system-level latencies whose
   30-day p95 is 2,580 s (S1 §3.2) and whose 7-day p99 is 2,796 s with a 4,968 s maximum (S2 F3). These
   are not `T_proof` — they include batching, queueing and L1 inclusion — but the awkwardness is real:
   the only public latency figures for the deployed pipeline's full path exceed the envelope at their
   tails, and the spec's per-K proving measurement is exactly what is missing.
6. **The live cost curve is not the designed acceptance path.** Live Unzen lands and proves in separate
   transactions with 1 blob and 164 bytes of calldata; the spec's `land(data, proof)` carries the batch's
   blobs in one transaction. The measured 75,594 gas per batch must not be transferred to the
   specification's payloads, where per-byte terms (blob count, keccak, the 0x0A precompile) dominate
   (S3 N2). The live curve fixes the *live regime's* shape only.
7. **D-8 without a live prover market.** The deployed prover is whitelisted, paid nothing on-chain, and
   the window contains no reward or bond event; the prover fee is negotiated off-chain (S3 F7). So the
   [bounded] 1.135× coverage excludes the largest unknown, and the spec's funded proving market has no
   live counterpart against which to check its premise. On the proposer's own share the measured week is
   already short (0.867×), and coverage falls below 1.0× above ≈ 1.567 gwei (S3 F8). The DA line is a second
   such edge: the corrected break-even blob fee is 0.243 gwei and the window's observed maximum is 0.4274 gwei,
   1.76× that — at the observed peak the blob line alone consumes the margin once the proof is paid
   (PB-AR-01). *([bounded] is the (a) row's label for both coverage ratios: the sampled week's fees are measured, the coverage of them is not.)*
8. **D-9 and the deployed late-bond burn.** The live L2 base fee is not burned, matching the no-burn
   reading of D-9; but the deployed `prove()` burns 50% of a late liveness bond when the whitelist is
   off (inactive today because `livenessBond = 0`). If D-9's "no burn" is meant to cover every protocol
   flow, the deployed rule contradicts it — a rule-text decision, not a measurement (S3 §5).
9. **Cycles are not comparable across provers.** For the same workload class, reported cycles/gas spans
   2.37–14.91 across teams (S1 §3.8). The spec's plan to compare `C` across backends is meaningful only
   within one backend and a fixed SDK; a third-party benchmark is not this design's guest, and the
   Taiko-funded per-opcode study adds the qualitative warning that cycles are not a universal proxy for
   proving time (S1 §3.10).
10. **The deployed system answers neither design question.** It is demand-limited at 0.52% of its own
    implied DA bound with no proof backlog (S1 §3.6), over a workload in which 90.88% of blocks sit at an
    anchor-only gas value and 94.07% carry exactly one transaction (S1 §3.4; PB-AR-08). It is neither DA-limited nor proving-limited in the sense S1 asks about, so it
    provides no evidence for the design point's verdict; the spec's §8.3 decision still needs the S1
    measurement.
11. **Production has no publication record and no on-chain opening check.** The deployed `MainnetInbox`
    has no `publish` entry point and no `pointEvaluation`/KZG call — its only blob check is
    `blobhash(i) != 0` with the hashes recorded in the event (S4 F5) — so DA-07/DA-08's
    referenced-publication path (D-11) and DA-03(ii)'s on-chain opening check have no production
    counterpart. The carried half is exercised on 40,473 proposals; the referenced half is not (S4 F1,
    F4, F5).
12. **The blob parameters the specification pins are two forks stale.** S4's pin "Blob limits 6/9,
    EIP-7691" and S3's `n_blobs` sweep ceiling of 9 describe the Prague/Electra set; the measured window
    is entirely post-BPO2 — target 14 / max 21 per block, update fraction 11,684,671, the fraction
    confirmed on chain (S4 F3, F6). The batch-length consequence is therefore bounded under a parameter
    set the chain no longer runs, and the sweep's numbers were to be re-based before reuse; that re-base
    has since been applied (spec/04 L1-01, spec/09 row 120; S1 §4.1/§4.4, S3 §2/§4), and no measured
    value changes here. *(Updated: see item 18.)*
13. **The public opening proofs are placeholders.** The beacon endpoint serves `kzg_proof = 0xc0‖0…0` for
    every sampled sidecar, so the commitment↔blob↔versioned-hash bindings verify but the *opening half* of
    production's binding could not be confirmed from public data at all (0/15 verify; a freshly computed
    proof verifies 15/15, S4 F4). Even a valid served proof would verify EIP-4844's own Fiat–Shamir
    challenge, not the Etna transcript's `z_i`.
14. **DA-03(iii)'s arithmetic sentence is wrong by ~126 bits.** The rule states the `% BLS_MODULUS`
    reduction biases the distribution by at most `BLS_MODULUS/2^256 ≈ 2^-127` — kept here as the
    specification's faulted text; the ratio is `0.4528450563462822 = 2^-1.142910586952811`, about
    `2^-1.14`, and the union bound over ≤ 4095 roots (≈ `2^-243`) is what survives (S4 F10). A text
    defect, to be confirmed by the reviewer who must recompute it. *(The earlier `≈ 2^-0.45` took `0.731`,
    the value of `2^-0.45`, as if it were the ratio; the wrong figure propagated into a lead brief before
    recomputation caught it, and the pre-registered
    [S4-blob-binding-review.md](../S4-blob-binding-review.md) §7 had `2^-1.14` right all along.)*
15. **Retention is measured shorter than a publication path may want.** Sidecars were served only to 39.2
    days at the tested public endpoint, probes at 62.7 and 86.2 days returned HTTP 403 (rate limiting,
    not conclusive), the protocol's p2p retention constant is 4096 epochs ≈ 18.2 days, and pre-Shasta
    blobs are gone (S4 F9). Any window the design assumes for a live publication record must fit inside
    what it is willing to pay to retrieve; public data bounds it, it does not fix it.

---

## (d) What remains unmeasurable without hardware — named quantities

These are the precise quantities the substitution cannot produce. They are not "gaps"; each names what
would measure it and which rule waits on it (S1 §4, S2 §4, S3 §4; the Phase B plan's S1–S4 questions).

| Quantity | Why public data cannot supply it | Named by |
|---|---|---|
| `C` — cycles per L2 gas for the pinned Taiko guest (raiko2 v0.8.0-rc1) | No public source reports cycles for this guest; other guests' cycles/gas spread ~5–6× | S1 §4(1); PARAM-03; LIVE-03 |
| `R_gas` — proven gas/s per machine at named hardware | ethproofs measures other guests on single L1 blocks; no public source states how many machines produced the live proofs or their utilisation | S1 §4(2); G-RATE, G-FLEET |
| DA-limited vs proving-limited verdict at the design point | Both sides unknown: `b` is workload-dependent and the proving bound needs `R_gas` | S1 §4(3); the §8.3 decision |
| In-guest blob polynomial-evaluation cost | Nothing public for the pinned image and fixture | S1 §4(4); M8/M9; PARAM-03 F2 |
| `T_proof` distribution by K ∈ {8, 32, 128}, and the wrapped-proof cost | The measured latencies are end-to-end and queueing-inclusive; no per-K measurement exists | S1 §4(5); M10, M13 |
| Workload sensitivity of `b` | The live mix is 90.88% anchor-only by gas value and 94.07% single-transaction (PB-AR-08); only one (near-empty) mix is observable | S1 §4(6) |
| Peak memory, machine price and fleet-sizing inputs (`N_MAX`, `B_fleet`) | No VRAM/RSS envelope for this guest and no dated price tied to a measured rate | S1 §4(7); M12, M14 |
| `N_conc = T_proof/(2K)` | Needs per-proof latency on the frozen workload and the design K | S1 §4(8); LIVE-03(ii) |
| `Δ_max` and the one-way delay matrix; round completion at n = 50/100/200 with Taiko's payload; `X`/`X_max` at 131,072 B; view-change rate; bandwidth, messages and vote size on the wire; fault response and recovery; node health; clock skew; the largest n at which 2 s holds; ladder conformance (G-CONFORM) | Public RPCs expose block intervals, not round events; no public network runs Taiko's consensus at these sizes and configurations | S2 §4, M1–M12 |
| `C_prove` — off-chain proof-generation cost | Negotiated privately; no ledger records it, and no reward/bond event exists on-chain | S3 N1; D-8 |
| `land(data, proof)` gas for K ∈ {8, 32, 128} at 131,072 B/block; per-backend verifier-route gas | That contract does not exist; live Unzen uses a different data regime and one routed verifier | S3 N2, N9 |
| Fee-vault sweep-interface gas; the credit predicate `delta ≥ expected` | No vault or credit predicate exists on either chain | S3 N3, N4; S5 §7–8 |
| `gas_per_new_storage_slot` and the acceptance-path slot list | Requires the `LandHarness`; the live storage layout differs | S3 N10; S5 |
| Payload bytes actually used per batch | The blob's used length is not in the event data or receipt | S3 N6 |
| **S4:** the in-guest blob polynomial-evaluation cost (S4 gate T5) | No public source contains a cycle count, wall-clock or peak-memory figure for the pinned guest, and none is derivable from L1 | S4 §4(1); the `blob-eval` guest on RISC Zero v3.0.6 / SP1 6.8.1 |
| **S4:** the contract/guest challenge identity (10,000-journal differential test; S4 gate T2) and the rejection matrix with the V1–V4 conventions (S4 gate T1) | Both are properties of two implementations and of the (undeployed) Etna contract; public data contains neither | S4 §4(2)–(3); the S4 harness |
| **S4:** whether production blobs carry valid KZG openings | The public beacon endpoint sampled serves placeholder proofs (0/15 verify), and a served proof would verify EIP-4844's challenge, not the Etna transcript's `z_i` | S4 §4(5); S4 F4 |
| **S4:** the independent cryptographic review of the binding between published bytes and the proven range, and the fixed-point/transcript conventions it reviews (S4 gates T3/T4, claims 1–5) | No amount of on-chain data substitutes for the review | S4 §4(4); [../README-public-data.md](../README-public-data.md) (S4 row) |

---

## (e) What Phase B's gate can and cannot now be said to have passed

Phase B's gates stand as written ([../README.md](../README.md); plan §3): **G1** — every harness produces
a number at all; **G2** — each spike has a pass/fail with evidence; **G3** — the parameter table is
re-derived from measured inputs and the specification is re-frozen.

- **G1 is not passed.** No harness ran; this programme produced measurements, not harness numbers.
- **G2 is not passed, and no pass/fail may be inferred from it.** S1's gates (G-RATE, G-FLEET, G-BLOB,
  G-VALID) are defined over pinned-guest cycles and wall-clock times on named hardware and none can be
  evaluated here; S2's round-completion and conformance gates need machines at n = 50/100/200; S3's
  conditions are stated over a `land(data, proof)` path that does not exist; S4's public-data half is now
  in ([blob-binding.md](./blob-binding.md)) but its gates T1–T5 and the independent cryptographic review
  are untouched by it (S4 §0, §4). The substitution can *bound* and *disclose*, and it must report the
  remainder as unmet.
- **G3 is not reached.** No parameter is FIXED and none was promoted: every value stays tagged
  `unmeasured`, and the two bounds recorded in (b) carry their assumptions and sources with them. The
  register stays open with named measurements.

What the programme **can** be said to have done is keep the substantive half of its substitution
discipline — no achieved rate promoted to a capability, no third-party benchmark presented as this
design's guest, no parameter FIXED, every figure labelled on the README ladder — and to have
**falsified one deployed-pipeline claim**: "the deployed pipeline cannot
sustain proofs as fast as proposals" is false for today's demand (zero backlog; S1 §5 finding 2). That is
not a Phase B gate pass. The gate's own rule applies to this synthesis as much as to any other artifact:
**no placeholder becomes a value, and no unmeasured register row is closed by a bound.**

*(PB-L-09: the earlier sentence also claimed every figure was "reproducible from the raw evidence"; four
figures did not reproduce at the audited revision (PB-L-01/02/04/08) and one decomposition did not
reconcile (PB-L-03). The claim is now scoped to the discipline that does hold; each of those figures has
been re-derived with a saved artifact under `results/raw/`.)*
