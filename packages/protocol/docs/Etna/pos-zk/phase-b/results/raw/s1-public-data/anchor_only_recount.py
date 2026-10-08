#!/usr/bin/env python3
"""S1 §3.5: the anchor-only count in the 422-block framing window.

The report claimed "422 L2 blocks, 12,367,506-12,367,927; 386 of them
anchor-only".  The cited raw file l2_payload_500.jsonl gives 383 blocks whose
gasUsed is exactly the anchor-only value 112,068 (90.8 %), not 386.

The other §3.5 figures are reproduced here for the same window: mean/median/max
frame bytes, mean gas and the blended b_payload.

Writes anchor-only-recount.json.  Usage: python3 anchor_only_recount.py
"""
import json, statistics

rows = [json.loads(l) for l in open("l2_payload_500.jsonl")]
first, last = 12367506, 12367927
win = [r for r in rows if first <= r["block"] <= last]
ANCHOR_GAS = 112068
anchor = [r for r in win if r["gasUsed"] == ANCHOR_GAS]
gas = [r["gasUsed"] for r in win]
frames = [r["frameLen"] for r in win]
out = {
    "source": "l2_payload_500.jsonl",
    "window": [first, last],
    "blocks": len(win),
    "anchor_only_blocks": len(anchor),
    "anchor_only_pct": 100.0 * len(anchor) / len(win),
    "mean_frame_bytes": statistics.mean(frames),
    "median_frame_bytes": statistics.median(frames),
    "max_frame_bytes": max(frames),
    "mean_gas_used": statistics.mean(gas),
    "b_payload_mean": statistics.mean(frames) / statistics.mean(gas),
    "file_rows": len(rows),
}
json.dump(out, open("anchor-only-recount.json", "w"), indent=1)
print(json.dumps(out, indent=1))
