#!/usr/bin/env python3
"""S4 F3: what the 2,020-header sample is, and the percentile convention it uses.

Written for the Phase B arithmetic re-review (PB-AR-05 / PB-AR-15).  Two claims
in blob-binding.md F3 and SYNTHESIS (a) did not reproduce from the committed
artifacts:

  * "systematic sample, every 20th block among the 40,474 distinct proposal
    blocks, 2,020 headers, 5.0%" -- the committed census yields a different
    every-20th set and a different end block, and the committed
    blob_price_stats.py combines three header files to n = 2,162;
  * the p90 = 33,430,313 wei is reproducible only under the artifact's own
    index rule sorted[int(0.9*n)]; nearest-rank gives a different value.

This script reports, from the committed files only:
  1. the census: distinct proposal blocks, the blocks[::20] sample, its size and
     last block;
  2. headers-sample.jsonl: size, first/last block and timestamp, and how much of
     the blocks[::20] set is present, missing, or absent from the census;
  3. the blob-price stats over headers-sample.jsonl under three percentile
     conventions (artifact int(0.9n) index, nearest-rank ceil(0.9n)-1, linear
     interpolation), all with the BPO2 fraction 11,684,671 verified in F3;
  4. the same stats over the committed blob_price_stats.py combined sample
     (headers-sample + headers-late + headers-sample-rev, deduplicated), which is
     what re-running that script now produces;
  5. PB-AR-15: the 24-block fee-check probe (blobfee-check.json) -- first/last
     block, mean gap, and the unprobed tail of the era.

Reads proposals_by_tx.csv, headers-sample.jsonl, headers-late.jsonl,
headers-sample-rev.jsonl, blobfee-check.json.  Writes f3-sample-and-probe.json.
Usage: python3 f3_sample_and_probe.py
"""
import csv, json, os, statistics

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


def prices_of(rows):
    return [fake_exponential(1, r['excessBlobGas'], FRACTION) for r in rows]


def conventions(prices):
    xs = sorted(prices)
    n = len(xs)
    return {
        'n': n,
        'p50': int(statistics.median(xs)),
        'p90_artifact_index_int(0.9n)': xs[min(n - 1, int(0.90 * n))],
        'p90_nearest_rank_ceil(0.9n)-1': xs[max(0, -(-9 * n // 10) - 1)],
        'p90_linear_interpolation': round(xs[int((n - 1) * 0.9)] + (xs[int((n - 1) * 0.9) + 1] - xs[int((n - 1) * 0.9)]) * ((n - 1) * 0.9 - int((n - 1) * 0.9)), 3),
        'min': xs[0], 'max': xs[-1],
    }


def main():
    outdir = os.path.dirname(os.path.abspath(__file__))
    rows = list(csv.DictReader(open(os.path.join(outdir, 'proposals_by_tx.csv'))))
    blocks = sorted({int(r['block']) for r in rows})
    every20 = blocks[::20]

    smp = load(os.path.join(outdir, 'headers-sample.jsonl'))
    smp_blocks = [r['block'] for r in smp]
    smp_set = set(smp_blocks)
    e20_set = set(every20)
    missing = sorted(e20_set - smp_set)
    extra = sorted(smp_set - e20_set)
    ts = {r['block']: r['timestamp'] for r in smp}

    late = load(os.path.join(outdir, 'headers-late.jsonl'))
    rev = load(os.path.join(outdir, 'headers-sample-rev.jsonl'))
    seen, combined = set(), []
    for r in smp + late + rev:
        if r['block'] not in seen:
            seen.add(r['block'])
            combined.append(r)

    probe = json.load(open(os.path.join(outdir, 'blobfee-check.json')))
    pblocks = [r['block'] for r in probe]
    gaps = [b - a for a, b in zip(pblocks, pblocks[1:])]
    era_end = blocks[-1]

    out = {
        'census': {
            'logs': len(rows),
            'distinct_blocks': len(blocks),
            'first_block': blocks[0], 'last_block': blocks[-1],
            'every_20th_n': len(every20),
            'every_20th_last_block': every20[-1],
        },
        'headers_sample': {
            'n': len(smp),
            'first_block': smp_blocks[0], 'last_block': smp_blocks[-1],
            'last_timestamp': ts[smp_blocks[-1]],
            'in_every_20th_set': len(smp_set & e20_set),
            'missing_vs_every_20th': len(missing),
            'first_missing_block': missing[0] if missing else None,
            'blocks_not_in_census_sample': len(extra),
        },
        'price_stats_headers_sample_only': conventions(prices_of(smp)),
        'price_stats_committed_script_combined': dict(
            {'n_sources': {'headers-sample': len(smp), 'headers-late': len(late), 'headers-sample-rev': len(rev)}},
            **conventions(prices_of(combined))),
        'probe': {
            'n_blocks': len(probe),
            'first_block': pblocks[0], 'last_block': pblocks[-1],
            'mean_gap_blocks': round(sum(gaps) / len(gaps), 1) if gaps else None,
            'min_gap_blocks': min(gaps) if gaps else None, 'max_gap_blocks': max(gaps) if gaps else None,
            'era_last_block': era_end,
            'unprobed_tail_blocks': era_end - pblocks[-1],
            'unprobed_tail_days_at_12s': round((era_end - pblocks[-1]) * 12 / 86400, 2),
        },
    }
    json.dump(out, open(os.path.join(outdir, 'f3-sample-and-probe.json'), 'w'), indent=1)

    c = out['census']
    print('census: %d logs, %d distinct blocks, %d..%d' % (c['logs'], c['distinct_blocks'], c['first_block'], c['last_block']))
    print('  every-20th sample: n=%d, last block %d' % (c['every_20th_n'], c['every_20th_last_block']))
    s = out['headers_sample']
    print('headers-sample.jsonl: n=%d, %d..%d (last ts %d)' % (s['n'], s['first_block'], s['last_block'], s['last_timestamp']))
    print('  present in every-20th set: %d; missing: %d (first missing %s)' % (s['in_every_20th_set'], s['missing_vs_every_20th'], s['first_missing_block']))
    for label in ['price_stats_headers_sample_only', 'price_stats_committed_script_combined']:
        st = out[label]
        print('%s: n=%d min=%d p50=%d p90[artifact]=%d p90[nearest]=%d p90[interp]=%s max=%d' % (
            label, st['n'], st['min'], st['p50'], st['p90_artifact_index_int(0.9n)'],
            st['p90_nearest_rank_ceil(0.9n)-1'], st['p90_linear_interpolation'], st['max']))
    p = out['probe']
    print('probe: %d blocks %d..%d, mean gap %.1f, era ends %d -> unprobed tail %d blocks (~%.1f days at 12 s)' % (
        p['n_blocks'], p['first_block'], p['last_block'], p['mean_gap_blocks'], p['era_last_block'],
        p['unprobed_tail_blocks'], p['unprobed_tail_days_at_12s']))


if __name__ == '__main__':
    main()
