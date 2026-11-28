#!/usr/bin/env python3
"""Unsigned consecutive stock updateState replay with frozen independent observations.

Runs original, two exact source faults, and each actual same-copy restoration.
Uses the existing authoritative isolation/supervision and shared cache lock.
"""
import argparse
from collections import Counter
import copy
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parent
_spec=importlib.util.spec_from_file_location('etna_handover_bootstrap',ROOT/'run_comet_bootstrap.py')
BOOT=importlib.util.module_from_spec(_spec);_spec.loader.exec_module(BOOT)
COMET=BOOT.COMET
PACKAGE='example.org/etna-comet-handover'
PARENT='TestWeightedHandover'
NAMES=('unchanged','unequal','add-remove','replacement','overlapping')
BRIDGE_PATH='state/etna_conformance_bridge.go'
FAULT_PATH='state/execution.go'
FAULTS={
 'omit-increment': ('\tnValSet.IncrementProposerPriority(1)\n','\t// Private conformance fault: omit the priority increment.\n'),
 'early-activation': ('\t\tValidators:                       state.NextValidators.Copy(),\n','\t\tValidators:                       nValSet.Copy(),\n'),
}

def literal_fixture():
    return json.loads((ROOT/'comet_handover/literals.json').read_bytes(),object_pairs_hook=COMET.EXECUTION.unique_object)

def require_go_outcomes(raw,returncode,mode):
    if mode not in ('normal',*FAULTS): raise ValueError('unknown observation mode')
    try: rows=[json.loads(line,object_pairs_hook=COMET.EXECUTION.unique_object) for line in raw.decode().splitlines() if line.strip()]
    except (ValueError,UnicodeError) as error: raise ValueError('invalid Go JSON stream') from error
    if not rows or any(type(row) is not dict or row.get('Package')!=PACKAGE for row in rows): raise ValueError('missing/unexpected Go package')
    identities=[PARENT+'/'+name for name in NAMES];allowed={PARENT,*identities}
    outcome='pass' if mode=='normal' else 'fail'
    runs=Counter();endings={};package_actions=[];outputs={};scopes=[]
    for row in rows:
        action,identity=row.get('Action'),row.get('Test')
        if action not in ('start','run','output','pass','fail'): raise ValueError('skipped/unexpected event')
        if identity is not None:
            if identity not in allowed: raise ValueError('unexpected native identity')
            if action=='run': runs[identity]+=1
            elif action in ('pass','fail'):
                if identity in endings: raise ValueError('duplicate native terminal')
                endings[identity]=action
            elif action!='output': raise ValueError('invalid test lifecycle event')
        elif action!='output': package_actions.append(action)
        if action=='output':
            payload=row.get('Output')
            if type(payload) is not str: raise ValueError('missing native output')
            frame=payload.startswith(('=== RUN   ','--- PASS: ','--- FAIL: ','PASS\n','FAIL\n','ok  \t','FAIL\t'))
            error=re.match(r'[ \t]+handover_test.go:[1-9][0-9]*: handover-observation-mismatch ',payload) is not None
            if 'OutputType' in row and row['OutputType']!=('frame' if frame else 'error' if error else ''): raise ValueError('wrong native OutputType')
            if not scopes or scopes[-1]!=identity: scopes.append(identity)
            outputs[identity]=outputs.get(identity,'')+payload
    if runs!=Counter({identity:1 for identity in allowed}) or endings!={identity:outcome for identity in allowed}: raise ValueError('missing/duplicate/wrong native outcome')
    if package_actions!=['start',outcome] or returncode!=int(mode!='normal'): raise ValueError('wrong native package/exit outcome')
    if scopes!=[PARENT,*identities,PARENT,None]: raise ValueError('wrong native scope ordering')
    duration=r'[0-9]+(?:\.[0-9]+)?s'
    if not re.fullmatch(re.escape('=== RUN   '+PARENT+'\n--- '+outcome.upper()+': '+PARENT)+r' \('+duration+r'\)\n',outputs[PARENT]): raise ValueError('wrong parent frames/diagnostics')
    fixture=literal_fixture()
    for name,identity in zip(NAMES,identities):
        lines=outputs[identity].splitlines(keepends=True)
        if len(lines)!=(3 if mode=='normal' else 4) or lines[0]!='=== RUN   '+identity+'\n': raise ValueError('missing/extra diagnostic or receipt')
        match=re.fullmatch(r'[ \t]+handover_test.go:[1-9][0-9]*: receipt=(.+)\n',lines[1])
        if not match: raise ValueError('wrong receipt diagnostic')
        receipt=json.loads(match[1],object_pairs_hook=COMET.EXECUTION.unique_object)
        expected=dict(name=name,transitions=6,inputUnchanged=True,observations=fixture['observations'][mode][name])
        # Canonical JSON distinguishes true from 1 and rejects extra fields.
        if json.dumps(receipt,sort_keys=True)!=json.dumps(expected,sort_keys=True): raise ValueError('wrong complete actual transition/input/state/header observation')
        if mode!='normal' and not re.fullmatch(r'[ \t]+handover_test.go:[1-9][0-9]*: handover-observation-mismatch id='+re.escape(name)+r'\n',lines[2]): raise ValueError('wrong fault diagnostic')
        if not re.fullmatch('--- '+outcome.upper()+': '+re.escape(identity)+r' \('+duration+r'\)\n',lines[-1]): raise ValueError('wrong leaf frame')
    package=('PASS\nok  \t' if mode=='normal' else 'FAIL\nFAIL\t')+PACKAGE+'\t'
    if not re.fullmatch(re.escape(package)+duration+r'\n',outputs[None]): raise ValueError('wrong package diagnostic')
    return {identity:outcome for identity in identities}

