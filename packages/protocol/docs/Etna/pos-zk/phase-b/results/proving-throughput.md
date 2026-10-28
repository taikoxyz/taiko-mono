# S1 — proving throughput and cost: what public data can establish

**Status: substitution report, not the S1 measurement.** Public-data stand-in for
[S1-proving-throughput.md](../S1-proving-throughput.md), executed 2026-10-07 (UTC) with no hardware and
no testnet. Every figure below carries an epistemic label; everything is reproducible from
`raw/s1-public-data/` (see [`commands.log`](raw/s1-public-data/commands.log) and the file inventory
in [`README.md`](raw/s1-public-data/README.md)).

**Read this first.** S1's gates (G-RATE, G-FLEET, G-BLOB, G-VALID) are defined over cycle counts and wall-clock
proof times produced by a pinned-guests harness on named hardware. None of that exists in public data. This report
therefore does **not** produce `b`, `C`, `R_gas`, or a pass/fail. It produces (i) measured, reproducible facts
about what the *deployed* Taiko system actually does, (ii) third-party published throughput/cost figures for
general-purpose zkVMs with hardware named, and (iii) an explicit list of what remains unanswerable — so that no
placeholder is filled by analogy.

---

## 1. Scope and question

S1 asks, for a frozen K-block L2 workload and pinned zkVM versions:

| # | Quantity | Symbol | S1's unit |
|---|---|---|---|
| 1 | zkVM cycles per L2 gas | `C` | cycles/gas |
| 2 | billed L1 data bytes per L2 gas (and payload bytes) | `b_billed`, `b_payload` | bytes/gas |
| 3 | proven gas per second **per machine** | `R_gas` | gas/s/machine |
| 4 | whether the L2 is DA-limited or proving-limited | — | verdict |

This substitution re-asks those four questions against public data only:

- **Q1 (cadence):** how often does the deployed Taiko inbox actually propose and prove, and how long does a batch
  take from proposal to proof? → yields an **achieved** system throughput, a lower bound on deployed behaviour,
  *never* a per-machine capability.
- **Q2 (third-party benchmarks):** what proving throughput and cost have credible public sources reported for
  general-purpose zkVMs capable of Ethereum-execution proofs, on what hardware, for what workload?
- **Q3 (Taiko-published data):** what has Taiko itself published about proving time, limits and cost?

Adapting the assignment's own framing: S1 is the spike where public data substitutes **least** well, because
`C` and `R_gas` are properties of *one guest binary on one machine class*, and neither is observable from a
chain, a dashboard or a blog. The substitution is honest only if that is stated up front — it is.

---

## 2. Sources and method

| Source | Type | What was taken | Coverage / retrieval |
|---|---|---|---|
| Taiko Shasta Inbox `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f` on Ethereum L1 | on-chain (archive logs via `https://gateway.tenderly.co/public/mainnet`) | `Proposed` / `Proved` events, blob counts, timestamps | L1 blocks 24,585,332–26,140,717 = 2026-03-04T16:36:47Z – 2026-10-07T13:09:59Z; 48,716 logs; fetched 2026-10-07T13:16:22Z |
| Taiko L2 `https://rpc.taiko.xyz` | on-chain | block gas, block time, raw transaction bytes | L2 blocks 11,072,005–12,368,005 = 2026-09-07T05:10:33Z – 2026-10-07T13:18:17Z |
| Blockscout REST `https://eth.blockscout.com/api/v2/blocks/<n>` | third-party indexer (used only as an independent cross-check of timestamps) | block timestamps | 401 blocks; 401/401 identical to the on-chain logs |
| ethproofs.org dashboard (public pages; API requires a key) | third-party dashboard of **team-submitted** proving measurements | per-proof proving time, proving cycles, hardware description, cost | proof records created 2026-10-07T12:26:38Z – 13:16:28Z (a 50-minute window); retrieved 2026-10-07T13:16Z |
| Succinct blog (2025-11-18, 2025-12-18) | vendor claim | SP1 Hypercube real-time proving on 16× RTX 5090 | stated workload: 954 L1 blocks in 23,807,739–23,812,008 |
| a16z crypto blog (2026-09-09), Lattice Jolt | vendor claim | Jolt proving rates in RV64IMAC cycles/s | laptop / MacBook Metal, no gas metric |
| docs.taiko.xyz (Unzen/Shasta pages) | first-party published parameters | proving window, `BLOCK_ZK_GAS_LIMIT` | live docs retrieved 2026-10-07 |
| `packages/protocol/docs/zk_gas_spec.md` (this repo) | first-party published model | `BLOCK_ZK_GAS_LIMIT` rationale, zk-gas multipliers | Appendix B/C |
| ethresear.ch "Measuring Per-Opcode Proving Time" (2026-01-27), Nethermind Research, **funded by Taiko** | third-party study (Taiko-funded) | SP1 v5.2.3 / risc0 v3.0.4 on 4× RTX 4090 per-opcode proving time | qualitative conclusions extracted; numeric tables are images |
| Boundless blog (2026-01-06) | vendor commentary | production-cost framing; no per-proof numbers | cited for context only |

