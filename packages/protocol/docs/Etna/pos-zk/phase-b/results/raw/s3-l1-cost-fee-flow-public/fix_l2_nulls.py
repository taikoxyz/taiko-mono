#!/usr/bin/env python3
"""Refill null entries in cached L2 chunk files (early chunks cached before the
null-check was added), then the caller re-runs collect_l2.py to re-aggregate."""
import json, glob, os, sys, time, urllib.request

URLS = ["https://taiko-rpc.publicnode.com", "https://taiko.drpc.org", "https://rpc.ankr.com/taiko",
        "https://taiko-mainnet.gateway.tenderly.co", "https://rpc.taiko.xyz"]
UA = "taiko-pos-zk-s3-public-data/1.0"

def post(url, payload, timeout=120):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"content-type": "application/json", "User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def main():
    fixes = []   # (path, index, block)
    for p in sorted(glob.glob("l2chunks/*.json")):
        arr = json.load(open(p))
        a, b = os.path.basename(p)[:-5].split("-")
        for i, v in enumerate(arr):
            if v is None:
                fixes.append((p, i, int(a) + i))
    print("null entries:", len(fixes))
    for j in range(0, len(fixes), 25):
        part = fixes[j:j+25]
        payload = [{"jsonrpc": "2.0", "id": k, "method": "eth_getBlockByNumber", "params": [hex(b), False]}
                   for k, (_, _, b) in enumerate(part)]
        got = None
        for a in range(20):
            try:
                d = post(URLS[a % len(URLS)], payload)
                by = {x["id"]: x for x in d}
                got = [by.get(k, {}).get("result") for k in range(len(part))]
                if any(x is None for x in got):
                    raise RuntimeError("still null")
                break
            except Exception as e:
                sys.stderr.write(f"retry {a}: {e}\n"); time.sleep(min(3 * (a + 1), 15))
        if got is None:
            raise RuntimeError("failed")
        touched = {}
        for (p, i, b), h in zip(part, got):
            touched.setdefault(p, []).append((i, h))
        for p, items in touched.items():
            arr = json.load(open(p))
            for i, h in items:
                arr[i] = h
            json.dump(arr, open(p, "w"))
        print("fixed", j, "/", len(fixes), flush=True)
    print("done")

if __name__ == "__main__":
    main()
