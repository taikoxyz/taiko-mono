#!/usr/bin/env python3
"""S4: systematic sample of proposal-block headers (every k-th unique block).

Fetches eth_getBlockByNumber(...,false) for every k-th block in the sorted list
of blocks that contain a Taiko proposal, writing headers-sample.jsonl.
Tries mevblocker and 0xrpc alternately.

Usage: header_sample.py <outdir> [k]
"""
import csv, json, os, sys, time, urllib.request

URLS = ["https://rpc.mevblocker.io", "https://0xrpc.io/eth"]
UA = {"content-type": "application/json", "user-agent": "Mozilla/5.0 (s4-public-data-collection)"}
BATCH = 20

def call_batch(url, calls, timeout=30):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        j = json.loads(r.read().decode())
    if not isinstance(j, list):
        raise RuntimeError(str(j)[:100])
    out = [None] * len(calls)
    for item in j:
        if "result" in item:
            out[item["id"]] = item["result"]
    return out

def main(outdir, k=20):
    rows = list(csv.DictReader(open(os.path.join(outdir, 'proposals_by_tx.csv'))))
    blocks = sorted({int(r['block']) for r in rows})
    sample = blocks[::k]
    path = os.path.join(outdir, 'headers-sample.jsonl')
    done = set()
    if os.path.exists(path):
        for line in open(path):
            try:
                done.add(json.loads(line)['block'])
            except Exception:
                pass
    todo = [b for b in sample if b not in done]
    print(f"blocks {len(blocks)} sample {len(sample)} todo {len(todo)}", flush=True)
    f = open(path, 'a')
    i = 0
    while i < len(todo):
        chunk = todo[i:i + BATCH]
        calls = [("eth_getBlockByNumber", [hex(b), False]) for b in chunk]
        got = False
        for url in [URLS[(i // BATCH) % 2]] + URLS:
            try:
                res = call_batch(url, calls)
                got = True
                break
            except Exception as e:
                print(f"  retry {i} {url}: {repr(e)[:80]}", flush=True)
                time.sleep(2)
        if not got:
            time.sleep(4)
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
        if (i // BATCH) % 10 == 0:
            print(f"  {i}/{len(todo)}", flush=True)
        time.sleep(0.2)
    f.close()
    print("DONE", len(done) + len(todo))

if __name__ == '__main__':
    main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 20)
