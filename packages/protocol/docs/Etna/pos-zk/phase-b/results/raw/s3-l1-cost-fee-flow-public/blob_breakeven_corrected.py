#!/usr/bin/env python3
"""S3 F8: the break-even blob base fee, corrected to include the amortised proving cost.

The report (l1-cost-fee-flow.md, F8) quoted:

    "Break-even blob base fee, holding execution cost at the sampled-hour value:
     1,069,729,806 wei (about 1.07 gwei/blob-gas, 2.5x the window's observed maximum)"

That figure divides the sampled hour's all-fee L2 revenue minus the batches'
*execution* cost by the 8 x 131,072 blob gas, and so omits the amortised on-chain
proving cost (0.000108355727396 ETH per batch) that the same finding's own
coverage model -- "L1 total (landing + on-chain proving)" -- includes.  With the
proving line restored the break-even is 4.4x lower, and the window's observed
maximum blob fee is 1.76x the corrected break-even rather than 0.4x of the
reported one: at the observed peak the blob line alone consumes the entire fee
margin once the proof is paid.

Derivation (all inputs from this directory's committed files):
    revenue           = sum of the 8 batches' l2_fee_total_eth           (coverage-metrics.csv)
    execution cost    = sum of l1_propose_eth - l1_blob_eth                (join-metrics.csv)
    proving cost      = 8 x prove_eth_per_proposal                       (coverage-summary.json)
    break-even        = (revenue - execution cost - proving cost) / (8 x 131,072)
and, on F8's aggregate L1-total basis (which pairs the aggregate L2 fees with the
aggregate landing + proving total):
    break-even_agg    = (aggregate l2_fees - aggregate l1_total) / (8 x 131,072)

Reads coverage-metrics.csv, join-metrics.csv, coverage-summary.json,
fee-percentiles.json.  Writes blob-breakeven-corrected.json.
Usage: python3 blob_breakeven_corrected.py
"""
import csv, json, os

GAS_PER_BLOB = 131072


def main():
    outdir = os.path.dirname(os.path.abspath(__file__))
    cov = list(csv.DictReader(open(os.path.join(outdir, 'coverage-metrics.csv'))))
    jm = {int(r['proposalId']): r for r in csv.DictReader(open(os.path.join(outdir, 'join-metrics.csv')))}
    summary = json.load(open(os.path.join(outdir, 'coverage-summary.json')))
    pct = json.load(open(os.path.join(outdir, 'fee-percentiles.json')))

    n = len(cov)
    blob_gas = n * GAS_PER_BLOB
    fees = sum(float(c['l2_fee_total_eth']) for c in cov)
    base_fees = sum(float(c['l2_base_fee_eth']) for c in cov)
    propose = sum(float(jm[int(c['proposalId'])]['l1_cost_eth']) for c in cov)
    blob = sum(float(jm[int(c['proposalId'])]['l1_blob_eth']) for c in cov)
    exec_ = propose - blob
    prove = n * summary['prove_eth_per_proposal']

    old = (fees - exec_) / blob_gas
    corrected = (fees - exec_ - prove) / blob_gas
    corrected_agg = (fees - propose - prove) / blob_gas

    max_blob_fee_wei = round(pct['blobBaseFee_gwei']['max'] * 1e9)
    blob_cost_at_max_eth = GAS_PER_BLOB * max_blob_fee_wei / 1e18
    margin_total_eth = fees - exec_ - prove
    margin_per_batch_eth = margin_total_eth / n
    coverage_at_max = (fees / n) / (exec_ / n + prove / n + blob_cost_at_max_eth)

    out = {
        'source': 'coverage-metrics.csv + join-metrics.csv + coverage-summary.json + fee-percentiles.json',
        'n_batches_sampled_hour': n,
        'blob_gas': blob_gas,
        'l2_fees_eth': fees, 'l2_base_fees_eth': base_fees,
        'l1_propose_total_eth': propose, 'l1_propose_exec_eth': exec_, 'l1_blob_eth': blob,
        'l1_prove_amortised_eth': prove,
        'reported_break_even_wei': (fees - exec_) / blob_gas * 1e18,
        'reported_break_even_numerator_eth': fees - exec_,
        'corrected_break_even_per_batch_wei': corrected * 1e18,
        'corrected_break_even_per_batch_gwei': corrected * 1e9,
        'corrected_break_even_aggregate_wei': corrected_agg * 1e18,
        'corrected_break_even_aggregate_gwei': corrected_agg * 1e9,
        'margin_left_for_blob_eth_total': margin_total_eth,
        'margin_left_for_blob_eth_per_batch': margin_per_batch_eth,
        'window_max_blob_fee_wei': max_blob_fee_wei,
        'window_max_blob_fee_gwei': max_blob_fee_wei / 1e9,
        'one_blob_at_window_max_eth': blob_cost_at_max_eth,
        'peak_blob_cost_over_margin': blob_cost_at_max_eth / margin_per_batch_eth,
        'window_max_over_corrected_per_batch': max_blob_fee_wei / (corrected * 1e18),
        'window_max_over_reported': max_blob_fee_wei / ((fees - exec_) / blob_gas * 1e18),
        'coverage_at_window_max_blob_fee_holding_other_terms': coverage_at_max,
    }
    json.dump(out, open(os.path.join(outdir, 'blob-breakeven-corrected.json'), 'w'), indent=1)

    print('8 batches in the sampled hour, %d blob gas' % blob_gas)
    print('  L2 fees            %.12f ETH' % fees)
    print('  propose total      %.12f ETH' % propose)
    print('  propose exec-only  %.12f ETH' % exec_)
    print('  amortised proving  %.12f ETH' % prove)
    print()
    print('reported figure (fees - exec)                    = %.0f wei = %.4f gwei' % (
        out['reported_break_even_wei'], out['reported_break_even_wei'] / 1e9))
    print('corrected, F8 per-batch model (- proving)        = %.0f wei = %.4f gwei' % (
        out['corrected_break_even_per_batch_wei'], out['corrected_break_even_per_batch_gwei']))
    print('corrected, aggregate L1-total basis              = %.0f wei = %.4f gwei' % (
        out['corrected_break_even_aggregate_wei'], out['corrected_break_even_aggregate_gwei']))
    print('reported / corrected ratio                       = %.2fx' % (
        out['reported_break_even_wei'] / out['corrected_break_even_per_batch_wei']))
    print()
    print('consequence: window max blob fee %.0f wei = %.4f gwei' % (
        max_blob_fee_wei, max_blob_fee_wei / 1e9))
    print('  one blob at that fee                            = %.12f ETH' % blob_cost_at_max_eth)
    print('  margin left after execution + proving, per batch= %.12f ETH' % margin_per_batch_eth)
    print('  peak blob cost / per-batch margin               = %.3fx' % out['peak_blob_cost_over_margin'])
    print('  max fee / corrected break-even                  = %.3fx' % out['window_max_over_corrected_per_batch'])
    print('  max fee / reported break-even                   = %.3fx' % out['window_max_over_reported'])
    print('  coverage at the peak blob fee, other terms held = %.3fx' % coverage_at_max)


if __name__ == '__main__':
    main()
