#!/usr/bin/env python3
"""S4: what the pre-Shasta Pacaya inbox did on L1 (calldata or blobs?).

Scans BatchProposed logs of the Pacaya TaikoInbox proxy
0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a over sampled 10,000-block windows,
then fetches each proposal transaction to record its EIP-2718 type, calldata
size and blob versioned hashes.

Usage: pacaya_check.py <outdir> <label:startBlock> ...
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rpc

TOPIC = "0x9eb7fc80523943f28950bbb71ed6d584effe3e1e02ca4ddc8c86e5ee1558c096"
OLD_INBOX = "0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a"

def main(outdir, windows):
    out = []
    for label, start in windows:
        rec = {'label': label, 'fromBlock': start, 'toBlock': start + 9999}
        try:
            logs, url = rpc.el('eth_getLogs', [{'address': OLD_INBOX, 'fromBlock': hex(start),
                                                'toBlock': hex(start + 9999), 'topics': [TOPIC]}])
            rec['url'] = url
            rec['proposals'] = len(logs)
            txs = [lg['transactionHash'] for lg in logs][:30]
            if txs:
                calls = [("eth_getTransactionByHash", [t]) for t in txs]
                res, u2 = rpc.el_batch(calls)
                rec['txSampleUrl'] = u2
                rec['sample'] = []
                for t in res:
                    if not t:
                        continue
                    rec['sample'].append({
                        'hash': t['hash'], 'type': t['type'],
                        'inputBytes': (len(t['input']) - 2) // 2,
                        'blobVersionedHashes': len(t.get('blobVersionedHashes') or []),
                        'to': t['to'], 'blockNumber': int(t['blockNumber'], 16)})
                types = {}
                for s in rec['sample']:
                    types[s['type']] = types.get(s['type'], 0) + 1
                rec['typeCounts'] = types
        except Exception as e:
            rec['error'] = repr(e)[:200]
        out.append(rec)
        print(json.dumps(rec)[:600], flush=True)
    json.dump(out, open(os.path.join(outdir, 'pacaya-era.json'), 'w'), indent=1)

if __name__ == '__main__':
    windows = []
    for a in sys.argv[2:]:
        label, start = a.split(':')
        windows.append((label, int(start)))
    main(sys.argv[1], windows)
