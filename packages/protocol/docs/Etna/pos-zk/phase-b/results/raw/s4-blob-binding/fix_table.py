import json, sys
p = sys.argv[1]
s = open(p).read()
pairs = [
 ('| 2025-09 (23,253,517) | Pacaya `BatchProposed` | 341 | 30 × `0x3` | 1–2 | 27,684–30,596 |',
  '| 2025-09 (23,253,517) | Pacaya `BatchProposed` | 341 | 30 × `0x3` | 1–3 | 1,604–58,116 |'),
 ('| 2026-02 (24,355,117) | Pacaya `BatchProposed` | 211 | 30 × `0x3` | 1 | 8,804–21,924 |',
  '| 2026-02 (24,355,117) | Pacaya `BatchProposed` | 211 | 30 × `0x3` | 1 | 5,284–27,684 |'),
 ('| 2025-02 (21,727,117) | TaikoL1 `BlockProposedV2` | 5,460 | 20 × `0x3` | 1 | 388–? |',
  '| 2025-02 (21,727,117) | TaikoL1 `BlockProposedV2` | 5,460 | 20 × `0x3` | 1 | 388–516 |'),
]
for a, b in pairs:
    if a in s:
        s = s.replace(a, b); print('replaced:', a[:60])
    else:
        print('NOT FOUND:', a[:60])
open(p, 'w').write(s)
