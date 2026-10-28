# S2 (public-data substitution) - round timing and the 2 s cadence (D1)

**Spike:** S2 - round timing at the target validator count (./S2-round-timing.md) - **Report version:** v1 (public-data substitution)
**Date (UTC):** 2026-10-07, 13:50Z - **Author:** S2 public-data collector (delegated subagent) - **Kind:** substitution report, NOT the S2 measurement
**Raw evidence:** ./raw/s2-public-data/ (COMMANDS.md, SOURCES.md, HASHES.txt, fetch/analysis scripts, all fetched JSON/CSV, per-file coverage logs)

**Scope statement, stated once and meant throughout.** There is no hardware and no testnet.
Nothing in this report is a measurement of a consensus round at n = 50 / 100 / 200, with or
without faults. No validator set was run. What follows is a **timing budget** built from
(a) live on-chain cadences of the shipped Taiko and Ethereum systems, and (b) reputable
published measurements of Tendermint/CometBFT-class engines. Where the question cannot be
answered this way, the row says so and is not filled with an estimate.

## 1. Scope and question

S2 is specified to measure round completion, block-interval and view-change behaviour of a
stock CometBFT-class engine at n = 50 / 100 / 200 across cloud regions, with and without
injected faults, and to derive TIMEOUT_MIN / TIMEOUT_MAX, Delta_max and X_max
(CONS-07(2)); it fills the PARAM-03 row "Round completion time at 2 s with a permissionless
global set".

Public data cannot run that experiment. It can answer these four substitute questions:

1. **Quantisation.** Every step anchored to Ethereum L1 is quantised by the L1 slot clock.
   What is the L1 block-interval distribution (mean, median, tail) over a stated recent window?
2. **Shipped cadences.** What cadence does Taiko's own system actually run today: L2 blocks,
   L1 proposals, and proof/attestation intervals?
3. **Comparable engines.** What do published measurements and live production CometBFT-class
   networks achieve at validator counts in and near 50-200?
4. **The bound.** What does that jointly bound for D1's 2 s cadence, and what remains open
   for the real S2?

## 2. Sources and method

| ID | Source | What it gives | Label |
|---|---|---|---|
| S-1/S-2 | Ethereum mainnet via rpc.mevblocker.io, cross-checked with ethereum-rpc.publicnode.com | 20,000 L1 headers (two providers) | [on-chain measured] |
| S-3 | Taiko mainnet L2 via rpc.taiko.xyz (chain id 167000) | 20,000 L2 headers | [on-chain measured] |
| S-4/S-5 | Taiko Shasta Inbox (L1 0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f) logs via the Tenderly archive gateway + headers for those blocks via mevblocker | 1,581 Proposed, 317 Proved over 7 days | [on-chain measured] |
| S-6/S-7/S-8 | Cosmos Hub, Celestia, dYdX Chain production RPCs | 1,000-block cadence samples at n = 180 / 95 / 21 | [on-chain measured, third-party network] |
| S-9 | Cason et al., SRDS 2021, "The design, architecture and performance of the Tendermint Blockchain Network" | controlled latency/throughput at n = 16/32/64/128, plus crash and Byzantine faults | [third-party reported] |
| S-10 | Senn & Cachin, CCS 2026 artifact + raw data (cryptobern/tenderload, tag ccs26) | baseline CometBFT throughput on 49 VMs, n = 28/49 | [third-party reported] |
| S-11 | cometbft/cometbft repository | negative result: no published latency benchmark table | [bounded] |
| S-12/S-13 | Taiko docs "Preconfirmations"; taiko-mono issue #20044 | the stated preconf block-time target range | [sourced - vendor documentation] |

Method notes.

- Every figure below is reproducible from **COMMANDS.md** in the raw directory; every fetch
  wrote a timestamped **&lt;file&gt;.meta.txt** recording each request's block range and time.
- Percentiles are nearest-rank (index = ceil(p/100 x N) - 1) and the sample count n is printed
  with every percentile. No p99 is quoted from fewer than 300 samples; p99.9 is quoted only
  where n &gt;= 1,000 (all rows here satisfy that except where stated).
- Times are UTC. L1/L2/inbox windows are **header-timestamp (chain) windows**, not wall-clock
  fetch windows; the fetch time of each file is in its meta log.
- Cross-check: 10,556 blocks were fetched from two independent L1 providers; **0 timestamp
  mismatches** (S-1 vs S-2).
- The L2 cadence window (11.11 h) is a sub-window of the 7-day window used for the L1
  proposal/proof cadences: 20,000 L2 blocks at 2 s cover 11.1 h, and a 7-day L2 sample would
  have required ~302,400 L2 blocks.
