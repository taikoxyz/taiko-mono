#!/usr/bin/env python3
"""S4: verify Taiko proposal blobs from public data.

For a given L1 block + transaction hash (a Taiko MainnetInbox propose tx):
 1. fetch the execution block (full txs) and locate the tx's blob versioned hashes
    at their block-level ordinal positions;
 2. fetch the beacon blob sidecars for the block's slot;
 3. recompute versioned_hash = 0x01 || sha256(kzg_commitment)[1:] and compare;
 4. verify the KZG blob proof with the reference c-kzg implementation and the
    mainnet trusted setup;
 5. recompute y = p_D(z) independently in Python (bit-reversed roots of unity,
    EIP-4844 evaluation form) for a transcript-like z, and compare with c-kzg's y;
 6. call the mainnet EIP-4844 point-evaluation precompile 0x0A by eth_call with
    (versioned_hash, z, y, commitment, proof) and record its return value.

Writes one JSON record per checked blob under blobs/.
"""
import hashlib, json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rpc

BLS_MODULUS = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001
N = 4096
GENESIS_TIME = 1606824023
SECONDS_PER_SLOT = 12
FIELD_ELEMENTS_PER_BLOB = 4096
BYTES_PER_BLOB = 131072

import ckzg  # provided on sys.path by the caller (pip --target)

def brp12(j):
    r = 0
    for _ in range(12):
        r = (r << 1) | (j & 1)
        j >>= 1
    return r

