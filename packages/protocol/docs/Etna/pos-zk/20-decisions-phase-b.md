# D-20 - the three Phase B decisions: batch length, cadence, and the fee margin

Owner input: **block time may be up to 4 seconds**; **batch length is left to the design**; D-8's margin is to be handled as far as the evidence allows. All three rest on measured Phase B data, and none of the measurements is a first-party measurement of the design point - each decision states which part is measured, which is derived, and which stays open.

## 1. `BATCH_BLOCKS` (K) = **14**

**Why 14.** The one-transaction blob ceiling in force is the EIP-7892 BPO2 set: **target 14, maximum 21** [on-chain measured: blobGasPrice == fake_exponential(1, excessBlobGas, 11,684,671) on 18/18 sampled blob blocks]. At the design's own data rate - one 131,072-byte blob per L2 block - a batch of K blocks needs K blobs in one transaction. Setting K to the **target** rather than the maximum means the transaction is publishable *by construction*: it never depends on the network tolerating a max-blob block, never bids for the last blob slots, and never breaks if a future fork lowers the maximum below 21. K = 21 would sit exactly on the hard edge; K = 14 leaves 7 blobs of headroom for nothing more than robustness.

**Why not smaller.** A smaller K buys settlement latency that the system cannot use. Measured proposal-to-proof latency on the live network is **p50 684 s, p95 2,580 s** [on-chain measured, 30 days]. At the new 4-second cadence, 14 blocks is **56 seconds** of L2 data - about 8% of the median proving latency. Batching is not the settlement bottleneck; proving is. So there is no latency argument for a smaller K, and every extra land transaction costs the measured **0.0000861 ETH** [on-chain measured, p50]. With 4-second blocks and K = 14, a batch covers 56 s.

**Why not 32.** The registered planning placeholder `BATCH_BLOCKS = 32` is **unpublishable in one L1 transaction** at the design rate: 32 blocks would need 32 blobs against a maximum of 21. This is not a preference - it is arithmetic, and it is the state the placeholder was in when Phase B found it.

**The bound is a product, not a constant.** K is bounded by `K <= capacity / per-block data`, so if the design's per-block data budget ever rises above 131,072 bytes, K must fall below 14. The register states the relation, not just the value.

**Residual, disclosed:** the per-block data budget (131,072 B per L2 block) is a **design assumption**, not a measurement - the live network runs at about 0.5% of its own DA bound. If the design rate is wrong, K = 14 is wrong with it. This is falsifier-class: a workload whose real per-block data exceeds one blob invalidates the choice.

## 2. Block time (D1) = **4 seconds**, D1's 2 seconds superseded

**Why 4.** D1 fixed 2 seconds when nothing had been measured. Phase B measured a bound: Ethereum L1 quantisation is **12 s with a p99.9 of 24 s** [on-chain measured, 66.9 h], and shipped CometBFT configurations run **2.87 s at n = 95 (Celestia)**, **5.70 s at n = 180 (Cosmos Hub)** and **0.616 s at n = 21 (dYdX)** [on-chain measured, third-party networks], against Tendermint's controlled measurements of **2.14-2.53 s at n = 16-128 including a 1 s commit wait** [third-party reported, Cason et al. SRDS 2021]. The live Taiko cadence of **2.000 s is achieved by two coinbase addresses** and is therefore no evidence about a BFT set at all [on-chain measured].

At 2 seconds the design would be claiming a round time **better than every production configuration measured at comparable n**. At 4 seconds it sits comfortably inside the observed envelope up to **n of about 128** (2.14-2.87 s observed, so roughly 40% headroom), and it uses the full allowance the owner granted. Above n = 128 the evidence does not support 4 s - at n = 180 the observed figure is 5.70 s - so the cadence and the validator count are now **one decision, not two**: 4 s is conditioned on the intended n staying near or below 128. If the intended n is 200, the evidence says the honest cadence is about 6 s, not 4.

**Consequences.** The epoch length in L1 blocks and every L2-block-denominated bound move with it: a 14-block batch is 56 s, not 28 s. `TIMEOUT_MIN`/`TIMEOUT_MAX` are still unmeasured - they need the S2 harness - and this decision does not set them; it sets the cadence they must be consistent with.

**Status: this is a bounded decision, not a measurement.** F-CADENCE-1 stays Open. What changes is that the design now sits inside the measured envelope rather than outside it, and its falsification condition is sharper: an S2 run at the pinned engine release showing a round cannot complete inside 4 s at the registered `N_MAX` would falsify this decision where it would merely have embarrassed 2 s.

## 3. Handling D-8's margin

**The finding.** L2 fee revenue covers L1 landing cost by **1.135x** at the median, but only **0.867x** for the proposer's actual share (75% of base fee plus priority fee), and **0.85x** at the p90 L1 price; break-even L1 prices are 1.567 / 1.484 / 1.196 gwei [on-chain measured, 8 batches with both sides measured in the same hour]. Every ratio is an **upper bound**, because the off-chain prover fee is negotiated off-chain and is not in them. L2 base fee is pinned at its **0.01 gwei floor** with blocks **0.28% full**.

**The measurement also shows where the money goes, and that is the handle.** Of the measured batch cost, **71.4% is priority fee**, 24.1% is base fee and 2.4% is blob cost [on-chain measured, 1,575 batches, 7 days]. The priority fee is a **discretionary bid by the submitter** - it is not a cost the chain imposes. Measured coverage is against the *observed* cost, which includes the submitter's own overpayment.

**Three changes, in order of effect:**
1. **Compute coverage against base-fee plus blob cost, not against the observed total.** The protocol cannot be required to cover a submitter's discretionary bid. On the measured decomposition this is a cost of 0.0432 ETH per batch against 0.1634 observed - so on the same fee revenue the ratio improves by roughly a factor of **3.8** [derived from the measured decomposition, not a new measurement]. This is the single largest lever and it costs nothing.
2. **Route the whole L2 base fee to the security budget.** The 0.867x case exists only because 25% of the base fee is diverted. Crediting 100% of the L2 base fee - which is what D-9 already requires in substance, no burn, penalties and fees to the treasury - removes the proposer-share case entirely and makes the relevant ratio 1.075x at the median rather than 0.867x.
3. **Keep the L2 base fee floor as a floor and stop treating it as revenue.** The floor is not earning; it is the minimum price. Revenue is **demand-limited**, not price-limited: blocks are 0.28% full, so coverage rises with usage and this design cannot fix it by raising a parameter without pricing users out at current demand.

**What is NOT done, and is disclosed rather than fixed:** the off-chain prover fee remains outside every ratio, so no coverage figure here is complete; the design point's proving cost is unmeasured (S1 could only bound per-machine throughput); and the reward floor `REWARD_QUOTE` is bounded below only, at **>= 0.0002146 ETH per batch**, excluding proving cost. **D-8 is therefore recorded as bounded-and-improved, not settled** - and its remaining falsifier is a measured off-chain proving cost that exceeds what the fee model leaves.

## What these three decisions do not do

They do not make increment 3 or the rotation actionable: aggregation still needs S1's cost line, and the rotation still needs an L1-verifiable `h_close`. They do not replace the S2 harness: both the cadence and the timeouts stay partly unmeasured. And none of them is a first-party measurement of the design point - they are decisions taken on the best available public evidence, each with its falsifier named, which is a different and more honest thing than a validated parameter.