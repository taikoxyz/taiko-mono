import re, json

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
        # walk back to the enclosing '{'
        i = m.start()
        depth = 0
        start = None
        j = i
        while j >= 0:
            if s[j] == '}':
                depth += 1
            elif s[j] == '{':
                if depth == 0:
                    start = j
                    break
                depth -= 1
            j -= 1
        if start is None:
            continue
        # walk forward to matching '}'
        depth = 0
        for k in range(start, len(s)):
            if s[k] == '{': depth += 1
            elif s[k] == '}':
                depth -= 1
                if depth == 0:
                    try:
                        out.append(json.loads(s[start:k+1]))
                    except Exception:
                        pass
                    break
    return out

s = rsc('ethproofs_provers.html')
prov = objects_with(s, 'avg_cost')
print('prover objects:', len(prov))
seen = set()
for p in prov:
    k = (p.get('name'), p.get('id'))
    if k in seen: continue
    seen.add(k)
    print(json.dumps({kk: p.get(kk) for kk in ['name','id','hardware_description','prover_type_id','avg_cost','avg_time','index','is_active'] if kk in p}))
open('ethproofs_provers_extract.json','w').write(json.dumps(prov, indent=1))
