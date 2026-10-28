import json, csv, collections
ts = {}
for l in open('block_times_30d.jsonl'):
    r = json.loads(l)
    ts[r['block']] = r['timestamp']
print('timestamps fetched:', len(ts), 'range', min(ts), max(ts))
props = list(csv.DictReader(open('proposed_events.csv')))
provs = list(csv.DictReader(open('proved_events.csv')))
diffs = collections.Counter()
n = 0
for p in props:
    b = int(p['blockNumber'])
    if b in ts:
        d = int(p['endOfSubmissionWindowTimestamp']) - ts[b]
        diffs[d] += 1
        n += 1
print('proposals matched to fetched block times:', n)
print('endOfSubmissionWindowTimestamp - block.timestamp, top values:', diffs.most_common(8))
# also: proposals per block, and id continuity
print('proposal id range:', props[0]['id'], props[-1]['id'], 'rows', len(props))
