#!/usr/bin/env python3
"""Decode Inbox Proposed/Proved logs into CSVs of the fields needed for cadence analysis.

Layout decoded (ABI):
Proposed(uint48 indexed id, address indexed proposer, bytes32 parentProposalHash,
         uint48 endOfSubmissionWindowTimestamp, uint8 basefeeSharingPctg, DerivationSource[] sources)
  DerivationSource { bool isForcedInclusion; LibBlobs.BlobSlice blobSlice; }
  LibBlobs.BlobSlice { bytes32[] blobHashes; uint24 offset; uint48 timestamp; }
Proved(uint48 firstProposalId, uint48 firstNewProposalId, uint48 lastProposalId, address indexed actualProver)
"""
import json, csv

PROP = '0x7c4c4523e17533e451df15762a093e0693a2cd8b279fe54c6cd3777ed5771213'
PROVED = '0xa274dcaff3629ec7d69d144038e97732516ff306fcbf8a2bc9423d106779a2f0'

def words(data):
    d = data[2:]
    return [d[i:i+64] for i in range(0, len(d), 64)]

def dec_proposed(l):
    w = words(l['data'])
    out = {'id': int(l['topics'][1], 16), 'proposer': '0x' + l['topics'][2][-40:],
           'parentProposalHash': '0x' + w[0] if w else None,
           'endOfSubmissionWindowTimestamp': int(w[1], 16) if len(w) > 1 else None,
           'basefeeSharingPctg': int(w[2], 16) if len(w) > 2 else None,
           'numSources': 0, 'numBlobs': 0, 'numForcedInclusions': 0, 'decodeError': ''}
    try:
        if len(w) < 4:
            out['decodeError'] = 'short-data'
            return out
        off = int(w[3], 16) // 32
        n = int(w[off], 16)
        out['numSources'] = n
        for i in range(n):
            sub = off + 1 + int(w[off + 1 + i], 16) // 32
            forced = int(w[sub], 16)
            out['numForcedInclusions'] += 1 if forced else 0
            bs = sub + int(w[sub + 1], 16) // 32
            arr = bs + int(w[bs], 16) // 32
            out['numBlobs'] += int(w[arr], 16)
    except IndexError:
        out['decodeError'] = 'index-error'
    return out

def dec_proved(l):
    w = words(l['data'])
    return {'firstProposalId': int(w[0], 16), 'firstNewProposalId': int(w[1], 16),
            'lastProposalId': int(w[2], 16), 'prover': '0x' + l['topics'][1][-40:]}

prop_rows, prov_rows = [], []
for line in open('inbox_logs_full.jsonl'):
    l = json.loads(line)
    t = l['topics'][0]
    base = {'blockNumber': int(l['blockNumber'], 16), 'txHash': l['transactionHash'],
            'logIndex': int(l['logIndex'], 16)}
    if t == PROP:
        r = dict(base); r.update(dec_proposed(l)); prop_rows.append(r)
    elif t == PROVED:
        r = dict(base); r.update(dec_proved(l)); prov_rows.append(r)

prop_rows.sort(key=lambda r: (r['blockNumber'], r['logIndex']))
prov_rows.sort(key=lambda r: (r['blockNumber'], r['logIndex']))
with open('proposed_events.csv', 'w', newline='') as f:
    wtr = csv.DictWriter(f, fieldnames=list(prop_rows[0].keys())); wtr.writeheader(); wtr.writerows(prop_rows)
with open('proved_events.csv', 'w', newline='') as f:
    wtr = csv.DictWriter(f, fieldnames=list(prov_rows[0].keys())); wtr.writeheader(); wtr.writerows(prov_rows)
blocks = sorted({r['blockNumber'] for r in prop_rows} | {r['blockNumber'] for r in prov_rows})
open('needed_blocks.txt', 'w').write('\n'.join(str(b) for b in blocks) + '\n')
print('proposed rows', len(prop_rows), 'proved rows', len(prov_rows), 'unique blocks', len(blocks))
print('decode errors:', sum(1 for r in prop_rows if r['decodeError']))
from collections import Counter
print('blob count per proposal:', dict(sorted(Counter(r['numBlobs'] for r in prop_rows).items())))
print('proposal id monotone:', all(prop_rows[i]['id'] < prop_rows[i+1]['id'] for i in range(len(prop_rows)-1)))
