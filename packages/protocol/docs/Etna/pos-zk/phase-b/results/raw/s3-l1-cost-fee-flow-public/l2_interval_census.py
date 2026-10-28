#!/usr/bin/env python3
"""S3 F4: the L2 2-second interval census, from the cited raw file.

The report (l1-cost-fee-flow.md F4) claimed "L2 block time 2 s for
85,555 / 85,587 intervals (99.97%)".  Neither number exists in any raw
artifact: l2-two-day.csv has 86,356 contiguous rows, so the two natural
populations are

  * intervals within a batch  = 86,356 - 451 proposals = 85,905 (the pair of
    consecutive blocks that share a proposalId; the first block of a batch has
    no within-batch predecessor);
  * all consecutive intervals = 86,356 - 1 = 86,355.

This script counts, over each population, how many consecutive block pairs are
exactly 2 s apart, and reports the non-2 s pairs.  It also re-derives the F4/F8
mean L2 gas per block (11,168,016,854 / 86,356) that F4 rounds to 129,389.

Writes l2-interval-census.json.  Usage: python3 l2_interval_census.py
"""
import csv, json, statistics

rows = list(csv.DictReader(open("l2-two-day.csv")))
nums = [int(r["number"]) for r in rows]
ts = [int(r["ts"]) for r in rows]
pids = [int(r["proposalId"]) for r in rows]
gas = [int(r["gasUsed"]) for r in rows]

out = {
    "source": "l2-two-day.csv",
    "rows": len(rows),
    "block_range": [min(nums), max(nums)],
    "contiguous": all(b - a == 1 for a, b in zip(nums, nums[1:])),
    "null_fields": sum(1 for r in rows for v in r.values() if v in ("", "None")),
    "distinct_proposal_ids": len(set(pids)),
    "total_l2_gas": sum(gas),
}

groups = {}
# within-batch: consecutive rows with the same proposalId
within = [(i, ts[i + 1] - ts[i]) for i in range(len(rows) - 1) if pids[i] == pids[i + 1]]
allpairs = [(i, ts[i + 1] - ts[i]) for i in range(len(rows) - 1)]
for name, pairs in (("within_batch", within), ("all_consecutive", allpairs)):
    d = {}
    for i, dt in pairs:
        d[dt] = d.get(dt, 0) + 1
    exact2 = d.get(2, 0)
    out[name] = {
        "intervals": len(pairs),
        "exactly_2s": exact2,
        "pct_2s": 100.0 * exact2 / len(pairs),
        "non_2s": {str(k): v for k, v in sorted(d.items()) if k != 2},
    }
out["mean_l2_gas_per_block"] = sum(gas) / len(gas)
out["median_l2_gas_per_block"] = statistics.median(gas)
json.dump(out, open("l2-interval-census.json", "w"), indent=1)

print(f"rows {len(rows)}  range {min(nums)}-{max(nums)}  contiguous={out['contiguous']}  "
      f"nulls={out['null_fields']}  proposals={out['distinct_proposal_ids']}")
for name in ("within_batch", "all_consecutive"):
    c = out[name]
    print(f"{name:15s}: {c['exactly_2s']}/{c['intervals']} at exactly 2 s = {c['pct_2s']:.4f}%   "
          f"non-2 s {c['non_2s']}")
print(f"total L2 gas {sum(gas)} -> mean {out['mean_l2_gas_per_block']:.2f}, median {out['median_l2_gas_per_block']}")
print()
print("non-2 s intervals (all consecutive):")
for i, dt in allpairs:
    if dt != 2:
        print(f"  L2 {nums[i]} -> {nums[i+1]}  {dt} s  proposalId {pids[i]} -> {pids[i+1]}")
