#!/usr/bin/env python3
"""S4: reverse-order header sample (from the end of the era backwards), 0xrpc.

Fetches eth_getBlockByNumber(...,false) for every k-th proposal block, starting
from the most recent, writing headers-sample-rev.jsonl.
"""
import csv, json, os, sys, time, urllib.request

URL = "https://0xrpc.io/eth"
UA = {"content-type": "application/json", "user-agent": "Mozilla/5.0 (s4-public-data-collection)"}
BATCH = 20

def call_batch(calls, timeout=30):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    req = urllib.request.Request(URL, data=json.dumps(payload).encode(), headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        j = json.loads(r.read().decode())
    if not isinstance(j, list):
        raise RuntimeError(str(j)[:100])
    out = [None] * len(calls)
    for it in j:
        if "result" in it:
            out[it["id"]] = it["result"]
    return out

def main(outdir, k=20):
    rows = list(csv.DictReader(open(os.path.join(outdir, 'proposals_by_tx.csv'))))
    blocks = sorted({int(r['block']) for r in rows})[::k]
    path = os.path.join(outdir, 'headers-sample-rev.jsonl')
    done = set()
    if os.path.exists(path):
        for line in open(path):
            try:
                done.add(json.loads(line)['block'])
            except Exception:
                pass
    todo = [b for b in reversed(blocks) if b not in done]
    print(f"todo {len(todo)}", flush=True)
    f = open(path, 'a')
    i = 0
    while i < len(todo):
        chunk = todo[i:i + BATCH]
        calls = [("eth_getBlockByNumber", [hex(b), False]) for b in chunk]
        try:
            res = call_batch(calls)
        except Exception as e:
            print(f"  retry {i}: {repr(e)[:80]}", flush=True)
            time.sleep(3)
            continue
        for b, h in zip(chunk, res):
            if h is None:
                continue
            f.write(json.dumps({'block': b, 'timestamp': int(h['timestamp'], 16),
                                'excessBlobGas': int(h['excessBlobGas'], 16),
                                'blobGasUsed': int(h['blobGasUsed'], 16),
                                'baseFeePerGas': int(h['baseFeePerGas'], 16)}) + '\n')
        f.flush()
        i += len(chunk)
        if (i // BATCH) % 5 == 0:
            print(f"  {i}/{len(todo)}", flush=True)
        time.sleep(0.1)
    f.close()
    print("DONE")

if __name__ == '__main__':
    main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 20)