def inputs():
    old,manifest,watched=BOOT.inputs()
    pins=json.loads((ROOT/'comet_handover/pins.json').read_bytes(),object_pairs_hook=COMET.EXECUTION.unique_object)
    if pins.get('schema')!='etna-comet-handover-pins-1' or pins.get('source')!=old['source'] or pins.get('expectedSubtests')!=list(NAMES): raise ValueError('wrong handover provenance')
    expected_files={'go.mod','go.sum','handover_test.go','literals.json','bridge.go.txt','derive_literals.py'}
    if set(pins.get('inputsSha256',{}))!=expected_files: raise ValueError('missing/extra handover pinned build inputs')
    for relative,digest in pins['inputsSha256'].items():
        if COMET.digest((ROOT/'comet_handover'/relative).read_bytes())!=digest: raise ValueError('wrong frozen handover input: '+relative)
    fixture=literal_fixture()
    if fixture.get('schema')!='etna-comet-handover-literals-1' or fixture.get('sourceCommit')!=pins['source']['commit'] or set(fixture['programs'])!=set(NAMES) or set(fixture['observations'])!={'normal',*FAULTS}: raise ValueError('wrong handover literal schema/source/programs')
    watched.update({p:COMET.digest(p.read_bytes()) for p in [Path(__file__),ROOT/'tests/test_comet_handover.py',ROOT/'COMET_HANDOVER.md',*(p for p in (ROOT/'comet_handover').iterdir() if p.is_file())]})
    return pins,manifest,watched

def prepare_private(source,destination,manifest):
    shutil.copytree(source,destination)
    overlay=copy.deepcopy(manifest)
    bridge=destination/BRIDGE_PATH
    if bridge.exists(): raise ValueError('generated bridge collides with original source')
    bridge.parent.chmod(0o755)
    bridge.write_bytes((ROOT/'comet_handover/bridge.go.txt').read_bytes())
    overlay['files'][BRIDGE_PATH]=COMET.file_entry(bridge.read_bytes())
    return overlay

def change_source(private,original_manifest,mode):
    path=private/FAULT_PATH;original=path.read_bytes()
    if COMET.file_entry(original)!=original_manifest['files'][FAULT_PATH]: raise ValueError('fault requires exactly restored original bytes')
    before,after=FAULTS[mode]
    if original.decode().count(before)!=1: raise ValueError('fault selector must match exactly once')
    path.chmod(0o644);path.write_bytes(original.decode().replace(before,after).encode())
    mutated=copy.deepcopy(original_manifest);mutated['files'][FAULT_PATH]=COMET.file_entry(path.read_bytes())
    return original,mutated

