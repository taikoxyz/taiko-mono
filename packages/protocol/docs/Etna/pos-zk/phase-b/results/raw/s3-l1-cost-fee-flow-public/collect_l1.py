#!/usr/bin/env python3
"""S3 public-data collector (resumable): Taiko Unzen Inbox on Ethereum mainnet.

Caches every RPC response on disk so a rate-limited run can be resumed by re-running.
Usage: collect_l1.py <start_ts> <end_ts> <proved_topic0>
"""
import json, os, sys, time, urllib.request, urllib.error

RPCS = [
    "https://ethereum-rpc.publicnode.com",
    "https://eth.drpc.org",
    "https://rpc.mevblocker.io",
    "https://gateway.tenderly.co/public/mainnet",
    "https://eth.blockrazor.xyz",
    "https://rpc.flashbots.net",
]
INBOX = "0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f"
TOPIC_PROPOSED = "0x7c4c4523e17533e451df15762a093e0693a2cd8b279fe54c6cd3777ed5771213"
UA = "taiko-pos-zk-s3-public-data/1.0"
LOGCHUNKS = "logchunks"
TXCACHE = "txcache"

def _post(url, payload, timeout):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"content-type": "application/json", "User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def rpc(method, params, tries=14):
    last = None
    for i in range(tries):
        url = RPCS[i % len(RPCS)]
        try:
            d = _post(url, {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}, 45)
            if "error" in d:
                raise RuntimeError(str(d["error"])[:200])
            return d["result"]
        except Exception as e:
            last = e
            time.sleep(min(1.0 * (2 ** min(i, 4)), 20))
    raise RuntimeError(f"all RPCs failed for {method}: {last}")

def block_ts(n):
    b = rpc("eth_getBlockByNumber", [hex(n), False])
    return int(b["timestamp"], 16)

def find_block_at_or_after(ts, lo, hi):
    while lo < hi:
        mid = (lo + hi) // 2
        if block_ts(mid) < ts:
            lo = mid + 1
        else:
            hi = mid
    return lo

def cached_json(path, fn):
    if os.path.exists(path) and os.path.getsize(path) > 2:
        return json.load(open(path))
    v = fn()
    json.dump(v, open(path, "w"))
    return v

def main():
    start_ts, end_ts, topic_proved = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
    os.makedirs(LOGCHUNKS, exist_ok=True); os.makedirs(TXCACHE, exist_ok=True)
    head = int(rpc("eth_blockNumber", []), 16)
    t_hi = block_ts(head)
    lo = head - int((t_hi - start_ts) / 12) - 3000
    start_block = find_block_at_or_after(start_ts, lo, head)
    end_block = find_block_at_or_after(end_ts, lo, head) - 1
    t0, t1 = block_ts(start_block), block_ts(end_block + 1)
    meta = {"inbox": INBOX, "topic_proposed": TOPIC_PROPOSED, "topic_proved": topic_proved,
            "window": {"start_ts": start_ts, "end_ts": end_ts, "start_block": start_block, "end_block": end_block,
                       "start_block_ts": t0, "end_block_plus1_ts": t1, "head": head,
                       "collected_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}}
    json.dump(meta, open("window.json", "w"), indent=1)
    print(json.dumps(meta["window"]), flush=True)

    logs = []
    step = 8000
    n = start_block
    while n <= end_block:
        to = min(n + step - 1, end_block)
        p = os.path.join(LOGCHUNKS, f"{n}-{to}.json")
        res = cached_json(p, lambda n=n, to=to: rpc("eth_getLogs", [{"address": INBOX, "fromBlock": hex(n), "toBlock": hex(to)}]))
        logs.extend(res)
        print("logs", n, to, len(res), "total", len(logs), flush=True)
        n = to + 1
        time.sleep(0.08)
    json.dump(logs, open("inbox-logs.json", "w"))

    def with_topic(t):
        return [l for l in logs if l["topics"] and l["topics"][0].lower() == t.lower()]
    prop, prov = with_topic(TOPIC_PROPOSED), with_topic(topic_proved)
    json.dump(prop, open("proposed-logs.json", "w")); json.dump(prov, open("proved-logs.json", "w"))
    print("proposed", len(prop), "proved", len(prov), flush=True)

    def fetch(kind, hashes):
        txs, rcs = {}, {}
        missing = [h for h in hashes if not os.path.exists(os.path.join(TXCACHE, f"{kind}-{h}.json"))]
        BS = 20
        for i in range(0, len(missing), BS):
            part = missing[i:i+BS]
            calls = [("eth_getTransactionByHash", [h]) for h in part] + [("eth_getTransactionReceipt", [h]) for h in part]
            payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(calls)]
            got = None
            for a in range(10):
                try:
                    resp = _post(RPCS[a % len(RPCS)], payload, 90)
                    by = {x["id"]: x for x in resp}
                    got = [by.get(j, {}).get("result") for j in range(len(calls))]
                    break
                except Exception as e:
                    sys.stderr.write(f"txbatch retry {a}: {e}\n")
                    time.sleep(min(2 * (a + 1), 20))
            if got is None:
                raise RuntimeError("tx batch failed")
            for k, h in enumerate(part):
                v = {"tx": got[k], "receipt": got[k + len(part)]}
                json.dump(v, open(os.path.join(TXCACHE, f"{kind}-{h}.json"), "w"))
            print(kind, i, "/", len(missing), flush=True)
            time.sleep(0.15)
        for h in hashes:
            v = json.load(open(os.path.join(TXCACHE, f"{kind}-{h}.json")))
            txs[h], rcs[h] = v["tx"], v["receipt"]
        return txs, rcs
    ph = sorted({l["transactionHash"] for l in prop}); vh = sorted({l["transactionHash"] for l in prov})
    ptx, prc = fetch("prop", ph); vtx, vrc = fetch("prov", vh)
    json.dump({"txs": ptx, "receipts": prc}, open("propose-txs.json", "w"))
    json.dump({"txs": vtx, "receipts": vrc}, open("prove-txs.json", "w"))
    print("fetched propose", len(ptx), "prove", len(vtx), flush=True)

    fh = {"baseFeePerGas": [], "blobBaseFeePerGas": [], "gasUsedRatio": [], "chunks": []}
    n = start_block
    while n <= end_block:
        cnt = min(1000, end_block - n + 1)
        p = os.path.join(LOGCHUNKS, f"fee-{n}-{cnt}.json")
        r = cached_json(p, lambda n=n, cnt=cnt: rpc("eth_feeHistory", [hex(cnt), hex(n + cnt - 1), [10, 50, 90]]))
        fh["baseFeePerGas"].extend(r["baseFeePerGas"]); fh["blobBaseFeePerGas"].extend(r.get("blobBaseFeePerGas", []))
        fh["gasUsedRatio"].extend(r["gasUsedRatio"]); fh["chunks"].append({"from": n, "count": cnt, "oldestBlock": r["oldestBlock"]})
        print("feeHistory", n, cnt, flush=True)
        n += cnt
        time.sleep(0.1)
    json.dump(fh, open("l1-fee-history.json", "w"))
    print("done", flush=True)

if __name__ == "__main__":
    main()
