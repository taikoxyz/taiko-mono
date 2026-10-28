#!/usr/bin/env python3
"""S3 F2: the 7-day cost decomposition, with its denominator made explicit.

The report's F2 table (l1-cost-fee-flow.md:75-78) presented
  base 0.039333 (24.1%) + priority 0.116723 (71.4%) + blob 0.003864 (2.4%) = 0.159920
against a 7-day total of 0.163428 (100%), i.e. shares summing to 97.9%.  The
cause: 33 of the 1,575 propose rows have a null baseFeePerGas in
propose-metrics.csv (their block headers were missing when analyze_l1.py ran),
so summary.json's base_fee_cost_wei / priority_cost_wei cover only 1,542 rows
while exec_cost_wei / blob_cost_wei / total_cost_wei cover 1,575.

This script closes the gap instead of leaving it implicit:
  * the 33 missing block headers were re-fetched with the canonical
    fetch_block_times.py (writes blockcache/<block>.json);
  * base and priority cost are then computed for all 1,575 rows, so the
    decomposition sums to the stated 7-day total and its shares to 100%;
  * the original 1,542-row subset is reported beside it, so the earlier figures
    remain checkable.

Reads propose-metrics.csv + blockcache/.  Writes fee-decomposition.json.
Usage: python3 fee_decomposition.py
"""
import csv, json, os

GAS_PER_BLOB = 131072


def main():
    rows = list(csv.DictReader(open("propose-metrics.csv")))
    assert len(rows) == 1575, len(rows)

    backfilled, still_missing = {}, []
    for r in rows:
        if r["baseFeePerGas"] == "None":
            bn = int(r["block"])
            p = os.path.join("blockcache", f"{bn}.json")
            if os.path.exists(p) and json.load(open(p)).get("baseFeePerGas"):
                backfilled[bn] = json.load(open(p))["baseFeePerGas"]
            else:
                still_missing.append(bn)
    if still_missing:
        raise SystemExit(f"missing block headers for {still_missing}; run fetch_block_times.py first")

    def decompose(sel):
        b = sum(int(r["gasUsed"]) * (int(r["baseFeePerGas"]) if r["baseFeePerGas"] != "None"
                                     else backfilled[int(r["block"])]) for r in sel)
        e = sum(int(r["exec_cost_wei"]) for r in sel)
        blob = sum(int(r["blob_cost_wei"]) for r in sel)
        return {"n_batches": len(sel), "base_fee_wei": b, "priority_wei": e - b, "blob_wei": blob,
                "exec_wei": e, "total_wei": e + blob}

    all_rows = rows
    subset = [r for r in rows if r["baseFeePerGas"] != "None"]
    d_all, d_sub = decompose(all_rows), decompose(subset)

    out = {
        "source": "propose-metrics.csv (1,575 rows) + blockcache/ (33 backfilled headers)",
        "n_batches_total": len(all_rows),
        "n_batches_with_base_fee_in_csv": len(subset),
        "n_batches_backfilled": len(backfilled),
        "backfilled_blocks": sorted(backfilled),
        "decomposition_all_1575": d_all,
        "decomposition_subset_1542": d_sub,
        "excluded_33_exec_wei": d_all["exec_wei"] - d_sub["exec_wei"],
    }

    def shares(d):
        t = d["total_wei"]
        return {"base": d["base_fee_wei"] / t, "priority": d["priority_wei"] / t, "blob": d["blob_wei"] / t}

    out["shares_all_1575"] = shares(d_all)
    json.dump(out, open("fee-decomposition.json", "w"), indent=1)

    for name, d in (("all 1,575 batches", d_all), ("the 1,542-row subset", d_sub)):
        s = shares(d)
        print(f"{name}:")
        print(f"  base fee (burned)   {d['base_fee_wei']/1e18:.6f} ETH  {s['base']*100:.1f}%")
        print(f"  priority fee        {d['priority_wei']/1e18:.6f} ETH  {s['priority']*100:.1f}%")
        print(f"  blob data           {d['blob_wei']/1e18:.6f} ETH  {s['blob']*100:.1f}%")
        print(f"  TOTAL               {d['total_wei']/1e18:.6f} ETH  {sum(s.values())*100:.1f}%")
    print()
    print("33 backfilled rows: exec %.6f ETH (%.2f%% of the week's cost); base %.6f / priority %.6f ETH" % (
        out["excluded_33_exec_wei"] / 1e18, 100 * out["excluded_33_exec_wei"] / d_all["total_wei"],
        (d_all["base_fee_wei"] - d_sub["base_fee_wei"]) / 1e18,
        (d_all["priority_wei"] - d_sub["priority_wei"]) / 1e18))
    print("5 backfilled blocks are prove-only (no propose row)" if len(backfilled) > 33 else "")


if __name__ == "__main__":
    main()
