import sys
p = sys.argv[1]
s = open(p).read()
B = chr(96)
fixes = [
 ('the measured fee is six to eight orders of\nmagnitude above it.',
  'the measured fee is between ~6 and ~9\norders of magnitude above it.'),
 ('2,020 (5.0 % of the 40,474) headers)', '2,020 headers, 5.0 % of the 40,474)'),
 ('blocks, the maximum blob gas observed in one block was\n21 (3 of 400 sampled blocks; the full histogram is in the raw file) blobs — a lower bound on the enforced maximum, not the\nmaximum itself.',
  'blocks, the maximum number of blobs observed in one block was **21**\n(3 of the 400 sampled blocks; full histogram in ' + B + 'network-blob-usage-sample.json' + B + ') — a lower\nbound on the enforced maximum, not the maximum itself.'),
 ('F1/F2/F5: exercised in production on 40,465 proposals',
  'F1/F2/F5: exercised in production on 40,473 proposals'),
 ('only ~2.4–6.4 KB is non-zero', 'only ~2.3–6.4 KB is non-zero'),
 ('| Proposer wrapper | ' + B + '0x68d30f47F19c07bCCEf4Ac7FAE2Dc12FCa3e0dC9' + B + ' | ' + B + 'labprovers.taiko.eth' + B + '; top-level sender of pre-Shasta proposals; logs are emitted by the rollup proxy |',
  '| Proposer wrapper(s) | ' + B + '0x68d30f47F19c07bCCEf4Ac7FAE2Dc12FCa3e0dC9' + B + ' (' + B + 'labprovers.taiko.eth' + B + '; 2024-08/2025-06 samples) and ' + B + '0xd5aa0e20e8a6e9b04f080cf8797410fafaa9688a' + B + ' (2025-09/2026-02 samples) | top-level sender of pre-Shasta proposals; the rollup proxy emits the logs |'),
 ('| Earlier-era samples | 10,000-block windows listed in §3.7 |',
  '| Earlier-era samples | 10,000-block windows listed in §3 F7 |'),
 ("The EIP-7892 values are the specification's BPO table; the live schedule above\nindependently confirms the max values and epochs.",
  "The EIP-7892 values are the specification's BPO table (that EIP presents the schedule as illustrative; the live node config above independently confirms the **max** values and epochs, and F3 confirms the BPO2 base-fee update fraction on chain — the **target** values rest on the EIP-7892 table)."),
]
for a, b in fixes:
    if a in s:
        s = s.replace(a, b); print('fixed:', a[:70].replace(chr(10), ' '))
    else:
        print('NOT FOUND:', a[:70].replace(chr(10), ' '))
open(p, 'w').write(s)