- The CometBFT-class production samples are **not** a controlled experiment: each chain runs
  its own commit-wait configuration, geography, load and hardware. They are reported as
  observations, never as a scaling law.

## 3. Findings

### F1 - Ethereum L1 block-interval distribution (the quantisation clock)

Command: python3 fetch_rpc.py blocks https://rpc.mevblocker.io 26120733 26140732 l1_blocks_mevblocker.jsonl --batch=500, then
python3 analyze.py blocks l1_blocks_mevblocker.jsonl l1_blocks.
Coverage: blocks 26,120,733-26,140,732, i.e. 2026-10-04T18:17:59Z to 2026-10-07T13:12:59Z
(66.92 h); fetched 2026-10-07T13:24:19-13:25:48Z. Label: **[on-chain measured]**.

| n | min | mean | p50 | p90 | p95 | p99 | p99.9 | max |
|---|---|---|---|---|---|---|---|---|
| 19,999 | 12.000 s | 12.046 s | 12.000 s | 12.000 s | 12.000 s | 12.000 s | 24.000 s | 36.000 s |

Interval histogram: 12 s x 19,924 (99.625%); 24 s x 74 (0.370%, one missed slot);
36 s x 1 (0.005%, two consecutive missed slots). Observed opportunity-gap tail: a step that
must wait for an L1 block has a p99.9 gap of 24 s and a maximum of 36 s in this window.

Cross-provider check (S-2): the same range fetched from ethereum-rpc.publicnode.com for the
10,556-block overlap gave identical timestamps for every block.

### F2 - Taiko mainnet L2 shipped cadence (2 s, exactly)

Command: python3 fetch_rpc.py blocks https://rpc.taiko.xyz 12347771 12367770 taiko_l2_blocks_12367770.jsonl --batch=50 --resume, then
python3 analyze.py blocks taiko_l2_blocks_12367770.jsonl taiko_l2.
Coverage: L2 blocks 12,347,771-12,367,770 = 2026-10-07T02:03:47Z to 13:10:27Z (11.11 h);
fetched 13:13:58-13:21:43Z. Label: **[on-chain measured]**.

| n | min | mean | p50 | p90 | p95 | p99 | p99.9 | max |
|---|---|---|---|---|---|---|---|---|
| 19,999 | 2.000 s | 2.000 s | 2.000 s | 2.000 s | 2.000 s | 2.000 s | 2.000 s | 4.000 s |

19,998 of 19,999 intervals are exactly 2.000 s; one is 4.000 s (99.995% at exactly 2 s).

Who produces it: over the same 20,000 blocks there are exactly **two distinct block
producers** (coinbase 0x35376d...8f06: 10,790 blocks; 0x5f62d0...9990: 9,210 blocks), and the
1,581 proposals in F3 come from the same two addresses. The 2 s cadence is therefore a
**permissioned two-preconfer cadence, not the output of a BFT committee**. The Taiko docs
(S-12) describe the preconfer's configured block time as "500 milliseconds to 2 seconds", and
issue #20044 (S-13) records the Shasta L2 block-time target as "2s" [sourced - vendor
documentation]. The shipped 2 s figure is consistent with D1, and is **not evidence** about a
50-200 validator set.

### F3 - Taiko Shasta L1 anchoring: proposal and proof cadences

Command: python3 fetch_rpc.py logs https://mainnet.gateway.tenderly.co 0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f 26090333 26140732 taiko_inbox_logs_7d.json --chunk=2000, then
fetch_rpc.py headers https://rpc.mevblocker.io inbox_log_heights.txt inbox_block_headers.json, then
python3 analyze.py inbox taiko_inbox_logs_7d.json inbox_block_headers.json.
Coverage: L1 blocks 26,090,333-26,140,732 (7 days). Proposals observed 2026-09-30T12:37:23Z to
2026-10-07T13:09:23Z; proposal ids 38,893-40,473. Label: **[on-chain measured]**.

| Quantity | n | min | mean | p50 | p90 | p95 | p99 | p99.9 | max |
|---|---|---|---|---|---|---|---|---|---|
| Proposal interval | 1,580 | 312 s | 384.0 s | 384 s | 384 s | 396 s | 396 s | 456 s | 468 s |
| Proved-event interval | 316 | 348 s | 1,918.6 s | 1,932 s | 2,052 s | 2,172 s | 2,508 s | 4,128 s | 4,128 s |
| Proof latency (proposal to Proved) | 1,579 | 564 s | 1,543.1 s | 1,488 s | 2,256 s | 2,400 s | 2,796 s | 4,596 s | 4,968 s |

