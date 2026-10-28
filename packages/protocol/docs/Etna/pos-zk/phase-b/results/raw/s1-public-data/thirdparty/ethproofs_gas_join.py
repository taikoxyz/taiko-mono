import json, statistics, datetime, sys
sys.path.insert(0,'..')
from rpc import batch

blk = json.load(open('ethproofs_blocks_extract.json'))
prov = json.load(open('ethproofs_provers_extract.json'))
name_by_cluster = {p['id']: (p['name'], p.get('hardware_description')) for p in prov}

def parse(ts):
    ts = ts.replace('Z', '+00:00')
    if '.' in ts:
        head, rest = ts.split('.', 1)
        frac, tz = rest.split('+', 1)
        frac = (frac + '000000')[:6]
        ts = head + '.' + frac + '+' + tz
    return datetime.datetime.fromisoformat(ts)

recs = []
for b in blk:
    cid = b['cluster_id']
    nm, hw = name_by_cluster.get(cid, ('?', '?'))
    recs.append({'block': b['block_number'], 'cluster_id': cid, 'cluster': nm, 'hw': hw,
                 'proving_ms': b['proving_time'], 'cycles': b['proving_cycles'],
                 'status': b['proof_status'], 'created': b['created_at'],
                 'size_bytes': b.get('size_bytes')})

ct = sorted(parse(r['created']) for r in recs)
print('records %d  created_at window: %s -> %s' % (len(recs), ct[0].isoformat(), ct[-1].isoformat()))
blocks = sorted({r['block'] for r in recs})
print('distinct L1 blocks', len(blocks), blocks[:3], '...', blocks[-3:])

URL = 'https://ethereum-rpc.publicnode.com'
res = batch(URL, [('eth_getBlockByNumber', [hex(n), False]) for n in blocks], tries=4)
gas = {int(b['number'], 16): int(b['gasUsed'], 16) for b in res}
open('ethproofs_block_gas.json', 'w').write(json.dumps(gas, indent=1))
for r in recs:
    r['gas_used'] = gas[r['block']]
    r['secs'] = r['proving_ms'] / 1000.0
    r['cycles_per_gas'] = r['cycles'] / r['gas_used']
    r['gas_per_sec'] = r['gas_used'] / r['secs']
open('ethproofs_blocks_with_gas.json', 'w').write(json.dumps(recs, indent=1))

print()
print('%-28s %-12s %5s %8s %12s %10s %10s' % ('cluster', 'hw', 'n', 'med_s', 'med_cycles', 'cyc/gas', 'gas/s'))
by = {}
for r in recs:
    by.setdefault(r['cluster'], []).append(r)
for c, rs in sorted(by.items(), key=lambda kv: -len(kv[1])):
    print('%-28s %-12s %5d %8.2f %12.0f %10.1f %10.0f' % (
        c[:28], (rs[0]['hw'] or '?')[:12], len(rs),
        statistics.median([x['secs'] for x in rs]),
        statistics.median([x['cycles'] for x in rs]),
        statistics.median([x['cycles_per_gas'] for x in rs]),
        statistics.median([x['gas_per_sec'] for x in rs])))
print()
print('all: median cycles/gas %.2f  median gas/s %.0f  (n=%d)' % (
    statistics.median([r['cycles_per_gas'] for r in recs]),
    statistics.median([r['gas_per_sec'] for r in recs]), len(recs)))
gs = [gas[n] for n in blocks]
print('L1 gasUsed of proved blocks: min %d median %d max %d' % (min(gs), statistics.median(gs), max(gs)))
