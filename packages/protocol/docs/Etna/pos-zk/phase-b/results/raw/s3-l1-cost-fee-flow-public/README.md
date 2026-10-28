# S3 public-data raw evidence — Taiko (Unzen) on Ethereum mainnet

Collector slug: `s3-l1-cost-fee-flow-public` · Collected 2026-10-07 (UTC) · Repo commit `66a6fbec63911e17cd1c71c97f444fba54a6fcc0`
Report: [../../l1-cost-fee-flow.md](../../l1-cost-fee-flow.md)

This directory is write-once raw evidence plus the scripts that produced it. Every
number in the report is reproducible by re-running the scripts in order (they cache
per chunk and resume; any RPC may rate-limit, so retries are built in).

## Windows

| Item | Value |
|---|---|
| L1 census window | blocks 26,086,570 – 26,136,782 = 2026-09-30T00:00:11Z – 2026-10-07T00:00:11Z (50,213 L1 blocks) |
| L2 census window | L2 blocks 12,257,702 – 12,344,057 = 2026-10-05T00:00:01Z – 2026-10-07T00:00:01Z (86,356 L2 blocks) |
| L2 fee sample | L2 blocks 12,322,459 – 12,324,258 = 2026-10-06T12:00:01Z – 12:59:59Z (1,800 L2 blocks) |
| L1 = Ethereum mainnet (chain id 1); L2 = Taiko Alethia (chain id 167000) | |

## Scripts (run in this order)

| Script | What it does |
|---|---|
| `collect_l1.py <start_ts> <end_ts> <Proved topic0>` | Fetches all Inbox logs, propose/prove txs + receipts, L1 fee history. Caches per chunk. |
| `fetch_logs_fast.py <from> <to> <step>` | Optional prefill of the log cache via a tenderly-first endpoint rotation (needed when publicnode/drpc reject archive log ranges). |
| `fetch_block_times.py propose-txs.json prove-txs.json` | Block headers (timestamp, base fee) for every propose/prove block. |
| `collect_l2.py <l2_from> <l2_to> <out.json>` | Taiko L2 block headers; writes per-block CSV and per-proposal groups (extraData byte0 = basefeeSharingPctg, bytes1..6 = proposalId). |
| `sample_l2_fees.py <l2_from> <l2_to> <out.json>` | Header + `eth_getBlockReceipts` per L2 block; exact base/priority fee totals. |
| `analyze_l1.py` | Per-batch L1 cost, decomposition, price percentiles, cost curve → `summary.json`, `propose-metrics.csv`, `prove-metrics.csv`. |
| `join_analysis.py` | Joins L1 propose cost to L2 gas per proposal → `join-metrics.csv`, `join-summary.json`. |
| `coverage.py` | L2 fee revenue vs L1 landing + on-chain proving for the sampled hour → `coverage-summary.json`. |
| `sensitivity.py` | Coverage vs L1 effective gas price percentiles → `sensitivity.json`. |
| `refill_txcache.py`, `fix_l2_nulls.py` | Repair helpers for entries that the batch fetchers returned null for; used once each. |

Review-fix scripts (added 2026-10-07 after the adversarial review; read-only over the files above,
except `fetch_block_times.py`, which backfills the 33 missing headers):

| Script | What it does |
|---|---|
| `fee_decomposition.py` | Recomputes the F2 decomposition over all 1,575 batches (33 headers backfilled) → `fee-decomposition.json` (review PB-L-03) |
| `l2_interval_census.py` | Counts 2 s intervals within batches and across all consecutive pairs → `l2-interval-census.json` (review PB-L-04, PB-L-10) |
| `blob_breakeven.py` | Derives the F8 break-even blob base fee from the sampled hour → `blob-breakeven.json` (review PB-L-08) |
| `kraken_window_stats.py` | In-window Kraken closes and the REWARD_QUOTE USD range → `kraken-window-stats.json` (review PB-L-11) |

Exact commands used (in the order run):

```bash
cd packages/protocol/docs/Etna/pos-zk/phase-b/results/raw/s3-l1-cost-fee-flow-public
python3 fetch_logs_fast.py 26086570 26136782 8000
python3 collect_l1.py 1790726400 1791331200 0xa274dcaff3629ec7d69d144038e97732516ff306fcbf8a2bc9423d106779a2f0
python3 refill_txcache.py
python3 fetch_block_times.py propose-txs.json prove-txs.json
python3 analyze_l1.py
python3 collect_l2.py 12257702 12344057 l2-two-day.json
python3 fix_l2_nulls.py && python3 collect_l2.py 12257702 12344057 l2-two-day.json
python3 join_analysis.py
python3 sample_l2_fees.py 12322459 12324258 l2-fee-sample-hour.json
python3 coverage.py
python3 sensitivity.py
# review fixes (2026-10-07): backfill the 33 missing propose headers, then the derivations
python3 fetch_block_times.py propose-txs.json prove-txs.json
python3 fee_decomposition.py
python3 l2_interval_census.py
python3 blob_breakeven.py
python3 kraken_window_stats.py
```

