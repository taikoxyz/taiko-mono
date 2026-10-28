#!/usr/bin/env python3
"""Fetch L1 block timestamps for a list of block numbers (one per line).
Writes JSONL {block,timestamp} to the output path (append, resumable).
Retries with backoff; rotates endpoints; sleeps between batches to respect
public-endpoint rate limits. The sleep is what keeps the public endpoints
from returning 403/429: ~50 calls per 1.5 s.

Usage: python3 fetch_block_times.py <blocks.txt> <out.jsonl> [batch] [sleep]
"""
import json, sys, time, datetime
sys.path.insert(0, ".")
from rpc import batch

blocks_file, out_path = sys.argv[1], sys.argv[2]
batch_size = int(sys.argv[3]) if len(sys.argv) > 3 else 50
sleep_s = float(sys.argv[4]) if len(sys.argv) > 4 else 1.5
ENDPOINTS = ["https://gateway.tenderly.co/public/mainnet", "https://rpc.mevblocker.io",
             "https://ethereum-rpc.publicnode.com"]

nums = [int(x) for x in open(blocks_file) if x.strip()]
done = {}
try:
    for line in open(out_path):
        r = json.loads(line)
        done[r["block"]] = r["timestamp"]
except FileNotFoundError:
    pass
todo = [n for n in nums if n not in done]
print("total %d, already %d, todo %d" % (len(nums), len(done), len(todo)), file=sys.stderr)

f = open(out_path, "a")
t0 = time.time()
for i in range(0, len(todo), batch_size):
    chunk = todo[i:i + batch_size]
    calls = [("eth_getBlockByNumber", [hex(n), False]) for n in chunk]
    res = None
    last_err = None
    for attempt in range(10):
        ep = ENDPOINTS[attempt % len(ENDPOINTS)]
        try:
            res = batch(ep, calls, tries=1)
            break
        except SystemExit as e:
            last_err = e
            res = None
            time.sleep(min(20, 1.5 * (attempt + 1)))
    if res is None:
        raise SystemExit("giving up at %d: %s" % (chunk[0], last_err))
    for n, blk in zip(chunk, res):
        if blk is None:
            raise SystemExit("null block %d" % n)
        f.write(json.dumps({"block": n, "timestamp": int(blk["timestamp"], 16)}) + "\n")
        done[n] = 1
    if (i // batch_size) % 10 == 0:
        f.flush()
        print("done %d/%d (%.0fs)" % (len(done), len(nums), time.time() - t0), file=sys.stderr)
    time.sleep(sleep_s)
f.flush(); f.close()
print(json.dumps({"blocks": len(done), "elapsedSec": round(time.time() - t0, 1),
                  "wallClockUTC": datetime.datetime.utcnow().isoformat() + "Z",
                  "command": " ".join(sys.argv), "batch": batch_size, "sleep": sleep_s}))
