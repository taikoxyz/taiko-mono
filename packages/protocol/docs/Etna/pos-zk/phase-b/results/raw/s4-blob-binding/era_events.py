#!/usr/bin/env python3
"""S4: sample the pre-Pacaya proposal event variants and the calldata fallback.

Windows:
  2025-02: BlockProposedV2 (0xefe9c6c0...) and CalldataTxList (0xa07bc5e8...)
  2024-08: BlockProposed (0xcda4e564...) and CalldataTxList
Records tx type, blob count and calldata size for up to 20 txs per topic.

Usage: era_events.py <outdir>
"""
import json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rpc

OLD = '0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a'
CASES = [
    ('2025-02-BlockProposedV2', '0xefe9c6c0b5cbd9c0eed2d1e9c00cfc1a010d6f1aff50f7facd665a639b622b26', 21727117, 21737116),
    ('2025-02-CalldataTxList',  '0xa07bc5e8f00f6065c8727821591c519efd2348e4ff0c26560a85592e85b6f418', 21727117, 21737116),
    ('2024-08-BlockProposed',   '0xcda4e564245eb15494bc6da29f6a42e1941cf57f5314bf35bab8a1fca0a9c60a', 20402317, 20412316),
    ('2024-08-CalldataTxList',  '0xa07bc5e8f00f6065c8727821591c519efd2348e4ff0c26560a85592e85b6f418', 20402317, 20412316),
]

def main(outdir):
    out = {}
    for label, topic, a, b in CASES:
        rec = {'topic': topic, 'fromBlock': a, 'toBlock': b}
        try:
            logs, u = rpc.el('eth_getLogs', [{'address': OLD, 'fromBlock': hex(a),
                                              'toBlock': hex(b), 'topics': [topic]}], timeout=45)
            rec['count'] = len(logs); rec['url'] = u
            txs = [l['transactionHash'] for l in logs][:20]
            if txs:
                res, u2 = rpc.el_batch([("eth_getTransactionByHash", [t]) for t in txs])
                s = []
                for t in res:
                    if not t:
                        continue
                    s.append({'type': t['type'], 'blobs': len(t.get('blobVersionedHashes') or []),
                              'calldataBytes': (len(t['input']) - 2) // 2, 'to': t['to']})
                rec['sample'] = s
                rec['types'] = {}
                for x in s:
                    rec['types'][x['type']] = rec['types'].get(x['type'], 0) + 1
                rec['blobs_min_max'] = [min(x['blobs'] for x in s), max(x['blobs'] for x in s)]
                rec['calldata_min_max'] = [min(x['calldataBytes'] for x in s), max(x['calldataBytes'] for x in s)]
        except Exception as e:
            rec['error'] = repr(e)[:180]
        out[label] = rec
        print(label, json.dumps({k: v for k, v in rec.items() if k != 'sample'})[:260], flush=True)
        json.dump(out, open(os.path.join(outdir, 'era-proposal-events.json'), 'w'), indent=1)
        time.sleep(2)

if __name__ == '__main__':
    main(sys.argv[1])