1,273 of 1,580 proposal intervals (80.6%) are exactly 384 s = 32 L1 slots; the mode is the
cadence, and the tail is one or two slots of jitter. Exactly two proposer addresses appear.

Derived: at 384 s per proposal and 2 s per L2 block (F2), one proposal covers about
**192 L2 blocks** [derived from F2 and F3].

### F4 - Live production CometBFT-class chains (third-party networks)

Commands in COMMANDS.md section 4 (fetch_cometbft_chain.py / fetch_cometbft.py + analyze.py).
All three samples are 1,000 consecutive blocks (999 intervals), fetched 2026-10-07.
Label: **[on-chain measured, third-party network]**.

| Network | Bonded validators | Engine | Window (UTC) | mean | p50 | p99 | max |
|---|---|---|---|---|---|---|---|
| dYdX Chain | 21 | CometBFT 0.38.5 | 13:12:43-13:22:59Z | 0.616 s | 0.608 s | 0.884 s | 1.198 s |
| Celestia | 95 | CometBFT 0.38.17 | 12:47:04-13:34:48Z | 2.867 s | 2.867 s | 2.891 s | 3.145 s |
| Cosmos Hub | 180 | CometBFT 0.38.22 | 11:59:57-13:34:47Z | 5.696 s | 5.813 s | 6.452 s | 10.270 s |

These are production configurations, not a controlled n-sweep: commit-wait settings, load and
geography differ, so the row order must not be read as a validator-count scaling law. What
they do establish is that live, permissionless CometBFT sets at n = 21, 95 and 180 commit at
these intervals - i.e. a 2 s interval is not observed at n = 95 or n = 180 in these shipped
configurations, although the causal factor could be configuration rather than validator count.

### F5 - Published controlled study: Tendermint at n = 16/32/64/128 with faults

Source S-9: Cason et al., SRDS 2021 (peer-reviewed), https://www.inf.usi.ch/faculty/pedone/Paper/2021/srds2021a.pdf
(fetched 2026-10-07T13:14Z; text extracted with pypdf 6.19.0 to
thirdparty/tendermint-srds2021-extracted.txt). Method as published: Tendermint v0.33.8, Go
1.15, default configuration; nodes spread evenly over 16 AWS regions on all continents; 1 KB
transactions; closed-loop clients saturating the system (1,536 clients at n = 128); 30 blocks
per fault-free run, 60 per fault run. Label: **[third-party reported]**.

| n | mean block (commit-to-commit) latency | throughput | derived consensus portion (mean minus the 1 s timeout_commit) |
|---|---|---|---|
| 16 | 2.14 s | 535 tps | 1.14 s |
| 32 | 2.20 s | 520 tps | 1.20 s |
| 64 | 2.38 s | 477 tps | 1.38 s |
| 128 | 2.53 s | 438 tps | 1.53 s |

The right-hand column is **[derived from third-party reported]** arithmetic on the published
means, using the paper's own statement that every block latency includes an artificial 1 s
timeout_commit and that the remainder (about 1.5 s at n = 128) is the three consensus
communication steps. At n = 128, 96% of blocks fell between 2.3 s and 2.7 s.

Faults at n = 128 (same source):

- **Crash:** 42 of 128 validators killed after 12 blocks (the maximum f that still progresses).
  About 64% of subsequent blocks stayed near 2.65 s (one round); ~17% took 2 rounds at ~8.4 s;
  10% took 3 rounds at ~15 s; 5% took 4 rounds at ~22 s; 4% took 5-6 rounds at ~30 s and ~39 s.
  The paper attributes the tail to adaptive timeouts, whose initial values are **3 s and 1 s**.
- **Byzantine:** 128 nodes sharing 64 validator keys (equivocation); no fork and no halt; 86% of
  transaction latencies in line with the fault-free 64-validator run; mean transaction latency
  3.32 s versus 3.07 s.

Transfer caveats (stated by the source or evident from it): engine version v0.33.8 (2020), not
the release S2 pins (v0.38.x / v0.40.0); block size 20 MB and 1 KB transactions, not Taiko's
131,072 B payload; latency measured at a client co-located in one AWS region, not at every
validator; no view-change-rate metric is reported.

### F6 - Published baseline-CometBFT artifact: throughput only, no timing

Source S-10 (Senn & Cachin, CCS 2026 artifact; raw data in cryptobern/tenderload tag ccs26).
Setup as published: 49 VMs, 4 vCPU / 4 GiB each, high-speed network. Label:
**[third-party reported]**.

