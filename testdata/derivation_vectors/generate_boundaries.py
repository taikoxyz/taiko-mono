#!/usr/bin/env python3
"""Deterministic Unzen fixtures; acceptance/fallback is authored, never inferred by a validator.

Stored DEFLATE blocks avoid compressor-version drift. Expected outputs encode the specified
inheritance/header formulas, but every source's accept/default choice is explicit below.
"""
import argparse
from copy import deepcopy
import json
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parent
ZERO = '00' * 20
PROPOSER = '99' * 20
BENEFICIARY = '11' * 20
EMPTY = 'c0'
FORKS = {167001: 0, 167000: 1786021200, 167013: 1781787600}


class Raw(bytes):
    """Already encoded RLP, inserted without another string wrapper."""


def rlp(value):
    if isinstance(value, Raw):
        return bytes(value)
    if isinstance(value, int):
        value = value.to_bytes((value.bit_length() + 7) // 8, 'big')
    if isinstance(value, list):
        data = b''.join(rlp(v) for v in value)
        base = 0xc0
    else:
        data = value
        if len(data) == 1 and data[0] < 128:
            return data
        base = 0x80
    if len(data) < 56:
        return bytes([base + len(data)]) + data
    size = len(data).to_bytes((len(data).bit_length() + 7) // 8, 'big')
    return bytes([base + 55 + len(size)]) + size + data


def stored_zlib(raw):
    out = bytearray(b'\x78\x01')
    chunks = [raw[i:i + 65535] for i in range(0, len(raw), 65535)] or [b'']
    for i, chunk in enumerate(chunks):
        out.extend(bytes([int(i == len(chunks) - 1)]))
        out.extend(struct.pack('<HH', len(chunk), len(chunk) ^ 0xffff))
        out.extend(chunk)
    return bytes(out) + struct.pack('>I', zlib.adler32(raw))


def list_contents(encoded):
    lead = encoded[0]
    start = 1 if lead <= 0xf7 else 1 + lead - 0xf7
    return encoded[start:]


def block(timestamp=1901, anchor=401, gas=30000000, coinbase=BENEFICIARY, txs=EMPTY):
    return dict(timestamp=timestamp, coinbase=coinbase, anchor_block_number=anchor,
                gas_limit=gas, transactions_rlp_hex=txs)


def manifest_raw(blocks):
    return rlp([[ [b['timestamp'], bytes.fromhex(b['coinbase']), b['anchor_block_number'],
                   b['gas_limit'], Raw.fromhex(b['transactions_rlp_hex'])] for b in blocks ]])


def source(blocks=None, *, want='accept', forced=False, offset=0, has_blobs=True,
           version=1, size_delta=0, size_high=0, raw=None, payload=None, missing=False,
           reject_extraction=False):
    blocks = deepcopy([block()] if blocks is None else blocks)
    if payload is None:
        compressed = stored_zlib(manifest_raw(blocks) if raw is None else raw)
        size = len(compressed) + size_delta + size_high
        payload = bytes(offset) + version.to_bytes(32, 'big') + size.to_bytes(32, 'big') + compressed
    return (dict(is_forced_inclusion=forced, has_blobs=has_blobs, offset=offset,
                 payload_hex=None if missing else payload.hex()), blocks, want, reject_extraction)


def build_cases():
    corpus = json.loads((ROOT / 'manifest_cases.json').read_text())['cases']
    old = {c['name']: c for c in corpus}
    tx1 = old['type2_control']['engine_tx_list_hex']
    tx2 = old['signed_control']['engine_tx_list_hex']
    # Wrap two distinct encoded candidates without decoding or re-signing either one.
    items = list_contents(bytes.fromhex(tx1)) + list_contents(bytes.fromhex(tx2))
    ordered = (bytes([0xf7 + (len(items).bit_length() + 7) // 8]) +
               len(items).to_bytes((len(items).bit_length() + 7) // 8, 'big') + items).hex() if len(items) >= 56 else (bytes([0xc0 + len(items)]) + items).hex()
    cases = []

    def add(name, category, sources=None, *, parent=None, proposal=None, chain=167001):
        p = dict(number=10, timestamp=1900, gas_limit=31000000, anchor_block_number=400)
        ctx = dict(timestamp=2000, origin_block_number=500, proposer=PROPOSER,
                   proposal_id=8, basefee_sharing_pctg=50)
        p.update(parent or {})
        ctx.update(proposal or {})
        initial = deepcopy(p)
        inputs, outputs, headers, counts, extracted = [], [], [], [], []
        for src, candidates, want, rejected in ([source()] if sources is None else sources):
            inputs.append(src)
            extracted.append(manifest_raw([block(0,0,0,ZERO)] if rejected else candidates).hex())
            if want == 'default' or src['is_forced_inclusion']:
                offset = 6144 if chain == 167000 else 1536
                # These are output construction formulas, NOT acceptance decisions.
                inherited = block(max(p['timestamp'] + 1, max(0, ctx['timestamp'] - offset)),
                                  p['anchor_block_number'],
                                  p['gas_limit'] - (1000000 if p['number'] else 0),
                                  ctx['proposer'])
                finalized = [inherited] if want == 'default' else [dict(inherited, transactions_rlp_hex=candidates[0]['transactions_rlp_hex'])]
            else:
                finalized = candidates
            counts.append(len(finalized))
            for b in finalized:
                derived = dict(b, number=p['number'] + 1, is_forced_inclusion=src['is_forced_inclusion'])
                outputs.append(derived)
                header = dict(gas_limit=b['gas_limit'] + 1000000,
                              extra_data_hex=(bytes([ctx['basefee_sharing_pctg']]) + ctx['proposal_id'].to_bytes(6, 'big')).hex(),
                              anchor_block_number=b['anchor_block_number'],
                              transactions_rlp_hex=b['transactions_rlp_hex'], anchor_first=True)
                headers.append(header)
                p = dict(number=derived['number'], timestamp=b['timestamp'], gas_limit=header['gas_limit'],
                         anchor_block_number=max(p['anchor_block_number'], b['anchor_block_number']))
        cases.append(dict(name=name, category=category, chain_id=chain, proposal=ctx,
                          parent=initial, sources=inputs,
                          expected=dict(source_block_counts=counts, extracted_manifests_rlp_hex=extracted,
                                        blocks=outputs, headers=headers, next_parent=p)))

    add('valid_control', 'extraction')
    add('ordered_candidates', 'header', [source([block(txs=ordered)])])
    for version, valid in [(0, False), (1, True), (2, False), (2**32-1, False),
                           (2**32+1, True), (2**64-1, False), (2**64, False), (2**64+1, False)]:
        add(f'version_{version}', 'version', [source(version=version, want='accept' if valid else 'default', reject_extraction=not valid)])
    for size_high in [2**64, 2**100, 2**255]:
        add(f'size_high_{size_high.bit_length()-1}', 'size', [source(size_high=size_high)])
    for delta in [-1, 1]:
        add(f'size_delta_{delta}', 'size', [source(size_delta=delta, want='default', reject_extraction=True)])
    for size in [0, 1, 2**64-1]:
        payload = bytearray(bytes.fromhex(source()[0]['payload_hex']))
        payload[32:64] = size.to_bytes(32, 'big')
        add(f'size_{size}', 'size', [source(payload=bytes(payload), want='default', reject_extraction=True)])
    for offset in [7, 131007, 131008, 131009]:
        add(f'offset_{offset}', 'offset', [source(offset=offset, want='default' if offset>131008 else 'accept', reject_extraction=offset>131008)])
    huge = source(); huge[0]['offset'] = 2**24-1
    add('offset_uint24_max', 'offset', [(huge[0], huge[1], 'default', True)])
    for n in [0, 1, 31, 32, 63]:
        add(f'payload_length_{n}', 'size', [source(payload=bytes(n), want='default', reject_extraction=True)])
    add('no_blobs', 'blob', [source(has_blobs=False, want='default', reject_extraction=True)])
    add('invalid_decoded_blob', 'blob', [source(missing=True, want='default', reject_extraction=True)])
    for count in [0, 1, 767, 768, 769]:
        bs = [block(9001+i) for i in range(count)]
        add(f'blocks_{count}', 'cardinality', [source(bs, want='default' if count in [0,769] else 'accept', reject_extraction=count>768)],
            parent=dict(timestamp=9000), proposal=dict(timestamp=10000))
    for count in [0, 1, 2, 768]:
        add(f'forced_blocks_{count}', 'cardinality',
            [source([block(txs=tx1) for _ in range(count)], forced=True, want='accept' if count==1 else 'default', reject_extraction=count!=1)])

    # Canonical manifest field decoding, independent of metadata validation.
    for field in ['timestamp', 'anchor_block_number', 'gas_limit']:
        b = block(); b[field] = 2**64
        add(f'rlp_{field}_overflow', 'rlp', [source([b], want='default', reject_extraction=True)])
    for length in [0, 19, 21]:
        add(f'rlp_coinbase_length_{length}', 'rlp', [source([block(coinbase='11'*length)], want='default', reject_extraction=True)])
    valid = manifest_raw([block()])
    add('rlp_trailing_byte', 'rlp', [source(raw=valid+b'\x00', want='default', reject_extraction=True)])
    add('rlp_root_not_list', 'rlp', [source(raw=rlp(b''), want='default', reject_extraction=True)])
    add('rlp_extra_source_field', 'rlp', [source(raw=rlp([[], 1]), want='default', reject_extraction=True)])
    for fields, name in [([1901, bytes.fromhex(BENEFICIARY), 401, 30000000], 'missing_transactions'),
                         ([1901, bytes.fromhex(BENEFICIARY), 401, 30000000, [], 0], 'extra_block_field'),
                         ([b'\x00\x01', bytes.fromhex(BENEFICIARY), 401, 30000000, []], 'leading_zero_integer')]:
        add('rlp_'+name, 'rlp', [source(raw=rlp([[fields]]), want='default', reject_extraction=True)])

    for label, ts, valid in [('lower_minus_one',1900,False),('lower_exact',1901,True),('lower_plus_one',1902,True),
                             ('upper_minus_one',1999,True),('upper_exact',2000,True),('upper_plus_one',2001,False)]:
        add('timestamp_'+label, 'timestamp', [source([block(ts)], want='accept' if valid else 'default')])
    for d in [-1,0,1]:
        add(f'timestamp_offset_{d}', 'timestamp', [source([block(8464+d)], want='default' if d<0 else 'accept')],
            parent=dict(timestamp=100), proposal=dict(timestamp=10000))
    add('timestamp_window_exhausted', 'timestamp', [source([block(2001, txs=tx1)], forced=True, want='default')], parent=dict(timestamp=2000))
    add('timestamp_window_last_second', 'timestamp', [source([block(txs=tx1)], forced=True)], parent=dict(timestamp=1999))
    add('timestamp_descends_late_block', 'timestamp', [source([block(1902), block(1901)], want='default')])
    add('timestamp_repeats_late_block', 'timestamp', [source([block(1901), block(1901)], want='default')])
    for chain, label in [(167000,'mainnet'),(167013,'hoodi')]:
        fork=FORKS[chain]; window=6144 if chain==167000 else 1536; lag=512 if chain==167000 else 128
        for d in [-1,0,1]:
            add(f'{label}_timestamp_offset_{d}', 'timestamp', [source([block(fork+10000-window+d, 901)], want='default' if d<0 else 'accept')],
                parent=dict(timestamp=fork), proposal=dict(timestamp=fork+10000, origin_block_number=1000), chain=chain)
            add(f'{label}_anchor_offset_{d}', 'anchor', [source([block(fork+1, 1000-lag+d)], want='default' if d<0 else 'accept')],
                parent=dict(timestamp=fork, anchor_block_number=100), proposal=dict(timestamp=fork+100, origin_block_number=1000), chain=chain)
        add(label+'_unzen_193_shasta_blocks', 'fork',
            [source([block(fork-193+i, 901) for i in range(193)])],
            parent=dict(timestamp=fork-194), proposal=dict(timestamp=fork, origin_block_number=1000), chain=chain)
        add(label+'_unzen_mixed_blocks', 'fork', [source([block(fork-1,901),block(fork,902)])],
            parent=dict(timestamp=fork-2), proposal=dict(timestamp=fork,origin_block_number=1000),chain=chain)

    for anchor, valid in [(399,False),(400,False),(401,True),(499,True),(500,True),(501,False)]:
        add(f'anchor_{anchor}', 'anchor', [source([block(anchor=anchor)],want='accept' if valid else 'default')])
    for label, anchor, valid in [('lower_minus_one',371,False),('lower_exact',372,True),('lower_plus_one',373,True)]:
        add('anchor_lag_'+label,'anchor',[source([block(anchor=anchor)],want='accept' if valid else 'default')],parent=dict(anchor_block_number=300))
    for name, anchor, valid in [('exact',372,True),('plus_one',371,False)]:
        add('forced_anchor_lag_'+name,'anchor',[source([block(txs=tx1)],forced=True,want='accept' if valid else 'default')],parent=dict(anchor_block_number=anchor))
    for origin in [0,127,128,129]:
        add(f'anchor_origin_{origin}','anchor',[source([block(txs=tx1)],forced=True,want='default' if origin==129 else 'accept')],parent=dict(anchor_block_number=0),proposal=dict(origin_block_number=origin))
    add('forced_parent_anchor_future','anchor',[source([block(txs=tx1)],forced=True,want='default')],parent=dict(anchor_block_number=501))
    add('anchor_regresses_late_block','anchor',[source([block(1901,402),block(1902,401)],want='default')])
    add('anchor_advances_only_last_block','anchor',[source([block(1901,400),block(1902,401)])])
    add('proposer_zero_anchor','anchor',[source([block(anchor=0)],want='default')])
    add('proposer_zero_anchor_then_advance','anchor',
        [source([block(1901,0),block(1902,401)],want='default')])

    for label, gas, valid in [('lower_minus_one',29993999,False),('lower_exact',29994000,True),('lower_plus_one',29994001,True),
                              ('upper_minus_one',30005999,True),('upper_exact',30006000,True),('upper_plus_one',30006001,False)]:
        add('gas_'+label,'gas',[source([block(gas=gas)],want='accept' if valid else 'default')])
    for initial in [10000000,45000000,30000123]:
        upper=min(initial*1000200//1000000,45000000)
        lower=min(max(initial*999800//1000000,10000000),upper)
        for label, gas, valid in [('lower_minus_one',lower-1,False),('lower_exact',lower,True),('upper_exact',upper,True),('upper_plus_one',upper+1,False)]:
            add(f'gas_parent_{initial}_{label}','gas',[source([block(gas=gas)],want='accept' if valid else 'default')],parent=dict(gas_limit=initial+1000000))
    add('gas_bad_late_block','gas',[source([block(1901),block(1902,gas=30006001)],want='default')])
    add('gas_rolls_within_source','gas',[source([block(1901,401,30006000),block(1902,402,30012001)])])
    add('gas_initial_bound_wrong_for_later_block','gas',
        [source([block(1901,401,30006000),block(1902,402,29994000)],want='default')])
    add('gas_rolls_between_sources','gas',
        [source([block(1901,401,30006000)]),source([block(1902,402,30012001)])])
    add('genesis_parent','gas',[source([],want='default')],parent=dict(number=0,gas_limit=30000000))
    add('non_genesis_parent_same_header_gas','gas',[source([],want='default')],parent=dict(gas_limit=30000000))
    add('forced_out_of_bounds_parent_gas','gas',[source([block(txs=tx1)],forced=True,want='default')],parent=dict(gas_limit=9000000))
    for delta in [-1,0,1]:
        add(f'gas_collapsed_interval_{delta}','gas',
            [source([block(gas=8001600+delta)],want='accept' if delta==0 else 'default')],
            parent=dict(gas_limit=9000000))
    add('forced_metadata_overwritten','inheritance',[source([block(2**64-1,2**64-1,2**64-1,txs=ordered)],forced=True)])
    add('default_looking_proposer','inheritance',[source([block(0,0,0,ZERO)],want='default')])
    add('default_looking_forced','inheritance',[source([block(0,0,0,ZERO)],forced=True)])
    add('forced_then_empty_proposer','sequence',[source([block(txs=tx1)],forced=True),source([],want='default')])
    add('empty_proposer_then_valid','sequence',[source([],want='default'),source([block(1902,401,txs=tx1)])])
    add('forced_then_valid_proposer','sequence',[source([block(txs=tx1)],forced=True),source([block(1902,401,txs=ordered),block(1903,402)])])
    add('valid_bad_valid','sequence',[source([block()]),source([block(1902,400,txs=tx2)],want='default'),source([block(1903,402,txs=ordered)])])
    add('two_forced_sources','sequence',[source([block(txs=tx1)],forced=True),source([block(txs=tx2)],forced=True)])
    add('later_failure_preserves_prefix','sequence',[source([block(txs=tx1)]),source(payload=bytes.fromhex(old['late_bad_transaction']['payload_hex']),want='default',reject_extraction=True)])
    add('inbox_forced_valid_bad_proposer','sequence',[
        source([block(txs=tx1)],forced=True),
        source([block(),block()],forced=True,want='default',reject_extraction=True),
        source([block(1903,401,txs=tx2)])])
    add('inbox_forced_then_late_bad_proposer','sequence',[
        source([block(txs=tx1)],forced=True),
        source(payload=bytes.fromhex(old['late_bad_transaction']['payload_hex']),want='default',reject_extraction=True)])
    add('exhausted_window_multiple_defaults','sequence',[source(want='default') for _ in range(3)],parent=dict(timestamp=2000))
    add('empty_activation_proposal','sequence',[],proposal=dict(proposal_id=0))
    for proposal_id in [1,255,256,65535,65536,0x010203040506,2**48-1]:
        add('proposal_id_uint48_max' if proposal_id==2**48-1 else f'proposal_id_{proposal_id}','header',proposal=dict(proposal_id=proposal_id))
    for sharing in [0,100,255]:
        add(f'basefee_sharing_{sharing}','header',proposal=dict(basefee_sharing_pctg=sharing))
    return dict(schema_version=1,cases=cases)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    encoded=json.dumps(build_cases(),indent=2)+'\n'
    path=ROOT/'boundary_cases.json'
    if args.check:
        if not path.exists() or path.read_text()!=encoded:
            raise SystemExit('boundary corpus drift; run generate_boundaries.py and review the diff')
    else:
        path.write_text(encoded)
    print(f'{len(json.loads(encoded)["cases"])} boundary vectors: '+('reproducible' if args.check else 'generated'))


if __name__=='__main__':
    main()
