import json, csv
ts = {}
for l in open('block_times_30d.jsonl'):
    r = json.loads(l)
    ts[r['block']] = r['timestamp']
props = list(csv.DictReader(open('proposed_events.csv')))
shown = 0
for p in props:
    b = int(p['blockNumber'])
    if b in ts and shown < 12:
        print('block', b, 'block_ts', ts[b], 'endOfSubmissionWindowTimestamp', p['endOfSubmissionWindowTimestamp'],
              'diff', ts[b] - int(p['endOfSubmissionWindowTimestamp']), 'basefeeShare', p['basefeeSharingPctg'])
        shown += 1
