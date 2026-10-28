# Phase B results — review entry point

Phase B of the Etna PoS/ZK programme ran five spike specifications (S1–S5) against public
data. This directory holds the results:

| Report | Spike |
|---|---|
| [proving-throughput.md](./proving-throughput.md) | S1 — proving throughput |
| [round-timing.md](./round-timing.md) | S2 — round timing |
| [l1-cost-fee-flow.md](./l1-cost-fee-flow.md) | S3 — L1 cost and fee flow |
| [blob-binding.md](./blob-binding.md) | S4 — blob binding review |
| [SYNTHESIS.md](./SYNTHESIS.md) | cross-spike synthesis |

[../README-public-data.md](../README-public-data.md) records how the public-data
programme relates to the spike specifications ([../README.md](../README.md), S1–S5).

`raw/` holds the evidence. Every script, every aggregate JSON and every command record
(`COMMANDS.md`, `commands.log`, the command lists inside each `README.md`) is committed, so
each report's figures can be checked without re-running a fetch wherever an aggregate exists,
and re-fetched from a named script where one does not.

## Datasets dropped from `raw/` (2026-10-08)

Four fetched CSVs — each several MB and tens of thousands of rows, together the bulk of the
pull request's line count — were removed to keep this PR reviewable. Nothing else was removed:
all scripts, aggregate JSON, logs, block headers, sidecars, third-party sources and command
records remain, and no report conclusion or measured value was changed.

| Dropped file | Size | Data rows | Re-created by | Needs RPC |
|---|---|---|---|---|
| `raw/s3-l1-cost-fee-flow-public/l2-two-day.csv` | 8,376,604 B | 86,356 | `python3 collect_l2.py 12257702 12344057 l2-two-day.json` (run in `raw/s3-l1-cost-fee-flow-public/`) | yes — Taiko Alethia RPCs listed in that directory's `README.md` |
| `raw/s4-blob-binding/proposals.csv` | 9,016,011 B | 40,475 | `python3 scan_chunks.py 24792175 26140717 .` then `python3 finish_scan2.py 25922175 26140717 .` then `python3 decode_proposed.py .` (run in `raw/s4-blob-binding/`) | yes — Ethereum mainnet RPCs listed in `raw/s4-blob-binding/COMMANDS.md` |
| `raw/s4-blob-binding/proposals_by_tx.csv` | 11,469,376 B | 40,474 | same three commands as `proposals.csv` | yes — as above |
| `raw/s1-public-data/proposed_events.csv` | 8,432,694 B | 40,474 | `gunzip -c inbox_logs_full.jsonl.gz > inbox_logs_full.jsonl && python3 decode_events.py` (run in `raw/s1-public-data/`) | no — it decodes the committed `inbox_logs_full.jsonl.gz` |

The exact commands are also recorded in each directory's own command record (annotated at the
point of use): `raw/s4-blob-binding/COMMANDS.md` §1, `raw/s3-l1-cost-fee-flow-public/README.md`
("Dropped for PR size"), and `raw/s1-public-data/commands.log` §2.

**Figure traceability after the drop.**

- **S1.** `proposed_events.csv` is a decode of the committed `inbox_logs_full.jsonl.gz`;
  `decode_events.py` re-creates it offline. Its consumers' outputs are committed
  (`anchor-only-share.json`, `anchor-only-recount.json`, `probe_logs.json`,
  `cadence_analysis.txt`), and `proved_events.csv` is unaffected.
- **S3.** The L2 census figures (`86,356` blocks, interval counts, per-block fees) are carried by
  committed aggregates — `l2-interval-census.json`, `fee-decomposition.json`,
  `l2-two-day.json`, `summary.json` — re-derived by committed scripts
  (`l2_interval_census.py`, `fee_decomposition.py`, `analyze_l1.py`) once the CSV is
  re-created. The dropped CSV's SHA-256 remains recorded in `l1-cost-fee-flow.md` §6.
- **S4.** The Shasta census counts (`40,474` logs, `40,473` blob-carrying proposals,
  `40,491` blobs) are committed in `raw/s4-blob-binding/summary.json`; the every-20th-block
  sample and its price statistics are committed in `headers-sample.jsonl` and
  `f3-sample-and-probe.json`, produced by `header_sample.py`/`f3_sample_and_probe.py` from
  the re-created CSVs.

**Before / after.** `raw/` was **96,458,943 bytes across 2,148 files**; after the drop it is
**59,164,258 bytes across 2,144 files** (four files removed, 37,294,685 bytes).