def restore_source(private,original,mutated,overlay,commit):
    path=private/FAULT_PATH
    if COMET.file_entry(path.read_bytes())!=mutated['files'][FAULT_PATH]: raise ValueError('fault drift before actual restoration')
    path.write_bytes(original)
    return COMET.verify_snapshot(private,overlay,commit)

def run_trial(phase,mode,source,manifest,args,pins,tool_hashes,watched):
    BOOT.require_stable(watched,'adapter/literal/provenance inputs')
    BOOT.require_stable({args.go_root/p:h for p,h in tool_hashes.items()},'Go toolchain')
    before=COMET.verify_snapshot(source,manifest,pins['source']['commit'])
    trial=args.output/phase;build=trial/'work/build';build.mkdir(parents=True)
    build_inputs=trial/'inputs';build_inputs.mkdir()
    for name in ('handover_test.go','literals.json','go.mod','go.sum'):
        (build_inputs/name).write_bytes((ROOT/'comet_handover'/name).read_bytes())
    modfiles=trial/'modfiles';modfiles.mkdir()
    (modfiles/'go.mod').write_bytes((build_inputs/'go.mod').read_bytes()+b'\nreplace github.com/cometbft/cometbft => /tmp/upstream\n')
    (modfiles/'go.sum').write_bytes((build_inputs/'go.sum').read_bytes())
    executed={p:COMET.digest(p.read_bytes()) for p in [*build_inputs.iterdir(),*modfiles.iterdir()]}
    command=[sys.executable,'-B',str(ROOT/'run_isolated.py')]
    for flag,binding in [('read',str(build_inputs)+'=/tmp/replay'),('read',str(source)+'=/tmp/upstream'),('read',str(modfiles)+'=/tmp/modfiles'),('read',str(args.go_root)+'=/tmp/go'),('read',str(args.module_cache)+'=/tmp/gomodcache'),('write',str(args.build_cache)+'=/tmp/gocache'),('write',str(trial/'work')+'=/tmp/output')]: command+=['--'+flag+'-bind',binding]
    command+=['--cwd','/tmp/replay','--timeout',str(args.timeout)]
    environment=dict(GOROOT='/tmp/go',GOMODCACHE='/tmp/gomodcache',GOCACHE='/tmp/gocache',GOPATH='/tmp/gopath',GOTMPDIR='/tmp/output/build',GOENV='off',GOTOOLCHAIN='local',GOPROXY='off',GOSUMDB='off',GOVCS='*:off',GOWORK='off',CGO_ENABLED='0',GOTELEMETRY='off',GOMAXPROCS='2')
    for key,value in environment.items(): command+=['--env',key+'='+value]
    command+=['--','/tmp/go/bin/go','test','-json','-count=1','-parallel=1','-p=2','-mod=readonly','-modfile=/tmp/modfiles/go.mod','-timeout=90s','-run=^'+PARENT+'$','.']
    started=time.monotonic();result=COMET.EXECUTION.execute(command,ROOT,args.timeout+10)
    raw=result['output'].encode('utf-8');(trial/'combined.log').write_bytes(raw)
    report=dict(phase=phase,mode=mode,sourceRoot=str(source),command=command,supervisorCommand=result['supervisor_argv'],returncode=result['returncode'],timedOut=result['timeout'],elapsedSeconds=round(time.monotonic()-started,3),combinedOutputFile='combined.log',combinedOutputSha256=COMET.digest(raw),streamsCombined=True,outputDecoding='utf-8-errors-replace',storedEncoding='utf-8-reencoded-text',sourceBefore=before,manifestSha256=COMET.digest(json.dumps(manifest,sort_keys=True).encode()),toolsSha256=tool_hashes,executedInputsBefore={str(p.relative_to(trial)):h for p,h in executed.items()},upstreamTestPackagesCompiled=False,selectedParent=PARENT)
    record=trial/'execution.json';record.write_text(json.dumps(report,indent=2,sort_keys=True)+'\n')
    if result['returncode']==125 or result['timeout']: raise ValueError('supervisor initialization/cleanup/timeout failure')
    BOOT.require_stable(executed,'executed generated inputs')
    report['executedInputsAfter']={str(p.relative_to(trial)):COMET.digest(p.read_bytes()) for p in executed}
    report['sourceAfter']=COMET.verify_snapshot(source,manifest,pins['source']['commit'])
    BOOT.require_stable(watched,'adapter/literal/provenance inputs')
    BOOT.require_stable({args.go_root/p:h for p,h in tool_hashes.items()},'Go toolchain')
    report['outcomes']=require_go_outcomes(raw,result['returncode'],mode)
    record.write_text(json.dumps(report,indent=2,sort_keys=True)+'\n')
    print(phase+': 5 exact leaves, 30 actual transitions and 35 complete observations verified',flush=True)
    return report

