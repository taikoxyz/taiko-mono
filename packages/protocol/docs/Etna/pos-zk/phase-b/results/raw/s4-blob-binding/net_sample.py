import json, time, urllib.request, collections
URLS = ["https://rpc.mevblocker.io", "https://0xrpc.io/eth"]
UA = {"content-type": "application/json", "user-agent": "Mozilla/5.0 (s4-public-data-collection)"}
def batch(url, calls, timeout=30):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        j = json.loads(r.read().decode())
    out = [None] * len(calls)
    for it in j:
        if "result" in it:
            out[it["id"]] = it["result"]
    return out
lo, hi = 24792175, 26140717
step = (hi - lo) // 400
blocks = [lo + i * step for i in range(400)]
hist = collections.Counter(); mx = 0; got = 0
for i in range(0, len(blocks), 25):
    chunk = blocks[i:i + 25]
    calls = [("eth_getBlockByNumber", [hex(b), False]) for b in chunk]
    res = None
    for url in URLS:
        try:
            res = batch(url, calls); break
        except Exception as e:
            time.sleep(1)
    if res is None:
        print("fail", i); continue
    for h in res:
        if not h:
            continue
        n = int(h["blobGasUsed"], 16) // 131072
        hist[n] += 1; mx = max(mx, n); got += 1
    time.sleep(0.2)
print("sampled", got, "max blobs in one block", mx, "hist", dict(sorted(hist.items())))
json.dump({"sampled_blocks": got, "max_blobs_per_block_observed": mx,
           "hist": {str(k): v for k, v in sorted(hist.items())}, "lo": lo, "hi": hi, "step": step},
          open("network-blob-usage-sample.json", "w"), indent=1)
