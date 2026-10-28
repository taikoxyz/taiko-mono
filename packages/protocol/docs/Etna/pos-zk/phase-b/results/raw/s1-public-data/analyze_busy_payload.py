#!/usr/bin/env python3
"""Marginal payload bytes per unit of user gas, from the busy-block samples.

Two samples of Taiko L2 blocks that are not anchor-only:
  l2_payload_busy.jsonl        - the first 193 of the 768 busy blocks found in the 30-day sample
  l2_payload_busy_spread.jsonl - every 4th busy block (192 blocks spread across the 30 days)
userBytes / userGas exclude the anchor transaction (to 0x1670...0001) and its gas,
so they measure the marginal payload cost of real traffic rather than the fixed
per-block anchor overhead.
"""
import json, statistics, sys

def load(path):
    try:
        rows = [json.loads(l) for l in open(path)]
    except FileNotFoundError:
        return []
    return [r for r in rows if r.get('bPayloadUser') is not None]

def show(name, rows):
    if not rows:
        print('%s: no rows' % name); return
    bu = sorted(r['bPayloadUser'] for r in rows)
    print('%s: n=%d  user bytes mean %.0f median %.0f | user gas mean %.0f median %.0f' % (
        name, len(rows),
        statistics.mean(r['userBytes'] for r in rows), statistics.median(r['userBytes'] for r in rows),
        statistics.mean(r['userGas'] for r in rows), statistics.median(r['userGas'] for r in rows)))
    print('    b_payload(user) mean %.6f  median %.6f  p10 %.6f  p90 %.6f' % (
        statistics.mean(bu), statistics.median(bu), bu[int(0.1 * (len(bu) - 1))], bu[int(0.9 * (len(bu) - 1))]))
    print('    b_payload(whole block incl. anchor) mean %.6f' % statistics.mean(r['bPayloadTotal'] for r in rows))
    blocks = [r['block'] for r in rows]
    print('    blocks %d..%d' % (min(blocks), max(blocks)))

show('contiguous-first sample', load('l2_payload_busy.jsonl'))
show('window-spread sample  ', load('l2_payload_busy_spread.jsonl'))
