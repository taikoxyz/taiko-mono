#!/usr/bin/env python3
"""Offline public stock-Comet component replay; requires prepared source and tools.

Never downloads dependencies. Initial-height blocks exercise public validation;
subsequent headers are synthetic transition inputs, not signed consensus blocks.
"""
import argparse
import copy
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import shutil
import stat
import sys

ROOT=Path(__file__).resolve().parent
PROFILE=ROOT/'comet_handover/apphash'
BRIDGE='state/etna_apphash_bridge.go'
FAULT='state/execution.go'
BEFORE=b'\tnValSet.IncrementProposerPriority(1)\n'
AFTER=b'\tnValSet.IncrementProposerPriority(2)\n'
PACKAGE='example.org/etna-comet-apphash'


def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result)
    return result


COMET=module('etna_apphash_comet',ROOT/'run_comet.py')
APP=module('etna_apphash_oracle',ROOT/'run_comet_apphash.py')
CURRENT=module('etna_apphash_current',ROOT/'current_spec.py')


def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def inventory(root):
    result={}
    for p in Path(root).rglob('*'):
        if p.is_symlink(): raise ValueError('symlink in source/input inventory')
        result[p.relative_to(root).as_posix()]={'kind':'directory' if p.is_dir() else 'file','mode':stat.S_IMODE(p.stat().st_mode)}
        if p.is_file(): result[p.relative_to(root).as_posix()].update(bytes=p.stat().st_size,sha256=sha(p))
    return result


def stable(root,expected):
    if inventory(root)!=expected: raise ValueError('source/input bytes, modes or paths changed')


def native_outcomes(raw,rc,receipts):
    # Runtime JSON includes decimal Elapsed; receipt numbers remain strict ints.
    def invalid(token): raise ValueError('nonfinite Go JSON number: '+token)
    rows=[json.loads(line,object_pairs_hook=COMET.EXECUTION.unique_object,parse_constant=invalid) for line in raw.splitlines() if line.strip()]
    expected={'TestAppHash','TestAppHash/late-rescale','TestAppHash/recovery-origin'}
    sequence=[('start',None),('run','TestAppHash'),('output','TestAppHash')]
    for name in ('late-rescale','recovery-origin'):
        test='TestAppHash/'+name
        sequence += [('run',test),*[('output',test)]*4,('pass',test)]
    sequence += [('output','TestAppHash'),('pass','TestAppHash'),('output',None),('output',None),('pass',None)]
    if [(r.get('Action'),r.get('Test')) for r in rows if isinstance(r,dict)]!=sequence:
        raise ValueError('wrong ordered native lifecycle')
    runs=[];ends={};packages=[];observed={};outputs={};scopes=[]
    for row in rows:
        if not isinstance(row,dict) or row.get('Package')!=PACKAGE or row.get('Action') not in ('start','run','output','pass'):
            raise ValueError('native error/skip/unknown outcome')
        action,identity=row['Action'],row.get('Test')
        if 'Elapsed' in row and (type(row['Elapsed']) not in (int,float) or not math.isfinite(row['Elapsed']) or row['Elapsed']<0):
            raise ValueError('invalid Go elapsed time')
        if identity is not None:
            if identity not in expected: raise ValueError('unexpected native test identity')
            if action=='run': runs.append(identity)
            elif action=='pass':
                if identity in ends: raise ValueError('duplicate native terminal')
                ends[identity]=action
            elif action!='output': raise ValueError('invalid test lifecycle')
        elif action!='output': packages.append(action)
        if action=='output':
            output=row.get('Output')
            if type(output) is not str: raise ValueError('missing native output')
            if not scopes or scopes[-1]!=identity: scopes.append(identity)
            outputs[identity]=outputs.get(identity,'')+output
            if 'receipt ' in output:
                match=re.fullmatch(r'\s+apphash_test.go:[1-9][0-9]*: receipt ([a-z-]+) ([1-9][0-9]*) ([0-9a-f]{64})\n',output)
                if not match: raise ValueError('wrong native receipt diagnostic')
                name,length,digest=match.groups();name+='.json'
                if name in observed or name not in receipts or identity!='TestAppHash/'+name.removesuffix('.json').removesuffix('-frames'):
                    raise ValueError('wrong/duplicate producer receipt identity')
                observed[name]={'bytes':int(length),'sha256':digest}
    if rc!=0 or sorted(runs)!=sorted(expected) or ends!={n:'pass' for n in expected} or packages!=['start','pass'] or observed!=receipts:
        raise ValueError('missing/wrong exact native outcomes or receipt binding')
    if scopes!=['TestAppHash','TestAppHash/late-rescale','TestAppHash/recovery-origin','TestAppHash',None]:
        raise ValueError('wrong native output ordering')
    duration=r'[0-9]+(?:\.[0-9]+)?s'
    if not re.fullmatch(r'=== RUN   TestAppHash\n--- PASS: TestAppHash \('+duration+r'\)\n',outputs['TestAppHash']):
        raise ValueError('wrong native parent diagnostics')
    for name in ('late-rescale','recovery-origin'):
        identity='TestAppHash/'+name
        lines=outputs[identity].splitlines(keepends=True)
        if len(lines)!=4 or lines[0]!='=== RUN   '+identity+'\n' or not re.fullmatch(r'--- PASS: '+re.escape(identity)+r' \('+duration+r'\)\n',lines[-1].lstrip()):
            raise ValueError('wrong native leaf diagnostics')
        for line,suffix in zip(lines[1:3],('', '-frames')):
            item=receipts[name+suffix+'.json']
            if not re.fullmatch(r'\s+apphash_test.go:[1-9][0-9]*: receipt '+name+suffix+' '+str(item['bytes'])+' '+item['sha256']+r'\n',line):
                raise ValueError('wrong native leaf receipt order/content')
    if not re.fullmatch(r'PASS\nok  \t'+re.escape(PACKAGE)+r'\t'+duration+r'\n',outputs[None]):
        raise ValueError('wrong native package diagnostics')
    return sorted(ends)


