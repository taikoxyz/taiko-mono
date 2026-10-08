#!/usr/bin/env python3
"""S4: decode Taiko MainnetInbox 'Proposed' event logs into CSV.

Event: Proposed(uint48 indexed id, address indexed proposer, bytes32 parentProposalHash,
                uint48 endOfSubmissionWindowTimestamp, uint8 basefeeSharingPctg,
                (bool isForcedInclusion,(bytes32[] blobHashes,uint24 offset,uint48 timestamp))[] sources)

Reads every logs/chunk-*.json, writes proposals.csv (one row per source) and
proposals_by_tx.csv (one row per log/tx).
"""
import json, glob, os, sys, csv

def words(data_hex):
    b = bytes.fromhex(data_hex[2:] if data_hex.startswith('0x') else data_hex)
    assert len(b) % 32 == 0, len(b)
    return [b[i:i+32] for i in range(0, len(b), 32)]

def u(w):
    return int.from_bytes(w, 'big')

def decode(data_hex):
    w = words(data_hex)
    parent = '0x' + w[0].hex()
    end_ts = u(w[1]); pct = u(w[2])
    arr_off = u(w[3]) // 32
    L = u(w[arr_off])
    elems = []
    for k in range(L):
        elem_off = arr_off + 1 + u(w[arr_off + 1 + k]) // 32
        is_forced = u(w[elem_off]) != 0
        slice_off = elem_off + u(w[elem_off + 1]) // 32
        hashes_off = u(w[slice_off]) // 32
        offset = u(w[slice_off + 1]); ts = u(w[slice_off + 2])
        hn = u(w[slice_off + hashes_off])
        hashes = ['0x' + w[slice_off + hashes_off + 1 + j].hex() for j in range(hn)]
        elems.append({'isForcedInclusion': is_forced, 'blobHashes': hashes,
                      'offset': offset, 'timestamp': ts})
    return {'parentProposalHash': parent, 'endOfSubmissionWindowTimestamp': end_ts,
            'basefeeSharingPctg': pct, 'sources': elems}

def main(outdir):
    rows, txrows = [], []
    files = sorted(glob.glob(os.path.join(outdir, 'logs', 'chunk-*.json')))
    for f in files:
        d = json.load(open(f))
        for lg in d['response']:
            dec = decode(lg['data'])
            pid = u(bytes.fromhex(lg['topics'][1][2:]))
            proposer = '0x' + lg['topics'][2][-40:]
            blk = int(lg['blockNumber'], 16); ts = int(lg.get('blockTimestamp', '0x0'), 16)
            nblobs = sum(len(s['blobHashes']) for s in dec['sources'])
            txrows.append({'block': blk, 'blockTimestamp': ts, 'txHash': lg['transactionHash'],
                           'logIndex': int(lg['logIndex'], 16), 'proposalId': pid, 'proposer': proposer,
                           'nsources': len(dec['sources']), 'nblobs': nblobs,
                           'basefeeSharingPctg': dec['basefeeSharingPctg'],
                           'endOfSubmissionWindowTimestamp': dec['endOfSubmissionWindowTimestamp'],
                           'parentProposalHash': dec['parentProposalHash'],
                           'blobHashes': ';'.join(h for s in dec['sources'] for h in s['blobHashes'])})
            for j, s in enumerate(dec['sources']):
                rows.append({'block': blk, 'blockTimestamp': ts, 'txHash': lg['transactionHash'],
                             'proposalId': pid, 'proposer': proposer, 'sourceIndex': j,
                             'isForcedInclusion': int(s['isForcedInclusion']),
                             'nblobs': len(s['blobHashes']), 'offset': s['offset'],
                             'sourceTimestamp': s['timestamp'],
                             'blobHashes': ';'.join(s['blobHashes'])})
    with open(os.path.join(outdir, 'proposals_by_tx.csv'), 'w', newline='') as f:
        wr = csv.DictWriter(f, fieldnames=list(txrows[0].keys())); wr.writeheader(); wr.writerows(txrows)
    with open(os.path.join(outdir, 'proposals.csv'), 'w', newline='') as f:
        wr = csv.DictWriter(f, fieldnames=list(rows[0].keys())); wr.writeheader(); wr.writerows(rows)
    print('files', len(files), 'logs', len(txrows), 'sources', len(rows))
    print('blocks', min(r['block'] for r in txrows), '-', max(r['block'] for r in txrows))
    print('total blobs', sum(r['nblobs'] for r in txrows))
    import collections
    print('blobs per tx:', dict(sorted(collections.Counter(r['nblobs'] for r in txrows).items())))
    print('nonzero proposer logs:', sum(1 for r in txrows if r['proposer'] != '0x'+'0'*40))
    # sanity: distinct proposal ids
    print('distinct ids:', len(set(r['proposalId'] for r in txrows)))
    print('dup tx hashes:', len(txrows) - len(set(r['txHash'] for r in txrows)))

if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else '.')
