#!/usr/bin/env python3
"""S4: sample beacon blob sidecars and check the commitment/proof layers.

For each sampled execution block:
  - fetch full txs, collect the block-level ordered blob versioned hashes;
  - fetch beacon blob sidecars for the block's slot;
  - for each sidecar: recompute versioned hash from the commitment; recompute the
    commitment from the blob with c-kzg + the mainnet trusted setup; verify the
    served kzg_proof; record whether it is the constant 0xc0||0..0 placeholder;
    verify a freshly computed proof for the same blob.

Writes sample-sidecars.json.
"""
import hashlib, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ckzg, rpc

GENESIS_TIME = 1606824023

def main(outdir, setup_path, blocks, max_per_block=3):
    ts = ckzg.load_trusted_setup(setup_path, 0)
    out = []
    for blk in blocks:
        rec = {'block': blk}
        try:
            b, url_el = rpc.el('eth_getBlockByNumber', [hex(blk), True])
            rec['blockTimestamp'] = int(b['timestamp'], 16)
            rec['blobGasUsed'] = int(b['blobGasUsed'], 16)
            rec['excessBlobGas'] = int(b['excessBlobGas'], 16)
            order = []
            for t in b['transactions']:
                for h in (t.get('blobVersionedHashes') or []):
                    order.append(h)
            rec['blockBlobs'] = len(order)
            slot = (rec['blockTimestamp'] - GENESIS_TIME) // 12
            rec['slot'] = slot
            d, base = rpc.beacon(f'/eth/v1/beacon/blob_sidecars/{slot}')
            rec['beaconUrl'] = base
            if 'data' not in d:
                rec['error'] = str(d)[:160]; out.append(rec); continue
            rec['sidecars'] = len(d['data'])
            checks = []
            for s in d['data'][:max_per_block]:
                i = int(s['index'])
                blob = bytes.fromhex(s['blob'][2:])
                comm = bytes.fromhex(s['kzg_commitment'][2:])
                proof = bytes.fromhex(s['kzg_proof'][2:])
                c = {'index': i, 'blobBytes': len(blob), 'commitmentBytes': len(comm),
                     'proofBytes': len(proof),
                     'proof_is_c0_placeholder': proof[0] == 0xc0 and proof[1:] == b'\x00' * 47,
                     'proof_hex': proof.hex()[:20] + '...'}
                vh = '0x01' + hashlib.sha256(comm).hexdigest()[2:]
                c['versionedHash_matches_block'] = (i < len(order) and vh == order[i])
                try:
                    comm_calc = bytes(ckzg.blob_to_kzg_commitment(blob, ts))
                    c['commitment_recomputed_from_blob'] = (comm_calc == comm)
                    good_proof = bytes(ckzg.compute_blob_kzg_proof(blob, comm_calc, ts))
                    c['served_proof_verifies'] = bool(ckzg.verify_blob_kzg_proof(blob, comm, proof, ts))
                    c['fresh_proof_verifies'] = bool(ckzg.verify_blob_kzg_proof(blob, comm, good_proof, ts))
                    c['served_proof_equals_fresh'] = (proof == good_proof)
                except Exception as e:
                    c['error'] = repr(e)[:160]
                checks.append(c)
            rec['checks'] = checks
        except Exception as e:
            rec['error'] = repr(e)[:200]
        out.append(rec)
        print(json.dumps(rec)[:900], flush=True)
    json.dump(out, open(os.path.join(outdir, 'sample-sidecars.json'), 'w'), indent=1)

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], [int(x) for x in sys.argv[3:]])
