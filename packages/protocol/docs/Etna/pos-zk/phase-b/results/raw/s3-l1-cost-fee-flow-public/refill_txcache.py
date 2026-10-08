#!/usr/bin/env python3
"""Refill any tx/receipt cache entries that are missing or null."""
import json, os, sys, time, urllib.request

RPCS = ["https://ethereum-rpc.publicnode.com", "https://eth.drpc.org", "https://rpc.mevblocker.io",
        "https://gateway.tenderly.co/public/mainnet", "https://eth.blockrazor.xyz", "https://rpc.flashbots.net"]
UA = "taiko-pos-zk-s3-public-data/1.0"

def post(url, payload, timeout=60):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"content-type": "application/json", "User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def main():
    logs = json.load(open("inbox-logs.json"))
    want = {"prop": sorted({l["transactionHash"] for l in logs if l["topics"][0].lower() == json.load(open("window.json"))["topic_proposed"].lower()}),
            "prov": sorted({l["transactionHash"] for l in logs if l["topics"][0].lower() == json.load(open("window.json"))["topic_proved"].lower()})}
    for kind, hashes in want.items():
        bad = []
        for h in hashes:
            p = f"txcache/{kind}-{h}.json"
            ok = False
            if os.path.exists(p):
                try:
                    v = json.load(open(p)); ok = v.get("tx") is not None and v.get("receipt") is not None
                except Exception:
                    ok = False
            if not ok:
                bad.append(h)
        print(kind, "missing", len(bad), "of", len(hashes))
        for i, h in enumerate(bad):
            payload = [{"jsonrpc": "2.0", "id": 1, "method": "eth_getTransactionByHash", "params": [h]},
                       {"jsonrpc": "2.0", "id": 2, "method": "eth_getTransactionReceipt", "params": [h]}]
            got = None
            for a in range(20):
                try:
                    d = post(RPCS[a % len(RPCS)], payload)
                    by = {x["id"]: x for x in d}
                    tx = by.get(1, {}).get("result"); rc = by.get(2, {}).get("result")
                    if tx is None or rc is None:
                        raise RuntimeError("null")
                    got = {"tx": tx, "receipt": rc}
                    break
                except Exception as e:
                    sys.stderr.write(f"retry {a} {h[:12]}: {e}\n"); time.sleep(min(2 * (a + 1), 15))
            if got is None:
                print("STILL MISSING", h); continue
            json.dump(got, open(f"txcache/{kind}-{h}.json", "w"))
            print("refilled", kind, i, h[:14])
            time.sleep(0.2)

if __name__ == "__main__":
    main()
