#!/usr/bin/env python3
"""Fetch block headers (timestamp, baseFeePerGas, blobGasUsed, excessBlobGas) for a
set of block numbers taken from propose/prove receipts. Cached per block."""
import json, os, sys, time, urllib.request

RPCS = ["https://ethereum-rpc.publicnode.com", "https://eth.drpc.org", "https://rpc.mevblocker.io",
        "https://gateway.tenderly.co/public/mainnet", "https://eth.blockrazor.xyz"]
UA = "taiko-pos-zk-s3-public-data/1.0"
CACHE = "blockcache"

def post(url, payload, timeout=90):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"content-type": "application/json", "User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def main():
    os.makedirs(CACHE, exist_ok=True)
    blocks = set()
    for f in sys.argv[1:]:
        d = json.load(open(f))
        for h, rc in d["receipts"].items():
            if rc:
                blocks.add(int(rc["blockNumber"], 16))
    blocks = sorted(blocks)
    print("blocks", len(blocks))
    todo = [b for b in blocks if not os.path.exists(os.path.join(CACHE, f"{b}.json"))]
    print("todo", len(todo))
    for i in range(0, len(todo), 20):
        part = todo[i:i+20]
        payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_getBlockByNumber", "params": [hex(b), False]}
                   for j, b in enumerate(part)]
        got = None
        for a in range(10):
            try:
                d = post(RPCS[a % len(RPCS)], payload)
                by = {x["id"]: x for x in d}
                got = [by.get(j, {}).get("result") for j in range(len(part))]
                break
            except Exception as e:
                sys.stderr.write(f"retry {a}: {e}\n"); time.sleep(min(2 * (a + 1), 15))
        if got is None:
            raise RuntimeError("failed batch")
        for b, h in zip(part, got):
            if h is None:
                continue
            json.dump({"number": int(h["number"], 16), "timestamp": int(h["timestamp"], 16),
                       "baseFeePerGas": int(h["baseFeePerGas"], 16),
                       "blobGasUsed": int(h.get("blobGasUsed", "0x0"), 16),
                       "excessBlobGas": int(h.get("excessBlobGas", "0x0"), 16),
                       "gasUsed": int(h["gasUsed"], 16), "gasLimit": int(h["gasLimit"], 16)},
                      open(os.path.join(CACHE, f"{b}.json"), "w"))
        print("fetched", i, "/", len(todo), flush=True)
        time.sleep(0.1)
    print("done")

if __name__ == "__main__":
    main()