Endpoints used (public, no API key): ethereum-rpc.publicnode.com, eth.drpc.org,
rpc.mevblocker.io, gateway.tenderly.co/public/mainnet, eth.blockrazor.xyz,
rpc.flashbots.net; Taiko: taiko-rpc.publicnode.com, taiko.drpc.org,
rpc.ankr.com/taiko, taiko-mainnet.gateway.tenderly.co, rpc.taiko.xyz.

## Files

| File | Content |
|---|---|
| `window.json` | Chain id, Inbox address, topic0s, exact block window and timestamps. |
| `inbox-logs.json` | Every log emitted by the Inbox proxy in the window (1,890: 1,575 Proposed, 315 Proved). |
| `proposed-logs.json`, `proved-logs.json` | The same logs split by event. |
| `propose-txs.json`, `prove-txs.json` | Full transactions and receipts for every propose/prove tx (1,575 / 315). |
| `l1-fee-history.json` | Per-block `baseFeePerGas`, `baseFeePerBlobGas`, gas/blob usage ratios for 50,264 blocks. |
| `blockcache/` | Per-block header (timestamp, base fee, blob gas) for propose/prove blocks. |
| `l2-two-day.json` | L2 census: per-proposal groups and per-block rows (86,356 rows). The collector's `l2-two-day.csv` output is not committed — see "Dropped for PR size" below. |
| `l2-fee-sample-hour.json` | Exact per-block and per-proposal L2 base/priority fee totals for the sampled hour. |
| `identification.txt` | Address-confirmation commands and outputs (chain id, code size, EIP-1967 slot, getConfig, verifier getters, topic0s). |
| `mainnet-contract-logs-L1.md` | Copy of the repo's deployment log (address provenance). |
| `taiko-docs-contract-addresses.html`, `protocol-*.html/.txt` | Copied Taiko documentation pages used for address and fee-flow statements. |
| `taikogeth-state_transition-taiko.go` | taiko-geth (branch `taiko`) state transition: base-fee split and treasury address derivation. |
| `kraken-ethusd-hourly.json` | Third-party ETH/USD hourly OHLC (Kraken public API) used for all USD conversions. |
| `propose-metrics.csv`, `prove-metrics.csv` | One row per propose/prove tx with every measured field and derived cost. |
| `summary.json`, `join-summary.json`, `coverage-summary.json`, `sensitivity.json`, `fee-percentiles.json` | Machine-readable results cited by the report. |
| `*.log` | Collector stdout (progress, retries, exit codes). |

SHA-256 of the principal artifacts is listed in section 6 of the report.
## Cache trimming (2026-10-07)

The per-chunk fetch caches (`l2chunks/`, `logchunks/`, `txcache/`, `feesample/`,
≈175 MB) were removed **after** the assembled files above were verified complete
(`l2-two-day.csv` = 86,356 rows, `inbox-logs.json` = 1,890 logs, `propose-txs.json` =
1,575 entries with no nulls, `l2-fee-sample-hour.json` = 1,800 rows). The assembled
files contain every field used by the analysis; re-running any collector re-creates
its cache. `blockcache/` is kept because `analyze_l1.py` reads it directly.

The full analysis chain was re-run from the assembled files after trimming and
reproduced the same numbers (`CHAIN OK`: total 0.16342765500568926 ETH,
coverage 1.1353403813841771 / 1.074747630473348).

## Dropped for PR size (2026-10-08)

`l2-two-day.csv` (86,356 data rows, 8,376,604 B) was removed from the committed evidence to keep
the pull request reviewable: it is fetched data whose figures are carried by committed aggregates.
It is the collector's own CSV output and is re-created by the command already listed above,
against the public Taiko Alethia RPCs in the endpoint list:

    python3 collect_l2.py 12257702 12344057 l2-two-day.json

`l2-two-day.json` (the same run's per-group output), every review-fix aggregate
(`l2-interval-census.json`, `fee-decomposition.json`, `blob-breakeven*.json`,
`kraken-window-stats.json`) and every script remain committed. `l2_interval_census.py`
re-derives the census counts once the CSV is re-created, and the SHA-256 of the dropped CSV
remains recorded in section 6 of `l1-cost-fee-flow.md`. See `../../README.md`
"Datasets dropped from raw/".