**Method notes that matter for re-checking.**

1. **Timestamps.** No separate timestamp fetching was needed for cadence: the archive endpoint returns a
   `blockTimestamp` field on every log. It was validated against an independent source (Blockscout REST) on
   401 event blocks: **401/401 identical**. L1 spacing within the window is always an integer multiple of 12 s
   (median 12.000 s/block) but intervals of 24 s occur, i.e. slots are genuinely missed, so timestamps are
   *measured*, never interpolated from block numbers.
2. **Blob counts** are decoded from the `Proposed` event's `DerivationSource[].blobSlice.blobHashes` array
   length — not inferred from the transaction.
3. **Payload bytes** for L2 blocks are computed from `eth_getRawTransactionByBlockNumberAndIndex` (exact raw
   transaction bytes) and the PRF-07(0) framing: `frame(h) = be32(len(body_h)) || body_h`, with `body_h` the RLP
   list of the block's transactions, RLP header included. Anchor transactions
   (`to = 0x1670000000000000000000000000000000010001`) are separated using `eth_getBlockReceipts`.
4. **Rate limits.** Public endpoints rate-limit aggressively (403/429 on batched archive requests). One 200k-block
   log span worked in ~6 s; batched block fetches did not survive at >50 calls/1.5 s. All figures below come from
   the successful runs recorded in `commands.log`; failed probe attempts (empty files, `.err` logs) were left in
   place and are not used.

---

## 3. Findings

### 3.1 Live cadence of the deployed Shasta inbox — [on-chain measured]

Command: `python3 fetch_inbox_logs.py … ` then `python3 analyze_cadence.py` (output: `cadence_analysis.txt`).

| Figure | Last 30 days | Last 7 days | Since Unzen (65 d) | Whole deployment (188 d) |
|---|---|---|---|---|
| window | 2026-09-07T13:11:35Z → 2026-10-07T13:09:59Z | 2026-09-30T13:15:47Z → head | 2026-08-03T12:50:11Z → head | 2026-04-02T13:18:23Z → head |
| proposals | 6,713 (223.8/day) | 1,575 (225.1/day) | 14,589 (224.4/day) | 40,474 (215.3/day) |
| proofs | 1,345 (44.8/day) | 316 (45.2/day) | 2,922 (44.9/day) | 8,224 (43.7/day) |
| proposal interval p50 | **384 s** | 384 s | 384 s | 384 s |
| proof interval p50 | **1,932 s** | 1,932 s | 1,920 s | 1,920 s |
| proposals / proof (p50, max) | 5, 5 | 5, 5 | 5, 5 | 5, 10 |
| proposals never proven at head | 2 (ids 40,472–40,473, i.e. the newest) | 2 | 2 | 3 |

Reading: the live inbox proposes one proposal every **32 L1 blocks (384 s)** and proves one batch of **exactly
5 proposals every ~32 minutes**. The proof pipeline is *keeping up*: only the two newest proposals are pending.

### 3.2 Proposal → proof latency — [on-chain measured]

Same command/output. Latency is measured per proof; "all covered" is the per-proposal latency over every proposal
in the proof's range (so it is the distribution a proposal actually experiences).

