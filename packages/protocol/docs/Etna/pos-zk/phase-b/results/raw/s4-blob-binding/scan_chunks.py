#!/usr/bin/env python3
"""S4: chunked eth_getLogs scan of the Taiko MainnetInbox 'Proposed' event.

Fixed 10,000-block chunks; a chunk is re-fetched split in half if every RPC
fails or if the response looks capped (>=1000 logs). Raw responses are written
verbatim under logs/ with their request metadata.

Usage: python3 scan_chunks.py <fromBlock> <toBlock> <outdir>
"""
import json, os, sys, time, urllib.request

TOPIC0 = "0x7c4c4523e17533e451df15762a093e0693a2cd8b279fe54c6cd3777ed5771213"
INBOX  = "0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f"
RPCS = [
    ("https://0xrpc.io/eth", 10000),
    ("https://rpc.mevblocker.io", 100000),
    ("https://eth.blockscout.com/api/eth-rpc", 20000),
    ("https://ethereum-rpc.publicnode.com", 1900),
]

def rpc(url, method, params, timeout=90):
    body = json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode()
    req = urllib.request.Request(url, data=body, headers={"content-type":"application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def get_logs(frm, to):
    span = to - frm + 1
    err = None
    for url, maxr in RPCS:
        if span > maxr:
            continue
        for attempt in range(3):
            try:
                j = rpc(url, "eth_getLogs", [{"address": INBOX, "fromBlock": hex(frm),
                                              "toBlock": hex(to), "topics": [TOPIC0]}])
                if "result" in j and isinstance(j["result"], list):
                    return j["result"], url
                err = j.get("error")
            except Exception as e:
                err = repr(e)[:160]
            time.sleep(1.0 + attempt)
    return None, err

def main(frm0, to0, outdir, chunk=10000):
    os.makedirs(os.path.join(outdir, "logs"), exist_ok=True)
    total = 0
    stack = list(range(frm0, to0 + 1, chunk))
    idx = []
    while stack:
        a = stack.pop(0)
        b = min(a + chunk - 1, to0)
        logs, url = get_logs(a, b)
        if logs is None:
            if b - a + 1 <= 50:
                raise RuntimeError(f"chunk {a}-{b} failed: {url}")
            mid = (a + b) // 2
            stack.insert(0, mid + 1); stack.insert(0, a)
            chunk = max(50, (b - a + 1) // 2)
            print(f"  split {a}-{b}", flush=True)
            continue
        if len(logs) >= 1000 and (b - a + 1) > 50:
            mid = (a + b) // 2
            stack.insert(0, mid + 1); stack.insert(0, a)
            print(f"  capped {a}-{b} {len(logs)} -> split", flush=True)
            continue
        with open(os.path.join(outdir, "logs", f"chunk-{a}-{b}.json"), "w") as f:
            json.dump({"request": {"url": url, "address": INBOX, "topic0": TOPIC0,
                                   "fromBlock": a, "toBlock": b,
                                   "fetched_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())},
                       "response": logs}, f)
        idx.append({"from": a, "to": b, "logs": len(logs), "url": url})
        total += len(logs)
        print(f"  {a}-{b}: {len(logs)} ({total})", flush=True)
        time.sleep(0.5)
    with open(os.path.join(outdir, "logs", "index.json"), "w") as f:
        json.dump({"fromBlock": frm0, "toBlock": to0, "total_logs": total,
                   "chunks": len(idx), "detail": idx}, f, indent=1)
    print("TOTAL", total)

if __name__ == "__main__":
    main(int(sys.argv[1]), int(sys.argv[2]), sys.argv[3])
