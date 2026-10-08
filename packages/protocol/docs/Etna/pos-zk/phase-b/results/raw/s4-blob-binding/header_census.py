#!/usr/bin/env python3
"""S4: fetch L1 block headers for every block that contains a Taiko proposal.

Reads proposals_by_tx.csv (from decode_proposed.py), collects the unique block
numbers, fetches eth_getBlockByNumber(...,false) in batches, and writes
headers.jsonl with block, timestamp, excessBlobGas, blobGasUsed.
"""
import csv, json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rpc

BATCH = 64

def main(outdir):
    rows = list(csv.DictReader(open(os.path.join(outdir, 'proposals_by_tx.csv'))))
    blocks = sorted({int(r['block']) for r in rows})
    done = {}
    path = os.path.join(outdir, 'headers.jsonl')
    if os.path.exists(path):
        for line in open(path):
            d = json.loads(line)
            done[d['block']] = d
    todo = [b for b in blocks if b not in done]
    print(f"blocks {len(blocks)} done {len(done)} todo {len(todo)}", flush=True)
    f = open(path, 'a')
    for i in range(0, len(todo), BATCH):
        chunk = todo[i:i + BATCH]
        calls = [("eth_getBlockByNumber", [hex(b), False]) for b in chunk]
        try:
            res, url = rpc.el_batch(calls, tries=4)
        except Exception as e:
            print(f"  batch {i} failed {repr(e)[:120]}", flush=True)
            time.sleep(5)
            continue
        got = 0
        for b, h in zip(chunk, res):
            if h is None:
                continue
            rec = {'block': b, 'timestamp': int(h['timestamp'], 16),
                   'excessBlobGas': int(h['excessBlobGas'], 16),
                   'blobGasUsed': int(h['blobGasUsed'], 16),
                   'baseFeePerGas': int(h['baseFeePerGas'], 16)}
            f.write(json.dumps(rec) + '\n'); got += 1
        f.flush()
        print(f"  {i + len(chunk)}/{len(todo)} (+{got}) via {url}", flush=True)
        time.sleep(0.4)
    f.close()

if __name__ == '__main__':
    main(sys.argv[1])
