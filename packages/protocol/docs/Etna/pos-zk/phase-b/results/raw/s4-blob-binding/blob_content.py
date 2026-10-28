#!/usr/bin/env python3
"""S4: inspect what Taiko actually publishes inside its proposal blobs.

For the most recent proposals in proposals_by_tx.csv (nblobs == 1), fetch the
beacon blob sidecar, read the LibBlobs.BlobSlice offset recorded in the Proposed
event, decode the 32-byte big-endian length prefix at that field-element offset,
and report payload bytes, padding, nonzero-byte fraction and SHA-256 of the blob.
"""
import csv, hashlib, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rpc

GENESIS = 1606824023
BYTES_PER_BLOB = 131072

def main(outdir, count=4):
    txs = list(csv.DictReader(open(os.path.join(outdir, 'proposals_by_tx.csv'))))
    srcs = list(csv.DictReader(open(os.path.join(outdir, 'proposals.csv'))))
    off = {r['txHash']: int(r['offset']) for r in srcs if r['blobHashes']}
    rows = [r for r in txs if int(r['nblobs']) == 1][-count:]
    out = []
    for r in rows:
        blk = int(r['block']); tx = r['txHash']
        b, _ = rpc.el('eth_getBlockByNumber', [hex(blk), True])
        order = [h for t in b['transactions'] for h in (t.get('blobVersionedHashes') or [])]
        idx = [i for i, t in enumerate(b['transactions']) if t['hash'] == tx]
        slot = (int(b['timestamp'], 16) - GENESIS) // 12
        d, base = rpc.beacon(f'/eth/v1/beacon/blob_sidecars/{slot}')
        side = {int(s['index']): s for s in d.get('data', [])}
        rec = {'block': blk, 'txHash': tx, 'proposalId': int(r['proposalId']),
               'eventBlobHashes': r['blobHashes'], 'slot': slot}
        if not side:
            rec['error'] = 'no sidecars'; out.append(rec); continue
        # the first blob of this tx
        first = None
        for t in b['transactions']:
            if t['hash'] == tx and t.get('blobVersionedHashes'):
                first = order.index(t['blobVersionedHashes'][0]); break
        s = side.get(first)
        blob = bytes.fromhex(s['blob'][2:])
        o = off.get(tx)
        rec.update({'blobIndexInBlock': first, 'eventOffsetElements': o,
                    'blobSha256': hashlib.sha256(blob).hexdigest(),
                    'versionedHash': order[first],
                    'versionedHashMatchesEvent': order[first] == r['blobHashes']})
        if o is not None:
            p = o * 32
            ln = int.from_bytes(blob[p:p + 32], 'big')
            rec['payloadStartByte'] = p
            rec['lengthPrefix'] = ln
            rec['lengthFitsBlob'] = ln <= BYTES_PER_BLOB - (p + 32)
            payload = blob[p + 32:p + 32 + ln] if rec['lengthFitsBlob'] else b''
            rec['payloadBytes'] = len(payload)
            rec['payloadSha256'] = hashlib.sha256(payload).hexdigest()
            rec['payloadHeadHex'] = payload[:48].hex()
            nz = sum(1 for x in blob if x)
            rec['nonzeroBytesInBlob'] = nz
            rec['nonzeroFraction'] = round(nz / BYTES_PER_BLOB, 6)
            rec['trailingAllZero'] = blob[p + 32 + ln:] == b'\x00' * len(blob[p + 32 + ln:])
        out.append(rec)
        print(json.dumps(rec)[:700], flush=True)
    json.dump(out, open(os.path.join(outdir, 'blob-content.json'), 'w'), indent=1)

if __name__ == '__main__':
    main(sys.argv[1])
