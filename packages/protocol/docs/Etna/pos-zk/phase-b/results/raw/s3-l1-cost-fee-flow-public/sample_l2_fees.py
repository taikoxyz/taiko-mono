#!/usr/bin/env python3
"""Exact L2 fee measurement for a contiguous L2 block range.

Fetches, per block, the header and all receipts (eth_getBlockReceipts), then reports
per-block and per-proposal totals of base fee and priority fee. Cached per block.
Usage: sample_l2_fees.py <l2_from> <l2_to> <out.json>
"""
import json, os, sys, time, urllib.request

URLS = ["https://taiko-rpc.publicnode.com", "https://taiko.drpc.org", "https://rpc.ankr.com/taiko",
        "https://taiko-mainnet.gateway.tenderly.co", "https://rpc.taiko.xyz"]
UA = "taiko-pos-zk-s3-public-data/1.0"
CACHE = "feesample"

def post(url, payload, timeout=120):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"content-type": "application/json", "User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def main():
    lo, hi, outp = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
    os.makedirs(CACHE, exist_ok=True)
    blocks = list(range(lo, hi + 1))
    blocks = [b for b in blocks if not os.path.exists(os.path.join(CACHE, f"{b}.json"))]
    print("todo", len(blocks))
    BS = 20
    for i in range(0, len(blocks), BS):
        part = blocks[i:i+BS]
        calls = []
        for b in part:
            calls.append(("eth_getBlockByNumber", [hex(b), False]))
            calls.append(("eth_getBlockReceipts", [hex(b)]))
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(calls)]
        got = None
        for a in range(20):
            try:
                d = post(URLS[a % len(URLS)], payload)
                by = {x["id"]: x for x in d}
                got = [by.get(j, {}).get("result") for j in range(len(calls))]
                if any(x is None for x in got):
                    raise RuntimeError("null result")
                break
            except Exception as e:
                sys.stderr.write(f"retry {a}: {e}\n"); time.sleep(min(3 * (a + 1), 15))
        if got is None:
            raise RuntimeError("batch failed")
        for k, b in enumerate(part):
            h = got[2 * k]; rs = got[2 * k + 1]
            json.dump({"header": h, "receipts": rs}, open(os.path.join(CACHE, f"{b}.json"), "w"))
        print("fetched", i, "/", len(blocks), flush=True)
        time.sleep(0.15)
    # aggregate
    rows = []
    for b in range(lo, hi + 1):
        d = json.load(open(os.path.join(CACHE, f"{b}.json")))
        h = d["header"]; rs = d["receipts"]
        ed = h["extraData"]
        pid = int(ed[4:16], 16) if len(ed) >= 16 else None
        base = int(h["baseFeePerGas"], 16)
        gas = sum(int(r["gasUsed"], 16) for r in rs)
        fees = sum(int(r["gasUsed"], 16) * int(r["effectiveGasPrice"], 16) for r in rs)
        base_total = gas * base
        rows.append({"block": b, "ts": int(h["timestamp"], 16), "proposalId": pid, "txs": len(rs),
                     "gasUsed": gas, "baseFeePerGas": base, "gasUsedHeader": int(h["gasUsed"], 16),
                     "baseTotal_wei": base_total, "feeTotal_wei": fees, "priorityTotal_wei": fees - base_total,
                     "gasPrices": sorted({int(r["effectiveGasPrice"], 16) for r in rs})})
    groups = {}
    for r in rows:
        g = groups.setdefault(r["proposalId"], {"proposalId": r["proposalId"], "blocks": 0, "txs": 0, "gasUsed": 0,
                                                "baseTotal_wei": 0, "feeTotal_wei": 0, "priorityTotal_wei": 0,
                                                "blockFirst": r["block"], "blockLast": r["block"],
                                                "tsFirst": r["ts"], "tsLast": r["ts"]})
        g["blocks"] += 1; g["txs"] += r["txs"]; g["gasUsed"] += r["gasUsed"]
        g["baseTotal_wei"] += r["baseTotal_wei"]; g["feeTotal_wei"] += r["feeTotal_wei"]
        g["priorityTotal_wei"] += r["priorityTotal_wei"]
        g["blockFirst"] = min(g["blockFirst"], r["block"]); g["blockLast"] = max(g["blockLast"], r["block"])
        g["tsFirst"] = min(g["tsFirst"], r["ts"]); g["tsLast"] = max(g["tsLast"], r["ts"])
    out = {"l2_from": lo, "l2_to": hi, "fetched_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "rows": rows, "groups": [groups[k] for k in sorted(groups)]}
    json.dump(out, open(outp, "w"), indent=1)
    tot_gas = sum(r["gasUsed"] for r in rows)
    tot_fee = sum(r["feeTotal_wei"] for r in rows)
    tot_base = sum(r["baseTotal_wei"] for r in rows)
    print("blocks", len(rows), "gas", tot_gas, "fee_wei", tot_fee, "base_wei", tot_base,
          "priority_wei", tot_fee - tot_base, "priority_share", (tot_fee - tot_base) / tot_fee if tot_fee else None)

if __name__ == "__main__":
    main()
