#!/usr/bin/env python3
"""Trigger detection, strict result aggregation, proof review and funds-release boundary."""
import argparse
import json
import os
from pathlib import Path
import subprocess
from prepare_pair import CLIENT,PROTOCOL,ROOT,REPO,PROJECT,run,sha,event_head,verify_event,current_heads,validate_heads

REQUIRED=['lean-proofs','rust-refinement','conformance','coverage']
RELEVANT=('formal/etna/','packages/protocol/','packages/taiko-client-rs/',
          'testdata/','.github/workflows/etna--formal.yml','.github/actions/',
          'package.json','pnpm-lock.yaml','pnpm-workspace.yaml','foundry.toml','remappings.txt',
          '.npmrc','.pnpmfile.cjs','.tool-versions','.gitmodules','patches/')
PROOF=('formal/etna/Etna/','formal/etna/manifests/','formal/etna/schemas/',
       'formal/etna/coverage.json','formal/etna/scripts/','formal/etna/tools',
       'formal/etna/lean-toolchain','formal/etna/lake','formal/etna/adapters/',
       '.github/workflows/etna--formal.yml')

def relevant(paths): return any(p.startswith(RELEVANT) for p in paths)
def proof_change(paths): return any(p.startswith(PROOF) for p in paths)

def aggregate(needed,results):
    if results.get('changes') != 'success': raise ValueError('changes detection did not succeed')
    if needed and any(results.get(name) != 'success' for name in REQUIRED):
        raise ValueError('relevant formal jobs must all succeed: '+str(results))
    if needed and results.get('nightly','skipped') not in {'success','skipped'}:
        raise ValueError('nightly execution failed')
    return 'passed' if needed else 'not-applicable'

def proof_review(event,revision):
    number=event['pull_request']['number']; author=event['pull_request']['user']['login']
    pages=json.loads(run(['gh','api','--paginate','--slurp',f'repos/{PROJECT}/pulls/{number}/reviews']))
    reviews=[review for page in pages for review in page]
    latest={}
    for review in reviews:
        if review['state'] in {'APPROVED','CHANGES_REQUESTED','DISMISSED'}:
            latest[review['user']['login']]=review
    for login,review in latest.items():
        if (login != author and review['state']=='APPROVED' and review['commit_id']==revision
            and 'Etna proof contract reviewed' in (review['body'] or '')):
            permission=json.loads(run(['gh','api',f'repos/{PROJECT}/collaborators/{login}/permission']))['permission']
            if permission in {'admin','maintain','write'}: return login
    raise ValueError('exact-head proof reviewer approval required: include "Etna proof contract reviewed"; updating hashes is not approval')

def release_allowed(report,release_sha,artifacts):
    if report.get('verification_sha') != release_sha or report.get('status') != 'passed':
        raise ValueError('release report is not a successful run of this exact SHA')
    if not artifacts or report.get('artifacts') != artifacts:
        raise ValueError('release artifact digests do not match verified artifacts')
    levels=report.get('release_obligations',{})
    required={'GUEST-SOUNDNESS','TIME-RULE-REFINEMENT','SOLIDITY-BYTECODE-REFINEMENT'}
    if set(levels) != required or any(levels[k] != 'implementation-proved' for k in required):
        raise ValueError('funds release blocked: genuine guest, time rules and exact bytecode refinement remain pending')

def changed(event):
    if 'pull_request' in event:
        base=event['pull_request']['base']['sha']; head=event['pull_request']['head']['sha']
    elif os.environ.get('GITHUB_EVENT_NAME')=='push' and event.get('before','').strip('0'):
        base=event['before']; head=event['after']
    else: return ['formal/etna/']
    return run(['git','diff','--name-only',base,head]).splitlines()

def select_artifact(artifacts,job,run_id,attempt):
    prefix=f'etna-{job}-{run_id}-'
    candidates=[]
    for artifact in artifacts:
        suffix=artifact['name'].removeprefix(prefix)
        if (artifact['name'].startswith(prefix) and suffix.isdecimal()
                and 0<int(suffix)<=attempt and not artifact['expired']):
            candidates.append((int(suffix),artifact['id']))
    if not candidates: raise ValueError('missing same-run artifact: '+job)
    return max(candidates)[1]

