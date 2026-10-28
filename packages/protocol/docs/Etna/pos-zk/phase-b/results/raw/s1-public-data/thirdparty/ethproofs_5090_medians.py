#!/usr/bin/env python3
"""S1 §3.8: RTX-5090 cluster medians and the range the report quotes.

The report (SYNTHESIS.md (a) row 36; proving-throughput.md §5 row 5) claimed
"3.4-12.6 Mgas/s on 4-16x RTX 5090 clusters".  Neither endpoint reproduces from
the cited raw file, and the table itself prints four 2x-5090 clusters.  This
script recomputes both the range and the cluster-size span from
ethproofs_blocks_joined.json (the reviewer's PB-L-01 derivation).

A cluster counts as RTX 5090 if the published hardware string or the cluster
name says 5090; ZKM (hardware not published) and cysic (RTX 4090) are excluded
from the 5090 range and reported separately.

Writes: ethproofs_5090_medians.json and prints the same table.
Usage:  python3 ethproofs_5090_medians.py
"""
import json, re, statistics

recs = json.load(open("ethproofs_blocks_joined.json"))
good = [r for r in recs if r.get("gas_used") and r.get("proving_ms") and r.get("cycles")]
for r in good:
    r["gas_per_sec"] = r["gas_used"] / (r["proving_ms"] / 1000.0)

by = {}
for r in good:
    by.setdefault(r["cluster"], []).append(r)


def is_5090(cluster, hw):
    return "5090" in cluster or "5090" in (hw or "")


def gpu_count(cluster, hw):
    m = re.search(r"(\d+)\s*x", cluster) or re.search(r"(\d+)\s*x", hw or "")
    return int(m.group(1)) if m else None


rows = []
for c, rs in by.items():
    hw = rs[0]["hw"]
    rows.append({
        "cluster": c, "hardware": hw, "n": len(rs),
        "median_gas_per_sec": statistics.median([x["gas_per_sec"] for x in rs]),
        "median_cycles_per_gas": statistics.median([x["cycles"] / x["gas_used"] for x in rs]),
        "median_secs": statistics.median([x["proving_ms"] / 1000.0 for x in rs]),
        "is_5090": is_5090(c, hw), "gpus": gpu_count(c, hw),
    })
rows.sort(key=lambda r: -r["median_gas_per_sec"])

m5090 = [r for r in rows if r["is_5090"]]
gpu_counts = sorted({r["gpus"] for r in m5090 if r["gpus"]})
rec_gps = [x["gas_per_sec"] for r in m5090 for x in by[r["cluster"]]]

out = {
    "source": "ethproofs_blocks_joined.json",
    "records_total": len(recs), "records_with_gas_time_cycles": len(good),
    "distinct_blocks_all": len({r["block"] for r in recs}),
    "distinct_blocks_good": len({r["block"] for r in good}),
    "block_gas_used": {"min": min(r["gas_used"] for r in good),
                       "median": statistics.median([r["gas_used"] for r in good]),
                       "max": max(r["gas_used"] for r in good)},
    "cluster_medians": rows,
    "range_5090_cluster_medians_gas_per_sec": [min(r["median_gas_per_sec"] for r in m5090),
                                               max(r["median_gas_per_sec"] for r in m5090)],
    "range_5090_record_level_gas_per_sec": [min(rec_gps), max(rec_gps)],
    "rtx5090_cluster_gpu_counts": gpu_counts,
}
json.dump(out, open("ethproofs_5090_medians.json", "w"), indent=1)

print("%-28s %-46s %3s %8s %9s %10s %5s %5s" %
      ("cluster", "hardware", "n", "med_s", "cyc/gas", "Mgas/s", "5090", "GPUs"))
for r in rows:
    print("%-28s %-46s %3d %8.2f %9.2f %10.3f %5s %5s" %
          (r["cluster"][:28], (r["hardware"] or "?")[:46], r["n"], r["median_secs"],
           r["median_cycles_per_gas"], r["median_gas_per_sec"] / 1e6,
           r["is_5090"], r["gpus"]))
lo, hi = out["range_5090_cluster_medians_gas_per_sec"]
rlo, rhi = out["range_5090_record_level_gas_per_sec"]
print()
print("RTX-5090 cluster medians: %.6f - %.6f Mgas/s (%d clusters)" % (lo / 1e6, hi / 1e6, len(m5090)))
print("RTX-5090 record level:    %.6f - %.6f Mgas/s" % (rlo / 1e6, rhi / 1e6))
print("RTX-5090 cluster sizes:   %s" % (", ".join("%dx" % g for g in gpu_counts)))
print("records %d, with gas+time+cycles %d, distinct blocks %d (all) / %d (complete subset)" %
      (len(recs), len(good), out["distinct_blocks_all"], out["distinct_blocks_good"]))
print("block gasUsed: min %d median %d max %d" %
      (out["block_gas_used"]["min"], out["block_gas_used"]["median"], out["block_gas_used"]["max"]))
