#!/usr/bin/env python3
"""S4: header census (lean, single RPC, resumable).

Reads proposals_by_tx.csv, fetches eth_getBlockByNumber(...,false) for the unique
proposal blocks in small batches via rpc.mevblocker.io, appends to headers.jsonl.
"""
import csv, json, os, sys, time, urllib.request

URL = "https://rpc.mevblocker.io"
UA = {"content-type": "application/json", "user-agent": "Mozilla/5.0 (s4-public-data-collection)"}
BATCH = 40

def batch(calls, timeout=30):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    req = urllib.request.Request(URL, data=json.dumps(payload).encode(), headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        j = json.loads(r.read().decode())
    if not isinstance(j, list):
        raise RuntimeError(str(j)[:120])
    out = [None] * len(calls)
    for item in j:
        if "result" in item:
            out[item["id"]] = item["result"]
    return out

def main(outdir):
    rows = list(csv.DictReader(open(os.path.join(outdir, 'proposals_by_tx.csv'))))
    blocks = sorted({int(r['block']) for r in rows})
    done = set()
    path = os.path.join(outdir, 'headers.jsonl')
    if os.path.exists(path):
        for line in open(path):
            try:
                done.add(json.loads(line)['block'])
            except Exception:
                pass
    todo = [b for b in blocks if b not in done]
    print(f"blocks {len(blocks)} done {len(done)} todo {len(todo)}", flush=True)
    f = open(path, 'a')
    i = 0
    while i < len(todo):
        chunk = todo[i:i + BATCH]
        calls = [("eth_getBlockByNumber", [hex(b), False]) for b in chunk]
        try:
            res = batch(calls)
        except Exception as e:
            print(f"  retry {i}: {repr(e)[:100]}", flush=True)
            time.sleep(4)
            continue
        got = 0
        for b, h in zip(chunk, res):
            if h is None:
                continue
            f.write(json.dumps({'block': b, 'timestamp': int(h['timestamp'], 16),
                                'excessBlobGas': int(h['excessBlobGas'], 16),
                                'blobGasUsed': int(h['blobGasUsed'], 16),
                                'baseFeePerGas': int(h['baseFeePerGas'], 16)}) + '\n')
            got += 1
        f.flush()
        i += len(chunk)
        if (i // BATCH) % 20 == 0:
            print(f"  {i}/{len(todo)} (+{got})", flush=True)
        time.sleep(0.15)
    f.close()
    print("DONE")

if __name__ == '__main__':
    main(sys.argv[1])
