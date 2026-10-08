#!/usr/bin/env python3
"""Fetch Inbox logs over a block window and write JSONL + a run log.

Usage: python3 fetch_inbox_logs.py <url> <address> <lo> <hi> <chunk> <out.jsonl>
Prints progress to stderr; writes one JSON log object per line; writes a
companion <out.jsonl>.meta.json with the exact parameters, endpoint and wall time.
"""
import json, sys, time, datetime
sys.path.insert(0, ".")
from rpc import call

url, address, lo, hi, chunk, out = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5]), sys.argv[6]
n = 0
t0 = time.time()
with open(out, "w") as f:
    b = lo
    while b <= hi:
        e = min(b + chunk - 1, hi)
        logs = None
        for attempt in range(6):
            try:
                logs = call(url, "eth_getLogs", [{"address": address, "fromBlock": hex(b), "toBlock": hex(e)}], tries=3)
                break
            except SystemExit:
                time.sleep(2 ** attempt)
        if logs is None:
            raise SystemExit("giving up on %d-%d" % (b, e))
        for l in logs:
            f.write(json.dumps(l) + "\n")
        n += len(logs)
        print("chunk %d-%d -> %d logs (total %d)" % (b, e, len(logs), n), file=sys.stderr)
        b = e + 1
        time.sleep(0.2)
meta = {
    "endpoint": url, "address": address, "fromBlock": lo, "toBlock": hi,
    "chunk": chunk, "logs": n, "out": out,
    "wallClockUTC": datetime.datetime.utcnow().isoformat() + "Z",
    "elapsedSec": round(time.time() - t0, 1),
    "command": " ".join(sys.argv),
}
open(out + ".meta.json", "w").write(json.dumps(meta, indent=2) + "\n")
print(json.dumps(meta))
