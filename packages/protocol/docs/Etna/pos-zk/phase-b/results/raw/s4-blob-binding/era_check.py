#!/usr/bin/env python3
"""S4: DA-mode trend check across Taiko's L1 rollup-contract eras.

Samples a 10,000-block window per era, counts proposal events, and classifies a
sample of proposal transactions (EIP-2718 type, calldata size, blob count).

Windows are passed as label:address:topic0:startBlock.
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rpc

def main(outdir, windows):
    out = []
    for label, addr, topic, start in windows:
        rec = {'label': label, 'address': addr, 'topic0': topic,
               'fromBlock': start, 'toBlock': start + 9999}
        try:
            hdr, _ = rpc.el('eth_getBlockByNumber', [hex(start), False])
            rec['fromTimestamp'] = int(hdr['timestamp'], 16)
            logs, url = rpc.el('eth_getLogs', [{'address': addr, 'fromBlock': hex(start),
                                                'toBlock': hex(start + 9999), 'topics': [topic]}])
            rec['url'] = url
            rec['proposals'] = len(logs)
            txs = [lg['transactionHash'] for lg in logs][:30]
            if txs:
                res, u2 = rpc.el_batch([("eth_getTransactionByHash", [t]) for t in txs])
                rec['txSampleUrl'] = u2
                rec['sample'] = []
                for t in res:
                    if not t:
                        continue
                    rec['sample'].append({'hash': t['hash'], 'type': t['type'],
                                          'inputBytes': (len(t['input']) - 2) // 2,
                                          'blobs': len(t.get('blobVersionedHashes') or []),
                                          'blockNumber': int(t['blockNumber'], 16)})
                tc, bc, ib = {}, [], []
                for s in rec['sample']:
                    tc[s['type']] = tc.get(s['type'], 0) + 1
                    bc.append(s['blobs']); ib.append(s['inputBytes'])
                rec['typeCounts'] = tc
                rec['blobsPerTx_min_max'] = [min(bc), max(bc)]
                rec['calldataBytes_min_max'] = [min(ib), max(ib)]
        except Exception as e:
            rec['error'] = repr(e)[:200]
        out.append(rec)
        print(json.dumps({k: v for k, v in rec.items() if k != 'sample'})[:600], flush=True)
    json.dump(out, open(os.path.join(outdir, 'era-trend.json'), 'w'), indent=1)

if __name__ == '__main__':
    ws = []
    for a in sys.argv[2:]:
        label, addr, topic, start = a.split(':')
        ws.append((label, addr, topic, int(start)))
    main(sys.argv[1], ws)
