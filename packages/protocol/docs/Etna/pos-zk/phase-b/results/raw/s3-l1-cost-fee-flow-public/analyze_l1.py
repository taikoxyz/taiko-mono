#!/usr/bin/env python3
"""S3 analysis: per-batch L1 cost, decomposition, cost curve and fee-coverage inputs.

Reads the raw caches produced by collect_l1.py / collect_l2.py / fetch_block_times.py
and writes propose-metrics.csv, prove-metrics.csv and summary.json.
Every figure printed here is a function of the raw files named in summary.json.
"""
import json, os, sys, statistics as st, datetime as dt

BLOCK_GAS = 21000
CALldata_ZERO = 4
CALLDATA_NONZERO = 16
GAS_PER_BLOB = 131072

def pct(xs, p):
    xs = sorted(x for x in xs if x is not None)
    if not xs: return None
    k = (len(xs) - 1) * p / 100.0
    f = int(k); c = min(f + 1, len(xs) - 1)
    return xs[f] + (xs[c] - xs[f]) * (k - f)

def load(p):
    return json.load(open(p))

def hexbytes(b):
    return (len(b) - 2) // 2

def calldata_bytes(b):
    raw = bytes.fromhex(b[2:])
    z = raw.count(0)
    return z, len(raw) - z, len(raw)

