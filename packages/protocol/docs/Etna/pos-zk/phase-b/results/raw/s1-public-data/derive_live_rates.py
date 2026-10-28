#!/usr/bin/env python3
"""Derived quantities for the live Taiko L2/Shasta inbox, from measured inputs.

Inputs (all measured, see the files named):
  - l2_sample_30d.jsonl   : every 100th Taiko L2 block, 2026-09-07..2026-10-07
  - proposed_events.csv / inbox_logs_full.jsonl : Proposed events with blockTimestamp
  - l2_payload_500.jsonl  : PRF-07(0) framing bytes for 500 consecutive L2 blocks
No input here is assumed; every output prints its formula.
"""
import json, statistics, datetime

rows = [json.loads(l) for l in open('l2_sample_30d.jsonl')]
rows.sort(key=lambda r: r['block'])
g = [r['gasUsed'] for r in rows]
t = [r['timestamp'] for r in rows]
b = [r['block'] for r in rows]
elapsed = t[-1] - t[0]
nblocks = b[-1] - b[0]
mean_gas = statistics.mean(g)
gas_per_block = mean_gas
gas_rate = gas_per_block * nblocks / elapsed
print('L2 sample window          : %s .. %s' % (
    datetime.datetime.utcfromtimestamp(t[0]).isoformat() + 'Z',
    datetime.datetime.utcfromtimestamp(t[-1]).isoformat() + 'Z'))
print('L2 blocks in window       : %d ; elapsed %d s ; mean spacing %.4f s' % (nblocks, elapsed, elapsed / nblocks))
print('L2 gas/block mean         : %.1f  (median %d)' % (gas_per_block, statistics.median(g)))
print('L2 gas/s (window mean)    : %.0f  [= mean gas/block / 2.0224 s]' % gas_rate)

props = [json.loads(l) for l in open('inbox_logs_full.jsonl')]
PROP = '0x7c4c4523e17533e451df15762a093e0693a2cd8b279fe54c6cd3777ed5771213'
prop_ts = sorted(int(l['blockTimestamp'], 16) for l in props if l['topics'][0] == PROP)
HEAD_TS = 1791378599
D30 = [x for x in prop_ts if x >= HEAD_TS - 30 * 86400]
span = HEAD_TS - D30[0]
print()
print('proposals (30 d)          : %d over %.0f s -> one per %.1f s' % (len(D30), span, span / len(D30)))
gas_per_proposal = gas_rate * (span / len(D30))
print('L2 gas per proposal       : %.1f Mgas  [= gas/s x proposal interval]' % (gas_per_proposal / 1e6))

# blob side: blob count per proposal decoded from the Proposed event data
import csv
blobs = [int(r['numBlobs']) for r in csv.DictReader(open('proposed_events.csv'))]
one = sum(1 for x in blobs if x == 1)
print('blobs per proposal        : 1 blob in %d of %d proposals (%.2f%%)' % (one, len(blobs), 100.0 * one / len(blobs)))
BLOB = 131072
b_billed = BLOB / gas_per_proposal
print('b_billed (live, 1 blob)   : %.6f bytes/gas  [= 131072 / %.0f]' % (b_billed, gas_per_proposal))
print('G_L2_TARGET at that b     : %.3f Mgas/s  [= 65536 / b_billed]' % (65536 / b_billed / 1e6))
print('achieved / DA bound       : %.4f%%' % (100.0 * gas_rate / (65536 / b_billed)))

pay = [json.loads(l) for l in open('l2_payload_500.jsonl')]
fr = [p['frameLen'] for p in pay]
gu = [p['gasUsed'] for p in pay]
print()
print('PRF-07 payload (500 blks) : frame bytes mean %.1f (min %d max %d) ; gas mean %.0f' % (
    statistics.mean(fr), min(fr), max(fr), statistics.mean(gu)))
print('b_payload (live, anchor-only blocks): %.6f bytes/gas [= 4 + len(RLP tx list)]' % (statistics.mean(fr) / statistics.mean(gu)))
print('b_payload if the same 218-byte frame carried a full 46,000,000-gas block: %.8f bytes/gas' % (218 / 46000000))
