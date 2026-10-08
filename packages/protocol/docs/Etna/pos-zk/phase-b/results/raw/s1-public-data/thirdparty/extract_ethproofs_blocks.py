import re, json, statistics

def rsc(path):
    t = open(path, encoding='utf-8', errors='ignore').read()
    chunks = re.findall(r'self\.__next_f\.push\(\[1,\s*("(?:[^"\\]|\\.)*")\]\)', t)
    s = ''
    for c in chunks:
        try: s += json.loads(c)
        except Exception: pass
    return s

def objects_with(s, key):
    out = []
    for m in re.finditer(r'"%s"' % key, s):
        i = m.start(); depth = 0; start = None; j = i
        while j >= 0:
            if s[j] == '}': depth += 1
            elif s[j] == '{':
                if depth == 0: start = j; break
                depth -= 1
            j -= 1
        if start is None: continue
        depth = 0
        for k in range(start, len(s)):
            if s[k] == '{': depth += 1
            elif s[k] == '}':
                depth -= 1
                if depth == 0:
                    try: out.append(json.loads(s[start:k+1]))
                    except Exception: pass
                    break
    return out

s = rsc('ethproofs_blocks.html')
blk = objects_with(s, 'proving_time')
print('block-level proof records:', len(blk))
seen = {}
for b in blk:
    seen[b.get('id', json.dumps(b)[:40])] = b
blk = list(seen.values())
print('unique:', len(blk))
if blk:
    print('keys:', sorted(blk[0].keys()))
    print('sample:', json.dumps({k: blk[0][k] for k in blk[0] if not isinstance(blk[0][k], (dict, list))})[:600])
open('ethproofs_blocks_extract.json','w').write(json.dumps(blk, indent=1))
times = [b.get('proving_time') for b in blk if isinstance(b.get('proving_time'), (int, float))]
print('proving_time n=%d min=%s median=%s max=%s' % (len(times), min(times), statistics.median(times), max(times)))
ts = [b.get('timestamp') for b in blk if b.get('timestamp')]
print('timestamp range:', min(ts) if ts else None, '->', max(ts) if ts else None)
