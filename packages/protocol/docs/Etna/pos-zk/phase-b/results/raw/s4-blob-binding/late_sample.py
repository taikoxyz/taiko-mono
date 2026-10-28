#!/usr/bin/env python3
"""S4: late-era header sample (blocks >= 25,700,000), every 100th proposal block."""
import csv, json, os, sys, time, urllib.request

URLS = ["https://0xrpc.io/eth", "https://rpc.mevblocker.io"]
UA = {"content-type": "application/json", "user-agent": "Mozilla/5.0 (s4-public-data-collection)"}

def call_batch(url, calls, timeout=30):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        j = json.loads(r.read().decode())
    out = [None] * len(calls)
    for it in j:
        if "result" in it:
            out[it["id"]] = it["result"]
    return out

def main(outdir, floor=25700000, k=100):
    rows = list(csv.DictReader(open(os.path.join(outdir, 'proposals_by_tx.csv'))))
    blocks = sorted({int(r['block']) for r in rows})
    sel = [b for b in blocks if b >= floor][::k]
    path = os.path.join(outdir, 'headers-late.jsonl')
    done = set()
    if os.path.exists(path):
        for line in open(path):
            try:
                done.add(json.loads(line)['block'])
            except Exception:
                pass
    todo = [b for b in sel if b not in done]
    print(f"late blocks {len(sel)} todo {len(todo)}", flush=True)
    f = open(path, 'a')
    for i in range(0, len(todo), 25):
        chunk = todo[i:i + 25]
        calls = [("eth_getBlockByNumber", [hex(b), False]) for b in chunk]
        res = None
        for url in URLS:
            try:
                res = call_batch(url, calls); break
            except Exception as e:
                time.sleep(1)
        if res is None:
            print("fail", i, flush=True); continue
        for b, h in zip(chunk, res):
            if h is None:
                continue
            f.write(json.dumps({'block': b, 'timestamp': int(h['timestamp'], 16),
                                'excessBlobGas': int(h['excessBlobGas'], 16),
                                'blobGasUsed': int(h['blobGasUsed'], 16),
                                'baseFeePerGas': int(h['baseFeePerGas'], 16)}) + '\n')
        f.flush()
        print(f"  {i + len(chunk)}/{len(todo)}", flush=True)
        time.sleep(0.2)
    f.close()
    print("DONE")

if __name__ == '__main__':
    main(sys.argv[1])
