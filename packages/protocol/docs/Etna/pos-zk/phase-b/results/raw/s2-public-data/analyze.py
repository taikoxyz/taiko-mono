#!/usr/bin/env python3
"""
S2 public-data substitution - interval statistics from the raw evidence files.

Modes
  blocks   <file.jsonl> <label>                # eth_getBlockByNumber headers (number,timestamp)
  cometbft <file.jsonl> <label>                # CometBFT blocks (height,time,num_txs)
  inbox    <logs.json> <headers.json>          # Taiko Shaped Inbox Proposed/Proved logs + L1 headers

Percentiles use the nearest-rank method (index = ceil(p/100*N)-1) and are printed
with the sample count so a reader can see when a tail percentile is thin.
Writes <label>_intervals.csv (or proposals.csv / proofs.csv) in the same directory.
"""
import json, sys, math, datetime, collections, csv, os

TOPIC_PROPOSED = "0x7c4c4523e17533e451df15762a093e0693a2cd8b279fe54c6cd3777ed5771213"
TOPIC_PROVED   = "0xa274dcaff3629ec7d69d144038e97732516ff306fcbf8a2bc9423d106779a2f0"

def iso(ts):
    return datetime.datetime.fromtimestamp(ts, datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def pct(vals, p):
    """nearest-rank percentile; vals need not be sorted"""
    if not vals: return None
    s = sorted(vals)
    k = max(1, math.ceil(p / 100.0 * len(s)))
    return s[k - 1]

def stats(dts):
    dts = [d for d in dts if d is not None]
    if not dts: return {}
    s = sorted(dts)
    return {
        "n": len(s), "min": s[0], "mean": sum(s) / len(s),
        "p50": pct(s, 50), "p90": pct(s, 90), "p95": pct(s, 95),
        "p99": pct(s, 99), "p999": pct(s, 99.9), "max": s[-1],
        "hist": collections.Counter(s).most_common(12),
    }

def show(label, st, unit="s"):
    if not st:
        print(f"{label}: no data"); return
    print(f"--- {label}: n={st['n']}")
    print(f"    min={st['min']:.3f}{unit} mean={st['mean']:.3f}{unit} p50={st['p50']:.3f}{unit} "
          f"p90={st['p90']:.3f}{unit} p95={st['p95']:.3f}{unit} p99={st['p99']:.3f}{unit} "
          f"p99.9={st['p999']:.3f}{unit} max={st['max']:.3f}{unit}")
    print(f"    top values (value:count): " + ", ".join(f"{v}:{c}" for v, c in st["hist"]))

def load_jsonl(path):
    return [json.loads(l) for l in open(path) if l.strip()]

def cmd_blocks(path, label):
    rows = load_jsonl(path)
    rows.sort(key=lambda r: int(r["number"], 16))
    res = []
    for a, b in zip(rows, rows[1:]):
        res.append({"from_block": int(a["number"], 16), "to_block": int(b["number"], 16),
                    "from_ts": int(a["timestamp"], 16), "to_ts": int(b["timestamp"], 16),
                    "interval_s": int(b["timestamp"], 16) - int(a["timestamp"], 16)})
    t0, t1 = int(rows[0]["timestamp"], 16), int(rows[-1]["timestamp"], 16)
    print(f"== {label}: blocks {int(rows[0]['number'],16)}..{int(rows[-1]['number'],16)} "
          f"({len(rows)} headers)")
    print(f"   window {iso(t0)} .. {iso(t1)} UTC  ({t1-t0} s, {(t1-t0)/3600:.2f} h)")
    show(label, stats([r["interval_s"] for r in res]))
    with open(f"{label}_intervals.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(res[0].keys()))
        w.writeheader(); w.writerows(res)
    print(f"   wrote {label}_intervals.csv")

def cmd_cometbft(path, label):
    rows = load_jsonl(path)
    rows.sort(key=lambda r: r["height"])
    def parse(t):
        # NOTE: strptime returns a naive datetime; .timestamp() would then read it as
        # LOCAL time. CometBFT emits RFC3339 UTC, so the tzinfo must be forced to UTC.
        dt = datetime.datetime.strptime(t[:26] + "Z", "%Y-%m-%dT%H:%M:%S.%fZ") if "." in t[:26] \
            else datetime.datetime.strptime(t[:19] + "Z", "%Y-%m-%dT%H:%M:%SZ")
        return dt.replace(tzinfo=datetime.timezone.utc).timestamp()
    res = []
    for a, b in zip(rows, rows[1:]):
        res.append({"from_height": a["height"], "to_height": b["height"],
                    "from_time": a["time"], "to_time": b["time"],
                    "interval_s": round(parse(b["time"]) - parse(a["time"]), 3)})
    t0, t1 = parse(rows[0]["time"]), parse(rows[-1]["time"])
    print(f"== {label}: heights {rows[0]['height']}..{rows[-1]['height']} ({len(rows)} blocks)")
    print(f"   window {iso(t0)} .. {iso(t1)} UTC  ({t1-t0:.0f} s, {(t1-t0)/3600:.2f} h)")
    show(label, stats([r["interval_s"] for r in res]))
    with open(f"{label}_intervals.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(res[0].keys()))
        w.writeheader(); w.writerows(res)
    print(f"   wrote {label}_intervals.csv")

def cmd_inbox(logs_path, headers_path):
    logs = json.load(open(logs_path))
    H = json.load(open(headers_path))
    def ts(bn_hex):
        h = str(int(bn_hex, 16))
        return int(H[h]["timestamp"], 16) if h in H else None
    props, proved = [], []
    for l in logs:
        t0 = l["topics"][0]
        if t0 == TOPIC_PROPOSED:
            props.append({"id": int(l["topics"][1], 16), "proposer": "0x" + l["topics"][2][-40:],
                          "block": int(l["blockNumber"], 16), "ts": ts(l["blockNumber"])})
        elif t0 == TOPIC_PROVED:
            d = l["data"][2:]
            words = [d[i:i+64] for i in range(0, len(d), 64)]
            proved.append({"firstProposalId": int(words[0], 16), "firstNewProposalId": int(words[1], 16),
                           "lastProposalId": int(words[2], 16), "actualProver": "0x" + l["topics"][1][-40:],
                           "block": int(l["blockNumber"], 16), "ts": ts(l["blockNumber"])})
    props.sort(key=lambda p: p["id"]); proved.sort(key=lambda p: p["block"])
    pmap = {p["id"]: p["ts"] for p in props}
    print(f"== Taiko Shasta Inbox logs: {len(props)} Proposed, {len(proved)} Proved over "
          f"{len(logs)} logs in blocks {min(l['blockNumber'] for l in logs)}..{max(l['blockNumber'] for l in logs) if False else max(int(l['blockNumber'],16) for l in logs)}")
    if props:
        ptimes = [p["ts"] for p in props if p["ts"]]
        print(f"   proposals: id {props[0]['id']}..{props[-1]['id']}, "
              f"{iso(min(ptimes))} .. {iso(max(ptimes))} UTC")
        show("proposal interval (s)", stats([b["ts"] - a["ts"] for a, b in zip(props, props[1:]) if a["ts"] and b["ts"]]))
        with open("proposals.csv", "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=["id", "proposer", "block", "ts"]); w.writeheader(); w.writerows(props)
    if proved:
        show("proved interval (s)", stats([b["ts"] - a["ts"] for a, b in zip(proved, proved[1:]) if a["ts"] and b["ts"]]))
        lat = []
        for pv in proved:
            for pid in range(pv["firstNewProposalId"], pv["lastProposalId"] + 1):
                if pid in pmap and pv["ts"] and pmap[pid]:
                    lat.append({"proposal_id": pid, "proposed_ts": pmap[pid], "proved_ts": pv["ts"],
                                "proved_block": pv["block"], "latency_s": pv["ts"] - pmap[pid]})
        show("proof latency proposal->Proved (s)", stats([x["latency_s"] for x in lat]))
        with open("proofs.csv", "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=["proposal_id", "proposed_ts", "proved_ts", "proved_block", "latency_s"])
            w.writeheader(); w.writerows(sorted(lat, key=lambda x: x["proposal_id"]))
        print(f"   wrote proposals.csv, proofs.csv")

if __name__ == "__main__":
    m = sys.argv[1]
    if m == "blocks": cmd_blocks(sys.argv[2], sys.argv[3])
    elif m == "cometbft": cmd_cometbft(sys.argv[2], sys.argv[3])
    elif m == "inbox": cmd_inbox(sys.argv[2], sys.argv[3])
    else: raise SystemExit("unknown mode")
