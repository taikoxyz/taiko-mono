#!/usr/bin/env python3
"""Fresh executable Lean/Rust/Foundry paired conformance (FI, committee, landing and the
L2 fee-vault claim), including seeded extra cases."""
import argparse
import json
import os
from pathlib import Path
import random
import subprocess
import tempfile
from prepare_pair import ROOT,REPO,sha

# Actual L2FeeVault rows in corpus/claim.jsonl; a shrunken corpus fails the paired run.
CLAIM_CASES=41


def seeded_rows(domain, seed, count=256):
    rng=random.Random(seed)
    rows=[]
    for i in range(count):
        if domain=='fi':
            timestamp=rng.randrange(2**64); delay=rng.randrange(2**64)
            anchor=rng.choice([rng.randrange(2**64),min(2**64-1,timestamp+delay)])
            args=[timestamp,delay,anchor]
            expected=str(anchor>=timestamp+delay).lower(); op='due'
        elif domain=='committee':
            total=rng.randrange(1,2**128); signed=rng.randrange(total+1)
            args=[signed,total]; expected=str(signed*3>total*2).lower(); op='quorum'
        else: raise ValueError('unknown seeded domain')
        rows.append({'id':f'{domain}-{seed}-{i}','op':op,'args':args,'expected':expected})
    return rows


def execute(command,log,cwd=REPO,env=None):
    with log.open('w') as output:
        subprocess.run(command,cwd=cwd,env=env,stdout=output,stderr=subprocess.STDOUT,check=True)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--scope',choices=['paired'],required=True)
    p.add_argument('--seed',type=int,required=True)
    p.add_argument('--protocol',type=Path,default=Path(os.environ.get('ETNA_PROTOCOL',''))/'packages/protocol')
    p.add_argument('--output',type=Path,default=None)
    a=p.parse_args()
    a.output=(a.output or Path(tempfile.mkdtemp(prefix='etna-paired-'))/'run').resolve()
    a.output.mkdir(parents=True,exist_ok=False)
    for domain in ['fi','committee']:
        execute(['python3',str(ROOT/'scripts'/f'{domain}_conformance.py')],a.output/(domain+'-fixed.log'))
        corpus=a.output/(domain+'-seeded.jsonl')
        corpus.write_text(''.join(json.dumps(r)+'\n' for r in seeded_rows(domain,a.seed)))
        execute(['python3',str(ROOT/'scripts'/f'{domain}_conformance.py'),'--corpus',str(corpus)],a.output/(domain+'-seeded.log'))
    execute(['python3',str(ROOT/'scripts/landing_conformance.py'),'--run-solidity','--protocol',str(a.protocol),
             '--observations',str(a.output/'observations.jsonl'),'--report',str(a.output/'landing.json')],a.output/'landing.log')
    result=json.loads((a.output/'landing.json').read_text())
    if (result['cases'],result['actual_preimages'],result['rust_statement_rows'],result['cuts']['plans'],result['cuts']['intervals'],result['failures']) != (74,39,74,4,12,[]):
        raise ValueError('incomplete paired conformance')
    execute(['python3',str(ROOT/'scripts/claim_conformance.py'),'--run-solidity','--protocol',str(a.protocol),
             '--observations',str(a.output/'claim-observations.jsonl'),'--report',str(a.output/'claim.json')],a.output/'claim.log')
    claim=json.loads((a.output/'claim.json').read_text())
    if (claim['cases'],claim['failures']) != (CLAIM_CASES,[]):
        raise ValueError('incomplete paired claim conformance')
    (a.output/'conformance.json').write_text(json.dumps({'seed':a.seed,'fresh_execution':True,'landing':result,
        'claim':claim,'seeded_cases_per_domain':256,'logs':{p.name:sha(p) for p in a.output.glob('*.log')}},indent=2)+'\n')

if __name__=='__main__': main()
