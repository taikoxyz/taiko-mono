# raw/s1-public-data — evidence for the S1 public-data substitution

All times UTC. Everything here was produced on **2026-10-07** between 13:09Z and 14:00Z, from a
workspace copy of `taiko-mono`. Re-run instructions: `commands.log` (same directory); the scripts are
self-contained apart from `rpc.py` (a small JSON-RPC client with retry/backoff) and Python 3.9+
(`urllib`, `json`, `statistics` only — no third-party packages).

## Endpoints

| Purpose | Endpoint | Notes |
|---|---|---|
| L1 archive logs | https://gateway.tenderly.co/public/mainnet | serves `eth_getLogs` over 200k-block spans and includes `blockTimestamp` on each log |
| L1 block REST (cross-check, gas) | https://eth.blockscout.com/api/v2/blocks/&lt;n&gt; | independent of the RPC path |
| L1 fallbacks | https://rpc.mevblocker.io, https://ethereum-rpc.publicnode.com | single calls only (batches are rejected/deprioritised) |
| Taiko L2 | https://rpc.taiko.xyz | fast; used for block/tx/receipt reads |

## Files

### Inputs / raw fetches
| File | What it is |
|---|---|
| `inbox_logs_full.jsonl.gz` | every log emitted by the Shasta Inbox `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f` from its deployment block 24,585,332 to head 26,140,717 (48,716 logs; gzipped from 63 MB) |
| `inbox_logs_full.jsonl.meta.json` | endpoint, block range, chunk size, wall clock, elapsed seconds, exact command |
| `proposed_events.csv` | **Not committed (PR size, 2026-10-08):** 40,474 decoded `Proposed` events: block, blockTimestamp-independent fields, proposer, parent hash, endOfSubmissionWindowTimestamp, basefeeSharingPctg, numSources, numBlobs, numForcedInclusions. Re-create offline with `gunzip -c inbox_logs_full.jsonl.gz > inbox_logs_full.jsonl && python3 decode_events.py` |
| `proved_events.csv` | 8,224 decoded `Proved` events: block, first/firstNew/last proposal id, prover |
| `l2_sample_30d.jsonl` | every 100th Taiko L2 block, 11,072,005–12,368,005 (12,961 samples): timestamp, gasUsed, gasLimit, tx count, baseFee |
| `l2_payload_500.jsonl` | 422 consecutive L2 blocks (12,367,506–12,367,927): raw tx byte lengths, PRF-07(0) frame bytes, gas |
| `l2_payload_busy.jsonl` | L2 blocks from the 30-day sample that carry > 1 tx (768 requested): per-tx raw bytes and gas, anchor/user split, per-block b_payload |
| `block_times_30d.jsonl` | 401 blocks fetched from Blockscout REST — the independent cross-check of the log’s `blockTimestamp` (401/401 identical) |
| `thirdparty/*.html`, `thirdparty/ethproofs_*_extract.json`, `ethproofs_blocks_joined.json` | archived ethproofs.org pages and their embedded data (prover, hardware, proving time, proving cycles, cost) |
| `thirdparty/ethproofs_block_gas.json` | gasUsed measured by us for the 40 distinct L1 blocks those proofs cover |
| `thirdparty/succinct_16gpu_blocks_sample.json` | gasUsed for 25 sampled blocks of the range Succinct names in its 16-GPU claim |
| `thirdparty/ethresear_ch_opcode_proving.{html,txt}` | archived Nethermind/Taiko-funded per-opcode proving-time study |
| `thirdparty/taiko_proving_system.html`, `thirdparty/taiko_llms_full.txt` | archived docs.taiko.xyz pages (proving window, `BLOCK_ZK_GAS_LIMIT`) |

### Scripts and their outputs
| Script | Output | What it does |
|---|---|---|
| `rpc.py` | — | JSON-RPC with retry/backoff (used by everything) |
| `tx_blocks.py` | stdout | resolves the inbox deployment and upgrade transactions to blocks/timestamps |
| `fetch_inbox_logs.py` | `logs/inbox_logs_full.jsonl` | paginated `eth_getLogs` over the inbox address |
| `decode_events.py` | `proposed_events.csv` (not committed — PR size), `proved_events.csv` | ABI-decodes the two events, including blob counts |
| `fetch_block_times_blockscout.py` | `block_times_30d.jsonl` | independent timestamp source (used only for validation) |
| `verify_block_timestamps.py` | stdout | cross-checks log timestamps vs Blockscout; measures L1 block spacing |
| `analyze_cadence.py` | `cadence_analysis.txt` | cadence, intervals, proof latency, backlog for D30/D7/Unzen/all windows |
| `sample_l2.py` | `l2_sample_30d.jsonl` | systematic L2 block sample |
| `analyze_l2_sample.py`, `derive_live_rates.py` | stdout (`l2_sample_30d.meta.json`, `l2_payload_500.meta.json`) | L2 gas rate, gas/proposal, b_billed, G_L2_TARGET |
| `l2_payload.py`, `l2_payload_busy.py` | `l2_payload_500.jsonl`, `l2_payload_busy.jsonl` | PRF-07(0) framing bytes per block from raw transaction bytes |
| `check_l1_regular.py`, `check_window_relation.py`, `check_window_relation2.py` | stdout | negative results kept for the record: the L1-timestamp regularity probe that was abandoned once `blockTimestamp` was found, and the test of whether `endOfSubmissionWindowTimestamp` recovers block time (it is 0 — permissionless proposing disabled) |
| `thirdparty/extract_ethproofs*.py`, `ethproofs_gas_join2.py`, `ethproofs_stats.py` | `thirdparty/ethproofs_blocks_with_gas.json` | extracts the dashboard’s embedded data and joins it with on-chain gas |
| `thirdparty/succinct_blocks_sample.py` | `thirdparty/succinct_16gpu_blocks_sample.json` | gas sample for the Succinct claim range |
| `thirdparty/ethproofs_5090_medians.py` | `thirdparty/ethproofs_5090_medians.json`, `.txt` | RTX-5090 cluster medians from `ethproofs_blocks_joined.json` and their range/GPU-count span (review PB-L-01) |
| `anchor_only_recount.py` | `anchor-only-recount.json`, `.txt` | anchor-only count and §3.5 framing figures for the 422-block window (review PB-L-12) |

### Failed / abandoned attempts (kept, not used)
`probe_logs.json` (empty), `block_times.err` and `*.err` files: public endpoints returned 403/429 for
large or rapid batched archive requests, and `eth_getLogs` deeper than ~10k blocks is refused by
publicnode. These are why the final pipeline uses one 200k-block log fetch on the Tenderly gateway and
`blockTimestamp` instead of per-block fetches.

## Licence / provenance note
On-chain and RPC data are public chain data. Third-party pages are archived verbatim for reproducibility;
their content remains the property of their publishers and is quoted here under fair use for a technical
report.
