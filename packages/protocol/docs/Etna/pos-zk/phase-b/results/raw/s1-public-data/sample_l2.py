#!/usr/bin/env python3
"""Systematic sample of Taiko L2 blocks: every <step>-th block in [lo,hi].
Writes JSONL {block,timestamp,gasUsed,gasLimit,txs,baseFee}.
Usage: python3 sample_l2.py <rpc> <lo> <hi> <step> <out.jsonl>
"""
import json, sys, time
sys.path.insert(0, ".")
from rpc import batch

rpc, lo, hi, step, out = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
nums = list(range(lo, hi + 1, step))
print("sampling %d blocks (%d..%d step %d)" % (len(nums), lo, hi, step), file=sys.stderr)
f = open(out, "w")
t0 = time.time()
BS = 50
for i in range(0, len(nums), BS):
    chunk = nums[i:i + BS]
    calls = [("eth_getBlockByNumber", [hex(n), False]) for n in chunk]
    res = batch(rpc, calls, tries=4)
    for n, b in zip(chunk, res):
        f.write(json.dumps({
            "block": int(b["number"], 16), "timestamp": int(b["timestamp"], 16),
            "gasUsed": int(b["gasUsed"], 16), "gasLimit": int(b["gasLimit"], 16),
            "txs": len(b["transactions"]), "baseFeePerGas": int(b.get("baseFeePerGas", "0x0"), 16),
        }) + "\n")
    if (i // BS) % 40 == 0:
        f.flush(); print("%d/%d %.0fs" % (i, len(nums), time.time() - t0), file=sys.stderr)
f.close()
print(json.dumps({"rpc": rpc, "lo": lo, "hi": hi, "step": step, "samples": len(nums), "out": out,
                  "elapsedSec": round(time.time() - t0, 1), "command": " ".join(sys.argv)}))
