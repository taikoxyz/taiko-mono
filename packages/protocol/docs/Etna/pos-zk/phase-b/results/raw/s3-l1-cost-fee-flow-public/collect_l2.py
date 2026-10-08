#!/usr/bin/env python3
"""L2-side census: fetch Taiko L2 block headers over a block span, attribute each
block to its L1 proposal via the Shasta extraData (byte0=basefeeSharingPctg,
bytes1..6=proposalId big-endian uint48), and sum L2 gasUsed per proposal.

Usage: collect_l2.py <l2_start_block> <l2_end_block> <out.json>
"""
import json, os, sys, time, urllib.request

UA = "taiko-pos-zk-s3-public-data/1.0"
URL = "https://rpc.taiko.xyz"
URLS = [
    "https://taiko-rpc.publicnode.com",
    "https://taiko.drpc.org",
    "https://rpc.ankr.com/taiko",
    "https://taiko-mainnet.gateway.tenderly.co",
    "https://rpc.taiko.xyz",
]
CHUNKS = "l2chunks"

def rpc_batch(calls, chunk=100, tries=5):
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i+chunk]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(part)]
        got = None
        for a in range(tries * len(URLS)):
            try:
                url = URLS[a % len(URLS)]
                req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                             headers={"content-type": "application/json", "User-Agent": UA})
                resp = json.loads(urllib.request.urlopen(req, timeout=180).read().decode())
                by = {x["id"]: x for x in resp}
                got = [by.get(j, {}).get("result") for j in range(len(part))]
                if any(x is None for x in got):
                    raise RuntimeError("null in batch")
                break
            except Exception as e:
                sys.stderr.write(f"retry {a}: {e}\n"); time.sleep(min(3 * (a + 1), 20))
        if got is None:
            raise RuntimeError("batch failed")
        out.extend(got)
        time.sleep(0.25)
    return out

def main():
    lo, hi, outp = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
    os.makedirs(CHUNKS, exist_ok=True)
    rows = []
    n = lo
    while n <= hi:
        m = min(n + 999, hi)
        cp = os.path.join(CHUNKS, f"{n}-{m}.json")
        if os.path.exists(cp) and os.path.getsize(cp) > 2:
            res = json.load(open(cp))
        else:
            res = rpc_batch([("eth_getBlockByNumber", [hex(x), False]) for x in range(n, m + 1)])
            json.dump(res, open(cp, "w"))
        for b in res:
            if b is None:
                rows.append({"number": None}); continue
            ed = b["extraData"]
            if len(ed) < 16:
                pid = None; pctg = None
            else:
                pctg = int(ed[2:4], 16); pid = int(ed[4:16], 16)
            rows.append({"number": int(b["number"], 16), "ts": int(b["timestamp"], 16),
                         "gasUsed": int(b["gasUsed"], 16), "gasLimit": int(b["gasLimit"], 16),
                         "baseFeePerGas": int(b["baseFeePerGas"], 16), "miner": b["miner"],
                         "pctg": pctg, "proposalId": pid})
        print("fetched", n, m, flush=True)
        n = m + 1
    # group
    groups = {}
    order = []
    for r in rows:
        pid = r.get("proposalId")
        if pid is None:
            continue
        g = groups.get(pid)
        if g is None:
            g = {"proposalId": pid, "blocks": 0, "gasUsed": 0, "blockFirst": r["number"], "blockLast": r["number"],
                 "tsFirst": r["ts"], "tsLast": r["ts"], "pctg": r["pctg"], "miners": set(), "baseFees": set(), "gasLimits": set()}
            groups[pid] = g; order.append(pid)
        g["blocks"] += 1; g["gasUsed"] += r["gasUsed"]
        g["blockFirst"] = min(g["blockFirst"], r["number"]); g["blockLast"] = max(g["blockLast"], r["number"])
        g["tsFirst"] = min(g["tsFirst"], r["ts"]); g["tsLast"] = max(g["tsLast"], r["ts"])
        g["miners"].add(r["miner"]); g["baseFees"].add(r["baseFeePerGas"]); g["gasLimits"].add(r["gasLimit"])
    for pid in order:
        g = groups[pid]
        g["miners"] = sorted(g["miners"]); g["baseFees"] = sorted(g["baseFees"]); g["gasLimits"] = sorted(g["gasLimits"])
    out = {"l2_start": lo, "l2_end": hi, "url": URL, "fetched_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "groups": [groups[p] for p in order]}
    json.dump(out, open(outp, "w"))
    csvp = outp.replace(".json", ".csv")
    with open(csvp, "w") as f:
        f.write("number,ts,gasUsed,gasLimit,baseFeePerGas,pctg,proposalId,miner" + chr(10))
        for r in rows:
            if r.get("number") is None:
                continue
            f.write(f"{r['number']},{r['ts']},{r['gasUsed']},{r['gasLimit']},{r['baseFeePerGas']},{r['pctg']},{r['proposalId']},{r['miner']}\n")
    print("wrote", outp, csvp, "rows", len(rows), "groups", len(groups), flush=True)

if __name__ == "__main__":
    main()
