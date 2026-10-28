#!/usr/bin/env python3
"""Fetch L1 block timestamps (+ gasUsed) for a list of block numbers via the
Blockscout REST API, with a JSON-RPC single-call fallback.

Blockscout: GET https://eth.blockscout.com/api/v2/blocks/<n> -> JSON with
  height, timestamp (ISO-8601 UTC, second resolution), gas_used.

Resumable: appends JSONL and skips blocks already present in the output.

Usage: python3 fetch_block_times_blockscout.py <blocks.txt> <out.jsonl> [workers]
"""
import json, sys, time, datetime, urllib.request
from concurrent.futures import ThreadPoolExecutor

blocks_file, out_path = sys.argv[1], sys.argv[2]
workers = int(sys.argv[3]) if len(sys.argv) > 3 else 6
BS = "https://eth.blockscout.com/api/v2/blocks/%d"
RPC = ["https://ethereum-rpc.publicnode.com", "https://gateway.tenderly.co/public/mainnet",
       "https://rpc.mevblocker.io"]

nums = [int(x) for x in open(blocks_file) if x.strip()]
done = set()
try:
    for line in open(out_path):
        done.add(json.loads(line)["block"])
except FileNotFoundError:
    pass
todo = [n for n in nums if n not in done]

def iso_to_epoch(s):
    s = s.replace("Z", "+00:00")
    if "." in s:
        head, rest = s.split(".", 1)
        frac, tz = rest.split("+", 1)
        s = head + "." + (frac + "000000")[:6] + "+" + tz
    return int(datetime.datetime.fromisoformat(s).timestamp())

def one(n):
    for attempt in range(6):
        try:
            req = urllib.request.Request(BS % n, headers={"user-agent": "taiko-mono-s1-research/1.0"})
            with urllib.request.urlopen(req, timeout=25) as r:
                d = json.loads(r.read().decode())
            return {"block": n, "timestamp": iso_to_epoch(d["timestamp"]),
                    "gasUsed": int(d["gas_used"]), "source": "blockscout"}
        except Exception:
            time.sleep(1.0 + attempt)
    for attempt in range(6):
        try:
            ep = RPC[attempt % len(RPC)]
            body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_getBlockByNumber",
                               "params": [hex(n), False]}).encode()
            req = urllib.request.Request(ep, data=body, headers={"content-type": "application/json"})
            with urllib.request.urlopen(req, timeout=25) as r:
                d = json.loads(r.read().decode())
            if "result" in d and d["result"]:
                return {"block": n, "timestamp": int(d["result"]["timestamp"], 16),
                        "gasUsed": int(d["result"]["gasUsed"], 16), "source": ep}
        except Exception:
            time.sleep(1.5 + attempt)
    return None

t0 = time.time()
print("total %d, already %d, todo %d" % (len(nums), len(done), len(todo)), file=sys.stderr)
f = open(out_path, "a")
failed = []
with ThreadPoolExecutor(max_workers=workers) as ex:
    for i, res in enumerate(ex.map(one, todo)):
        if res is None:
            failed.append(todo[i])
            continue
        f.write(json.dumps(res) + "\n")
        if i % 200 == 0:
            f.flush()
            print("done %d/%d (%.0fs) failed=%d" % (i, len(todo), time.time() - t0, len(failed)), file=sys.stderr)
f.flush(); f.close()
print(json.dumps({"blocks": len(todo) - len(failed), "failed": len(failed), "workers": workers,
                  "elapsedSec": round(time.time() - t0, 1),
                  "wallClockUTC": datetime.datetime.utcnow().isoformat() + "Z",
                  "command": " ".join(sys.argv)}))
if failed:
    open(out_path + ".failed.txt", "w").write("\n".join(str(x) for x in failed) + "\n")
