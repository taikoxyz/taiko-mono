# S3 — L1 cost per batch, the fee flow and the reward floor: what public data establishes

**Status:** public-data substitution for the S3 spike (no hardware, no testnet, no harness) · **Date:** 2026-10-07 (Asia/Singapore; all chain times UTC) · **Repo commit:** `66a6fbec63911e17cd1c71c97f444fba54a6fcc0` · **Report version:** v1

This report answers as much of [S3-l1-cost-and-fee-flow.md](../S3-l1-cost-and-fee-flow.md) as **existing public data on Ethereum mainnet and Taiko Alethia** can answer. It is a substitution, not a simulation: it measures the **live Taiko Unzen protocol**, not the pos-zk specification's `land(data, proof)` acceptance path, which does not exist on any chain. Every figure below is reproducible from the scripts in [raw/s3-l1-cost-fee-flow-public](./raw/s3-l1-cost-fee-flow-public/README.md). Where a number would require the designed protocol, a harness, or off-chain data, the report says so instead of estimating.

---

## 1. Scope and question

**The spike's question:** what does one batch landing on L1 cost, decomposed into execution gas, data cost and fixed overhead; what is the cost curve against the blob and execution fee markets; and does L2 fee revenue cover landing plus proving (D-8)?

**What was measured here:** the live analogue — every `propose` batch-landing transaction and every `prove` proof-submission transaction of Taiko's Unzen inbox on Ethereum mainnet over a stated window, their L2 gas coverage (from Taiko L2 block `extraData`), and the exact L2 fee revenue for a sampled hour.

**Mapping of terms.** In live Unzen, one `propose(bytes,bytes)` call = one proposal = one L2 batch; `Proposed` is the batch-landing event. `prove(bytes,bytes)` is the proof-submission transaction. There is no separate "verifier entry point" for users — the Inbox calls the verifier internally. **The specification's `land(data, proof)` (one atomic transaction carrying both blob data and a proof) does not exist on Ethereum mainnet**, the chain this report covers; landing and proving are two separate transactions and two separate cost lines, which is how this report treats them.

