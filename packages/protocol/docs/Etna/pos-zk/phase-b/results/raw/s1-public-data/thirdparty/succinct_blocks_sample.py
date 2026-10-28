import json, statistics, urllib.request, time
from concurrent.futures import ThreadPoolExecutor
LO, HI = 23807739, 23812008
nums = [LO + i * ((HI - LO) // 24) for i in range(25)]
def one(n):
    for a in range(6):
        try:
            req = urllib.request.Request('https://eth.blockscout.com/api/v2/blocks/%d' % n,
                                         headers={'user-agent': 'taiko-mono-s1-research/1.0'})
            with urllib.request.urlopen(req, timeout=25) as r:
                d = json.loads(r.read().decode())
            return {'block': n, 'gas_used': int(d['gas_used']), 'timestamp': d['timestamp']}
        except Exception:
            time.sleep(1 + a)
    return None
out = []
with ThreadPoolExecutor(max_workers=5) as ex:
    for r in ex.map(one, nums):
        if r: out.append(r)
json.dump(out, open('thirdparty/succinct_16gpu_blocks_sample.json', 'w'), indent=1)
gs = [r['gas_used'] for r in out]
print('sampled %d of the 954 blocks in Succinct claim range %d..%d' % (len(out), LO, HI))
print('gasUsed: min %d median %d mean %.0f max %d' % (min(gs), statistics.median(gs), statistics.mean(gs), max(gs)))
print('derived bound: cluster of 16x RTX 5090 proving a block in <12 s -> >= %.0f gas/s for the cluster, >= %.0f gas/s per GPU' % (
    statistics.median(gs) / 12.0, statistics.median(gs) / 12.0 / 16))
print('mean-based: %.0f gas/s cluster, %.0f gas/s per GPU' % (statistics.mean(gs) / 12.0, statistics.mean(gs) / 12.0 / 16))
