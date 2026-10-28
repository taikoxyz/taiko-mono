#!/usr/bin/env python3
"""Minimal JSON-RPC client with retry/backoff for public endpoints.
Usage:
  python3 rpc.py call <url> <method> '<params-json>'
  python3 rpc.py logs <url> <address> <fromBlock> <toBlock> [chunk]
Writes nothing to disk unless redirected; all output is JSON on stdout.
"""
import json, sys, time, urllib.request, urllib.error

def call(url, method, params, tries=8, base=1.5):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, data=body, headers={"content-type": "application/json"})
            with urllib.request.urlopen(req, timeout=45) as resp:
                out = json.loads(resp.read().decode())
            if "error" in out:
                raise RuntimeError("rpc error: %s" % json.dumps(out["error"])[:300])
            return out["result"]
        except Exception as e:  # noqa
            last = e
            time.sleep(base ** i * 0.5)
    raise SystemExit("FAILED %s %s: %s" % (method, json.dumps(params)[:200], last))

def batch(url, calls, tries=8):
    """calls: list of (method, params). Returns list of results (or raises)."""
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    body = json.dumps(payload).encode()
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, data=body, headers={"content-type": "application/json"})
            with urllib.request.urlopen(req, timeout=60) as resp:
                out = json.loads(resp.read().decode())
            out.sort(key=lambda r: r["id"])
            res = []
            for r in out:
                if "error" in r:
                    raise RuntimeError("rpc error: %s" % json.dumps(r["error"])[:200])
                res.append(r["result"])
            return res
        except Exception as e:
            last = e
            time.sleep(1.5 ** i * 0.5)
    raise SystemExit("BATCH FAILED: %s" % last)

def get_logs(url, address, lo, hi, chunk=2000, topics=None):
    out = []
    b = lo
    while b <= hi:
        e = min(b + chunk - 1, hi)
        params = {"address": address, "fromBlock": hex(b), "toBlock": hex(e)}
        if topics:
            params["topics"] = topics
        out.extend(call(url, "eth_getLogs", [params]))
        b = e + 1
    return out

if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "call":
        print(json.dumps(call(sys.argv[2], sys.argv[3], json.loads(sys.argv[4]))))
    elif cmd == "logs":
        address = sys.argv[3]; lo = int(sys.argv[4]); hi = int(sys.argv[5])
        chunk = int(sys.argv[6]) if len(sys.argv) > 6 else 2000
        print(json.dumps(get_logs(sys.argv[2], address, lo, hi, chunk)))
