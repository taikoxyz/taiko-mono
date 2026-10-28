#!/usr/bin/env python3
"""S4: verify the in-force blob base fee mechanics on chain.

For sampled execution blocks: read excessBlobGas from the header and the
blobGasPrice from the block's blob-transaction receipts, then test which
BLOB_BASE_FEE_UPDATE_FRACTION (Cancun 3338477, Prague 5007716, BPO1 8346193,
BPO2 11684671) reproduces the measured price under the EIP-4844
fake_exponential(MIN_BASE_FEE_PER_BLOB_GAS=1, excess, fraction) rule.

Usage: blobfee_check.py <outdir> <block...>
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rpc

CANDIDATES = {'cancun_3338477': 3338477, 'prague_5007716': 5007716,
              'bpo1_8346193': 8346193, 'bpo2_11684671': 11684671}

def fake_exponential(factor, numerator, denominator):
    i, output, acc = 1, 0, factor * denominator
    while acc > 0:
        output += acc
        acc = (acc * numerator) // (denominator * i)
        i += 1
    return output // denominator

def main(outdir, blocks):
    out = []
    for blk in blocks:
        rec = {'block': blk}
        try:
            call = [("eth_getBlockByNumber", [hex(blk), False]),
                    ("eth_getBlockReceipts", [hex(blk)])]
            res, url = rpc.el_batch(call)
            b, rs = res[0], res[1]
            if b is None or rs is None:
                rec['error'] = 'missing block or receipts'
                out.append(rec); continue
            ex = int(b['excessBlobGas'], 16)
            used = int(b['blobGasUsed'], 16)
            prices = sorted(set(int(r['blobGasPrice'], 16) for r in rs
                                if r.get('blobGasUsed') and int(r['blobGasUsed'], 16) > 0))
            nblobtx = sum(1 for r in rs if r.get('blobGasUsed') and int(r['blobGasUsed'], 16) > 0)
            rec.update({'url': url, 'excessBlobGas': ex, 'blobGasUsed': used,
                        'nBlobTxs': nblobtx, 'blobGasPrice_measured': prices,
                        'blobGasPrice_formula': {k: fake_exponential(1, ex, v) for k, v in CANDIDATES.items()},
                        'timestamp': int(b['timestamp'], 16)})
            rec['matching_fraction'] = [k for k, v in rec['blobGasPrice_formula'].items() if v in prices]
        except Exception as e:
            rec['error'] = repr(e)[:180]
        out.append(rec)
        print(json.dumps(rec)[:400], flush=True)
    json.dump(out, open(os.path.join(outdir, 'blobfee-check.json'), 'w'), indent=1)

if __name__ == '__main__':
    main(sys.argv[1], [int(x) for x in sys.argv[2:]])
