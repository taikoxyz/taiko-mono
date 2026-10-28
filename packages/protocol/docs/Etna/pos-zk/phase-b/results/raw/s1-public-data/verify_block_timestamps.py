import json, collections
L = [json.loads(l) for l in open('inbox_logs_full.jsonl')]
missing = sum(1 for l in L if 'blockTimestamp' not in l)
print('logs', len(L), 'missing blockTimestamp', missing)
ts = {int(l['blockNumber'], 16): int(l['blockTimestamp'], 16) for l in L}
print('distinct blocks with timestamps', len(ts))
import datetime
v = sorted(ts.items())
print('first', v[0][0], datetime.datetime.utcfromtimestamp(v[0][1]).isoformat() + 'Z')
print('last ', v[-1][0], datetime.datetime.utcfromtimestamp(v[-1][1]).isoformat() + 'Z')
# cross-check against blockscout-fetched file
bs = {}
for l in open('block_times_30d.jsonl'):
    r = json.loads(l)
    bs[r['block']] = r['timestamp']
inter = [b for b in bs if b in ts]
agree = sum(1 for b in inter if ts[b] == bs[b])
print('cross-check vs Blockscout: overlap %d, identical %d' % (len(inter), agree))
if inter:
    bad = [(b, ts[b], bs[b]) for b in inter if ts[b] != bs[b]][:5]
    print('mismatches (block, log_ts, blockscout_ts):', bad)
# 12s regularity check
import statistics
xs = sorted(ts)
deltas = collections.Counter()
for a, b in zip(xs, xs[1:]):
    dt = ts[b] - ts[a]
    db = b - a
    deltas[(db, dt)] += 1
top = deltas.most_common(10)
print('top (blockDelta, timeDelta) pairs:', top)
ratios = [ (ts[b] - ts[a]) / (b - a) for a, b in zip(xs, xs[1:]) if b > a]
print('per-interval seconds-per-block: min %.4f median %.4f max %.4f' % (min(ratios), statistics.median(ratios), max(ratios)))