| Latency (s) | p50 | p90 | p95 | max | mean |
|---|---|---|---|---|---|
| last covered proposal → proof (30 d) | **684** | 1,896 | 2,580 | 6,972 | 925 |
| first newly covered proposal → proof (30 d) | 2,220 | 3,444 | 4,104 | 8,520 | 2,468 |
| all covered proposals → proof (30 d) | 1,560 | 2,832 | 3,468 | 8,520 | 1,695 |
| last covered proposal → proof (whole 188 d) | 468 | 1,464 | 2,316 | 676,884 | 1,995 |

This is **system-level end-to-end latency**: it contains batching policy, queueing, retries and L1 inclusion.
It is **not** `T_proof` in S1's sense (witness-ready → receipt) and must not be used as one.

### 3.3 Batch composition — [on-chain measured]

Command: `python3 decode_events.py`.

- Blobs per proposal over the whole deployment: **1 blob in 40,465 of 40,474 proposals (99.98%)**, 2 blobs in 4,
  4 blobs in 2, 5 blobs in 2, 0 in the genesis proposal.
- A proof covers 5 proposals in the steady state (30-day window: p50 = p90 = p95 = 5, max = 5, min = 1 for the
  newest in-flight batch), i.e. **~5 blobs per proof**.
- Live L2 blocks per proposal: 384 s of L2 at a measured 2.023 s block time ≈ **190 L2 blocks**.

### 3.4 What the live L2 actually produces — [on-chain measured]

Commands: `sample_l2.py` (every 100th L2 block, 30 days, n = 12,961) then `analyze_l2_sample.py`,
`derive_live_rates.py`.

| Figure | Value | Note |
|---|---|---|
| L2 block time | **2.023 s** mean (mode 2.000 s) | sample spacing exactly 200 s per 100 blocks |
| gas per block | mean **122,318**, median **112,068**, max 2,311,140 | gas limit constant 46,000,000 |
| blocks that are anchor-only | **72.6%** at exactly 112,068 gas; **90.9%** at 112,068 or 112,056 gas; **94.07%** carry exactly one transaction | 5.93% of blocks carry > 1 tx |
| achieved L2 gas rate | **60,476 gas/s** (0.0605 Mgas/s) | = window-mean gas/block ÷ measured block time |
| L2 gas per proposal | **23.2 Mgas** at the 384 s interval; 23.35 Mgas at the 30-day mean interval | = 60,476 gas/s × 384 s = 23.22 Mgas; §3.5's `b_billed` divisor uses 23.35 Mgas = 60,476 × 386.2 s (the mean proposal interval from `derive_live_rates.py`) |
| L2 gas per proof | ~117 Mgas | = gas/s × 1,932 s |

*PB-L-15: the per-proposal row read "23.3 Mgas = gas/s × 384 s", but 60,476 × 384 = 23.22 Mgas, which
rounds to 23.2; 23.35 is the figure from the 30-day **mean** proposal interval (386.2 s) that §3.5's
`b_billed` divisor actually uses. Both are now stated with their own interval. `G_L2_TARGET` stays
11.6–11.7 Mgas/s and the "0.52 % of the DA bound" conclusion is unaffected.*

*PB-AR-08: the row's parenthetical definition (== 112,068 gas) is exact but reads as the whole near-empty
regime. `l2_sample_30d.jsonl` (n = 12,961) has 9,407 blocks at 112,068 (72.58%) and 2,372 at 112,056 (18.30%)
— 11,779 = 90.88% at one of the two single-anchor gas values — and 12,193 = 94.07% of blocks carry exactly
one transaction. The blended `b_payload` is a byte/gas ratio and is unaffected; the workload-sensitivity
caveat's direction is right but its magnitude was understated by ~20 points. Re-derived in
[`anchor_only_share.py`](./raw/s1-public-data/anchor_only_share.py) → [`anchor-only-share.json`](./raw/s1-public-data/anchor-only-share.json).*

### 3.5 Bytes per L2 gas on live data — [on-chain measured] / [derived]

