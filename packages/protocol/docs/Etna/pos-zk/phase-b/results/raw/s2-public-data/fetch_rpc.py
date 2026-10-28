#!/usr/bin/env python3
"""
S2 (public-data substitution) raw-evidence fetcher.

Modes
  blocks <rpc_url> <from_block> <to_block> <out.jsonl> [--batch N] [--full]
      Fetches every block in [from,to] inclusive via JSON-RPC batch
      eth_getBlockByNumber(n, false). Writes one JSON object per line.
      Default: trimmed fields {number,timestamp,hash,parentHash,miner,gasUsed,gasLimit}
      --full: writes the complete header object as returned.

  logs <rpc_url> <address> <from_block> <to_block> <out.json> [--topic0 0x..] [--chunk N]
      eth_getLogs in chunks of N blocks (default 10000). On error the chunk is
      halved and retried, down to 1 block. Writes the list of raw log objects.

Every request and every retry is appended to <out>.meta.txt with a UTC timestamp,
so the fetch is reproducible and its coverage window is auditable.
"""
import json, sys, time, urllib.request, urllib.error, datetime, os

def now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def log_meta(path, line):
    with open(path, "a") as f:
        f.write(now() + " " + line + "\n")

def rpc(url, payload, retries=6):
    body = json.dumps(payload).encode()
    last = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, data=body, headers={
                "content-type": "application/json",
                "user-agent": "curl/8.7.1",  # some public RPCs 403 the default python-urllib UA
            })
            with urllib.request.urlopen(req, timeout=90) as r:
                return json.loads(r.read())
        except Exception as e:
            last = e
            time.sleep(min(2 ** attempt, 20))
    raise RuntimeError(f"rpc failed after {retries} attempts: {last}")

def fetch_blocks(url, frm, to, out, batch, full, meta, resume=False):
    n = frm
    total = 0
    mode = "w"
    if resume and os.path.exists(out) and os.path.getsize(out) > 0:
        with open(out) as g:
            last = None
            for line in g:
                if line.strip():
                    last = line
        if last:
            n = int(json.loads(last)["number"], 16) + 1
            total = n - frm
            mode = "a"
            log_meta(meta, f"RESUME at block {n}")
    with open(out, mode) as f:
        while n <= to:
            hi = min(n + batch - 1, to)
            payload = [{"jsonrpc":"2.0","id":i,"method":"eth_getBlockByNumber",
                        "params":[hex(n + i), False]} for i in range(hi - n + 1)]
            res = rpc(url, payload)
            if isinstance(res, dict):
                res = [res]
            got = {}
            for item in res:
                if "result" in item and item["result"]:
                    b = item["result"]
                    got[int(b["number"], 16)] = b
            for i in range(n, hi + 1):
                b = got.get(i)
                if b is None:
                    for attempt in range(5):      # individual retry: batch may drop entries under rate limiting
                        time.sleep(2 * (attempt + 1))
                        one = rpc(url, {"jsonrpc":"2.0","id":1,"method":"eth_getBlockByNumber","params":[hex(i), False]})
                        if "result" in one and one["result"]:
                            b = one["result"]
                            log_meta(meta, f"individual retry ok block {i} attempt {attempt+1}")
                            break
                    if b is None:
                        raise RuntimeError(f"missing block {i} after individual retries")
                if full:
                    f.write(json.dumps(b, separators=(",",":")) + "\n")
                else:
                    f.write(json.dumps({k: b[k] for k in
                        ("number","timestamp","hash","parentHash","miner","gasUsed","gasLimit")},
                        separators=(",",":")) + "\n")
            total += hi - n + 1
            log_meta(meta, f"blocks {n}-{hi} ok ({len(got)} headers) cumulative={total}")
            print(f"\r  {total} blocks", end="", file=sys.stderr, flush=True)
            n = hi + 1
            time.sleep(0.05)
    print("", file=sys.stderr)
    return total

