#!/usr/bin/env python3
"""
Fast CometBFT block-timestamp fetcher using the /blockchain endpoint
(20 blocks per HTTP request), for third-party production cadence checks.

Usage: fetch_cometbft_chain.py <rpc_url> <n_blocks> <out.jsonl>
Writes {"height","time","num_txs"} per line plus <out>.meta.txt and
<out>.validators.json (paginated /validators result).
"""
import json, sys, time, urllib.request, datetime

def now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def req(url, retries=6, timeout=45):
    last = None
    for a in range(retries):
        try:
            r = urllib.request.Request(url, headers={"user-agent": "curl/8.7.1"})
            with urllib.request.urlopen(r, timeout=timeout) as resp:
                return json.loads(resp.read())
        except Exception as e:
            last = e
            time.sleep(min(2 ** a, 15))
    raise RuntimeError(f"get failed {url}: {last}")

def main():
    url, n, out = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    meta = out + ".meta.txt"
    st = req(url + "/status")["result"]
    tip = int(st["sync_info"]["latest_block_height"])
    net, ver = st["node_info"]["network"], st["node_info"]["version"]
    with open(meta, "a") as f:
        f.write(f"{now()} START cometbft-chain url={url} network={net} version={ver} tip={tip} n={n}\n")
    lo = tip - n + 1
    written = 0
    with open(out, "w") as f:
        h = lo
        while h <= tip:
            hi = min(h + 19, tip)
            r = req(f"{url}/blockchain?minHeight={h}&maxHeight={hi}")
            metas = r["result"]["block_metas"] or []
            for m in metas:
                hdr = m["header"]
                f.write(json.dumps({"height": int(hdr["height"]), "time": hdr["time"],
                                    "num_txs": int(m.get("num_txs") or 0)}, separators=(",", ":")) + "\n")
                written += 1
            h = hi + 1
            time.sleep(0.15)
    vals, page, total = [], 1, None
    while True:
        v = req(f"{url}/validators?per_page=100&page={page}")
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
        f.write(f"{now()} END cometbft-chain blocks={written} validators={len(vals)} (total={total})\n")
    print(f"{net}: {written} blocks, {len(vals)} validators", file=sys.stderr)

if __name__ == "__main__":
    main()
