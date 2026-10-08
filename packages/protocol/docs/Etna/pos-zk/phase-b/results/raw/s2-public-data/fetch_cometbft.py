#!/usr/bin/env python3
"""
Fetch CometBFT (Tendermint) block timestamps + the current validator set from a
public CometBFT RPC endpoint, for third-party production cadence comparisons.

Usage: fetch_cometbft.py <rpc_url> <n_blocks> <out.jsonl> [--batch N]

Writes <out.jsonl> with {"height","time","num_txs"} per block and
<out>.validators.json with the paginated /validators result plus a count.
A <out>.meta.txt records the endpoint, node version, network and UTC window.
"""
import json, sys, time, urllib.request, datetime

def now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def post(url, payload, retries=6, timeout=60):
    body = json.dumps(payload).encode()
    last = None
    for a in range(retries):
        try:
            req = urllib.request.Request(url, data=body, headers={
                "content-type": "application/json", "user-agent": "curl/8.7.1"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read())
        except Exception as e:
            last = e
            time.sleep(min(2 ** a, 20))
    raise RuntimeError(f"post failed: {last}")

def get(url, retries=6, timeout=60):
    last = None
    for a in range(retries):
        try:
            req = urllib.request.Request(url, headers={"user-agent": "curl/8.7.1"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read())
        except Exception as e:
            last = e
            time.sleep(min(2 ** a, 20))
    raise RuntimeError(f"get failed: {last}")

def main():
    url, n, out = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    batch = 20
    for a in sys.argv[4:]:
        if a.startswith("--batch="):
            batch = int(a.split("=")[1])
    meta = out + ".meta.txt"
    st = post(url, {"jsonrpc":"2.0","id":1,"method":"status","params":{}})
    res = st["result"]
    tip = int(res["sync_info"]["latest_block_height"])
    ver = res["node_info"]["version"]
    net = res["node_info"]["network"]
    moniker = res["node_info"].get("moniker")
    with open(meta, "a") as f:
        f.write(f"{now()} START cometbft url={url} network={net} version={ver} moniker={moniker} tip={tip} n={n}\n")
    lo = tip - n + 1
    written = 0
    with open(out, "w") as f:
        h = lo
        while h <= tip:
            hi = min(h + batch - 1, tip)
            payload = [{"jsonrpc":"2.0","id":i,"method":"block",
                        "params":{"height":str(h+i)}} for i in range(hi - h + 1)]
            r = post(url, payload)
            if isinstance(r, dict):
                r = [r]
            byh = {}
            for item in r:
                b = (item.get("result") or {}).get("block")
                if b:
                    byh[int(b["header"]["height"])] = b
            for i in range(h, hi + 1):
                b = byh.get(i)
                if b is None:                      # retry individually (object then array params)
                    for attempt in range(4):
                        time.sleep(1 + attempt)
                        one = post(url, {"jsonrpc":"2.0","id":1,"method":"block","params":{"height":str(i)}})
                        b = (one.get("result") or {}).get("block")
                        if b: break
                        one = post(url, {"jsonrpc":"2.0","id":1,"method":"block","params":[str(i)]})
                        b = (one.get("result") or {}).get("block")
                        if b: break
                    if b is None:
                        raise RuntimeError(f"missing cometbft block {i}")
                f.write(json.dumps({"height": i, "time": b["header"]["time"],
                                    "num_txs": len(b.get("data", {}).get("txs") or [])},
                                   separators=(",", ":")) + "\n")
                written += 1
            print(f"\r  {written} blocks", end="", file=sys.stderr, flush=True)
            h = hi + 1
            time.sleep(0.1)
    print("", file=sys.stderr)
    # validator set (paginated)
    vals, page = [], 1
    while True:
        v = get(f"{url}/validators?per_page=100&page={page}")
        vs = v.get("result", {}).get("validators") or []
        vals.extend(vs)
        total = int(v.get("result", {}).get("total") or 0)
        if len(vals) >= total or not vs or page > 20:
            break
        page += 1
        time.sleep(0.3)
    with open(out + ".validators.json", "w") as f:
        json.dump({"count": len(vals), "total_reported": total, "validators": vals}, f, indent=1)
    with open(meta, "a") as f:
        f.write(f"{now()} END cometbft blocks={written} validators={len(vals)} (total={total})\n")
    print(f"wrote {written} blocks; validators={len(vals)} (reported total={total})", file=sys.stderr)

if __name__ == "__main__":
    main()
