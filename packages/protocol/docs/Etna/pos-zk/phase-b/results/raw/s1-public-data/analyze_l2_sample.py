import json, statistics, datetime
rows = [json.loads(l) for l in open('l2_sample_30d.jsonl')]
rows.sort(key=lambda r: r['block'])
g = [r['gasUsed'] for r in rows]
t = [r['timestamp'] for r in rows]
b = [r['block'] for r in rows]
txs = [r['txs'] for r in rows]
print('samples', len(rows), 'block', b[0], '->', b[-1])
print('time', datetime.datetime.utcfromtimestamp(t[0]).isoformat() + 'Z', '->',
      datetime.datetime.utcfromtimestamp(t[-1]).isoformat() + 'Z')
dts = [t[i+1]-t[i] for i in range(len(t)-1)]
dbs = [b[i+1]-b[i] for i in range(len(b)-1)]
print('sample spacing: blocks', statistics.mode(dbs), 'seconds', statistics.mode(dts),
      '-> implied block time', statistics.mode(dts)/statistics.mode(dbs))
print('gasUsed: min %d median %d mean %.1f max %d' % (min(g), statistics.median(g), statistics.mean(g), max(g)))
import collections
c = collections.Counter(g)
print('top gasUsed values:', c.most_common(5))
print('txs per block: mode', statistics.mode(txs), 'max', max(txs), 'mean %.3f' % statistics.mean(txs))
print('blocks with >1 tx: %d (%.2f%%)' % (sum(1 for x in txs if x > 1), 100.0*sum(1 for x in txs if x > 1)/len(txs)))
print('blocks with gasUsed == 112068: %d (%.2f%%)' % (c[112068], 100.0*c[112068]/len(rows)))
print('gasLimit values:', collections.Counter(r['gasLimit'] for r in rows).most_common(3))
# achieved rate: use the full-window average gas per block and the exact elapsed window
mean_gas = statistics.mean(g)
elapsed = t[-1]-t[0]
nblocks = b[-1]-b[0]
rate = mean_gas * nblocks / elapsed
print('window elapsed %d s over %d blocks; window-mean gas/block %.1f' % (elapsed, nblocks, mean_gas))
print('achieved L2 gas/s over the sampled window (derived): %.1f' % rate)
top = sorted(rows, key=lambda r: -r['gasUsed'])[:10]
print('busiest sampled blocks:', [(r['block'], r['gasUsed'], r['txs']) for r in top])