def fetch_logs(url, address, frm, to, out, topic0, chunk, meta):
    all_logs = []
    stack = [(frm, to)]
    while stack:
        lo, hi = stack.pop()
        params = {"address": address, "fromBlock": hex(lo), "toBlock": hex(hi)}
        if topic0:
            params["topics"] = [topic0]
        try:
            res = rpc(url, {"jsonrpc":"2.0","id":1,"method":"eth_getLogs","params":[params]})
            if "error" in res:
                raise RuntimeError(json.dumps(res["error"])[:200])
            logs = res.get("result", [])
            all_logs.extend(logs)
            log_meta(meta, f"logs {lo}-{hi} ok n={len(logs)} cumulative={len(all_logs)}")
            print(f"  logs {lo}-{hi}: {len(logs)}", file=sys.stderr)
            time.sleep(0.2)
        except Exception as e:
            span = hi - lo + 1
            if span <= 1:
                raise RuntimeError(f"getLogs failed at single block {lo}: {e}")
            half = span // 2
            stack.append((lo + half, hi))
            stack.append((lo, lo + half - 1))
            log_meta(meta, f"logs {lo}-{hi} FAILED ({e}); split to {span//2}-block halves")
            print(f"  split {lo}-{hi}: {e}", file=sys.stderr)
            time.sleep(1)
    with open(out, "w") as f:
        json.dump(all_logs, f, indent=1)
    return len(all_logs)

def main():
    mode = sys.argv[1]
    args = [a for a in sys.argv[2:] if not a.startswith("--")]
    opts = {}
    for a in sys.argv[2:]:
        if a.startswith("--"):
            k, _, v = a[2:].partition("=")
            opts[k] = v if v else True
    meta = args[-1] + ".meta.txt"
    if mode == "blocks":
        url, frm, to, out = args[0], int(args[1]), int(args[2]), args[3]
        batch = int(opts.get("batch", 100))
        log_meta(meta, f"START blocks url={url} from={frm} to={to} batch={batch} full={bool(opts.get('full'))}")
        t0 = time.time()
        tot = fetch_blocks(url, frm, to, out, batch, bool(opts.get("full")), meta, bool(opts.get("resume")))
        log_meta(meta, f"END blocks n={tot} elapsed={time.time()-t0:.1f}s")
    elif mode == "logs":
        url, address, frm, to, out = args[0], args[1], int(args[2]), int(args[3]), args[4]
        chunk = int(opts.get("chunk", 10000))
        log_meta(meta, f"START logs url={url} address={address} from={frm} to={to} topic0={opts.get('topic0')}")
        t0 = time.time()
        n = fetch_logs(url, address, frm, to, out, opts.get("topic0"), chunk, meta)
        log_meta(meta, f"END logs n={n} elapsed={time.time()-t0:.1f}s")
    elif mode == "headers":
        # headers <rpc_url> <heights_file> <out.json>  -- arbitrary heights, batched
        url, heights_file, out = args[0], args[1], args[2]
        heights = [int(x) for x in open(heights_file).read().split()]
        log_meta(meta, f"START headers url={url} n={len(heights)}")
        res = {}
        for i in range(0, len(heights), 100):
            chunk = heights[i:i+100]
            payload = [{"jsonrpc":"2.0","id":j,"method":"eth_getBlockByNumber",
                        "params":[hex(h), False]} for j, h in enumerate(chunk)]
            r = rpc(url, payload)
            if isinstance(r, dict):
                r = [r]
            for item in r:
                if item.get("result"):
                    b = item["result"]
                    res[str(int(b["number"], 16))] = {"timestamp": b["timestamp"], "hash": b["hash"]}
            time.sleep(0.2)
        with open(out, "w") as f:
            json.dump(res, f, indent=1, sort_keys=True)
        log_meta(meta, f"END headers n={len(res)}")
        print(f"headers: {len(res)}/{len(heights)}", file=sys.stderr)
    else:
        raise SystemExit("unknown mode")

if __name__ == "__main__":
    main()
