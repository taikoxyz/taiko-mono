#!/usr/bin/env python3
"""S4: finish the Shasta-era Proposed log scan with mevblocker, 10k chunks.

Usage: finish_scan2.py <fromBlock> <toBlock> <outdir>
"""
import json, os, sys, time, urllib.request

TOPIC0 = "0x7c4c4523e17533e451df15762a093e0693a2cd8b279fe54c6cd3777ed5771213"
INBOX = "0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f"
URL = "https://rpc.mevblocker.io"
UA = {"content-type": "application/json", "user-agent": "Mozilla/5.0 (s4-public-data-collection)"}

def get(frm, to):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_getLogs",
                       "params": [{"address": INBOX, "fromBlock": hex(frm), "toBlock": hex(to),
                                   "topics": [TOPIC0]}]}).encode()
    req = urllib.request.Request(URL, data=body, headers=UA)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode())

def main(frm0, to0, outdir, chunk=10000):
    total = 0
    a = frm0
    while a <= to0:
        b = min(a + chunk - 1, to0)
        ok = False
        for attempt in range(5):
            try:
                j = get(a, b)
                if "result" in j:
                    logs = j["result"]
                    with open(os.path.join(outdir, "logs", f"chunk-{a}-{b}.json"), "w") as f:
                        json.dump({"request": {"url": URL, "address": INBOX, "topic0": TOPIC0,
                                               "fromBlock": a, "toBlock": b,
                                               "fetched_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())},
                                   "response": logs}, f)
                    total += len(logs)
                    print(f"{a}-{b}: {len(logs)} ({total})", flush=True)
                    a = b + 1; ok = True; break
                raise RuntimeError(str(j)[:120])
            except Exception as e:
                print(f"  retry {a}-{b}: {repr(e)[:110]}", flush=True)
                time.sleep(3 * (attempt + 1))
        if not ok:
            raise SystemExit(f"failed at {a}")
        time.sleep(0.3)
    print("TOTAL", total)

if __name__ == "__main__":
    main(int(sys.argv[1]), int(sys.argv[2]), sys.argv[3])
