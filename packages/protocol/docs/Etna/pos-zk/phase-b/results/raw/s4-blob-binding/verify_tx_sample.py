#!/usr/bin/env python3
"""S4: verify a spread sample of Shasta-era proposal transactions on L1.

For every k-th proposal in proposals_by_tx.csv, fetch the transaction and its
receipt and check:
  - EIP-2718 type is 0x3 (blob transaction);
  - the transaction's blobVersionedHashes equal the event's recorded blobHashes,
    element-wise and in order;
  - the receipt's blobGasUsed equals 131072 * number of blobs;
  - to == the MainnetInbox proxy.
Also records calldata size and maxFeePerBlobGas.
"""
import csv, json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rpc

INBOX = "0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f"

def main(outdir, step=1000, limit=60):
    rows = list(csv.DictReader(open(os.path.join(outdir, 'proposals_by_tx.csv'))))
    src = {}
    for r in csv.DictReader(open(os.path.join(outdir, 'proposals.csv'))):
        src.setdefault(r['txHash'], []).extend(r['blobHashes'].split(';') if r['blobHashes'] else [])
    picked = rows[::step][:limit]
    out = []
    for i in range(0, len(picked), 20):
        batch = picked[i:i + 20]
        calls = []
        for r in batch:
            calls.append(("eth_getTransactionByHash", [r['txHash']]))
            calls.append(("eth_getTransactionReceipt", [r['txHash']]))
        res, url = rpc.el_batch(calls)
        for j, r in enumerate(batch):
            t, rc = res[2 * j], res[2 * j + 1]
            rec = {'block': int(r['block']), 'txHash': r['txHash'],
                   'proposalId': int(r['proposalId']), 'eventBlobs': int(r['nblobs']),
                   'url': url}
            if t:
                ev = sorted(h for h in src.get(r['txHash'], []) if h)
                txh = t.get('blobVersionedHashes') or []
                rec.update({'type': t['type'], 'to': t['to'],
                            'toIsInbox': t['to'].lower() == INBOX.lower(),
                            'calldataBytes': (len(t['input']) - 2) // 2,
                            'maxFeePerBlobGas': int(t['maxFeePerBlobGas'], 16) if t.get('maxFeePerBlobGas') else None,
                            'txBlobs': len(txh),
                            'blobHashesMatchEvent': txh == [h for h in src.get(r['txHash'], []) if h]})
            if rc:
                rec.update({'receiptType': rc['type'],
                            'blobGasUsed': int(rc['blobGasUsed'], 16) if rc.get('blobGasUsed') else 0,
                            'blobGasPrice': int(rc['blobGasPrice'], 16) if rc.get('blobGasPrice') else 0,
                            'gasUsed': int(rc['gasUsed'], 16),
                            'status': rc['status']})
                rec['blobGasUsedMatches'] = rec.get('blobGasUsed') == 131072 * rec.get('txBlobs', 0)
            out.append(rec)
        print(f"{i + len(batch)}/{len(picked)}", flush=True)
        time.sleep(0.5)
    json.dump(out, open(os.path.join(outdir, 'tx-sample.json'), 'w'), indent=1)
    types = {}
    for r in out:
        types[r.get('type')] = types.get(r.get('type'), 0) + 1
    print('sample', len(out), 'types', types)
    print('all to inbox:', all(r.get('toIsInbox') for r in out))
    print('all blobHashes match:', all(r.get('blobHashesMatchEvent') for r in out))
    print('all blobGasUsed match:', all(r.get('blobGasUsedMatches') for r in out))

if __name__ == '__main__':
    main(sys.argv[1])
