#!/usr/bin/env python3
"""Sensitivity of the coverage ratio to the L1 execution price, using measured inputs.

Assumption (labelled in the report): propose and prove transactions pay the same L1
effective gas price at a given percentile, and L2 fee revenue is held at the measured
sampled-hour per-batch value. Both are observed quantities held fixed, not modelled.
"""
import csv, json

def pct(xs, p):
    xs = sorted(xs)
    k = (len(xs) - 1) * p / 100.0
    f = int(k); c = min(f + 1, len(xs) - 1)
    return xs[f] + (xs[c] - xs[f]) * (k - f)

def main():
    prop = list(csv.DictReader(open("propose-metrics.csv")))
    prov = list(csv.DictReader(open("prove-metrics.csv")))
    cov = json.load(open("coverage-summary.json"))
    gas_p = sorted(int(r["gasUsed"]) for r in prop)
    gas_v = sorted(int(r["gasUsed"]) for r in prov)
    egp_p = [int(r["effectiveGasPrice"]) for r in prop]
    egp_v = [int(r["effectiveGasPrice"]) for r in prov]
    per_batch_fees = cov["aggregate"]["l2_fees_eth"] / 8          # sampled hour, per proposal
    per_batch_base = cov["aggregate"]["l2_base_fees_eth"] / 8
    per_batch_prio = per_batch_fees - per_batch_base
    g_p = pct(gas_p, 50)
    g_v = pct(gas_v, 50)
    rows = []
    for label, p in [("p10", 10), ("p50", 50), ("p90", 90), ("p99", 99), ("max", 100)]:
        e = pct(egp_p, p)
        propose = g_p * e / 1e18
        ev = pct(egp_v, p)
        prove = g_v * ev / 1e18 / 5
        total = propose + prove
        rows.append({"point": label, "propose_egp_wei": e, "prove_egp_wei": ev,
                     "l1_propose_eth": propose, "l1_prove_amortized_eth": prove, "l1_total_eth": total,
                     "l2_fees_eth": per_batch_fees,
                     "coverage_all_fees": per_batch_fees / total,
                     "coverage_base_fee_only": per_batch_base / total,
                     "proposer_only_revenue_eth": 0.75 * per_batch_base + per_batch_prio,
                     "coverage_proposer_only": (0.75 * per_batch_base + per_batch_prio) / total})
    out = {"assumptions": ["propose and prove pay the same L1 effective gas price percentile",
                           "L2 per-batch fee revenue = measured 2026-10-06 12:00-13:00 UTC aggregate / 8 proposals",
                           "L2 base fee 75% to proposer / 25% to treasury (docs.taiko.xyz + taiko-geth source)"],
           "inputs": {"propose_gas_median": g_p, "prove_gas_median": g_v,
                      "per_batch_l2_fees_eth": per_batch_fees, "per_batch_l2_base_eth": per_batch_base,
                      "per_batch_l2_priority_eth": per_batch_prio},
           "points": rows}
    json.dump(out, open("sensitivity.json", "w"), indent=1)
    print(json.dumps(out, indent=1))

if __name__ == "__main__":
    main()
