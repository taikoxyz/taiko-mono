#!/usr/bin/env python3
"""Small robust JSON-RPC / beacon helper for the S4 public-data collection."""
import json, time, urllib.request, urllib.error

EL_RPCS = [
    "https://rpc.mevblocker.io",
    "https://eth.blockscout.com/api/eth-rpc",
    "https://0xrpc.io/eth",
    "https://ethereum-rpc.publicnode.com",
]
BEACON_RPCS = [
    "https://ethereum-beacon-api.publicnode.com",
    "https://lodestar-mainnet.chainsafe.io",
    "https://beaconstate.info",
]

def _post(url, payload, timeout):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"content-type": "application/json", "user-agent": "Mozilla/5.0 (s4-public-data-collection)"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def el(method, params, tries=3, timeout=60, urls=None):
    err = None
    for a in range(tries):
        for url in (urls or EL_RPCS):
            try:
                j = _post(url, {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}, timeout)
                if "result" in j:
                    return j["result"], url
                err = j.get("error")
            except Exception as e:
                err = repr(e)[:160]
            time.sleep(1.5)
    raise RuntimeError(f"{method} failed via all RPCs: {err}")

def el_batch(calls, tries=3, timeout=90, urls=None):
    """calls: list of (method, params). Returns list of results (None on per-call error)."""
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    err = None
    for a in range(tries):
        for url in (urls or EL_RPCS):
            try:
                j = _post(url, payload, timeout)
                if isinstance(j, list):
                    out = [None] * len(calls)
                    for item in j:
                        if "result" in item:
                            out[item["id"]] = item["result"]
                    return out, url
                err = str(j)[:160]
            except Exception as e:
                err = repr(e)[:160]
            time.sleep(2)
    raise RuntimeError(f"batch failed via all RPCs: {err}")

def beacon(path, timeout=45, urls=None):
    err = None
    for a in range(3):
        for base in (urls or BEACON_RPCS):
            try:
                req = urllib.request.Request(base + path, headers={'user-agent': 'Mozilla/5.0 (s4-public-data-collection)'})
                with urllib.request.urlopen(req, timeout=timeout) as r:
                    return json.loads(r.read().decode()), base
            except urllib.error.HTTPError as e:
                body = e.read().decode()[:200]
                err = f"{e.code} {body}"
                if e.code == 404:
                    return {"error": err}, base
            except Exception as e:
                err = repr(e)[:160]
            time.sleep(1.0)
    raise RuntimeError(f"beacon {path} failed: {err}")
