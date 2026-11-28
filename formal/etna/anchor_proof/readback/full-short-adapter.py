import sys,json
sys.path.insert(0,'/tmp/source')
import check_trace as c
from pathlib import Path
raw=Path('/tmp/source/full.log')
trace=c.read_pinned_raw(raw,"b2a70b23e5081d5ffcd7de42f074fa9583e2385ed050ed14d3540e738ce67075",'NoProbe')
states,actions=c.framed(trace)
o=c.fixture('/tmp/source/oracle.json',c.ORACLE);s=c.fixture('/tmp/source/supplement.json',c.SUPPLEMENT)
facts=c.evaluate('new',states,actions,o,s)
assert facts['script']=='ShortFirst' and facts['fullyComparedTargets']==(12,13,14)
print(json.dumps(dict(mode='full-short-new',rawOutcome='NoProbe',logSha256=trace.raw_digest,statesRead=len(trace.frames),actual=facts),sort_keys=True))