def identity(path):
    s=Path(path).stat();return f'{s.st_dev}:{s.st_ino}'


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    for n in ('source','go-root','module-cache','build-cache','build-lock','output','workspace-root'):
        parser.add_argument('--'+n,type=Path,required=True)
    for n in ('expected-cache-identity','expected-lock-identity'):
        parser.add_argument('--'+n,required=True)
    parser.add_argument('--smoke-only',action='store_true')
    args=parser.parse_args(argv);args.timeout=100
    projection_name = 'comet_signed/public-votes.json'
    projection = (ROOT / projection_name).read_bytes()
    if hashlib.sha256(projection).hexdigest() != APP.PROJECTION_SHA:
        raise ValueError('public-votes.json differs from the reviewed public projection')
    pins=APP.read_json((PROFILE/'pins.json').read_bytes())
    expected_inputs={'comet_handover/apphash/'+n for n in ('apphash_test.go','programs.json','go.mod','go.sum','bridge.go.txt')}
    expected_inputs.update(('run_comet_apphash.py','run_comet_apphash_native.py','COMET_APPHASH.md'))
    expected_inputs.add(projection_name)
    if pins.get('inputsSha256', {}).get(projection_name) != APP.PROJECTION_SHA:
        raise ValueError('public-votes.json profile pin differs from reviewed projection')
    if pins.get('schema')!='etna-comet-apphash-pins-1' or set(pins.get('inputsSha256',{}))!=expected_inputs:
        raise ValueError('wrong/omitted pinned profile input inventory')
    manifest=APP.read_json((ROOT/'manifests/comet.json').read_bytes())
    if pins['sourceManifestSha256']!=sha(ROOT/'manifests/comet.json') or pins['sourceCommit']!=manifest['commit']:
        raise ValueError('wrong original source manifest')
    watched={ROOT/name:digest for name,digest in pins['inputsSha256'].items()}
    watched[PROFILE/'pins.json']=sha(PROFILE/'pins.json')
    for p,d in watched.items():
        if sha(p)!=d: raise ValueError('profile input differs: '+p.name)
    bundle=CURRENT.classify_workspace_documents({n:(args.workspace_root/n).read_bytes() for n in CURRENT.DOCUMENT_PATHS},APP.read_json(CURRENT.MANIFEST_PATH.read_bytes()))
    claim=CURRENT.select_claim(bundle['bundleId'],'comet-validator-state','stock-app-hash')
    # Selection is scope metadata only; actual results are recorded separately.
    for p in (CURRENT.MANIFEST_PATH,Path(CURRENT.__file__),Path(COMET.__file__),ROOT/'run_baseline.py',ROOT/'run_isolated.py',COMET.EXECUTION_PATH): watched[p]=sha(p)
    for n in CURRENT.DOCUMENT_PATHS: watched[args.workspace_root/n]=sha(args.workspace_root/n)
    COMET.validate_layout(args,watched)
    # Exact prepared inode identities supplied by a root-reviewed packet. Never
    # create, follow a symlink to, or silently replace the shared cache lock.
    if args.build_lock.is_symlink() or args.build_cache.is_symlink(): raise ValueError('symlink cache/lock')
    fd=os.open(args.build_lock,os.O_RDONLY|os.O_NOFOLLOW)
    with os.fdopen(fd,'rb') as lock:
        def check_identity():
            st=os.fstat(lock.fileno())
            if f'{st.st_dev}:{st.st_ino}'!=args.expected_lock_identity or identity(args.build_lock)!=args.expected_lock_identity or identity(args.build_cache)!=args.expected_cache_identity:
                raise ValueError('shared physical cache/lock identity changed')
        check_identity();COMET.EXECUTION.acquire_lock(lock,30);check_identity()
        COMET.verify_snapshot(args.source,manifest,pins['sourceCommit'])
        source_inventory=inventory(args.source)
        tools=[args.go_root/'bin/go',args.go_root/'VERSION',*(p for n in ('asm','compile','link','vet') for p in (args.go_root/'pkg/tool').glob('*/'+n))]
        tool_hashes={str(p.relative_to(args.go_root)):sha(p) for p in tools}
        tool_pin=ROOT/'comet_signed/pins.json'
        if tool_hashes!=APP.read_json(tool_pin.read_bytes())['goToolSha256']:
            raise ValueError('Go SDK differs from independently pinned tools')
        watched[tool_pin]=sha(tool_pin)
        args.output.mkdir()
        private=args.output/'private-upstream';shutil.copytree(args.source,private)
        bridge=private/BRIDGE
        if bridge.exists(): raise ValueError('bridge path collision')
        parent_mode=stat.S_IMODE(bridge.parent.stat().st_mode)
        bridge.parent.chmod(parent_mode|0o200)
        try:
            bridge.write_bytes((PROFILE/'bridge.go.txt').read_bytes());bridge.chmod(0o644)
        finally: bridge.parent.chmod(parent_mode)
        overlay=copy.deepcopy(manifest);overlay['files'][BRIDGE]=COMET.file_entry(bridge.read_bytes())
        original_inventory=inventory(private)
        (args.output/'overlay-manifest.json').write_text(json.dumps(overlay,sort_keys=True,indent=2)+'\n')
        original=(private/FAULT).read_bytes();mode=stat.S_IMODE((private/FAULT).stat().st_mode)
        reports=[]
        for phase in (('smoke',) if args.smoke_only else ('original','priority-two','restored')):
            expected_manifest=copy.deepcopy(overlay)
            if phase=='priority-two':
                if original.count(BEFORE)!=1: raise ValueError('ambiguous priority source selector')
                (private/FAULT).chmod(mode|0o200)
                try: (private/FAULT).write_bytes(original.replace(BEFORE,AFTER))
                finally: (private/FAULT).chmod(mode)
                expected_manifest['files'][FAULT]=COMET.file_entry((private/FAULT).read_bytes())
            elif phase=='restored':
                if (private/FAULT).read_bytes()!=original.replace(BEFORE,AFTER): raise ValueError('wrong pre-restoration bytes')
                (private/FAULT).chmod(mode|0o200)
                try: (private/FAULT).write_bytes(original)
                finally: (private/FAULT).chmod(mode)
            phase_inventory=inventory(private)
            if phase!='priority-two' and phase_inventory!=original_inventory: raise ValueError('restored source paths/modes differ')
            COMET.verify_snapshot(private,expected_manifest,pins['sourceCommit'])
            trial=args.output/phase;inputs=trial/'inputs';inputs.mkdir(parents=True)
            for n in ('apphash_test.go','programs.json','go.mod','go.sum'): shutil.copy2(PROFILE/n,inputs/n)
            staged_projection = inputs / 'public-votes.json'
            staged_projection.write_bytes(projection)
            staged_projection.chmod(0o444)
            modfiles=trial/'modfiles';modfiles.mkdir()
            (modfiles/'go.mod').write_bytes((PROFILE/'go.mod').read_bytes()+b'\nreplace github.com/cometbft/cometbft => /tmp/upstream\n')
            shutil.copy2(PROFILE/'go.sum',modfiles/'go.sum')
            work=trial/'work';(work/'build').mkdir(parents=True);(work/'receipts').mkdir();(work/'tmp').mkdir()
            in_inv,mod_inv=inventory(inputs),inventory(modfiles)
            cmd=[sys.executable,'-B',str(ROOT/'run_isolated.py')]
            for flag,binding in [('read',f'{inputs}=/tmp/replay'),('read',f'{private}=/tmp/upstream'),('read',f'{modfiles}=/tmp/modfiles'),('read',f'{args.go_root}=/tmp/go'),('read',f'{args.module_cache}=/tmp/gomodcache'),('write',f'{args.build_cache}=/tmp/gocache'),('write',f'{work}=/tmp/output')]: cmd+=['--'+flag+'-bind',binding]
            cmd+=['--cwd','/tmp/replay','--timeout','100']
            env=dict(GOROOT='/tmp/go',GOMODCACHE='/tmp/gomodcache',GOCACHE='/tmp/gocache',GOPATH='/tmp/gopath',GOTMPDIR='/tmp/output/build',TMPDIR='/tmp/output/tmp',GOENV='off',GOTOOLCHAIN='local',GOPROXY='off',GOSUMDB='off',GOVCS='*:off',GOWORK='off',CGO_ENABLED='0',GOTELEMETRY='off',GOMAXPROCS='2',ETNA_APPHASH_RECEIPTS='/tmp/output/receipts')
            for k,v in env.items(): cmd+=['--env',k+'='+v]
            cmd+=['--','/tmp/go/bin/go','test','-json','-count=1','-parallel=1','-p=2','-mod=readonly','-modfile=/tmp/modfiles/go.mod','-timeout=90s','-run=^TestAppHash$','.']
            check_identity()
            for p,d in watched.items():
                if sha(p)!=d: raise ValueError('watched input changed before phase')
            if sha(staged_projection) != APP.PROJECTION_SHA:
                raise ValueError('staged public-votes.json differs from the reviewed public projection')
            result=COMET.EXECUTION.execute(cmd,ROOT,110)
            raw=result['output'].encode();(trial/'combined.log').write_bytes(raw)
            report=dict(phase=phase,command=cmd,supervisorCommand=result['supervisor_argv'],returncode=result['returncode'],timedOut=result['timeout'],combinedOutputSha256=hashlib.sha256(raw).hexdigest(),outputDecoding='utf-8-errors-replace',sourceManifest=expected_manifest,sourceInventory=phase_inventory,generatedInputsBefore={'inputs':in_inv,'modfiles':mod_inv},toolsSha256=tool_hashes)
            record=trial/'execution.json';record.write_text(json.dumps(report,sort_keys=True,indent=2)+'\n')
            if result['timeout'] or result['returncode']==125: raise ValueError('native timeout/cleanup failure')
            files={p.name:dict(bytes=p.stat().st_size,sha256=sha(p)) for p in (work/'receipts').iterdir() if p.is_file()}
            report['nativeOutcomes']=native_outcomes(raw,result['returncode'],files)
            if phase=='priority-two':
                try: APP.verify_directory(work/'receipts')
                except ValueError as error:
                    if str(error)!='receipt value mismatch at $.observations[1].next.members[0].priority': raise
                    report['consumerExpectedRejection']=str(error)
                else: raise ValueError('priority source variation escaped actual receipt verifier')
            else:
                report['verifiedReceipts']=APP.verify_directory(work/'receipts')
                if report['verifiedReceipts']!=files: raise ValueError('producer diagnostics and consumed receipt bytes differ')
            stable(inputs,in_inv);stable(modfiles,mod_inv);stable(private,phase_inventory);stable(args.source,source_inventory)
            for p,d in watched.items():
                if sha(p)!=d: raise ValueError('watched input changed during phase')
            for p,d in tool_hashes.items():
                if sha(args.go_root/p)!=d: raise ValueError('Go tool changed during phase')
            check_identity();report['allInputsStable']=True
            record.write_text(json.dumps(report,sort_keys=True,indent=2)+'\n');reports.append(report)
            print(phase+': native PASS, consumer '+('expected exact rejection' if phase=='priority-two' else 'PASS'),flush=True)
        if not args.smoke_only:
            for name in reports[0]['verifiedReceipts']:
                if (args.output/'original/work/receipts'/name).read_bytes()!=(args.output/'restored/work/receipts'/name).read_bytes(): raise ValueError('restoration receipt differs')
        stable(private,original_inventory)
        (args.output/'summary.json').write_text(json.dumps(dict(schema='etna-comet-apphash-native-1',status='PASS',workspace=bundle,claim=claim,toolsSha256=tool_hashes,sourceBeforeAfter=source_inventory,profileInputsSha256={str(p):d for p,d in watched.items()},reports=reports),sort_keys=True,indent=2)+'\n')
    return 0


if __name__=='__main__':
    try: raise SystemExit(main())
    except (OSError,ValueError) as error:
        print('appHash replay failed: '+str(error),file=sys.stderr);raise SystemExit(1)
