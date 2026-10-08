#!/usr/bin/env python3
"""Fee-coverage arithmetic: L2 fee revenue per proposal vs L1 landing + on-chain proving."""
import json, csv, statistics as st

def pct(xs, p):
    xs = sorted(x for x in xs if x is not None)
    k = (len(xs) - 1) * p / 100.0
    f = int(k); c = min(f + 1, len(xs) - 1)
    return xs[f] + (xs[c] - xs[f]) * (k - f)

def stats(xs):
    xs = [x for x in xs if x is not None]
    return {"n": len(xs), "min": min(xs), "p10": pct(xs, 10), "p50": pct(xs, 50), "mean": sum(xs) / len(xs),
            "p90": pct(xs, 90), "p99": pct(xs, 99), "max": max(xs)}

def main():
    smp = json.load(open("l2-fee-sample-hour.json"))
    jm = {}
    with open("join-metrics.csv") as f:
        for r in csv.DictReader(f):
            jm[int(r["proposalId"])] = r
    summ = json.load(open("summary.json"))
    prove_eth_per_proposal = summ["prove"]["eth_per_newly_proven_proposal"]

    # proposals fully inside the sampled hour
    groups = [g for g in smp["groups"] if g["blockFirst"] > smp["l2_from"] and g["blockLast"] < smp["l2_to"]]
    rows = []
    for g in groups:
        j = jm.get(g["proposalId"])
        rows.append({
            "proposalId": g["proposalId"], "l2_blocks": g["blocks"], "l2_gas": g["gasUsed"],
            "l2_base_fee_eth": g["baseTotal_wei"] / 1e18,
            "l2_priority_fee_eth": g["priorityTotal_wei"] / 1e18,
            "l2_fee_total_eth": g["feeTotal_wei"] / 1e18,
            "l1_propose_eth": float(j["l1_cost_eth"]) if j else None,
            "l1_prove_amortized_eth": prove_eth_per_proposal,
            "l1_total_eth": (float(j["l1_cost_eth"]) + prove_eth_per_proposal) if j else None,
        })
        if rows[-1]["l1_total_eth"]:
            rows[-1]["coverage_total_fees"] = rows[-1]["l2_fee_total_eth"] / rows[-1]["l1_total_eth"]
            rows[-1]["coverage_base_fee_only"] = rows[-1]["l2_base_fee_eth"] / rows[-1]["l1_total_eth"]
    with open("coverage-metrics.csv", "w") as f:
        if rows:
            cols = list(rows[0].keys()); f.write(",".join(cols) + "\n")
            for r in rows: f.write(",".join(str(r[c]) for c in cols) + "\n")

    hour = {"l2_from": smp["l2_from"], "l2_to": smp["l2_to"], "blocks": len(smp["rows"]),
            "gas": sum(r["gasUsed"] for r in smp["rows"]),
            "fee_total_eth": sum(r["feeTotal_wei"] for r in smp["rows"]) / 1e18,
            "base_total_eth": sum(r["baseTotal_wei"] for r in smp["rows"]) / 1e18,
            "priority_total_eth": sum(r["priorityTotal_wei"] for r in smp["rows"]) / 1e18,
            "proposals_fully_covered": len(rows)}
    hour["priority_share"] = hour["priority_total_eth"] / hour["fee_total_eth"]
    hour["fee_per_l2_gas_wei"] = hour["fee_total_eth"] * 1e18 / hour["gas"]

    out = {"hour": hour,
           "prove_eth_per_proposal": prove_eth_per_proposal,
           "per_proposal": {k: stats([r[k] for r in rows]) for k in
                            ["l2_blocks", "l2_gas", "l2_base_fee_eth", "l2_priority_fee_eth", "l2_fee_total_eth",
                             "l1_propose_eth", "l1_total_eth", "coverage_total_fees", "coverage_base_fee_only"]},
           "aggregate": {
               "l2_fees_eth": sum(r["l2_fee_total_eth"] for r in rows),
               "l2_base_fees_eth": sum(r["l2_base_fee_eth"] for r in rows),
               "l1_propose_eth": sum(r["l1_propose_eth"] for r in rows if r["l1_propose_eth"]),
               "l1_prove_amortized_eth": prove_eth_per_proposal * len(rows),
           }}
    a = out["aggregate"]
    a["l1_total_eth"] = a["l1_propose_eth"] + a["l1_prove_amortized_eth"]
    a["coverage_total_fees"] = a["l2_fees_eth"] / a["l1_total_eth"]
    a["coverage_base_fee_only"] = a["l2_base_fees_eth"] / a["l1_total_eth"]
    # cost floor per L2 gas implied by L1 costs at the sampled hour's batch sizes
    a["l1_cost_per_l2_gas_wei"] = a["l1_total_eth"] * 1e18 / sum(r["l2_gas"] for r in rows)
    a["l2_fee_per_l2_gas_wei"] = a["l2_fees_eth"] * 1e18 / sum(r["l2_gas"] for r in rows)
    json.dump(out, open("coverage-summary.json", "w"), indent=1)
    print(json.dumps(out, indent=1))

if __name__ == "__main__":
    main()
