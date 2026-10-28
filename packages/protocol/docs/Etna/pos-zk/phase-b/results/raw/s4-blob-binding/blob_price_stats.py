#!/usr/bin/env python3
"""S4: blob-price and blob-cost statistics over the sampled proposal blocks.

Inputs: headers-sample.jsonl (every 20th proposal block, in order),
headers-late.jsonl (every 100th proposal block >= 25,700,000),
headers.jsonl (contiguous prefix census, used only for the monthly view).
Computes the EIP-4844 blob base fee with the BPO2 update fraction 11,684,671
(verified against receipts by blobfee_check.py) and the resulting per-blob cost.
Writes blob-price-series.json.
"""
import json, os, statistics, datetime, collections

FRACTION = 11684671
GAS_PER_BLOB = 131072

def fake_exponential(factor, numerator, denominator):
    i, out, acc = 1, 0, factor * denominator
    while acc > 0:
        out += acc
        acc = (acc * numerator) // (denominator * i)
        i += 1
    return out // denominator

def load(path):
    return [json.loads(l) for l in open(path)] if os.path.exists(path) else []

def stats(rows):
    prices = [fake_exponential(1, r['excessBlobGas'], FRACTION) for r in rows]
    costs = [GAS_PER_BLOB * p for p in prices]
    prices_sorted = sorted(prices)
    def q(x):
        return prices_sorted[min(len(prices_sorted) - 1, int(x * len(prices_sorted)))]
    return {
        'n_blocks': len(rows),
        'price_wei_min': min(prices), 'price_wei_p50': int(statistics.median(prices)),
        'price_wei_p90': q(0.90), 'price_wei_max': max(prices),
        'blob_cost_wei_min': min(costs), 'blob_cost_wei_p50': int(statistics.median(costs)),
        'blob_cost_wei_p90': q(0.90) * GAS_PER_BLOB, 'blob_cost_wei_max': max(costs),
        'excessBlobGas_min': min(r['excessBlobGas'] for r in rows),
        'excessBlobGas_max': max(r['excessBlobGas'] for r in rows)}

def main(outdir):
    smp = load(os.path.join(outdir, 'headers-sample.jsonl'))
    late = load(os.path.join(outdir, 'headers-late.jsonl'))
    rev = load(os.path.join(outdir, 'headers-sample-rev.jsonl'))
    full = load(os.path.join(outdir, 'headers.jsonl'))
    seen, combined = set(), []
    for r in smp + late + rev:
        if r['block'] not in seen:
            seen.add(r['block']); combined.append(r)
    out = {
        'fraction_used': FRACTION, 'gas_per_blob': GAS_PER_BLOB,
        'sample_sources': {'headers-sample.jsonl': len(smp), 'headers-late.jsonl': len(late),
                           'headers-sample-rev.jsonl': len(rev), 'headers.jsonl': len(full)},
        'combined_sample': stats(combined) if combined else None,
        'monthly_combined': {},
        'monthly_full_prefix_census': {}}
    for label, rows in [('combined', combined), ('full', full)]:
        m = collections.defaultdict(list)
        for r in rows:
            key = datetime.datetime.utcfromtimestamp(r['timestamp']).strftime('%Y-%m')
            m[key].append(r)
        target = out['monthly_combined'] if label == 'combined' else out['monthly_full_prefix_census']
        for k in sorted(m):
            target[k] = stats(m[k])
    json.dump(out, open(os.path.join(outdir, 'blob-price-series.json'), 'w'), indent=1)
    c = out['combined_sample']
    print('combined n', c['n_blocks'])
    print('price wei min/p50/p90/max', c['price_wei_min'], c['price_wei_p50'], c['price_wei_p90'], c['price_wei_max'])
    print('blob cost ETH min/p50/p90/max', c['blob_cost_wei_min'] / 1e18, c['blob_cost_wei_p50'] / 1e18,
          c['blob_cost_wei_p90'] / 1e18, c['blob_cost_wei_max'] / 1e18)
    for k, v in out['monthly_combined'].items():
        print(' ', k, 'n', v['n_blocks'], 'p50 wei', v['price_wei_p50'])

if __name__ == '__main__':
    main(os.path.dirname(os.path.abspath(__file__)))
