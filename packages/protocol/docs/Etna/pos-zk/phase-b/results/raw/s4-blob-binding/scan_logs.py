#!/usr/bin/env python3
"""S4 public-data scan: Taiko MainnetInbox 'Proposed' logs on Ethereum L1.

Fetches eth_getLogs for the inbox proxy filtered to the Proposed event topic,
in adaptive chunks, with RPC fallback, splitting, and retry. Writes every raw
response to raw/logs/ and an index of chunks.

Usage: python3 scan_logs.py <fromBlock> <toBlock> <outdir>
"""
import json, os, sys, time, urllib.request

TOPIC0 = "0x7c4c4523e17533e451df15762a093e0693a2cd8b279fe54c6cd3777ed5771213"
INBOX  = "0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f"
# (url, max range in blocks)
RPCS = [
    ("https://rpc.mevblocker.io", 100000),
    ("https://eth.blockscout.com/api/eth-rpc", 20000),
    ("https://0xrpc.io/eth", 10000),
    ("https://ethereum-rpc.publicnode.com", 2000),
]

def rpc(url, method, params, timeout=90):
    body = json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode()
    req = urllib.request.Request(url, data=body, headers={"content-type":"application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def get_logs(frm, to):
    span = to - frm + 1
    last_err = None
    for url, maxr in RPCS:
        if span > maxr:
            continue
        for attempt in range(2):
            try:
                j = rpc(url, "eth_getLogs", [{
                    "address": INBOX, "fromBlock": hex(frm), "toBlock": hex(to),
                    "topics": [TOPIC0]}])
                if "result" in j and isinstance(j["result"], list):
                    return j["result"], url
                last_err = j.get("error")
            except Exception as e:
                last_err = repr(e)[:200]
            time.sleep(1.5 * (attempt + 1))
    return None, last_err

def scan(frm, to, outdir):
    os.makedirs(os.path.join(outdir, "logs"), exist_ok=True)
    all_logs, chunks = [], []
    stack = [(frm, to)]
    while stack:
        a, b = stack.pop(0)
        logs, url = get_logs(a, b)
        if logs is None:
            if b - a + 1 <= 1000:
                raise RuntimeError(f"chunk {a}-{b} failed: {url}")
            mid = (a + b) // 2
            print(f"  split {a}-{b} ({(b-a+1)} blocks)", flush=True)
            stack.insert(0, (mid + 1, b)); stack.insert(0, (a, mid))
            continue
        name = f"logs/chunk-{a}-{b}.json"
        with open(os.path.join(outdir, name), "w") as f:
            json.dump({"request": {"url": url, "address": INBOX, "topic0": TOPIC0,
                                   "fromBlock": a, "toBlock": b,
                                   "fetched_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())},
                       "response": logs}, f)
        chunks.append((a, b, len(logs), url))
        all_logs.extend(logs)
        print(f"  {a}-{b}: {len(logs)} logs via {url}", flush=True)
        time.sleep(0.8)
    return all_logs, chunks

if __name__ == "__main__":
    frm, to, outdir = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
    t0 = time.time()
    logs, chunks = scan(frm, to, outdir)
    print("TOTAL", len(logs), "in", round(time.time()-t0, 1), "s")
    with open(os.path.join(outdir, "logs", "index.json"), "w") as f:
        json.dump({"fromBlock": frm, "toBlock": to, "total_logs": len(logs),
                   "chunks": [{"from": a, "to": b, "logs": n, "url": u} for a, b, n, u in chunks]}, f, indent=1)
