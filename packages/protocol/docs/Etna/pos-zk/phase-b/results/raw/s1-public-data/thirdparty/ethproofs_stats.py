import json, statistics

blocks = json.load(open('ethproofs_blocks_extract.json'))
prov = json.load(open('ethproofs_provers_extract.json'))
gas = json.load(open('ethproofs_block_gas.json'))
name_by_cluster = {p['id']: (p['name'], p.get('hardware_description')) for p in prov}

recs = []
for b in blocks:
    cid = b['cluster_id']
    nm, hw = name_by_cluster.get(cid, ('?', '?'))
    g = gas.get(str(b['block_number'])) or gas.get(b['block_number'])
    recs.append({'block': b['block_number'], 'cluster_id': cid, 'cluster': nm, 'hw': hw,
                 'proving_ms': b.get('proving_time'), 'cycles': b.get('proving_cycles'),
                 'status': b.get('proof_status'), 'created': b.get('created_at'),
                 'size_bytes': b.get('size_bytes'), 'gas_used': g})
json.dump(recs, open('ethproofs_blocks_joined.json', 'w'), indent=1)

def ok(r):
    return r.get('gas_used') and r.get('proving_ms') and r.get('cycles')
good = [r for r in recs if ok(r)]
for r in good:
    r['secs'] = r['proving_ms'] / 1000.0
    r['cycles_per_gas'] = r['cycles'] / r['gas_used']
    r['gas_per_sec'] = r['gas_used'] / r['secs']
json.dump(good, open('ethproofs_blocks_with_gas.json', 'w'), indent=1)

def med(xs):
    return statistics.median(xs) if xs else float('nan')
print('records %d ; with gas+time+cycles %d ; distinct blocks %d' % (
    len(recs), len(good), len({r['block'] for r in good})))
print()
print('%-27s %-13s %4s %9s %13s %9s %11s' % ('cluster', 'hardware', 'n', 'med secs', 'med cycles', 'cyc/gas', 'gas/s'))
by = {}
for r in good:
    by.setdefault(r['cluster'], []).append(r)
for c, rs in sorted(by.items(), key=lambda kv: -len(kv[1])):
    print('%-27s %-13s %4d %9.2f %13.0f %9.2f %11.0f' % (
        c[:27], (rs[0]['hw'] or '?')[:13], len(rs),
        med([x['secs'] for x in rs]), med([x['cycles'] for x in rs]),
        med([x['cycles_per_gas'] for x in rs]), med([x['gas_per_sec'] for x in rs])))
print()
print('ALL: n=%d med secs %.2f med cycles %.0f med cycles/gas %.2f med gas/s %.0f' % (
    len(good), med([r['secs'] for r in good]), med([r['cycles'] for r in good]),
    med([r['cycles_per_gas'] for r in good]), med([r['gas_per_sec'] for r in good])))
gs = [r['gas_used'] for r in good]
print('proved L1 blocks: gasUsed min %d median %d max %d' % (min(gs), med(gs), max(gs)))
ct = sorted(r['created'] for r in good)
print('record created window: %s .. %s' % (ct[0], ct[-1]))
