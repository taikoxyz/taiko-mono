import sys, time
sys.path.insert(0, '.')
from rpc import call
URL = 'https://ethereum-rpc.publicnode.com'
base = 26140717
ts = {}
for i in range(0, 25):
    n = base - i
    for a in range(4):
        try:
            b = call(URL, 'eth_getBlockByNumber', [hex(n), False], tries=1)
            ts[n] = int(b['timestamp'], 16)
            break
        except SystemExit:
            time.sleep(1.2)
    time.sleep(0.4)
vals = sorted(ts.items(), reverse=True)
print('fetched', len(vals))
prev = None
for n, t in vals:
    d = (prev - t) if prev is not None else None
    print(n, t, 'delta', d)
    prev = t
