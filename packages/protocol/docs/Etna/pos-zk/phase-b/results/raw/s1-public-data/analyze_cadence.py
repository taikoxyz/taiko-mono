#!/usr/bin/env python3
"""Cadence and proof-latency analysis from the Inbox logs (Proposed/Proved).

Timestamps come from each log's own blockTimestamp field (returned by the
archive endpoint for every log); the same field was cross-checked against an
independent source (Blockscout REST) on 401 blocks with 401/401 agreement.

Windows analysed:
  ALL   - activation of the Shasta inbox (first Proposed) .. last event fetched
  UNZEN - since the Unzen upgrade block 25674458 (2026-08-03T12:46:23Z)
  D30   - the 30 days ending at the fetch head block 26140717 (2026-10-07T13:09:59Z)
  D7    - the 7 days ending at the same head
Outputs cadence_events.csv (per event) and prints the summary used in the report.
"""
import json, csv, datetime, statistics, collections

HEAD = 26140717
HEAD_TS = 1791378599
DAY = 86400
PROP = '0x7c4c4523e17533e451df15762a093e0693a2cd8b279fe54c6cd3777ed5771213'
PROVED = '0xa274dcaff3629ec7d69d144038e97732516ff306fcbf8a2bc9423d106779a2f0'

logs = [json.loads(l) for l in open('inbox_logs_full.jsonl')]
props, provs = [], []
for l in logs:
    t = l['topics'][0]
    bn = int(l['blockNumber'], 16)
    ts = int(l['blockTimestamp'], 16)
    if t == PROP:
        props.append({'id': int(l['topics'][1], 16), 'block': bn, 'ts': ts,
                      'proposer': '0x' + l['topics'][2][-40:]})
    elif t == PROVED:
        d = l['data'][2:]
        w = [d[i:i + 64] for i in range(0, len(d), 64)]
        provs.append({'block': bn, 'ts': ts, 'first': int(w[0], 16),
                      'firstNew': int(w[1], 16), 'last': int(w[2], 16),
                      'prover': '0x' + l['topics'][1][-40:]})
props.sort(key=lambda r: r['id'])
provs.sort(key=lambda r: (r['block'], r['firstNew']))

def window(lo_ts):
    p = [x for x in props if x['ts'] >= lo_ts]
    q = [x for x in provs if x['ts'] >= lo_ts]
    return p, q

def stats(xs):
    if not xs:
        return None
    xs = sorted(xs)
    def pct(p):
        return xs[min(len(xs) - 1, int(round(p * (len(xs) - 1))))]
    return {'n': len(xs), 'min': xs[0], 'p50': statistics.median(xs), 'p90': pct(0.90),
            'p95': pct(0.95), 'max': xs[-1], 'mean': round(statistics.mean(xs), 1)}

def report(name, lo_ts):
    p, q = window(lo_ts)
    if not p:
        print(name, 'no events'); return
    span = (HEAD_TS - p[0]['ts'])
    print('== %s ==' % name)
    print('  window: %s .. %s (%.2f days), L1 blocks %d..%d' % (
        datetime.datetime.utcfromtimestamp(p[0]['ts']).isoformat() + 'Z',
        datetime.datetime.utcfromtimestamp(HEAD_TS).isoformat() + 'Z', span / DAY,
        p[0]['block'], HEAD))
    print('  proposals: %d (%.1f/day); proofs: %d (%.1f/day)' % (
        len(p), len(p) / (span / DAY), len(q), len(q) / (span / DAY)))
    pi = [p[i + 1]['ts'] - p[i]['ts'] for i in range(len(p) - 1)]
    qi = [q[i + 1]['ts'] - q[i]['ts'] for i in range(len(q) - 1)]
    print('  proposal interval s: %s' % stats(pi))
    print('  proof interval s:    %s' % stats(qi))
    # proof latency: for each proof, per covered proposal
    byid = {x['id']: x for x in props}
    lat_first, lat_last, lat_all, cover = [], [], [], []
    for r in q:
        f, ln = r['firstNew'], r['last']
        if f in byid and ln in byid:
            lat_first.append(r['ts'] - byid[f]['ts'])
            lat_last.append(r['ts'] - byid[ln]['ts'])
            for i in range(f, ln + 1):
                if i in byid:
                    lat_all.append(r['ts'] - byid[i]['ts'])
            cover.append(ln - f + 1)
    print('  proposals newly proven per proof: %s' % stats(cover))
    print('  latency firstNew->proof s: %s' % stats(lat_first))
    print('  latency last->proof s:     %s' % stats(lat_last))
    print('  latency over all covered  s: %s' % stats(lat_all))
    # unproven backlog at head
    proven = set()
    for r in q:
        for i in range(r['firstNew'], r['last'] + 1):
            proven.add(i)
    unproven = [x['id'] for x in p if x['id'] not in proven]
    print('  proposals in window never covered by a proof: %d (ids %s..%s)' % (
        len(unproven), unproven[0] if unproven else None, unproven[-1] if unproven else None))
    print()

lo_all = props[0]['ts']
report('D30 (last 30 days)', HEAD_TS - 30 * DAY)
report('D7 (last 7 days)', HEAD_TS - 7 * DAY)
report('UNZEN (since 2026-08-03)', 1785761183)
report('ALL (since inbox activation)', lo_all)

# per-day table for the last 30 days
print('== per-day (last 30 days) ==')
buckets = collections.defaultdict(lambda: [0, 0])
for x in props:
    if x['ts'] >= HEAD_TS - 30 * DAY:
        buckets[(x['ts'] // DAY) * DAY][0] += 1
for x in provs:
    if x['ts'] >= HEAD_TS - 30 * DAY:
        buckets[(x['ts'] // DAY) * DAY][1] += 1
days = sorted(buckets)
for d in days:
    print('  %s  proposals %4d  proofs %4d' % (
        datetime.datetime.utcfromtimestamp(d).strftime('%Y-%m-%d'), buckets[d][0], buckets[d][1]))