PRF-07(0) framing measured on a contiguous recent window (422 L2 blocks, 12,367,506–12,367,927; 383 of them
anchor-only, 90.8 % — `python3 anchor_only_recount.py`; *PB-L-12: the count read 386 and did not
reproduce from the cited file — the rest of this section's figures do*):

| Figure | Value | Basis |
|---|---|---|
| frame size `4 + len(RLP tx list)` | mean 278.4 B, median 218 B, max 2,068 B | raw transaction bytes |
| gas per block in the same window | mean 134,344, median 112,068 | same blocks |
| **`b_payload` (live workload)** | **0.00207 B/gas** mean (0.00195 median-of-blocks) | frame bytes ÷ gas |
| **`b_billed` (live, blob-quantised)** | **0.00561 B/gas** | 131,072 B ÷ 23.35 Mgas per proposal (the 30-day mean interval, 386.2 s; the 384 s p50 interval would give 23.22 Mgas and 0.00564 B/gas) |
| implied `G_L2_TARGET = 65,536 / b_billed` | **11.68 Mgas/s** | S1 §1 formula, live b |
| achieved ÷ that bound | **0.52%** | 60,476 gas/s ÷ 11.68 Mgas/s |

Marginal view over blocks that carry real user transactions (the 200 busy blocks measured, from the 768 that the
30-day sample contains; coverage 2026-09-07T05:10:33Z – 2026-09-16T07:11:35Z, i.e. the first ~9 days of the
window; anchor transaction and its gas excluded) — [on-chain measured, small sample]:

| Figure | mean | median | p10 | p90 |
|---|---|---|---|---|
| `b_payload(user)` = user tx bytes ÷ user gas | **0.00804** | 0.00745 | 0.00325 | 0.01070 |
| `b_payload` over the whole block (anchor included) | 0.00451 | — | — | — |

Three caveats stop these from being S1's `b`: (i) the near-empty regime dominates (94.07% of L2 blocks carry exactly one
transaction and 90.88% sit at one of the two anchor-only gas values, 112,068 or 112,056 — PB-AR-08), so the blended figure is 0.0021 while the marginal user figure is ~0.0074–0.0080 — **the
spread of that pair is itself the workload sensitivity the S1 spec requires to be measured, and it is not
resolved here**; (ii) the busy sample covers 9 of 30 days and only 200 of the 768 busy blocks (the window-spread
re-sample was abandoned when the L2 RPC began rate-limiting; the partial file is kept as
`l2_payload_busy_spread.partial.jsonl`); (iii) the live blob contains Taiko's own manifest encoding, not the
PRF-07 canonical payload — the 131,072 B is real billed bytes, while the framing above is recomputed per the spec.

### 3.6 Is the live L2 DA-limited or proving-limited? — [on-chain measured] for today's system; [not establishable from public data] for the design point

- Today the deployed L2 runs at **60.5 kgas/s**, which is **0.52%** of the DA-bound rate implied by its own measured
  `b_billed` (11.68 Mgas/s), and the proof pipeline has no backlog. So the deployed system is **neither
  DA-limited nor proving-limited: it is demand-limited** — an honest answer that is different from both options
  S1 offers, and only obtainable because public data shows *achieved* not *capacity* rates.
