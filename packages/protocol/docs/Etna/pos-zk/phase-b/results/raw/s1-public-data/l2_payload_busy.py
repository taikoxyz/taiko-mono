#!/usr/bin/env python3
"""Payload-bytes measurement for Taiko L2 blocks that carry user transactions.

For each requested height:
  frame(h) = be32(len(body_h)) || body_h ; body_h = RLP list of the block's txs
  anchor tx = the first tx, to 0x1670000000000000000000000000000000010001 (L1 attributes)
  user gas  = gasUsed - sum(gasUsed of the anchor tx), from eth_getBlockReceipts
Prints one JSON line per block.

Usage: python3 l2_payload_busy.py <rpc> <blocks.txt> <out.jsonl>
"""
import json, sys, time
sys.path.insert(0, ".")
from rpc import batch, call

rpc, listfile, out = sys.argv[1], sys.argv[2], sys.argv[3]
ANCHOR = '0x1670000000000000000000000000000000010001'

def rlp_list_len(total):
    if total <= 55:
        return 1 + total
    n = (total.bit_length() + 7) // 8
    return 1 + n + total

nums = [int(x) for x in open(listfile) if x.strip()]
f = open(out, "w")
t0 = time.time()
for i, h in enumerate(nums):
    blk = call(rpc, 'eth_getBlockByNumber', [hex(h), True])
    ntx = len(blk['transactions'])
    raws = batch(rpc, [('eth_getRawTransactionByBlockNumberAndIndex', [hex(h), hex(k)]) for k in range(ntx)], tries=4)
    raw_lens = [(len(r) - 2) // 2 for r in raws]
    body_len = rlp_list_len(sum(raw_lens))
    receipts = call(rpc, 'eth_getBlockReceipts', [hex(h)])
    gas = [int(r['gasUsed'], 16) for r in receipts]
    anchor_gas = gas[0] if gas else 0
    tos = [t['to'] for t in blk['transactions']]
    anchor_idx = 0 if tos and tos[0] and tos[0].lower() == ANCHOR else None
    user_gas = int(blk['gasUsed'], 16) - (gas[anchor_idx] if anchor_idx is not None else 0)
    user_bytes = sum(raw_lens) - (raw_lens[anchor_idx] if anchor_idx is not None else 0)
    f.write(json.dumps({
        'block': h, 'timestamp': int(blk['timestamp'], 16), 'gasUsed': int(blk['gasUsed'], 16),
        'txs': ntx, 'rawTxLens': raw_lens, 'gasPerTx': gas, 'anchorIdx': anchor_idx,
        'bodyLen': body_len, 'frameLen': 4 + body_len,
        'bPayloadTotal': (4 + body_len) / int(blk['gasUsed'], 16),
        'userBytes': user_bytes, 'userGas': user_gas,
        'bPayloadUser': (user_bytes / user_gas) if user_gas > 0 else None,
    }) + '\n')
    f.flush()
    if i % 50 == 0:
        print('%d/%d %.0fs' % (i, len(nums), time.time() - t0), file=sys.stderr)
f.close()
print(json.dumps({'rpc': rpc, 'blocks': len(nums), 'out': out,
                  'elapsedSec': round(time.time() - t0, 1), 'command': ' '.join(sys.argv)}))
