import json, statistics, datetime

blk = json.load(open('ethproofs_blocks_extract.json'))
print('records', len(blk))
def parse(ts):
    return datetime.datetime.fromisoformat(ts.replace('Z','+00:00'))
rows=[]
for b in blk:
    try:
        q=parse(b['queued_timestamp']); p=parse(b['proving_timestamp']); pr=parse(b['proved_timestamp'])
        rows.append((b['block_number'], b['proving_time'], (pr-p).total_seconds(), (pr-q).total_seconds(), b['proving_cycles'], b['proof_status']))
    except Exception as e:
        pass
print('n with timestamps', len(rows))
for r in rows[:8]:
    print('block %d proving_time=%s (proved-proving)=%.2fs (proved-queued)=%.2fs cycles=%s status=%s' % r)
pt=[r[1] for r in rows]; wall=[r[2] for r in rows]
print('proving_time min/med/max', min(pt), statistics.median(pt), max(pt))
print('wall proved-proving min/med/max', round(min(wall),2), round(statistics.median(wall),2), round(max(wall),2))
print('ratio proving_time/wall median', round(statistics.median([a/b for a,b in zip(pt,wall)]),3))
ct=[parse(b['created_at']) for b in blk]
print('created_at range', min(ct).isoformat(), '->', max(ct).isoformat())
st=set(b['proof_status'] for b in blk); print('statuses', st)
# distinct teams/clusters
cl={}
for b in blk: cl.setdefault(b['cluster_id'],0); cl[b['cluster_id']]+=1
print('clusters', cl)