- Since `b` is unknown for the design workload, the DA-bound rate at the design point is unknown too
  (it is 65,536/b; at the spec's illustrative b = 0.006 it would be 10.9 Mgas/s). Whether the *design point* is
  DA-limited or proving-limited **cannot be determined from public data** (see §4).

### 3.7 Structural consequence for K and one-transaction batches — [derived]

At the DA-bound rate (65,536 B/s, S1 §1 — the design's own baseline, unchanged), the live 384 s proposal span
would produce 65,536 × 384 = **25,165,824 B = 192 blobs**. With the measured BPO2 maximum of 21 blobs per L1
block, publishing that in one transaction is impossible; it needs ≥ 10 L1 blocks of blob capacity
(ceil(192/21) = 10). Equivalently, at the DA-bound rate one `land` transaction (≤ 21 blobs = 2,752,512 B) can
carry at most 42 s of L2 data = **K ≤ 21 two-second L2 blocks**, 14 (the BPO2 target) being the design's chosen
planning length and 21 the hard edge. The deployed system runs K ≈ 190 — far outside what the DA-bound rate
permits in one transaction — which is only possible because it runs at 0.5% of the DA bound. This is a
measured-input confirmation of S1 §4.4, not a new bound. *(Re-based: the 9-blob ceiling, the K ≤ 9 / 18 s figures
and the ≥ 22 L1 blocks figure were the superseded EIP-7691 set, stale by two forks; the measured BPO2 set is
target 14 / max 21 / base-fee update fraction 11,684,671 (S4 F6 = [blob-binding.md](./blob-binding.md) §3), and
the design baseline rates — 65,536 B/s, 786,432 B per 12 s, one 131,072 B blob per 2 s L2 block — are unchanged.)*

### 3.8 Third-party proving throughput on named hardware (ethproofs.org) — [third-party reported]

ethproofs.org is a third-party dashboard whose numbers are **submitted by the proving teams** under the site's
"race to mainnet" framework; the API needs a key, so the figures were extracted from the public pages' embedded
data (files in `thirdparty/`). Window: proof records created **2026-10-07T12:26:38Z – 13:16:28Z** (50 min), 108
records over 40 distinct L1 Ethereum blocks (the 105 records with complete gas + time + cycles cover 37
of them, which is the subset the table below uses); gas for those blocks measured on-chain by us
(`thirdparty/ethproofs_stats.py`). Workload = **single L1 Ethereum blocks** (gas 4.2–51.3 Mgas, median 27.8 Mgas),
not Taiko L2 batches.

| cluster (prover) | hardware (as published) | n | median s/proof | median cycles/gas | median gas/s |
|---|---|---|---|---|---|
| Axiom (OpenVM 2.1, revm) | 16× NVIDIA 5090 | 20 | 2.24 | 6.50 | **12,644,434** |
| Airbender v3 (Matter Labs) | 4× 5090 | 20 | 2.43 | 7.13 | 11,420,014 |
| Zisk | 8× 5090 | 20 | 3.45 | 2.37 | 7,998,628 |
| Airbender v3 | 2× 5090 | 20 | 3.97 | 7.13 | 7,019,664 |
| ZisK | 2× 5090 (+Threadripper PRO 9965WX) | 2 | 6.33 | 2.46 | 3,905,463 |
| Zilkworm Airbender | 2× RTX 5090 (on-prem node) | 2 | 8.71 | 11.37 | 2,844,709 |
| ZKM | not published | 14 | 16.52 | 7.70 | 1,763,962 |
| Succinct Twin Peaks (SP1) | 2× RTX 5090 | 2 | 23.55 | 12.95 | 1,050,898 |
| Pico (Brevis) | 2× RTX 5090 | 2 | 25.85 | 14.91 | 957,646 |
| cysic | RTX 4090 + EPYC 7773X | 3 | 93.57 | 11.62 | 344,774 |

*PB-L-01: the range quoted from this table earlier read "3.4–12.6 Mgas/s on 4–16× RTX 5090 clusters". The
eight 5090 cluster medians are 0.958–12.644 Mgas/s (ZisK 2× is the 3.905 nearest to 3.4) and four of the
eight clusters are 2×, so the cluster-size span is 2–16×. Re-derived from the cited raw file by
[`thirdparty/ethproofs_5090_medians.py`](./raw/s1-public-data/thirdparty/ethproofs_5090_medians.py).*
*(PB-L-08, Low class: the paragraph above this table read "108 records covering 37 distinct L1 Ethereum
blocks"; the saved file holds 108 records over 40 distinct blocks, and 37 is the distinct-block count of
the 105-record complete subset the table uses. Corrected in place; the quoted 4.2–51.3 Mgas gas range and
27.8 Mgas median are those of the same 105 records and stand.)*

Two observations that bear directly on S1's metric design:

- **cycles/gas is not comparable across provers.** For the *same* L1 block, reported proving cycles differ by up to
  ~5× between teams (e.g. 2.37 for Zisk vs 12.95 for SP1 on the same workload class); gas/s is the comparable
  quantity. S1's plan to compare `C` across RISC Zero and SP1 is therefore only meaningful *within* a backend
  (and with a fixed SDK), exactly as S1 §3.2's SDK-match rule says.
- Cost per proof is also published on the same site for the same clusters (e.g. $0.0016–$0.0105 per L1-block proof
  for the 5090 clusters in this window); it is **not** converted here into ETH per L2 gas because it depends on a
  GPU price index and a proving-market model that is out of scope for S1 (it is S3's input).

### 3.9 Other named third-party figures

| Source | Claim | Hardware / workload | Label |
|---|---|---|---|
| Succinct blog, 2025-11-18 (and 2025-12-18) | "proves 99.7% of L1 Ethereum blocks under 12 s, 95.4% under 10 s"; cluster buildable for < $100,000 | **16× NVIDIA RTX 5090**, random 954 L1 blocks 23,807,739–23,812,008 | [third-party reported — vendor self-reported, no independent replication] |
| derived from the above + our gas sample | ≥ **1.30 Mgas/s per cluster**, ≥ **0.081 Mgas/s per GPU** | 25 sampled blocks of the stated range: median 15.64 Mgas, mean 19.47 Mgas; "under 12 s" is an upper bound, so this is a lower bound | [bounded — assumes the sampled gas mix represents the 954 blocks and that 12 s is attainable in production] |
| a16z crypto, 2026-09-09 (Lattice Jolt) | "over 2 million RV64IMAC cycles/s" CPU-only; "over 10 million RV64IMAC cycles/s" with Metal; curve-based Jolt ~4M cycles/s on Metal | a laptop / MacBook, model not stated; **no gas metric, no Ethereum workload** | [third-party reported — vendor claim; not convertible to gas/s] |
| Boundless, 2026-01-06 | production proving economics; "GPU hardware alone can exceed $6.5M" for Base-scale throughput; warns benchmarks "reflect the cost of generating a single proof under ideal conditions" | no per-proof numbers | [third-party reported — commentary, no measurement] |

*(PB-AR-09: the three rows above are the report's only [third-party reported] figures with no retained source — `raw/s1-public-data/thirdparty/` holds no snapshot of the Succinct, a16z/Lattice-Jolt or Boundless pages, so their numbers are not re-checkable from the raw evidence. The ethproofs.org pages and the Nethermind/Taiko-funded study **are** archived there. A [`commands.log`](./raw/s1-public-data/commands.log) now exists; it is reconstructed at review time from the collectors' recorded `command` fields and each script's usage string.)*

### 3.10 Taiko's own published proving data — [first-party published]

| Figure | Value | Where |
|---|---|---|
| Proving window (proof "late" after this) | **4 hours** | docs.taiko.xyz (Unzen reference table) |
| Max proof submission delay | 3 minutes | same table |
| `BLOCK_ZK_GAS_LIMIT` | **100,000,000 zk gas per L2 block** ("initial value … a placeholder derived from the following model") | `docs.taiko.xyz`; `packages/protocol/docs/zk_gas_spec.md` Appendix C |
| Model behind it | 4× GPUs, 1-second L2 blocks, 384 blocks/proposal, ~12 h deadline → 43.2B zk gas ⇒ 112.5M/block, rounded down | Appendix C |
| ⇒ implied rate in *that model* | 43.2e9 zk gas / 43,200 s = **1.0M zk gas/s on 4 GPUs** (0.25M/GPU) | [derived] from the published model — **not a measurement**, and zk gas ≠ EVM gas |
| zk-gas multipliers (relative proving cost) | point_evaluation 859×, bls12_pairing 365×, blake2f 166×, modexp 154×, mulmod 113× … keccak256 31×, add 19×, push1 9× | zk_gas_spec.md Appendix B/C; derived from the Nethermind study below |
| Liveness bond in force | **0** ("effectively dormant today") | docs.taiko.xyz — relevant to why proofs may lag without penalty |

**Taiko-funded third-party measurement** — [third-party reported, Taiko-funded]: Lin Oshitani (Nethermind
Research), *Measuring Per-Opcode Proving Time*, ethresear.ch, 2026-01-27, funded by Taiko. Setup: **sp1-v5.2.3
(sp1-cluster) and risc0-v3.0.4**, **4× NVIDIA RTX 4090**, reth-v1.9.3. It measures marginal proving time per gas
per opcode/precompile and concludes that **cycles are not a universal proxy for proving time**: within one
operation the fit is linear (high R²), but time-per-cycle "spreads widely" across operations because different
operations use different circuits/precompiles. Its numeric tables are images, so no numbers are quoted here.

---

## 4. What public data CANNOT establish here

Each item names the S1 metric it blocks. None of these is filled with an estimate.

1. **`C` — cycles per L2 gas for Taiko's exact guest.** No public source reports cycles for the pinned Raiko
   guest (raiko2 v0.8.0-rc1) on Taiko L2 blocks. The closest public numbers are other guests on other chains
   (§3.8), and §3.8 shows why they do not transfer: cycles/gas varies ~5× across zkVM implementations for the
   same workload. Blocks S1 §5 (M5, M6), PARAM-03, LIVE-03's rate inequality.
2. **`R_gas` — proven gas/s per machine for Taiko's guest and a named machine class.** Three compounding gaps:
   (a) no Taiko-guest measurement exists publicly; (b) the ethproofs numbers are for *other* guests and *L1* blocks
   (median 27.8 Mgas single-block proofs, not K-block batches); (c) no public source states how many machines the
   live Taiko proofs were produced on, or their utilisation, so the achieved 60.5 kgas/s cannot be divided by a
   machine count. Blocks M11 (R_gas), G-RATE, G-FLEET, LIVE-03(i).
3. **The DA-limited vs proving-limited verdict at the design point.** Both sides of the comparison are unknown for
   the design workload: `b_billed` is workload-dependent, and the proving bound needs `R_gas`. What *is*
   established is that the deployed system is demand-limited (§3.6), which does not answer S1's question.
   Blocks the §2 decision and DR-1's input.
4. **In-guest blob evaluation cost** (M8/M9, PARAM-03 open item F2): nothing public.
5. **`T_proof` distribution by K ∈ {8, 32, 128} and the wrapped-proof cost** (M10, M13, proof modes): nothing public.
   The measured 684 s p50 in §3.2 is end-to-end and includes batching/queueing; it is not a per-K measurement.
6. **Workload sensitivity of `b`** (S1 §4.1's mandatory add-on): the live L2 is ~73% anchor-only blocks, so the
   measured `b_payload`/`b_billed` characterise one (empty) mix only.
7. **Peak memory, machine price, and fleet sizing inputs** (M12, M14; `N_MAX`, `B_fleet`): public data gives
   neither VRAM/RSS envelopes for Taiko's guest nor a dated price for a *named* machine class tied to a measured
   `R_gas`.
8. **The concurrency term `N_conc = T_proof/(2K)`** (LIVE-03(ii)): needs per-proof latency on the frozen workload and
   the design K, neither of which exists publicly.

**What would establish them.** The list is short and specific, which is the point of this spike:
- **For `C`, `R_gas`, `b`, and the DA/proving verdict:** the S1 harness itself — pinned RISC Zero v3.0.6 and
  SP1 v6.8.1 guests, the frozen ≥ 4,096-block Taiko L2 range, K ∈ {8, 32, 128}, on the pre-registered GPU class —
  i.e. the measurement this report substitutes for.
- **For a cheap interim bound only:** run *one* cell (K = 32, E and E+C+B, unwrapped) on *one* backend on one
  pre-registered GPU node, and report `C` and `R_gas` with the caveat that one cell cannot carry the gate.
- **For an independent check of `C`:** a third party repeating the same guest on a second machine class — worth
  doing precisely because §3.8 shows reported cycles are not portable across implementations.

---

## 5. What this changes in the specification

| # | Finding (label) | Parameter / rule it bears on | Sufficient to fix it, or only to bound it? |
|---|---|---|---|
| 1 | Live `b_payload` 0.00207 B/gas blended, 0.00745–0.00804 B/gas marginal on user traffic; `b_billed` 0.00561 B/gas [on-chain measured] | `b` (register row b), `G_L2_TARGET` | **Bound only.** These are real billed bytes per real L2 gas, but for the live workload and Taiko's manifest encoding, not PRF-07 at the design workload. They bracket the spec's illustrative values: the blended (near-empty) ratio is 0.0021, the marginal user ratio ~0.0075–0.0080 against illustrative b = 0.006, and the blob-quantised ratio 0.0056 against illustrative 0.006/0.02 — so b = 0.02 looks unlikely for this mix and b ≈ 0.006 looks plausible, but the mandatory workload-sensitivity add-on is not satisfied by public data. |
| 2 | Achieved L2 rate 60,476 gas/s; backlog ≈ 0; 1 proof / 32 min [on-chain measured] | `BATCH_BLOCKS` (K), pipeline depth, `LIVE-03`(i)-(ii) | **Bound only, and only as a lower bound on what the deployed pipeline sustains.** It is system-level and demand-limited; it says nothing about the fleet's capacity. It does, however, falsify "the deployed pipeline cannot sustain proofs as fast as proposals" for today's demand. |
| 3 | p50 last-covered → proof 684 s, p95 2,580 s (30 d) [on-chain measured] | evidence for `T_PROOF_MAX_PERMITTED`; S1 §8's latency-distribution requirement | **Bound only.** It is an end-to-end system latency on a live workload, not `T_proof` at K ∈ {8,32,128}; the spec's 4-hour proving window (docs) is ~4× the measured p95, which is consistent but not evidence of capacity. |
| 4 | 1 blob per proposal; ~5 blobs per proof [on-chain measured]; 384 s span ⇒ 192 blobs at the DA-bound rate, i.e. K ≤ 21 per land-tx [derived] | §4.4 publishability bound, K, `MAX_BATCH_BLOCKS`, LIVE-03(iii) | **Sufficient to confirm the existing bound, not to set K.** The measured live numbers reproduce S1 §4.4's claim (blobCount ≤ K; K > 21 unpublishable in one transaction at the DA-bound rate) and show the deployed K ≈ 190 is only viable at 0.5% of the DA bound. *(Re-based to the measured BPO2 per-transaction maximum of 21 blobs — target 14 / max 21 / update fraction 11,684,671, S4 F6; 14 is the design's chosen planning length and 21 the hard edge.)* |
| 5 | ethproofs: 0.96–12.64 Mgas/s across 2–16× RTX 5090 cluster medians (eight 5090 clusters; record-level 0.94–16.20) on 4.2–51.3 Mgas L1 blocks; cycles/gas spreads 2.4–14.9 across teams [third-party reported] | `R_gas` (M11), fleet sizing, and S1's cross-backend comparison of `C` | **Bound only, on the optimistic side.** It bounds what a *different* guest on *named* hardware achieves; it is evidence that a fleet of a few such machines would exceed today's 0.06 Mgas/s demand, not evidence about Raiko's guest. The cycles spread is a **negative finding for the metric design**: `C` must not be compared across backends. |
| 6 | Succinct 16× RTX 5090, 99.7% of L1 blocks < 12 s ⇒ ≥ 1.30 Mgas/s per cluster [third-party reported + derived] | `R_gas`, fleet sizing | **Bound only** (vendor claim, different chain, single-block workload, no independent replication). |
| 7 | Taiko's `BLOCK_ZK_GAS_LIMIT` = 100M is a placeholder from a 4-GPU/12-h budget model ⇒ 1.0M zk gas/s on 4 GPUs; liveness bond = 0 [first-party published] | `BLOCK_ZK_GAS_LIMIT`, K, D-8 bond sizing | **Neither fixed nor newly bounded — but it names the placeholder's own assumption.** The model's implied 0.25M zk gas/s/GPU is the number S1 was meant to replace with a measurement; until then the spec should cite it as an assumption, not a measurement. |
| 8 | Nethermind/Taiko-funded study: cycles are not a linear proxy for proving time across operations [third-party reported, Taiko-funded] | `C` (M6), zk-gas metering | **Bound on interpretation: do not treat `C` as a proxy for `T_proof`.** It supports keeping both a cycle metric and a wall-clock metric, as S1 §5 already does. |
| 9 | Deployed system is neither DA- nor proving-limited but demand-limited (0.52% of its implied DA bound) [on-chain measured] | the §8.3 decision's premise, `G_L2_TARGET` | **Fixes nothing**: the spec's decision is about the *design* rate, not today's. It does mean no operational evidence exists either way, so the §8.3 choice must still be made on the S1 measurement. |

**Nothing in this report promotes a placeholder to a value, and no S1 gate is passed or failed here.**

---

## 6. Files

Raw evidence, scripts and per-file provenance: [`raw/s1-public-data/`](raw/s1-public-data/) —
inventory in [`README.md`](raw/s1-public-data/README.md), the reproduction commands in
[`commands.log`](raw/s1-public-data/commands.log) (reconstructed at review time from the collectors' recorded `command` fields and the scripts' usage strings — PB-AR-09). Primary artifacts:
`cadence_analysis.txt`, `proposed_events.csv`, `proved_events.csv`, `logs/inbox_logs_full.jsonl.gz`,
`l2_sample_30d.jsonl`, `l2_payload_500.jsonl`, `l2_payload_busy.jsonl`, `thirdparty/`.
