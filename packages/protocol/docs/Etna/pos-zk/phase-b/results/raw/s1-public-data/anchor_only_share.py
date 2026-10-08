#!/usr/bin/env python3
"""S1 section 3.4/3.5: how much of the live L2 workload is anchor-only.

Written for the Phase B arithmetic re-review (PB-AR-08).  The report's
"blocks that are anchor-only (== 112,068 gas): 72.6%" is correct for its own
parenthetical definition but understates the near-empty regime by ~20 points:
112,056 gas is the other single-anchor-transaction gas value seen in the live
sample, and 94.07% of blocks carry exactly one transaction.

Reads l2_sample_30d.jsonl (every 100th L2 block, 30 days, n = 12,961).
Writes anchor-only-share.json.
Usage: python3 anchor_only_share.py
"""
import collections, json, os


def main():
    outdir = os.path.dirname(os.path.abspath(__file__))
    rows = [json.loads(l) for l in open(os.path.join(outdir, 'l2_sample_30d.jsonl'))]
    n = len(rows)
    gas = collections.Counter(r['gasUsed'] for r in rows)
    txs = collections.Counter(r['txs'] for r in rows)
    g68 = gas.get(112068, 0)
    g56 = gas.get(112056, 0)
    single = txs.get(1, 0)

    out = {
        'source': 'l2_sample_30d.jsonl (every 100th L2 block, 30 days)',
        'n_blocks': n,
        'gasUsed_112068': {'count': g68, 'pct': round(100.0 * g68 / n, 2)},
        'gasUsed_112056': {'count': g56, 'pct': round(100.0 * g56 / n, 2)},
        'anchor_only_either_gas': {'count': g68 + g56, 'pct': round(100.0 * (g68 + g56) / n, 2)},
        'single_transaction_blocks': {'count': single, 'pct': round(100.0 * single / n, 2)},
        'multi_transaction_blocks': {'count': n - single, 'pct': round(100.0 * (n - single) / n, 2)},
        'top_gasUsed_values': gas.most_common(6),
        'txs_histogram': dict(sorted(txs.items())),
    }
    json.dump(out, open(os.path.join(outdir, 'anchor-only-share.json'), 'w'), indent=1)
    print('n = %d blocks' % n)
    print('  gasUsed == 112,068          : %d = %.2f%%' % (g68, out['gasUsed_112068']['pct']))
    print('  gasUsed == 112,056          : %d = %.2f%%' % (g56, out['gasUsed_112056']['pct']))
    print('  anchor-only (either value)  : %d = %.2f%%' % (g68 + g56, out['anchor_only_either_gas']['pct']))
    print('  exactly one transaction     : %d = %.2f%%' % (single, out['single_transaction_blocks']['pct']))
    print('  more than one transaction   : %d = %.2f%%' % (n - single, out['multi_transaction_blocks']['pct']))


if __name__ == '__main__':
    main()