def main():
    p=argparse.ArgumentParser(description=__doc__); p.add_argument('command',choices=['changes','aggregate','release','artifacts'])
    p.add_argument('--report',type=Path); p.add_argument('--results'); p.add_argument('--relevant',choices=['true','false'])
    p.add_argument('--proof-review',choices=['true','false']); p.add_argument('--coverage',type=Path)
    p.add_argument('--job',choices=['coverage','rust-refinement','conformance','run'])
    p.add_argument('--extraction',type=Path); p.add_argument('--conformance',type=Path); p.add_argument('--pair',type=Path)
    a=p.parse_args(); event=json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text())
    revision=event_head()
    if a.command=='artifacts':
        run_id=os.environ['GITHUB_RUN_ID']; attempt=int(os.environ['GITHUB_RUN_ATTEMPT'])
        pages=json.loads(run(['gh','api','--paginate','--slurp',f'repos/{PROJECT}/actions/runs/{run_id}/artifacts']))
        artifacts=[item for page in pages for item in page['artifacts']]
        with open(os.environ['GITHUB_OUTPUT'],'a') as output:
            for job in ([a.job] if a.job else ['coverage','rust-refinement','conformance']):
                output.write(job+'='+str(select_artifact(artifacts,job,run_id,attempt))+'\n')
        return
    if a.command=='changes':
        paths=changed(event)
        values={'relevant':str(relevant(paths)).lower(),'proof_review':str(proof_change(paths)).lower()}
        with open(os.environ['GITHUB_OUTPUT'],'a') as output:
            for k,v in values.items(): output.write(k+'='+v+'\n')
        print(json.dumps(values|{'paths':paths,'draft':event.get('pull_request',{}).get('draft',False)}))
        return
    if a.command=='release':
        report=json.loads(a.report.read_text())
        ledger=json.loads((ROOT/'coverage.json').read_text())
        release_allowed(report,revision,ledger['contract_artifacts']); return
    needed=a.relevant=='true'; status=aggregate(needed,json.loads(a.results))
    report={'schema_version':1,'verification_sha':revision,'status':status,'jobs':json.loads(a.results),
            'release_obligations':{k:'pending' for k in ['GUEST-SOUNDNESS','TIME-RULE-REFINEMENT','SOLIDITY-BYTECODE-REFINEMENT']}}
    if needed:
        validate_heads(current_heads()); verify_event(revision)
        coverage=json.loads(a.coverage.read_text())
        if (coverage.get('verification_overlay') != revision or not coverage.get('kernel_audit')
                or coverage.get('theorems') != 204 or coverage.get('exact_rust_functions') != 17):
            raise ValueError('coverage report lacks exact current SHA/kernel audit')
        ledger=json.loads((ROOT/'coverage.json').read_text())
        if coverage['ledger_sha256'] != sha(ROOT/'coverage.json'): raise ValueError('stale coverage ledger')
        extraction=json.loads(a.extraction.read_text())
        paired=json.loads(a.conformance.read_text())
        pair=json.loads(a.pair.read_text())
        if (extraction['verification_sha'] != revision or pair['verification_sha'] != revision
                or pair['upstream_client'] != CLIENT or pair['paired_protocol'] != PROTOCOL
                or not paired['fresh_execution'] or paired['seed'] != 20261015):
            raise ValueError('execution receipts do not bind the current pair')
        if paired['landing']['failures'] or paired['landing']['cases'] != 56:
            raise ValueError('paired execution receipt is incomplete')
        report.update(extraction=extraction,conformance=paired,pair_identity=pair['assembled_sha256'],
            input_digests={str(path.relative_to(ROOT)):sha(path) for path in
                [ROOT/'tools.lock.json',ROOT/'lake-manifest.json',ROOT/'tools/opam-environment.export',
                 *sorted((ROOT/'manifests').glob('*.json'))]})
        report.update(coverage=coverage,proof_levels={e['id']:e['bridge_level'] for e in ledger['obligations']},
                      artifacts=ledger['contract_artifacts'])
        if a.proof_review=='true' and 'pull_request' in event:
            report['proof_reviewer']=proof_review(event,revision)
    a.report.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))

if __name__=='__main__': main()
