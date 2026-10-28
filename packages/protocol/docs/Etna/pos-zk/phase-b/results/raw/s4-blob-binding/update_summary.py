import json, os
d = os.path.dirname(os.path.abspath(__file__))
S = json.load(open(os.path.join(d, 'summary.json')))
for name, key in [('network-blob-usage-sample.json', 'network_blob_usage'),
                  ('blob-price-series.json', 'blob_price_series'),
                  ('era-proposal-events.json', 'era_proposal_events'),
                  ('control-checks.json', 'control_checks'),
                  ('blob-content.json', 'blob_content')]:
    p = os.path.join(d, name)
    if os.path.exists(p):
        S[key] = json.load(open(p))
S['artifact_notes'] = {
 'census': 'block 24792175-26140714, 40474 Proposed logs, decoded to proposals.csv/proposals_by_tx.csv',
 'tx_sample': 'every 1000th proposal row; 40 real proposals all type 0x3 with matching blob hashes',
 'sidecar_sample': '15 sidecars over 5 blocks: versioned hash and commitment recomputation match; served proofs are 0xc0||0..0 placeholders and do not verify; fresh proofs verify',
 'blob_price_series': 'systematic sample: every 20th of the 40474 proposal blocks (2020 blocks), whole era, BPO2 fraction 11684671',
 'network_blob_usage': '400 blocks spread across the era; max 21 blobs observed in a block',
 'retention': 'beacon sidecars served at 0.1/5.7/25.1/39.2 days; 62.7/86.2 days returned HTTP 403 (rate limit, not conclusive)',
}
json.dump(S, open(os.path.join(d, 'summary.json'), 'w'), indent=1)
print('summary keys:', sorted(S.keys()))