**Not in scope, because it cannot be measured from public data:** off-chain proof-generation cost (`C_prove` in the spike's `R_min`), the `LandHarness` / `SweepVault` / fee-vault-credit-check gas, the K ∈ {8, 32, 128} matrix at the specification's 131,072-bytes-per-L2-block data budget, and the specification's reward-ledger interface. See §4.

---

## 2. Sources and method

### 2.1 Chains, contracts and how each was confirmed

Ethereum mainnet `eth_chainId` = `0x1`; Taiko Alethia `eth_chainId` = `167000` (0x28c58). Addresses were **not** taken from memory: each was located in Taiko's own deployment log ([mainnet-contract-logs-L1.md](../../../../../deployments/mainnet-contract-logs-L1.md), the canonical source cited by [docs.taiko.xyz/network/contract-addresses](https://docs.taiko.xyz/network/contract-addresses)) and then confirmed on-chain with `cast` / JSON-RPC. Raw commands and outputs: [identification.txt](./raw/s3-l1-cost-fee-flow-public/identification.txt).

| Role | Address | How confirmed |
|---|---|---|
| Inbox proxy (propose + prove entry) | `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f` | 170 bytes of code; EIP-1967 impl slot `0x360894…382bbc` = `0x5253D4C91e80b880DdB54B78E74082Abe066F6b9` (the log's impl); `getConfig()` matches the log's config byte-for-byte; live `Proposed` logs match topic0 computed from the repo ABI |
| Proof verifier (called by Inbox) | `0x7284aaC05555Ae6559bdAd8B4221eC9584254Eec` | `getConfig().proofVerifier` equals it; its `sgxGethVerifier`/`sgxRethVerifier`/`risc0RethVerifier`/`sp1RethVerifier` getters return the four impls in the deployment log |
| Prover whitelist | `0xEa798547d97e345395dA071a0D7ED8144CD612Ae` | `getConfig().proverWhitelist`; `isProverWhitelisted(0xa5cb…6875)` = true (the only address that submitted proofs in the window) |
| Bond token | `0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800` (TAIKO) | `getConfig().bondToken`; listed as TaikoToken in the docs/deployment log |
| Fee/bond vault on L1 | **none exists** | No such address in the docs or deployment log; `getConfig()` has no vault field; the 7-day event census shows no `BondDeposited`, `BondWithdrawn` or `LivenessBondSettled` event |
| Legacy inboxes | `0x06a9Ab27…Feb19a` (Pacaya), `0xf6eA848c…e0eF9` (Hoodi-era) | 0 logs in the last 2,000 L1 blocks — the Unzen proxy is the only live landing point |

### 2.2 Windows and price sources

| Item | Value |
|---|---|
| L1 census window | blocks **26,086,570 – 26,136,782** = **2026-09-30T00:00:11Z → 2026-10-07T00:00:11Z** (7.0 days, 50,213 blocks) |
| L2 census window | L2 blocks **12,257,702 – 12,344,057** = **2026-10-05T00:00:01Z → 2026-10-07T00:00:01Z** |
| L2 fee sample | L2 blocks **12,322,459 – 12,324,258** = **2026-10-06T12:00:01Z → 12:59:59Z** |
| Why this window | a full week captures the diurnal L1 fee cycle (the census would be unrepresentative at a single snapshot), contains no protocol upgrade (last: Unzen, 2026-08-03), and ends on a whole UTC day |
| USD prices | Kraken public OHLC, pair `XETHZUSD`, 1-hour candles, close price of the hour containing each block ([kraken-ethusd-hourly.json](./raw/s3-l1-cost-fee-flow-public/kraken-ethusd-hourly.json)); retrieved 2026-10-07. The fetched series is 182 h (min $2,561 / median $2,696 / max $2,755), but its minimum close is 13 h *after* the window ends; over the **168 in-window hours** the closes are **min $2,661 / median $2,697 / max $2,755** (`kraken_window_stats.py`). *(PB-L-11: the earlier row quoted the out-of-window minimum as covering the window.)* |
| Fees (L1) | `eth_feeHistory` per block: `baseFeePerGas`, `baseFeePerBlobGas`; per-tx `effectiveGasPrice`, `blobGasPrice` from receipts |

**Figure labels.** `[on-chain measured]` = value fetched from a node and reproducible from the raw file (arithmetic on measured inputs is marked "derived" with its formula). `[third-party reported – source, methodology]` = published by someone else. `[bounded – bound and assumptions]` = a range that holds only under stated assumptions. `[not establishable from public data]` = no public source can produce it.

---

## 3. Findings

### F1 — What one live batch landing costs on L1 (7-day census, all 1,575 batches)

The 7-day window contains **1,575 `Proposed` events emitted by 1,575 `propose` transactions (1:1)**; all are type-3 (blob) transactions, each carrying **exactly 1 blob**, each with **exactly 164 bytes of calldata**. `[on-chain measured]` Source: `inbox-logs.json`, `propose-txs.json`, `propose-metrics.csv`; command `python3 analyze_l1.py`.

| Figure (7-day window) | Value | Status |
|---|---|---|
| Batches landed / propose txs | 1,575 | [on-chain measured] |
| `gasUsed` per batch | 75,594 (**1,572** of 1,575; 3 at 78,448; mean 75,599.436) | [on-chain measured] |
| Blobs per batch | 1 (all 1,575) | [on-chain measured] |
| Calldata bytes | 164 (all 1,575) | [on-chain measured] |
| Effective gas price | p10 1.070, p50 1.126, p90 1.834, p99 3.920, max 9.624 gwei | [on-chain measured] |
| Cost per batch, p50 | **0.0000861 ETH** ≈ **$0.233** | [on-chain measured] (+ Kraken close) |
| Cost per batch, mean | 0.0001038 ETH ≈ $0.280 | [on-chain measured] |
| Cost per batch, p90 / max | 0.0001448 / 0.0007683 ETH | [on-chain measured] |
| Week total | **0.1634 ETH** ≈ **$431.31** | [on-chain measured] |

*PB-AR-10: the `gasUsed` count read "1,574 of 1,575"; [`propose-metrics.csv`](./raw/s3-l1-cost-fee-flow-public/propose-metrics.csv) has **1,572** rows at 75,594 and 3 at 78,448 (mean 75,599.436), re-derived in [`s3_report_recounts.py`](./raw/s3-l1-cost-fee-flow-public/s3_report_recounts.py). No other figure moves.*

Representative median batch: tx [`0x684ff092…9242`](https://etherscan.io/tx/0x684ff0927fe83dc1540b2475affc0e254cb1d851c6b084f634554bf91d669242), L1 block 26,120,757 — 75,594 gas at 1.1257 gwei = 0.0000851 ETH, plus 1 blob at 7,846,422 wei/blob-gas = 0.0000010 ETH; total **0.0000861 ETH ($0.233)**.

### F2 — Cost decomposition: it is almost all execution gas, and mostly priority fee

| Component | 7-day total (ETH) | Share | Status |
|---|---|---|---|
| Execution gas — L1 base fee (**burned**) | 0.040346 | 24.7% | [on-chain measured] (derived: gas × block base fee) |
| Execution gas — priority fee (**to L1 builder**) | 0.119218 | 72.9% | [on-chain measured] (derived: gas × (effective − base)) |
| Blob data — 1 blob × 131,072 blob gas × blob base fee | 0.003864 | 2.4% | [on-chain measured] (derived) |
| **Total** | **0.163428** | 100% | [on-chain measured] |

**Denominator.** The table decomposes **all 1,575 batches** of the 7-day census. The first pass left a gap here: 33 of the 1,575 rows (2.1% of batches, 0.003508 ETH of execution cost = 2.15% of the week's cost) had no cached block header, so `base_fee_cost_wei` and `priority_cost_wei` in `summary.json` covered only **1,542** rows while `total_cost_wei` and `blob_cost_wei` covered 1,575 — the three lines then summed to 0.159920 ETH and 97.9%, not to the stated total and 100%. The 33 headers have been re-fetched with `fetch_block_times.py` and [`fee_decomposition.py`](./raw/s3-l1-cost-fee-flow-public/fee_decomposition.py) recomputes all three lines over the full population. The original figures remain checkable in [`fee-decomposition.json`](./raw/s3-l1-cost-fee-flow-public/fee-decomposition.json): base 0.039333 and priority 0.116723 over the 1,542 rows with headers, blob 0.003864 over all 1,575 — that mixed denominator is what produced the 97.9% — plus the 33 excluded rows' 0.003508 ETH execution volume. *(PB-L-03: the earlier table silently dropped 2.1% of its population and reported shares that summed to 97.9%.)*

Per-batch gas decomposition (all batches, constant): **fixed overhead 21,000 gas (27.8%)** + **calldata 752 gas (1.0%)** + **contract execution 53,842 gas (71.2%)** = 75,594 gas. `[on-chain measured]` (calldata gas derived from the 164-byte input's 156 zero / 8 non-zero bytes at EIP-2028 prices). **The blob-data line is 2.4% of cost in this window because blob base fees ran 0.0027–0.427 gwei (min–max over the window); the execution side dominates at the average, but at the top of that range one blob costs more than the entire fee margin once the proof is paid (F8, PB-AR-01), so the 2.4% average is not headroom.**

### F3 — The cost curve over the measured fee market

Per-block fee series for all **50,213** blocks of the window (26,086,570–26,136,782 inclusive) `[on-chain measured]`; "median batch" = the measured median gas (75,594) and blob count (1). The committed `l1-fee-history.json` carries **50,264** `baseFeePerGas` and `baseFeePerBlobGas` entries — `eth_feeHistory` returns count + 1 per request, so 51 look-ahead entries over 51 chunks — while its `gasUsedRatio` and `blobGasUsedRatio` hold exactly 50,213 ([`s3_report_recounts.py`](./raw/s3-l1-cost-fee-flow-public/s3_report_recounts.py)). *(PB-AR-06: the earlier "50,264 blocks" counted the fee-history look-ahead entries, ~51 more than the window contains; no percentile moves.)*

| Price point | L1 base fee (gwei) | Blob base fee (gwei/blob-gas) | Median batch at base fee only (ETH) | Median batch at the observed median **effective** price + blob at that point (ETH) |
|---|---|---|---|---|
| min | 0.0478 | 0.0027 | 0.0000040 | 0.0000855 |
| p50 | 0.1273 | 0.0073 | 0.0000106 | 0.0000861 |
| p90 | 0.8443 | 0.0479 | 0.0000701 | 0.0000914 |
| p99 | 2.9903 | 0.1522 | 0.0002460 | 0.0001051 |
| max | 9.1522 | 0.4274 | 0.0007479 | 0.0001411 |

`[on-chain measured]` base fee and blob fee percentiles. The last column is `summary.json`'s `median_batch_total_eth_at_obs_median_egp`: the median batch's **effective** gas price is held at the window's observed median (1.125879441 gwei, i.e. an execution term constant at 0.00008511 ETH) and the **blob** fee varies with the price point — the base fee does **not** vary in it. That is why at p99 and max the column (0.0001051, 0.0001411) sits **below the base-fee-only floor of the same table** (0.0002460, 0.0007479): the p99/max base fees exceed the median effective price, so the column is not a cost at those price points and must not be read as one. *(PB-AR-06: the label described holding the priority fee at its ≈1.0 gwei median while the base fee varied — a construction that cannot produce the printed values; re-derived in [`s3_report_recounts.py`](./raw/s3-l1-cost-fee-flow-public/s3_report_recounts.py).)* Blob-gas utilisation of L1 blocks was p50 19%, p90 52%, max 100% `[on-chain measured]`, so the blob market was not saturated.

### F4 — The live batch is ~192 L2 blocks at a 2-second L2 cadence

Over the 2-day L2 census (451 proposals, 86,356 L2 blocks) `[on-chain measured]`:

| Figure | Value |
|---|---|
| L2 blocks per batch | 192 for 446/451 proposals; 5 short batches (59–191) |
| L2 block time | 2 s for **85,904 / 85,905 intervals within a batch (99.9988%)**, and for **86,352 / 86,355 of all consecutive intervals (99.997%)**; gas limit 46,000,000 (all blocks) |
| L2 gas per batch | p50 22,758,998; mean 24,820,984; max 49,272,897 |
| L2 gas per L2 block | median 112,068; mean 129,325 |

Attribution method (not an assumption): each Taiko L2 block's `extraData` is `0x<basefeeSharingPctg:1 byte><proposalId:6 bytes>`; all 451 batches decode to `pctg = 75` and the proposal IDs join 1:1 to the L1 `Proposed` events. `[on-chain measured]`

*PB-L-04: this row earlier read "2 s for 85,555 / 85,587 intervals (99.97%)". Neither number appears in any raw artifact — `l2-two-day.csv` has 86,356 contiguous rows with no nulls, so the two natural denominators are the ones now shown: 86,356 − 451 proposals = 85,905 within-batch intervals (one is 8 s), and 86,355 consecutive intervals in total (adding a 4 s and an 82 s cross-batch gap). Re-derived by [`l2_interval_census.py`](./raw/s3-l1-cost-fee-flow-public/l2_interval_census.py) → [`l2-interval-census.json`](./raw/s3-l1-cost-fee-flow-public/l2-interval-census.json); the corrected ratios are stronger than the reported one. PB-L-10: the same table's mean is corrected from 129,389 to 129,325 (= 11,168,016,854 ÷ 86,356), matching F8.*

### F5 — Cost per L2 block and per L2 gas (propose side)

Joining each propose tx's actual cost to the L2 gas its batch covered (449 fully covered proposals, Oct 5–7) `[on-chain measured]`; `python3 join_analysis.py`:

| Figure | p50 | mean | p90 | max |
|---|---|---|---|---|
| L1 propose cost per batch (ETH) | 0.0000985 | 0.0001161 | 0.0001682 | 0.0004434 |
| Cost per L2 block (ETH) | 0.000000514 | 0.000000605 | 0.000000876 | 0.000002309 |
| **Cost per L2 gas (wei)** | **4,014,700** | 4,815,044 | 7,272,260 | 18,799,428 |

That is **0.00401 gwei per L2 gas at p50** for landing alone. Adding the amortised on-chain proof cost (F7: 0.0001084 ETH per batch ÷ 22.76 M L2 gas = 4.76 M wei) gives **≈0.0088 gwei per L2 gas** at p50 batch size (0.0093 gwei is the aggregate for the 8 sampled batches, whose L1 prices were slightly higher).

### F6 — The live fee flow, and what the L2 collects

Measured on Taiko L2: base fee is **10,000,000 wei (0.01 gwei) on all 86,356 blocks** of the census, and `basefeeSharingPctg = 75` on all batches. `[on-chain measured]` Total L2 gas over the 2-day census = 11,168,016,854 → **L2 base-fee revenue 0.111680 ETH / 2 days** (0.0558 ETH/day). `[on-chain measured] (derived)`

For the sampled hour (1,800 blocks, 217.04 M L2 gas), all receipts were fetched: total L2 fees **0.0023259 ETH**, of which base fee 0.0021704 ETH (93.3%) and priority fee 0.0001555 ETH (6.7%). `[on-chain measured]` The split of the base fee — 75% to the L2 block proposer, 25% to the Taiko DAO treasury, and **no burn** — is stated by Taiko's docs ([docs.taiko.xyz/protocol/economics](https://docs.taiko.xyz/protocol/economics)) and implemented in [taiko-geth `core/state_transition.go`](https://raw.githubusercontent.com/taikoxyz/taiko-geth/taiko/core/state_transition.go) (`feeCoinbase = totalFee × pctg / 100; feeTreasury = totalFee − feeCoinbase`; treasury address = `0x1670000000000000000000000000000000010001` for chain 167000 — the same string the docs list as `TaikoAnchor`). `[third-party reported – Taiko docs + taiko-geth source, reviewed not executed]` The treasury address's L2 balance was **76.3132 ETH** at L2 head 12,367,835 (2026-10-07 ~13:11Z) `[on-chain measured]`; its composition is not proven by the balance alone.

### F7 — Proving on L1: uniform, pricey, and completely unrewarded on-chain

| Figure (7-day window) | Value | Status |
|---|---|---|
| `Proved` events / prove txs | 315 / 315 (single sender `0xa5cb…6875`, whitelisted) | [on-chain measured] |
| Proposals finalised per proof | exactly 5 (min = max = p50 = 5) | [on-chain measured] |
| `gasUsed` per prove tx | 399,414 (p10 399,390; max 399,474) | [on-chain measured] |
| Cost per prove tx (p50) | 0.0004504 ETH | [on-chain measured] |
| Prove cost per proposal (amortised) | **0.0001084 ETH** | [on-chain measured] (derived: 0.170660 ETH ÷ 1,575) |
| Week total prove cost | 0.170660 ETH | [on-chain measured] |
| On-chain prover reward / bond events | **zero** (no reward event; `getBond(proposer) = (0,0)`; `minBond = 0`, `livenessBond = 0`) | [on-chain measured] |

There is **no prover market and no reward transfer on L1** to measure: the deployed `prove()` pays nothing, and when the prover whitelist is enabled it skips bond settlement entirely (source at the deployment commit, `Inbox.sol` `prove()` §3). The prover fee is **negotiated off-chain**: "Compensation to provers for generating validity proofs. This is negotiated off-chain between proposers and provers." `[third-party reported – docs.taiko.xyz/protocol/economics]` Therefore the closest public proxy for the proving-cost line is the **on-chain proof submission cost only** (0.0001084 ETH/proposal); the generation cost is `[not establishable from public data]`.

### F8 — D-8 coverage, measured: thin margin at today's prices, negative at p90, before any prover fee

Exact comparison for the **8 batches wholly inside the sampled hour** (both sides measured in the same hour, no extrapolation) `[on-chain measured]`; `python3 coverage.py`:

| Per batch | ETH | Status |
|---|---|---|
| L2 fees collected (base + priority) | 0.0002437 | [on-chain measured] |
| L2 base fee alone | 0.0002307 | [on-chain measured] |
| L1 propose (actual, same hour) | 0.0001063 | [on-chain measured] |
| L1 prove amortised (5 proposals/proof, F7) | 0.0001084 | [on-chain measured] |
| **L1 total (landing + on-chain proving)** | **0.0002146** | derived |
| Coverage, all L2 fees ÷ L1 total | **1.135×** | [bounded – excludes off-chain proving cost] |
| Coverage, base fee only ÷ L1 total | **1.075×** | [bounded – same exclusion] |
| Coverage, proposer's own share (75% base + 100% priority) ÷ L1 total | **0.867×** | [bounded – uses the documented 75/25 split] |

Sensitivity to the L1 execution price, holding the measured L2 revenue fixed `[bounded – assumes propose and prove pay the same L1 price percentile and that the sampled hour's L2 revenue is representative]`; `python3 sensitivity.py`:

| L1 effective price point | 1.070 gwei (p10) | 1.126 (p50) | 1.834 (p90) | 3.920 (p99) |
|---|---|---|---|---|
| Coverage, all L2 fees | 1.47× | 1.39× | **0.85×** | **0.39×** |
| Coverage, base fee only | 1.39× | 1.32× | **0.81×** | **0.37×** |
| Coverage, proposer's share only | 1.12× | 1.06× | **0.65×** | **0.30×** |

**Break-even L1 effective gas price** (same assumptions): **1.567 gwei** on all L2 fees, **1.484 gwei** on base fees only, **1.196 gwei** on the proposer's share only, at the observed L2 base fee floor of 0.01 gwei and the observed batch size. Break-even **blob** base fee, holding execution cost at the sampled-hour value **and including the amortised on-chain proving cost that this finding's own "L1 total (landing + on-chain proving)" contains**: **243,041,212 wei** = **0.2430 gwei/blob-gas** on the per-batch model, or **221,621,770 wei** = **0.2216 gwei** on the aggregate L1-total basis — derived as [Σ L2 fees − Σ (propose cost − blob cost) − Σ amortised prove] ÷ (8 batches × 131,072 blob gas) = 0.000254847 ETH ÷ 1,048,576 = 243,041,212 wei ([blob_breakeven_corrected.py](./raw/s3-l1-cost-fee-flow-public/blob_breakeven_corrected.py) → [blob-breakeven-corrected.json](./raw/s3-l1-cost-fee-flow-public/blob-breakeven-corrected.json)). **The window's observed maximum blob fee is 0.4274 gwei, which is 1.76× the corrected break-even: at the observed peak the blob line alone (0.00005602 ETH/batch) exceeds the entire remaining margin (0.00003186 ETH/batch) and all-fee coverage falls to ≈0.91×, before any off-chain prover fee. At observed peak blob fees the fee revenue no longer covers the batch once proving is paid.** *(PB-AR-01: the earlier figure of **1,069,729,806 wei** = 1.07 gwei, "2.5× the window's observed maximum", divided [Σ L2 fees − Σ execution-only propose cost] by the blob gas and so omitted the amortised proving cost (0.000108356 ETH/batch) that the same coverage model includes everywhere else; it was 4.4× too high and inverted the headroom reading, and the "2.5× the observed maximum" claim is withdrawn. [blob_breakeven.py](./raw/s3-l1-cost-fee-flow-public/blob_breakeven.py) reproduces the old figure to the wei from the execution-only basis — PB-L-08's provenance point stands — and [blob_breakeven_corrected.py](./raw/s3-l1-cost-fee-flow-public/blob_breakeven_corrected.py) derives the corrected pair; the "0.222e9" line in the earlier PB-L-08 note is this aggregate-basis corrected value, not a failed reconstruction of the old figure.)*

The L2 base fee has no headroom to respond: it sits at its floor (10,000,000 wei on every block measured), because L2 blocks average 0.28% full (mean 129,325 gas of a 46,000,000 limit). So revenue can only grow with L2 activity, not with price.

### F9 — What is left of the spike's arithmetic after this substitution

| Spike quantity | Public-data value | Status |
|---|---|---|
| `C_land(batch)` | 0.0000861 ETH p50 (propose only; 1 blob, 164-byte calldata, 75,594 gas) | [on-chain measured] |
| `C_L1_verify` | 0.0004504 ETH per proof ÷ 5 proposals = 0.0001084 ETH/batch | [on-chain measured] |
| `C_L1_data` | 0.0000010 ETH/batch at the window's median blob fee (2.4% of cost) | [on-chain measured] |
| `C_prove` (off-chain) | — | [not establishable from public data] |
| `gas_per_new_storage_slot` | — (the live acceptance path's write set is not re-measured here; no slot-count harness was built) | [not establishable from public data] |
| `R_min` / `REWARD_QUOTE` floor | **≥0.0002146 ETH/batch** at the sampled prices (landing + on-chain verification only) | [bounded – a lower bound that omits C_prove, C_bridge_ops, C_ops] |
| `MAX_BATCH_BLOCKS` | live observed: 192 L2 blocks/batch; the protocol enforced no smaller constant in the window | [on-chain measured] for the live regime |
| break-even fee level `f*` | 1.567 gwei L1-equivalent (see F8); in L2-gas terms at the sampled hour: L1 total 0.0093 gwei per L2 gas vs L2 fee 0.0106 gwei per L2 gas | [bounded – same exclusion] |

---

## 4. What public data CANNOT establish here

| # | Not establishable | Why | Effect on the conclusions |
|---|---|---|---|
| N1 | Off-chain proving cost `C_prove` | Taiko's docs state the prover fee is negotiated off-chain; the deployed `prove()` transfers no reward and the window contains no bond/reward event. No public ledger records it | Every coverage figure in F8 is an **upper bound on coverage**: adding any positive prover fee lowers the ratio and raises the break-even price. D-8 cannot be closed without it |
| N2 | The specification's `land(data, proof)` gas for K ∈ {8,32,128} at 131,072 bytes/L2-block | That contract does not exist; the live protocol uses 1 blob per ~192 blocks and a 164-byte call, a different data regime | The measured per-batch gas (75,594) must **not** be transferred to the specification's payloads; per-byte terms (blob count, keccak, 0x0A precompile) would dominate there |
| N3 | The fee-vault sweep interface and its gas | No fee vault exists on either chain; live L2 fees are credited in-L2 to coinbase/treasury by the execution client | The R4-PB-01 sweep-interface deliverable stays open; public data can measure the **amount** to be swept (F6) but not the sweep |
| N4 | The fee-vault credit check (`delta ≥ expected`) cost and predicate | The check is a pos-zk design element with no deployed instance | Cannot be measured; the live protocol has no equivalent (fees are credited by consensus, not proved) |
| N5 | A hard protocol `MAX_BATCH_BLOCKS` | The live Inbox stores no such constant; the observed 192 is a proposer policy (32 L1 slots × 6 L2 blocks) | Only a **bound on what the live system did**, not the spec's admission bound |
| N6 | Payload bytes actually used per batch | The blob's used length is not in the event data or the receipt; parsing blob contents is a different workstream (S1/S4) | `b` (bytes per L2 gas) and per-byte costs of the designed payload stay unmeasured |
| N7 | L2 fee revenue outside the sampled hour (priority component) | Base fee is measured for the whole census; priority fees need per-block receipts, fetched exactly for 1,800 blocks | Revenue outside the sample is `[bounded – base fee exact, priority assumed at the sampled share (6.7%)]` |
| N8 | Whether the treasury's 76.31 ETH balance is entirely base-fee accrual | A balance is a stock; only traces/state diffs would attribute flows, and archive state is not available on the public endpoints used | The split is documented, the accrual over 2 days is derivable (0.0277 ETH), but the composition of the balance is not proven |
| N9 | Verifier-route gas per proof type (SP1 Groth16/PLONK, RISC0) | The live inbox uses one routed verifier; per-sub-verifier gas requires the harness and fixtures | The 399,414 gas/prove tx is the **routed** cost, not a per-backend measurement |
| N10 | `gas_per_new_storage_slot` and the acceptance-path slot list for the designed checkpoint/recovery-generation writes | Requires the `LandHarness`; the live Inbox's storage layout differs | S5's recovery-state sizing cannot consume a measured unit from public data |

---

## 5. What this changes in the specification

| Parameter / rule | Finding that bears on it | Sufficient to fix it? |
|---|---|---|
| `REWARD_QUOTE` (09-parameters, unmeasured) | Measured **floor** for the L1-side cost of one live batch: **0.0002146 ETH** (landing 0.0001063 + on-chain proving 0.0001084) at the sampled prices; ≈$0.57–0.59 at the **in-window** hourly closes ($2,661–2,755; $0.569–0.597 for the 8 sampled batches at their own hours). *(PB-L-11: the earlier ≈$0.55–0.58 range used the series minimum, a close 13 h outside the window.)* The specification's `R_min` also needs `C_prove`, `C_bridge_ops`, `C_ops` | **Only bounds it from below.** It cannot be fixed: the off-chain prover fee is the largest unknown (N1) and the designed payload's gas is unmeasured (N2) |
| `MAX_BATCH_BLOCKS` / `BATCH_BLOCKS` | The live protocol ran batches of **192 L2 blocks** (446/451) at 2 s cadence, with a flat 75,594-gas acceptance cost and 1 blob; the spec's K ∈ {8,32,128} at 131,072 B/block is a different data regime | **Only informs it.** Public data shows a larger K than the spec's placeholder 32 was **exercised live** — an achieved, demand-limited cadence (91–99.9% of blocks anchor-only, ≈0.5% of the DA bound), not a demonstrated capability — but it says nothing about the spec's per-block data budget, and the blob ceiling at that budget (K ≤ 21 in one transaction) is untouched *(re-based to the measured BPO2 per-transaction maximum of 21 blobs — target 14 / max 21 / update fraction 11,684,671, S4 F6; 14 is the design's chosen planning length and 21 the hard edge)*. *(PB-L-06: "was sustainable live" presented an achieved rate as a capability; wording corrected.)* |
| Fee-vault credit check (R4-PB-08 / CONS-01) | No fee vault or in-guest credit predicate exists in the live protocol; L2 fees are credited directly by the execution client (N3, N4) | **Cannot be fixed from public data.** The check needs the harness and a rule decision |
| D-8 ("L2 fees fund security") | At the observed L1 prices and the L2 base-fee floor: all L2 fees cover landing + on-chain proving **1.135×** (base fee alone 1.075×); the proposer's own 75%+priority share covers only **0.867×**; coverage crosses 1.0× at **1.567 gwei** L1 effective price (all fees) or **1.196 gwei** (proposer-only); the blob break-even is **0.243 gwei** and the window's peak blob fee is 1.76× that, so at the peak the data line alone consumes the margin (PB-AR-01). Off-chain proving cost is excluded | **Bounds it, does not settle it.** The funding premise holds in the measured week only if the unmeasured prover fee stays inside a ~13% margin (all-fee basis) — and the design must decide whether the treasury's 25% is part of the security budget, since the proposer alone is short |
| D-9 ("penalties to the treasury, no burn") | The live L2 base fee is **not burned** (100% split to coinbase/treasury, F6), which matches the no-burn rule for fee revenue; the deployed `prove()` code burns 50% of a **late liveness bond** when the whitelist is off — currently inactive because `livenessBond = 0` | **Informs the wording.** If D-9's "no burn" is meant to cover all protocol flows, the liveness-bond rule (as deployed) contradicts it; that is a rule question, not a measurement |
| `C_L1_data` / blob cost line | Measured 2.4% of batch cost at the window's blob fees (p50 0.0073 gwei); break-even blob fee **≈0.243 gwei (243,041,212 wei)** on the per-batch coverage model (**0.2216 gwei / 221,621,770 wei** on the aggregate L1-total basis) — **0.57× the window's observed maximum, i.e. the peak is 1.76× the break-even** ([`blob_breakeven_corrected.py`](./raw/s3-l1-cost-fee-flow-public/blob_breakeven_corrected.py)) | **Fixes the live-regime shape, and bounds its headroom the other way (PB-AR-01)**: at the window's peak blob fee one blob costs more than the whole fee margin once proving is paid. The designed regime's blob count (K blobs at the spec's data budget) is unmeasured |
| `gas_per_new_storage_slot` (S5) | Not measured (N10) | **Not sufficient** — S5 must wait for the harness |

**One-line answer to the spike's headline question.** Yes, in the measured week L2 fee revenue covered L1 landing plus on-chain proof submission, by ~13% on an all-fees basis and by ~7% on base fees alone — but the proposer's own share did not (−13%), the margin vanishes at L1 prices above ~1.57 gwei, and the off-chain proving cost, which the protocol's own documentation says exists and is negotiated privately, is not in the measurement at all.

---

## 6. Raw evidence

All files under [`raw/s3-l1-cost-fee-flow-public/`](./raw/s3-l1-cost-fee-flow-public/README.md); SHA-256 of the principal artifacts:

| Artifact | SHA-256 (first 16 hex) |
|---|---|
| `window.json` | `535d51bacb3c604f` |
| `inbox-logs.json` | `a4f96bba14d51463` |
| `propose-txs.json` | `f83929ca1d35c530` |
| `prove-txs.json` | `18c8eb8efbba1b9e` |
| `l1-fee-history.json` | `876e0782aa266b3d` |
| `l2-two-day.csv` (86,356 rows) | `695de11ba1aa89ce` |
| `l2-fee-sample-hour.json` | `f122060e7a61a609` |
| `propose-metrics.csv` | `36dfcc54ed041e48` |
| `prove-metrics.csv` | `e465523df5a48c49` |
| `join-metrics.csv` | `2a163c537cb21ee1` |
| `summary.json` | `aba803cd9f923474` |
| `join-summary.json` | `415b7c361b788f6f` |
| `coverage-summary.json` | `a5bd9e07d46cab4e` |
| `sensitivity.json` | `50b668b20b935aef` |
| `identification.txt` | `9dd53dda69b80ef9` |
| `report-numbers.json` | `90b1d8f4a8e9207a` |

Re-run everything with the commands in the raw README (`collect_l1.py` → `fetch_block_times.py` → `analyze_l1.py` → `collect_l2.py` → `join_analysis.py` → `sample_l2_fees.py` → `coverage.py` → `sensitivity.py`). No specification file, plan, or other collector's report was modified.
