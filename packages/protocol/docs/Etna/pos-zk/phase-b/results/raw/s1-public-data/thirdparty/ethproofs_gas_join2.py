import json, sys, time, statistics, urllib.request
from concurrent.futures import ThreadPoolExecutor

def iso_to_epoch(s):
    s = s.replace('Z', '+00:00')
    if '.' in s:
        head, rest = s.split('.', 1)
        frac, tz = rest.split('+', 1)
        s = head + '.' + (frac + '000000')[:6] + '+' + tz
    import datetime
    return int(datetime.datetime.fromisoformat(s).timestamp())

blocks = json.load(open('ethproofs_blocks_extract.json'))
prov = json.load(open('ethproofs_provers_extract.json'))
name_by_cluster = {p['id']: (p['name'], p.get('hardware_description')) for p in prov}
uniq = sorted({b['block_number'] for b in blocks})

def one(n):
    for a in range(6):
        try:
            req = urllib.request.Request('https://eth.blockscout.com/api/v2/blocks/%d' % n,
                                         headers={'user-agent': 'taiko-mono-s1-research/1.0'})
            with urllib.request.urlopen(req, timeout=25) as r:
                d = json.loads(r.read().decode())
            return n, int(d['gas_used'])
        except Exception:
            time.sleep(1 + a)
    return n, None

gas = {}
with ThreadPoolExecutor(max_workers=6) as ex:
    for n, g in ex.map(one, uniq):
        if g is not None:
            gas[n] = g
print('gas fetched for %d of %d blocks' % (len(gas), len(uniq)))
json.dump(gas, open('ethproofs_block_gas.json', 'w'), indent=1)

recs = []
for b in blocks:
    cid = b['cluster_id']
    nm, hw = name_by_cluster.get(cid, ('?', '?'))
    g = gas.get(b['block_number'])
    r = {'block': b['block_number'], 'cluster_id': cid, 'cluster': nm, 'hw': hw,
         'proving_ms': b['proving_time'], 'cycles': b['proving_cycles'],
         'status': b['proof_status'], 'created': b['created_at'], 'gas_used': g,
         'size_bytes': b.get('size_bytes')}
    if g:
        r['secs'] = r['proving_ms'] / 1000.0
        r['cycles_per_gas'] = r['cycles'] / g
        r['gas_per_sec'] = g / r['secs']
    recs.append(r)
json.dump(recs, open('ethproofs_blocks_with_gas.json', 'w'), indent=1)

ct = sorted(iso_to_epoch(r['created']) for r in recs)
import datetime
print('records %d, created window %s -> %s' % (len(recs),
      datetime.datetime.utcfromtimestamp(ct[0]).isoformat() + 'Z',
      datetime.datetime.utcfromtimestamp(ct[-1]).isoformat() + 'Z'))
gs = [gas[n] for n in uniq if n in gas]
print('L1 gasUsed: min %d median %d max %d' % (min(gs), statistics.median(gs), max(gs)))
print()
print('%-26s %-14s %4s %8s %12s %9s %10s' % ('cluster', 'hw', 'n', 'med_s', 'med_cycles', 'cyc/gas', 'gas/s'))
by = {}
for r in recs:
    if r.get('gas_used'):
        by.setdefault(r['cluster'], []).append(r)
for c, rs in sorted(by.items(), key=lambda kv: -len(kv[1])):
    print('%-26s %-14s %4d %8.2f %12.0f %9.2f %10.0f' % (
        c[:26], (rs[0]['hw'] or '?')[:14], len(rs),
        statistics.median([x['secs'] for x in rs]),
        statistics.median([x['cycles'] for x in rs]),
        statistics.median([x['cycles_per_gas'] for x in rs]),
        statistics.median([x['gas_per_sec'] for x in rs])))
allr = [r for r in recs if r.get('gas_used')]
print()
print('ALL: n=%d  median cycles/gas %.2f  median gas/s %.0f  median proof secs %.2f  median cycles %.0f' % (
    len(allr), statistics.median([r['cycles_per_gas'] for r in allr]),
    statistics.median([r['gas_per_sec'] for r in allr]),
    statistics.median([r['secs'] for r in allr]),
    statistics.median([r['cycles'] for r in allr])))