def main():
    base = os.path.dirname(os.path.abspath(__file__))
    os.chdir(base)
    win = load("window.json")
    logs = load("inbox-logs.json")
    prop_logs = load("proposed-logs.json")
    prov_logs = load("proved-logs.json")
    ptx = load("propose-txs.json")
    vtx = load("prove-txs.json")
    # fee history assembled from the per-chunk raw responses (field name is baseFeePerBlobGas)
    fh = load("l1-fee-history.json")

    w = win["window"]
    print("window blocks", w["start_block"], "-", w["end_block"], "ts", w["start_block_ts"], "-", w["end_block_plus1_ts"])

    # event census
    from collections import Counter
    tc = Counter(l["topics"][0] for l in logs)
    print("event topic census:")
    known = {win["topic_proposed"]: "Proposed", win["topic_proved"]: "Proved"}
    for t, n in tc.most_common():
        print("   ", known.get(t, "(unlabelled)"), t, n)

    # hourly ETH/USD from kraken
    kr = load("kraken-ethusd-hourly.json")["result"]
    kk = [k for k in kr if k != "last"][0]
    hourly = {int(r[0]): float(r[4]) for r in kr[kk]}   # close price
    def usd_at(ts):
        h = ts - (ts % 3600)
        return hourly.get(h) or hourly.get(h - 3600) or hourly.get(h + 3600)

    # block headers cache
    def header(bn):
        p = os.path.join("blockcache", f"{bn}.json")
        return load(p) if os.path.exists(p) else None

    rows = []
    for h, tx in ptx["txs"].items():
        rc = ptx["receipts"].get(h)
        if not tx or not rc:
            continue
        bn = int(rc["blockNumber"], 16)
        hd = header(bn)
        ts = hd["timestamp"] if hd else None
        z, nz, tot = calldata_bytes(tx["input"])
        gas = int(rc["gasUsed"], 16)
        egp = int(rc["effectiveGasPrice"], 16)
        intrinsic = BLOCK_GAS + 4 * z + 16 * nz
        access = tx.get("accessList") or []
        intrinsic += 2400 * len(access) + 1900 * sum(len(a.get("storageKeys", [])) for a in access)
        blobs = len(tx.get("blobVersionedHashes") or [])
        bgu = int(rc.get("blobGasUsed") or "0x0", 16)
        bgp = int(rc.get("blobGasPrice") or "0x0", 16)
        exec_cost = gas * egp
        blob_cost = bgu * bgp
        total = exec_cost + blob_cost
        bfpg = (hd or {}).get("baseFeePerGas")
        base_cost = gas * bfpg if bfpg else None
        prio_cost = gas * (egp - bfpg) if bfpg else None
        rows.append({
            "hash": h, "block": bn, "ts": ts, "proposer": tx["from"], "type": tx["type"],
            "input_bytes": tot, "zero_bytes": z, "nonzero_bytes": nz,
            "gasUsed": gas, "intrinsic_gas": intrinsic, "contract_gas": gas - intrinsic,
            "calldata_gas": 4 * z + 16 * nz,
            "effectiveGasPrice": egp, "baseFeePerGas": (hd or {}).get("baseFeePerGas"),
            "blobs": blobs, "blobGasUsed": bgu, "blobGasPrice": bgp,
            "exec_cost_wei": exec_cost, "blob_cost_wei": blob_cost, "total_cost_wei": total,
            "base_fee_cost_wei": base_cost, "priority_cost_wei": prio_cost,
            "usd": usd_at(ts) if ts else None,
            "total_cost_usd": (total / 1e18) * usd_at(ts) if ts and usd_at(ts) else None,
        })
    rows.sort(key=lambda r: r["block"])
    with open("propose-metrics.csv", "w") as f:
        cols = list(rows[0].keys())
        f.write(",".join(cols) + "\n")
        for r in rows:
            f.write(",".join(str(r[c]) for c in cols) + "\n")

    def stats(xs):
        xs = [x for x in xs if x is not None]
        return {"n": len(xs), "min": min(xs), "p10": pct(xs, 10), "p50": pct(xs, 50), "mean": sum(xs) / len(xs),
                "p90": pct(xs, 90), "p99": pct(xs, 99), "max": max(xs)}

    out = {"window": w, "n_propose_txs": len(rows), "n_proposed_logs": len(prop_logs), "n_proved_logs": len(prov_logs),
           "event_topic_census": {known.get(t, t): n for t, n in tc.items()}}
    out["gasUsed"] = stats([r["gasUsed"] for r in rows])
    out["input_bytes"] = stats([r["input_bytes"] for r in rows])
    out["effectiveGasPrice"] = stats([r["effectiveGasPrice"] for r in rows])
    out["blobs"] = stats([r["blobs"] for r in rows])
    out["total_cost_wei"] = stats([r["total_cost_wei"] for r in rows])
    out["exec_cost_wei"] = stats([r["exec_cost_wei"] for r in rows])
    out["blob_cost_wei"] = stats([r["blob_cost_wei"] for r in rows])
    out["total_cost_usd"] = stats([r["total_cost_usd"] for r in rows])
    out["total_eth"] = sum(r["total_cost_wei"] for r in rows) / 1e18
    out["total_exec_eth"] = sum(r["exec_cost_wei"] for r in rows) / 1e18
    out["total_blob_eth"] = sum(r["blob_cost_wei"] for r in rows) / 1e18
    out["total_usd"] = sum(r["total_cost_usd"] for r in rows if r["total_cost_usd"])
    out["base_fee_cost_wei"] = stats([r["base_fee_cost_wei"] for r in rows])
    out["priority_cost_wei"] = stats([r["priority_cost_wei"] for r in rows])
    out["total_base_fee_eth"] = sum(r["base_fee_cost_wei"] for r in rows if r["base_fee_cost_wei"]) / 1e18
    out["total_priority_eth"] = sum(r["priority_cost_wei"] for r in rows if r["priority_cost_wei"] is not None) / 1e18
    out["intrinsic_gas"] = stats([r["intrinsic_gas"] for r in rows])
    out["contract_gas"] = stats([r["contract_gas"] for r in rows])
    out["calldata_gas"] = stats([r["calldata_gas"] for r in rows])
    out["total_intrinsic_gas"] = sum(r["intrinsic_gas"] for r in rows)
    out["total_contract_gas"] = sum(r["contract_gas"] for r in rows)
    out["blob_count_dist"] = dict(Counter(r["blobs"] for r in rows))
    out["type_dist"] = dict(Counter(r["type"] for r in rows))
    out["proposer_dist"] = dict(Counter(r["proposer"] for r in rows))

    # per-day
    days = {}
    for r in rows:
        if not r["ts"]: continue
        d = dt.datetime.utcfromtimestamp(r["ts"]).strftime("%Y-%m-%d")
        g = days.setdefault(d, {"n": 0, "eth": 0.0, "usd": 0.0, "gas": 0, "blobs": 0, "blob_eth": 0.0, "exec_eth": 0.0})
        g["n"] += 1; g["eth"] += r["total_cost_wei"] / 1e18; g["usd"] += r["total_cost_usd"] or 0
        g["gas"] += r["gasUsed"]; g["blobs"] += r["blobs"]
        g["blob_eth"] += r["blob_cost_wei"] / 1e18; g["exec_eth"] += r["exec_cost_wei"] / 1e18
    out["per_day"] = days

    # fee-history percentiles
    bf = [int(x, 16) for x in fh["baseFeePerGas"]]
    bbf = [int(x, 16) for x in fh.get("baseFeePerBlobGas", [])]
    out["baseFee_percentiles"] = stats(bf)
    out["blobBaseFee_percentiles"] = stats(bbf)
    out["fee_history_blocks"] = len(bf)
    out["blobGasUsedRatio"] = stats(fh.get("blobGasUsedRatio", []) or [0])

    # median batch cost at observed price points
    med_gas = pct([r["gasUsed"] for r in rows], 50)
    med_blobs = pct([r["blobs"] for r in rows], 50)
    med_egp = pct([r["effectiveGasPrice"] for r in rows], 50)
    med_prio = pct([r["priority_cost_wei"] for r in rows], 50)
    curve = []
    for label, p in [("min", 0), ("p50", 50), ("p90", 90), ("p99", 99), ("max", 100)]:
        b = pct(bbf, p) if bbf else None
        e = pct(bf, p)
        blob_cost = med_blobs * GAS_PER_BLOB * (b or 0)
        exec_cost_base = med_gas * e                      # execution gas at that base fee, no priority
        exec_cost_obs = med_gas * med_egp                 # execution gas at the observed median effective price
        curve.append({"point": label, "baseFeePerGas": e, "blobBaseFeePerGas": b,
                      "median_batch_exec_eth_at_basefee": exec_cost_base / 1e18,
                      "median_batch_exec_eth_at_obs_median_egp": exec_cost_obs / 1e18,
                      "median_batch_blob_eth": blob_cost / 1e18,
                      "median_batch_total_eth_at_basefee": (exec_cost_base + blob_cost) / 1e18,
                      "median_batch_total_eth_at_obs_median_egp": (exec_cost_obs + blob_cost) / 1e18})
    out["cost_curve"] = curve
    out["median_effective_gas_price"] = med_egp
    out["median_priority_cost_wei"] = med_prio

    # prove txs
    prows = []
    for h, tx in vtx["txs"].items():
        rc = vtx["receipts"].get(h)
        if not tx or not rc: continue
        bn = int(rc["blockNumber"], 16)
        hd = header(bn)
        gas = int(rc["gasUsed"], 16); egp = int(rc["effectiveGasPrice"], 16)
        z, nz, tot = calldata_bytes(tx["input"])
        prows.append({"hash": h, "block": bn, "ts": hd["timestamp"] if hd else None,
                      "gasUsed": gas, "input_bytes": tot, "effectiveGasPrice": egp,
                      "cost_wei": gas * egp, "type": tx["type"],
                      "blobs": len(tx.get("blobVersionedHashes") or []),
                      "from": tx["from"]})
    prows.sort(key=lambda r: r["block"])
    if prows:
        with open("prove-metrics.csv", "w") as f:
            cols = list(prows[0].keys())
            f.write(",".join(cols) + "\n")
            for r in prows: f.write(",".join(str(r[c]) for c in cols) + "\n")
        out["prove"] = {"n": len(prows), "gasUsed": stats([r["gasUsed"] for r in prows]),
                        "total_eth": sum(r["cost_wei"] for r in prows) / 1e18,
                        "cost_wei": stats([r["cost_wei"] for r in prows]),
                        "type_dist": dict(Counter(r["type"] for r in prows)),
                        "from_dist": dict(Counter(r["from"] for r in prows))}

    # proposals newly proven per proof, from the Proved event payload
    prov_rows = []
    for l in prov_logs:
        d = l["data"][2:]
        words = [int(d[i:i+64], 16) for i in range(0, len(d), 64)]
        if len(words) >= 3:
            first_pid, first_new, last_pid = words[0], words[1], words[2]
            prov_rows.append({"tx": l["transactionHash"], "block": int(l["blockNumber"], 16),
                              "firstProposalId": first_pid, "firstNewProposalId": first_new,
                              "lastProposalId": last_pid, "newlyProven": last_pid - first_new + 1})
    out["proved_events"] = {"n": len(prov_rows),
                            "newlyProven_total": sum(r["newlyProven"] for r in prov_rows),
                            "newlyProven_per_proof": stats([r["newlyProven"] for r in prov_rows]),
                            "sample": prov_rows[:3] + prov_rows[-3:]}
    if out.get("prove") and out["proved_events"]["newlyProven_total"]:
        out["prove"]["eth_per_newly_proven_proposal"] = out["prove"]["total_eth"] / out["proved_events"]["newlyProven_total"]
    json.dump(out, open("summary.json", "w"), indent=1, default=str)
    print(json.dumps({k: out[k] for k in ["n_propose_txs", "n_proved_logs", "gasUsed", "input_bytes", "effectiveGasPrice",
                                          "blobs", "total_eth", "total_usd", "per_day", "baseFee_percentiles",
                                          "blobBaseFee_percentiles", "cost_curve", "blob_count_dist", "type_dist"]},
                     indent=1, default=str))

if __name__ == "__main__":
    main()
