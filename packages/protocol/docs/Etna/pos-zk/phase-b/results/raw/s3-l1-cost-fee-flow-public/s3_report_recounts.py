#!/usr/bin/env python3
"""S3 F1/F3: figures the arithmetic re-review could not reproduce (PB-AR-06, PB-AR-10).

PB-AR-06 (F3):
  * "Per-block fee series for all 50,264 blocks of the window".  The window is
    blocks 26,086,570-26,136,782 inclusive = 50,213 blocks.  l1-fee-history.json
    holds 50,264 baseFeePerGas and baseFeePerBlobGas entries -- eth_feeHistory
    returns count+1 entries per request over 51 chunks, i.e. 51 look-ahead
    entries -- while gasUsedRatio and blobGasUsedRatio hold exactly 50,213.
  * The last column of the F3 table is labelled "[bounded -- assumes the priority
    fee stays at the window's observed median of ~1.0 gwei while the base fee
    varies]".  It is summary.json cost_curve[*].median_batch_total_eth_at_obs_
    median_egp: the *effective* gas price (not the base fee) is held at the
    observed median 1.125879441 gwei and the blob fee varies with the point.  At
    p99 and max the column value is below the base-fee-only floor of the same
    table, which the stated model cannot produce.

PB-AR-10 (F1): "gasUsed per batch 75,594 (1,574 of 1,575)" -- propose-metrics.csv
has 1,572 rows at 75,594 and 3 at 78,448 (mean 75,599.436).

Reads window.json, l1-fee-history.json, summary.json, fee-percentiles.json,
propose-metrics.csv.  Writes s3-report-recounts.json.
Usage: python3 s3_report_recounts.py
"""
import collections, csv, json, os


def main():
    outdir = os.path.dirname(os.path.abspath(__file__))
    win = json.load(open(os.path.join(outdir, 'window.json')))['window']
    fh = json.load(open(os.path.join(outdir, 'l1-fee-history.json')))
    summ = json.load(open(os.path.join(outdir, 'summary.json')))
    pct = json.load(open(os.path.join(outdir, 'fee-percentiles.json')))
    rows = list(csv.DictReader(open(os.path.join(outdir, 'propose-metrics.csv'))))

    n_window = win['end_block'] - win['start_block'] + 1
    gas_counts = collections.Counter(int(r['gasUsed']) for r in rows)
    gas_vals = [int(r['gasUsed']) for r in rows]

    curve = []
    for p in summ['cost_curve']:
        curve.append({
            'point': p['point'],
            'base_fee_gwei': p['baseFeePerGas'] / 1e9,
            'base_fee_only_eth': p['median_batch_total_eth_at_basefee'],
            'reported_incl_observed_priority_eth': p['median_batch_total_eth_at_obs_median_egp'],
            'exec_at_basefee_eth': p['median_batch_exec_eth_at_basefee'],
            'exec_at_obs_median_egp_eth': p['median_batch_exec_eth_at_obs_median_egp'],
            'blob_at_point_eth': p['median_batch_blob_eth'],
            'reported_below_base_fee_only': p['median_batch_total_eth_at_obs_median_egp'] < p['median_batch_total_eth_at_basefee'],
        })

    out = {
        'window': {'start_block': win['start_block'], 'end_block': win['end_block'], 'n_blocks': n_window},
        'fee_history': {
            'baseFeePerGas_entries': len(fh['baseFeePerGas']),
            'baseFeePerBlobGas_entries': len(fh['baseFeePerBlobGas']),
            'gasUsedRatio_entries': len(fh['gasUsedRatio']),
            'blobGasUsedRatio_entries': len(fh['blobGasUsedRatio']),
            'chunks': len(fh['chunks']),
            'look_ahead_entries': len(fh['baseFeePerGas']) - n_window,
        },
        'cost_curve_column': {
            'source': 'summary.json cost_curve[*].median_batch_total_eth_at_obs_median_egp',
            'median_effective_gas_price_wei': summ['median_effective_gas_price'],
            'const_exec_at_obs_median_egp_eth': summ['cost_curve'][0]['median_batch_exec_eth_at_obs_median_egp'],
            'median_priority_cost_wei': summ['median_priority_cost_wei'],
            'points': curve,
        },
        'propose_gasUsed_counts': {str(k): v for k, v in sorted(gas_counts.items())},
        'propose_gasUsed_mean': round(sum(gas_vals) / len(gas_vals), 3),
        'propose_rows': len(rows),
    }
    json.dump(out, open(os.path.join(outdir, 's3-report-recounts.json'), 'w'), indent=1)

    print('window %d..%d = %d blocks' % (win['start_block'], win['end_block'], n_window))
    print('feeHistory baseFeePerGas=%d baseFeePerBlobGas=%d gasUsedRatio=%d blobGasUsedRatio=%d chunks=%d (look-ahead %d)' % (
        len(fh['baseFeePerGas']), len(fh['baseFeePerBlobGas']), len(fh['gasUsedRatio']),
        len(fh['blobGasUsedRatio']), len(fh['chunks']), out['fee_history']['look_ahead_entries']))
    print('cost-curve column: effective gas price held at %.9f gwei; exec term constant %.12f ETH' % (
        summ['median_effective_gas_price'] / 1e9, summ['cost_curve'][0]['median_batch_exec_eth_at_obs_median_egp']))
    print('  point  base-fee-only ETH   reported col ETH   reported < base-fee floor?')
    for p in curve:
        print('  %-5s  %.7f            %.7f         %s' % (
            p['point'], p['base_fee_only_eth'], p['reported_incl_observed_priority_eth'],
            p['reported_below_base_fee_only']))
    print('propose gasUsed counts: %s ; mean %.3f over %d rows' % (
        dict(sorted(gas_counts.items())), out['propose_gasUsed_mean'], len(rows)))


if __name__ == '__main__':
    main()
