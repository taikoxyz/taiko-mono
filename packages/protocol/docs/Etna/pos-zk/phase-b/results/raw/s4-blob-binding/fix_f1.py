import sys
p = sys.argv[1]
s = open(p).read()
old = """| proposal events (logs) | 40,474 |
| of which the genesis event (id 0, proposer 0x0, 0 blobs) | 1 |
| proposal transactions with ≥1 blob | 40,465 (99.98 %) |
| proposals with 2 / 4 / 5 blobs | 4 / 2 / 2 |"""
new = """| proposal events (logs) | 40,474 |
| of which the genesis event (id 0, proposer 0x0, 0 blobs) | 1 |
| proposal transactions with ≥1 blob | 40,473 (100 % of proposals) |
| proposals with exactly 1 blob | 40,465 (99.98 % of proposals) |
| proposals with 2 / 4 / 5 blobs | 4 / 2 / 2 |"""
if old in s:
    s = s.replace(old, new); print('fixed F1 table')
else:
    print('F1 table pattern not found')
open(p, 'w').write(s)