def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ('source','go-root','module-cache','build-cache','build-lock','output'): parser.add_argument('--'+name,type=Path,required=True)
    parser.add_argument('--timeout',type=int,default=180);args=parser.parse_args(argv)
    try:
        pins,manifest,watched=inputs();COMET.validate_layout(args,watched)
        tools=[args.go_root/'bin/go',args.go_root/'VERSION',*(p for name in ('asm','compile','link','vet') for p in sorted((args.go_root/'pkg/tool').glob('*/'+name)))]
        tool_hashes={str(p.relative_to(args.go_root)):COMET.digest(p.read_bytes()) for p in tools}
        args.build_lock=args.build_lock.resolve()
        with args.build_lock.open('a') as lock:
            COMET.EXECUTION.acquire_lock(lock,min(args.timeout,60))
            original_verified=COMET.verify_snapshot(args.source,manifest,pins['source']['commit'])
            args.output.mkdir(parents=True)
            private=args.output/'private-upstream';overlay=prepare_private(args.source,private,manifest)
            (args.output/'overlay-manifest.json').write_text(json.dumps(overlay,indent=2,sort_keys=True)+'\n')
            reports=[run_trial('normal','normal',private,overlay,args,pins,tool_hashes,watched)];faults={};restorations={}
            for mode in FAULTS:
                original,mutated=change_source(private,overlay,mode)
                (args.output/(mode+'-manifest.json')).write_text(json.dumps(mutated,indent=2,sort_keys=True)+'\n')
                (args.output/(mode+'-execution.go')).write_bytes((private/FAULT_PATH).read_bytes())
                faults[mode]=dict(path=FAULT_PATH,originalSha256=COMET.digest(original),mutantSha256=mutated['files'][FAULT_PATH]['sha256'])
                reports.append(run_trial(mode,mode,private,mutated,args,pins,tool_hashes,watched))
                restorations[mode]=restore_source(private,original,mutated,overlay,pins['source']['commit'])
                reports.append(run_trial(mode+'-restored','normal',private,overlay,args,pins,tool_hashes,watched))
            BOOT.require_stable(watched,'adapter/literal/provenance inputs')
            summary=dict(schema='etna-comet-handover-execution-1',status='PASS',sourceCommit=pins['source']['commit'],originalSourceBefore=original_verified,originalSourceAfter=COMET.verify_snapshot(args.source,manifest,pins['source']['commit']),actualSameCopyRestorations=restorations,samePrivateSourceRestored=len({r['sourceRoot'] for r in reports})==1,bridgePath=BRIDGE_PATH,bridgeSha256=overlay['files'][BRIDGE_PATH]['sha256'],inputSha256={str(p.relative_to(ROOT.parent)):h for p,h in watched.items()},reports=reports,faults=faults,boundaries=['Actual MakeGenesisState and consecutive private updateState; 5 unsigned programs with public B/-B/2B points','Independent pre-execution literal members/powers/priorities/stored proposers/change heights and protobuf/Merkle header projections','No upstream test packages, key generation, signing, commit admission, ApplyBlock, round locks, node/P2P, registry derivation, or authentic signed history','No rescale branch, overflow/clipping, arbitrary validator count or live protocol completion claim'])
            (args.output/'summary.json').write_text(json.dumps(summary,sort_keys=True,indent=2)+'\n')
            print('PASS: two exact stock source faults and actual same-copy restoration')
    except (OSError,ValueError,subprocess.SubprocessError) as error:
        print('Comet handover failed: '+str(error),file=sys.stderr);return 1
    return 0

if __name__=='__main__': raise SystemExit(main())