| Series | Run file | Offered rate | Achieved avg_tx_rate |
|---|---|---|---|
| n = 28 | baseline_n_28_1000_1.csv | ~1,000 tx/s | 976.7 tx/s |
| n = 28 | baseline_n_28_10000_1.csv | ~10,000 tx/s | 9,962.0 tx/s |
| n = 49 | baseline_n_49_1000_1.csv | ~1,000 tx/s | 976.7 tx/s |

Why this does not help S2: the published CSV metrics are total_time, total_txs, total_bytes,
avg_tx_rate and avg_data_rate only. The artifact contains **no block interval and no
per-block/per-round latency**, so it cannot bound round timing or the 2 s cadence.

### F7 - Negative result: the CometBFT repository publishes no latency benchmark table

Source S-11, checked 2026-10-07T13:19Z on main and the v0.34.x / v0.37.x / v0.38.x lines:
docs/references/benchmarks{,.md,/index.md} and docs/architecture/benchmarks* return HTTP 404.
What exists is tooling (test/loadtime/README.md: a load generator and a latency report tool,
with no published numbers) and docs/references/rfc/tendermint-core/rfc-003-performance-questions.md
(a taxonomy of performance questions, explicitly without measurements). Label:
**[bounded - negative result for the checked paths and date]**. Consequence: S2's "engine's own
benchmarks" (S2 section 3.2) provide a method, not numbers; no timeout can be sourced from the
repository.

## 4. What public data CANNOT establish here

These rows are **not** filled with estimates. They are what the original S2 must still supply.

| S2 quantity | Why public data cannot supply it |
|---|---|
| M1 one-way delay matrix, Delta_max | Requires timestamped probes between nodes of the intended topology. No public dataset measures node-pair p99 for a future permissionless Taiko set; cloud RTT tables are not node-pair measurements. |
| M2 round completion time | Public RPCs expose block intervals, not per-height round start to 2/3 precommit. No public chain publishes this for a Taiko-shaped design. |
| M3 block interval at n = 50/100/200 with Taiko's payload | No public network runs Taiko's consensus at those sizes; F4's chains differ in workload and configuration. |
| M4 X (block processing) and X_max at 131,072 B | Requires running Taiko's execution client on the fixed payload. Not obtainable by reading a chain. |
| M5 view-change rate | Requires the engine's own metrics from a controlled run; not exposed by public RPCs. |
| M6/M7/M8 bandwidth, messages per validator, vote size on the wire | Not exposed by any public interface. |
| M9 fault response and recovery | Requires a fault-injection campaign with the engine pinned; no public campaign exists at these n for this design. |
| M10 node health, M11 clock skew | Requires access to the nodes. |
| M12 largest n at which 2 s holds | Cannot be extrapolated from production configurations (F4) or from a 2020 engine version (F5). |
| Ladder conformance (G-CONFORM) | Requires stalling a round and observing it. |

Two specific traps this report avoids. First, Taiko's live 2 s L2 cadence is produced by two
permissioned preconfers (F2) and says nothing about a BFT round at n = 50-200. Second, the
production CometBFT intervals in F4 are shipped configurations, so they bound what is
*observed*, not what is *achievable* by Taiko's engine at a given n.

## 5. What this changes in the specification

No specification file, plan or other report was edited. **No parameter below is fixed by this
report; the register rows stay unmeasured.** Each row states what the public data does to the
question and what is still required to close it.