_OMEGA = pow(7, (BLS_MODULUS - 1) // N, BLS_MODULUS)
_X = [pow(_OMEGA, brp12(j), BLS_MODULUS) for j in range(N)]

def eval_blob_python(blob: bytes, z: int) -> int:
    """p_D(z) in the EIP-4844 evaluation form: element j is the evaluation at
    omega^{brp12(j)} (the bit-reversed convention)."""
    ys = []
    for j in range(N):
        v = int.from_bytes(blob[32 * j:32 * j + 32], 'big')
        if v >= BLS_MODULUS:
            raise ValueError(f"non-canonical field element at {j}")
        ys.append(v)
    zn = pow(z, N, BLS_MODULUS)
    acc = 0
    for j in range(N):
        acc = (acc + ys[j] * _X[j] % BLS_MODULUS * pow((z - _X[j]) % BLS_MODULUS, BLS_MODULUS - 2, BLS_MODULUS)) % BLS_MODULUS
    inv_n = pow(N, BLS_MODULUS - 2, BLS_MODULUS)
    return (zn - 1) % BLS_MODULUS * inv_n % BLS_MODULUS * acc % BLS_MODULUS

def to32(x: int) -> bytes:
    return x.to_bytes(32, 'big')

def main(outdir, setup_path, targets):
    """targets: list of (blockNumber, txHash)"""
    setup = ckzg.load_trusted_setup(setup_path, 0)
    os.makedirs(os.path.join(outdir, 'blobs'), exist_ok=True)
    for blk, txhash in targets:
        rec = {'block': blk, 'txHash': txhash}
        b, url_el = rpc.el('eth_getBlockByNumber', [hex(blk), True])
        rec['blockHash'] = b['hash']; rec['blockTimestamp'] = int(b['timestamp'], 16)
        rec['excessBlobGas'] = int(b['excessBlobGas'], 16)
        rec['blobGasUsed_block'] = int(b['blobGasUsed'], 16)
        slot = (rec['blockTimestamp'] - GENESIS_TIME) // SECONDS_PER_SLOT
        rec['slot'] = slot
        # block-level ordered blob hashes
        order = []
        for t in b['transactions']:
            for h in (t.get('blobVersionedHashes') or []):
                order.append((t['hash'], h))
        ti = [i for i, (h, _) in enumerate(order) if h == txhash]
        if not ti:
            rec['error'] = 'tx has no blob versioned hashes in this block'
            json.dump(rec, open(os.path.join(outdir, 'blobs', f"{blk}-{txhash[:10]}.json"), 'w'), indent=1)
            print(json.dumps(rec)); continue
        rec['blockBlobHashes'] = len(order)
        rec['txBlobOrdinals'] = ti
        d, url_b = rpc.beacon(f'/eth/v1/beacon/blob_sidecars/{slot}')
        rec['beaconUrl'] = url_b
        if 'data' not in d:
            rec['error'] = f"sidecars unavailable: {str(d)[:120]}"
            json.dump(rec, open(os.path.join(outdir, 'blobs', f"{blk}-{txhash[:10]}.json"), 'w'), indent=1)
            print(json.dumps(rec)); continue
        side = {int(s['index']): s for s in d['data']}
        checks = []
        for k, idx in enumerate(ti):
            if idx not in side:
                checks.append({'ordinal': idx, 'error': 'no sidecar at this index'}); continue
            s = side[idx]
            blob = bytes.fromhex(s['blob'][2:])
            comm = bytes.fromhex(s['kzg_commitment'][2:])
            proof = bytes.fromhex(s['kzg_proof'][2:])
            vh_tx = order[idx][1]
            vh_calc = '0x01' + hashlib.sha256(comm).hexdigest()[2:]
            c = {'ordinal': idx, 'versionedHash_tx': vh_tx, 'versionedHash_recomputed': vh_calc,
                 'versionedHash_match': vh_calc == vh_tx,
                 'blobBytes': len(blob), 'commitmentBytes': len(comm), 'proofBytes': len(proof)}
            try:
                c['ckzg_verify_blob_kzg_proof'] = bool(ckzg.verify_blob_kzg_proof(blob, comm, proof, setup))
            except Exception as e:
                c['ckzg_verify_blob_kzg_proof'] = f'error {e}'
            # transcript-like challenge: sha256 over a domain tag and the tx hash, reduced mod p
            z_int = int.from_bytes(hashlib.sha256(b'TAIKO_ETNA_CHALLENGE' + bytes.fromhex(txhash[2:]) + to32(idx)).digest(), 'big') % BLS_MODULUS
            try:
                proof2, y2 = ckzg.compute_kzg_proof(blob, to32(z_int), setup)
                c['ckzg_computed_y'] = hex(int.from_bytes(y2, 'big'))
                c['ckzg_computed_proof_matches_sidecar'] = (bytes(proof2) == proof)
            except Exception as e:
                c['ckzg_compute_kzg_proof'] = f'error {e}'; y2 = None
            t0 = time.time()
            try:
                y_py = eval_blob_python(blob, z_int)
                c['python_eval_y'] = hex(y_py)
                c['python_eval_seconds'] = round(time.time() - t0, 2)
                if y2 is not None:
                    c['python_y_matches_ckzg_y'] = (y_py == int.from_bytes(y2, 'big'))
            except Exception as e:
                c['python_eval'] = f'error {e}'
            # on-chain 0x0A precompile check via eth_call at latest block
            try:
                inp = ('0x' + (bytes.fromhex(vh_tx[2:]) + to32(z_int) + (bytes(y2) if y2 is not None else to32(0)) + comm + (bytes(proof2) if y2 is not None else proof)).hex())
                r, url_call = rpc.el('eth_call', [{'to': '0x000000000000000000000000000000000000000a', 'data': inp}, 'latest'])
                c['precompile_0x0A_call'] = {'url': url_call, 'inputBytes': (len(inp) - 2) // 2, 'result': r}
                exp = '0x' + (to32(FIELD_ELEMENTS_PER_BLOB) + to32(BLS_MODULUS)).hex()
                c['precompile_0x0A_return_expected'] = exp
                c['precompile_0x0A_ok'] = (r == exp)
            except Exception as e:
                c['precompile_0x0A_call'] = f'error {repr(e)[:200]}'
            checks.append(c)
        rec['checks'] = checks
        json.dump(rec, open(os.path.join(outdir, 'blobs', f"{blk}-{txhash[:10]}.json"), 'w'), indent=1)
        print(json.dumps(rec)[:1500])

if __name__ == '__main__':
    outdir = sys.argv[1]; setup_path = sys.argv[2]
    targets = []
    for a in sys.argv[3:]:
        blk, tx = a.split(':')
        targets.append((int(blk), tx))
    main(outdir, setup_path, targets)
