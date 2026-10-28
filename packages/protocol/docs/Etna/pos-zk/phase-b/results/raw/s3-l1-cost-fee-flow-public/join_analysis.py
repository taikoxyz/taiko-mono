#!/usr/bin/env python3
"""Join L1 propose cost with L2 gas per proposal (from the L2 extraData census)."""
import json, os, statistics as st
from collections import Counter

def pct(xs, p):
    xs = sorted(x for x in xs if x is not None)
    if not xs: return None
    k = (len(xs) - 1) * p / 100.0
    f = int(k); c = min(f + 1, len(xs) - 1)
    return xs[f] + (xs[c] - xs[f]) * (k - f)

def stats(xs):
    xs = [x for x in xs if x is not None]
    return {"n": len(xs), "min": min(xs), "p10": pct(xs, 10), "p50": pct(xs, 50), "mean": sum(xs) / len(xs),
            "p90": pct(xs, 90), "p99": pct(xs, 99), "max": max(xs)}

def main():
    l2 = json.load(open("l2-two-day.json"))
    groups = {g["proposalId"]: g for g in l2["groups"]}
    logs = json.load(open("proposed-logs.json"))
    win = json.load(open("window.json"))["window"]
    import csv
    metrics = {}
    with open("propose-metrics.csv") as f:
        for r in csv.DictReader(f):
            metrics[r["hash"]] = r
    rows = []
    for l in logs:
        pid = int(l["topics"][1], 16)
        g = groups.get(pid)
        m = metrics.get(l["transactionHash"])
        if not g or not m:
            continue
        # keep only proposals wholly inside the L2 census window (drop edge partials)
        if g["blockFirst"] <= l2["l2_start"] or g["blockLast"] >= l2["l2_end"]:
            continue
        gas_l2 = g["gasUsed"]
        l1_total = float(m["total_cost_wei"]) / 1e18
        l1_exec = float(m["exec_cost_wei"]) / 1e18
        l1_blob = float(m["blob_cost_wei"]) / 1e18
        base_fee = m["baseFeePerGas"]
        rows.append({
            "proposalId": pid, "l1_tx": l["transactionHash"], "l1_block": int(l["blockNumber"], 16),
            "l2_blocks": g["blocks"], "l2_gas": gas_l2,
            "l2_gas_per_block": gas_l2 / g["blocks"],
            "l1_cost_eth": l1_total, "l1_exec_eth": l1_exec, "l1_blob_eth": l1_blob,
            "cost_per_l2_block_eth": l1_total / g["blocks"],
            "cost_per_l2_gas_wei": (l1_total * 1e18) / gas_l2,
            "l1_effective_gas_price": int(m["effectiveGasPrice"]),
            "l2_base_fee": g["baseFees"][0] if len(g["baseFees"]) == 1 else None,
            "l2_base_fee_revenue_eth": gas_l2 * (g["baseFees"][0] if len(g["baseFees"]) == 1 else 0) / 1e18,
            "miner": g["miners"][0] if len(g["miners"]) == 1 else None,
            "ts_first": g["tsFirst"], "ts_last": g["tsLast"],
        })
    rows.sort(key=lambda r: r["proposalId"])
    with open("join-metrics.csv", "w") as f:
        if rows:
            cols = list(rows[0].keys()); f.write(",".join(cols) + "\n")
            for r in rows: f.write(",".join(str(r[c]) for c in cols) + "\n")
    out = {"l2_window": {"l2_start": l2["l2_start"], "l2_end": l2["l2_end"]},
           "l1_window": win, "n_joined": len(rows),
           "l2_blocks_per_proposal": stats([r["l2_blocks"] for r in rows]),
           "l2_gas_per_proposal": stats([r["l2_gas"] for r in rows]),
           "l1_cost_eth": stats([r["l1_cost_eth"] for r in rows]),
           "cost_per_l2_block_eth": stats([r["cost_per_l2_block_eth"] for r in rows]),
           "cost_per_l2_gas_wei": stats([r["cost_per_l2_gas_wei"] for r in rows]),
           "l1_effective_gas_price": stats([r["l1_effective_gas_price"] for r in rows]),
           "l2_base_fee_dist": dict(Counter(r["l2_base_fee"] for r in rows)),
           "l2_base_fee_revenue_eth_total": sum(r["l2_base_fee_revenue_eth"] for r in rows),
           "l1_cost_eth_total": sum(r["l1_cost_eth"] for r in rows),
           "miner_dist": dict(Counter(r["miner"] for r in rows))}
    json.dump(out, open("join-summary.json", "w"), indent=1, default=str)
    print(json.dumps(out, indent=1, default=str))

if __name__ == "__main__":
    main()