| Spec item | What the public data says | Sufficient to fix? | Still required |
|---|---|---|---|
| **TIMEOUT_MIN** (base round budget T_min = k x round_trip, round_trip = 4 x Delta_max + X_max) | No Delta_max or X_max exists for Taiko's set, so T_min cannot be computed. The published controlled study shows the consensus portion of a round at n = 128 in 16 AWS regions is about 1.5 s and that one trailing leader failure costs about 5.8 s with 3 s/1 s initial timeouts. | **Bounded only.** | S2 stage 0/1 (delay matrix, X, ladder mapping). |
| **TIMEOUT_MAX** (CONS-07(2) proposes 30 s) | The published crash trace reaches ~30 s and ~39 s for 5-6 rounds with 42/128 validators down under v0.33.8 defaults. | **Bounded only**, and against a different engine version. | S2 stage 2 fault cells at the pinned release. |
| **Delta_max** (advisory one-way delay, unmeasured) | The closest published proxy is S-9's region-latency distribution: about 76% of the 16 region pairs are below 100 ms, but only about 40% of node pairs are below 100 ms once the overlay is accounted for (figure axis to ~400 ms). This is a proxy for a *different* deployment. | **Not establishable from public data.** Assumption A-CONS-3 remains an assumption. | S2 stage 0 pairwise probes. |
| **X_max** (local execution for one 131,072 B block, unmeasured) | Nothing in public data measures Taiko's execution client on the fixed payload. | **Not establishable from public data.** | S2 stage 3 block-import cell. |
| **D1 - 2 s cadence at n = 50/100/200** | Taiko's shipped 2 s L2 cadence is a two-preconfer permissioned cadence (F2). Live CometBFT cadences: 0.62 s at n = 21, 2.87 s at n = 95, 5.70 s at n = 180 (F4, different configurations). The controlled published study gives 2.53 s mean block latency at n = 128 including a 1 s commit wait (F5). | **Bounded, NOT confirmed.** The 2 s cadence at n >= 50 remains a DESIGN TARGET. | S2 stage 1/2 G-CADENCE runs at the pinned engine release and real geography. |
| **PARAM-03 row "Round completion time at 2 s with a permissionless global set"** | Nothing here measures it. | **Not establishable from public data.** | S2 as specified. |
| **G-TRACE (round_trip &lt;= 1.500 s)** | S-9's derived consensus portion at n = 128 is ~1.53 s in a 16-region AWS deployment - the same order of magnitude as the committed trace, but a different definition, workload and engine version. | **Bound only, and it is suggestive rather than probative.** | S2 stage 0/1 measured delay matrix. |
| **G-FAULT (leader failure &lt;= 5 blocks / 10 s)** | The published crash trace: one extra round costs ~5.8 s, two ~8.4 s, three ~15 s. Against a 2 s cadence, a two-round recovery already consumes more than four cadence intervals. | **Informative for the threshold's tightness; cannot fix it.** | S2 stage 2 fault cells. |
| **M8 vote size on the wire** | Not addressed by this substitution. | **Not establishable from public data.** | S2 engine metrics. |

Bottom line for the decision this spike informs: public data **does not confirm** and **does
not falsify** D1's 2 s cadence at n = 50-200. It bounds the problem from two sides - the L1
clock quantises any L1-anchored step at 12 s (F1) and, in the shipped Taiko system, proposals
land every 384 s with proofs completing ~25 min later (F3); CometBFT-class engines are
observed committing at 0.62-5.70 s across production sets of 21-180 validators (F4) and a
controlled study put a 128-validator round at ~1.5 s plus a 1 s commit wait (F5). The
remaining uncertainty is exactly what S2 was written to remove, and it needs machines.

## 6. Raw evidence index

All paths are relative to this report's directory, ./raw/s2-public-data/. SHA-256 values are
in HASHES.txt.

| File | Content |
|---|---|
| COMMANDS.md, SOURCES.md | Every command run; every source with URL, retrieval time and method |
| fetch_rpc.py, fetch_cometbft.py, fetch_cometbft_chain.py, analyze.py | Fetch and analysis scripts (the analysis script documents the nearest-rank percentile method) |
| l1_blocks_mevblocker.jsonl (+ .meta.txt) | 20,000 Ethereum L1 headers, S-1 |
| l1_blocks_26140732.jsonl | 10,556 L1 headers from the second provider, S-2 (cross-check) |
| l1_blocks_intervals.csv | 19,999 L1 intervals (block range and timestamps) |
| taiko_l2_blocks_12367770.jsonl (+ .meta.txt, + taiko_l2_intervals.csv) | 20,000 Taiko L2 headers and their 19,999 intervals, S-3 |
| taiko_inbox_logs_7d.json (+ .meta.txt) | 1,898 raw Inbox logs, S-4 |
| inbox_log_heights.txt, inbox_block_headers.json (+ .meta.txt) | L1 headers for the log blocks, S-5 |
| proposals.csv, proofs.csv | Per-proposal and per-proof records with timestamps and intervals |
| cosmos_hub_blocks.jsonl, celestia_blocks.jsonl, dydx_blocks.jsonl (+ .meta.txt, + .validators.json, + *_intervals.csv) | Third-party production cadence samples and validator sets, S-6/S-7/S-8 |
| thirdparty/tendermint-srds2021-srds.pdf, thirdparty/tendermint-srds2021-extracted.txt | Published study S-9, as fetched and as text-extracted |
| thirdparty/zenodo-ccs26-artifact-appendix.pdf, thirdparty/tenderload/ | Artifact S-10 |
| thirdparty/tenderload-parameters.json | Series parameters for S-10 |
| HASHES.txt | SHA-256 of every evidence file |
