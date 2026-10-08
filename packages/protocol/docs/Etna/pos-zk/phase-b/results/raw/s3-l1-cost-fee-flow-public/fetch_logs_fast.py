#!/usr/bin/env python3
"""Fast log-chunk prefill: tries several endpoints at several chunk sizes and writes
the collector's cache files (logchunks/<from>-<to>.json)."""
import json, os, sys, time, urllib.request

RPCS = [
    "https://gateway.tenderly.co/public/mainnet",
    "https://rpc.mevblocker.io",
    "https://eth.blockrazor.xyz",
    "https://rpc.flashbots.net",
    "https://ethereum-rpc.publicnode.com",
    "https://eth.drpc.org",
]
INBOX = "0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f"
UA = "taiko-pos-zk-s3-public-data/1.0"

def post(url, payload, timeout=120):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"content-type": "application/json", "User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def get_logs(frm, to):
    payload = {"jsonrpc": "2.0", "id": 1, "method": "eth_getLogs",
               "params": [{"address": INBOX, "fromBlock": hex(frm), "toBlock": hex(to)}]}
    errs = []
    for url in RPCS:
        try:
            d = post(url, payload)
            if "error" in d:
                errs.append((url, str(d["error"])[:90])); continue
            return d["result"], url
        except Exception as e:
            errs.append((url, str(e)[:60]))
        time.sleep(0.2)
    raise RuntimeError(str(errs))

def main():
    frm, to = int(sys.argv[1]), int(sys.argv[2])
    step = int(sys.argv[3]) if len(sys.argv) > 3 else 8000
    os.makedirs("logchunks", exist_ok=True)
    n = frm
    while n <= to:
        m = min(n + step - 1, to)
        p = os.path.join("logchunks", f"{n}-{m}.json")
        if os.path.exists(p) and os.path.getsize(p) > 2:
            print("cached", n, m); n = m + 1; continue
        ok = False
        for s in (8000, 4000, 1000, 200):
            if m - n + 1 < s and s != 8000:
                pass
            try:
                mm = min(n + s - 1, to)
                res, url = get_logs(n, mm)
                # write under the actual chunk key used by the collector only when size matches step
                json.dump(res, open(os.path.join("logchunks", f"{n}-{mm}.json"), "w"))
                print("fetched", n, mm, len(res), url, flush=True)
                n = mm + 1
                ok = True
                break
            except Exception as e:
                print("fail size", s, str(e)[:200], flush=True)
        if not ok:
            raise SystemExit("could not fetch " + str(n))
        time.sleep(0.2)

if __name__ == "__main__":
    main()
