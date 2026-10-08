#!/usr/bin/env python3
"""Measure the PRF-07(0) payload framing bytes for a contiguous Taiko L2 block range.

For each height h in [lo,hi]:
  frame(h) = be32(len(body_h)) || body_h
  body_h   = RLP list of the block's transactions in execution order
  len(P)   = sum over h of len(frame(h)) = 4 + len(body_h)

The raw transaction bytes come from eth_getRawTransactionByBlockNumberAndIndex, so
len(body_h) is computed, not estimated. RLP list header: 0xc0+len if len <= 55 else
0xf7+len(len-bytes) followed by the big-endian length.

Usage: python3 l2_payload.py <rpc> <lo> <hi> <out.jsonl>
"""
import json, sys, time
sys.path.insert(0, ".")
from rpc import batch, call

rpc, lo, hi, out = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]

def rlp_list_len(total):
    if total <= 55:
        return 1 + total
    n = (total.bit_length() + 7) // 8
    return 1 + n + total

f = open(out, "w")
t0 = time.time()
for h in range(lo, hi + 1):
    blk = call(rpc, "eth_getBlockByNumber", [hex(h), False])
    ntx = len(blk["transactions"])
    raws = []
    if ntx:
        raws = batch(rpc, [("eth_getRawTransactionByBlockNumberAndIndex", [hex(h), hex(i)]) for i in range(ntx)], tries=4)
    raw_lens = [(len(r) - 2) // 2 for r in raws]
    body_len = rlp_list_len(sum(raw_lens))
    f.write(json.dumps({
        "block": h, "timestamp": int(blk["timestamp"], 16), "gasUsed": int(blk["gasUsed"], 16),
        "gasLimit": int(blk["gasLimit"], 16), "txs": ntx, "rawTxLens": raw_lens,
        "bodyLen": body_len, "frameLen": 4 + body_len,
        "bPayload": (4 + body_len) / int(blk["gasUsed"], 16),
    }) + "\n")
    f.flush()
    if h % 50 == 0:
        print("%d/%d %.0fs" % (h - lo, hi - lo, time.time() - t0), file=sys.stderr)
    time.sleep(0.25)
f.close()
print(json.dumps({"rpc": rpc, "lo": lo, "hi": hi, "out": out, "blocks": hi - lo + 1,
                  "elapsedSec": round(time.time() - t0, 1), "command": " ".join(sys.argv)}))
