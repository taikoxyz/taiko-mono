#!/usr/bin/env python3
"""Bounded offline stock Bootstrap restart and handshake experiments.

Uses the existing authoritative namespace supervisor and unmodified F04 literal
mapper/observer inputs. No node, signing, fetching or power-loss experiment.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent
# Import the existing source/layout/supervisor and frozen F03 validation seams.
import importlib.util
_spec = importlib.util.spec_from_file_location('etna_restart_bootstrap', ROOT / 'run_comet_bootstrap.py')
BOOT = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(BOOT)
COMET = BOOT.COMET
PACKAGE = 'example.org/etna-comet-restart'
PARENT = 'TestCheckpointRestart'
NAMES = ('origin-clean-close', 'current-clean-close', 'origin-kill-after-ack',
         'current-kill-after-ack', 'readiness-no-ack', 'readiness-wrong-child',
         'readiness-failed-worker', 'observer-controls')
# Each scenario selects a separate bounded native parent/leaf contract;
# persistence never broadens to ./... test selection.
HANDSHAKE_PARENT = 'TestCheckpointHandshake'
HANDSHAKE_NAMES = ('consistent-no-replay','negative-info-height','nonempty-apphash-mismatch',
                   'app-ahead','app-below-store-base','state-ahead','store-too-far-ahead',
                   'missing-last-response','wrong-height-last-response','empty-store-equal',
                   'empty-store-mismatch','empty-store-different-app-height','nonone-first-block-crash',
                   'app-behind-finalize-boundary','app-behind-commit-boundary')
HANDSHAKE_FAULT_NAMES = {'nonempty-apphash-mismatch','empty-store-mismatch'}
SCENARIOS = {'persistence': (PARENT, NAMES), 'handshake': (HANDSHAKE_PARENT,HANDSHAKE_NAMES)}
IDENTITIES = tuple(PARENT + '/' + name for name in NAMES)
FAULT_PATH = 'state/store.go'
# Include the entire Bootstrap function to distinguish its final batch write
# from all other WriteSync calls in this pinned file.
FAULT_BEFORE = '''func (store dbStore) Bootstrap(state State) error {
\tbatch := store.db.NewBatch()
\tdefer func(batch dbm.Batch) {
\t\terr := batch.Close()
\t\tif err != nil {
\t\t\tpanic(err)
\t\t}
\t}(batch)
\theight := state.LastBlockHeight + 1
\tif height == 1 {
\t\theight = state.InitialHeight
\t}

\tif height > 1 && !state.LastValidators.IsNilOrEmpty() {
\t\tif err := store.saveValidatorsInfo(height-1, height-1, state.LastValidators, batch); err != nil {
\t\t\treturn err
\t\t}
\t}

\tif err := store.saveValidatorsInfo(height, height, state.Validators, batch); err != nil {
\t\treturn err
\t}

\tif err := store.saveValidatorsInfo(height+1, height+1, state.NextValidators, batch); err != nil {
\t\treturn err
\t}

\tif err := store.saveConsensusParamsInfo(height,
\t\tstate.LastHeightConsensusParamsChanged, state.ConsensusParams, batch); err != nil {
\t\treturn err
\t}

\tif err := batch.Set(stateKey, state.Bytes()); err != nil {
\t\treturn err
\t}

\tif err := batch.WriteSync(); err != nil {
\t\tpanic(err)
\t}

\treturn batch.Close()
}
'''
WRITE_CALL = '\tif err := batch.WriteSync(); err != nil {\n\t\tpanic(err)\n\t}\n'
FAULT_AFTER = FAULT_BEFORE.replace(WRITE_CALL, '\t// Private restart conformance fault: omit the entire Bootstrap batch write.\n')


HANDSHAKE_FAULT_BEFORE = '''func assertAppHashEqualsOneFromState(appHash []byte, state sm.State) {
	if !bytes.Equal(appHash, state.AppHash) {
		panic(fmt.Sprintf(`state.AppHash does not match AppHash after replay. Got
%X, expected %X.

State: %v

Did you reset CometBFT without resetting your application's data?`,
			appHash, state.AppHash, state))
	}
}
'''
HANDSHAKE_FAULT_AFTER = 'func assertAppHashEqualsOneFromState(appHash []byte, state sm.State) {\n\t// Private handshake conformance fault: omit the entire AppHash guard.\n}\n'


def fault_selector(scenario):
    if scenario == 'persistence': return FAULT_PATH,FAULT_BEFORE,FAULT_AFTER
    if scenario == 'handshake': return 'consensus/replay.go',HANDSHAKE_FAULT_BEFORE,HANDSHAKE_FAULT_AFTER
    raise ValueError('unknown execution scenario')


def handshake_expectation(name):
    fixture=json.loads((ROOT/'comet_restart/handshake_observations.json').read_bytes(),
                       object_pairs_hook=COMET.EXECUTION.unique_object)
    if fixture.get('schema')!='etna-comet-handshake-observations-1':
        raise ValueError('wrong frozen handshake observation schema')
    expected=fixture['cases'][name]
    for key in ('stateBefore','stateAfter'):
        expected[key]=fixture['states'][expected.pop(key+'Profile')]
    return expected


def require_handshake_receipt(data,name,mutant):
    if type(data) is not dict or set(data) != {'kind','name','directory','parentPID','workerPID','observation'}:
        raise ValueError('missing/extra handshake receipt fields')
    if (data['kind'] != 'handshake' or data['name'] != name
            or data['directory'] != '/tmp/output/handshake/'+name):
        raise ValueError('wrong handshake case/directory binding')
    pids=[data['parentPID'],data['workerPID']]
    if any(type(pid) is not int or pid <= 0 for pid in pids) or len(set(pids)) != 2:
        raise ValueError('handshake worker is not a distinct owned process')
    expected = handshake_expectation(name)
    if mutant:
        expected['result']=dict(kind='success',reason='',panicType='')
    if json.dumps(data['observation'],sort_keys=True) != json.dumps(expected,sort_keys=True):
        raise ValueError('wrong complete handshake inputs/result/calls/state/rows observation')


def require_receipt(data, name, mutant):
    if type(data) is not dict:
        raise ValueError('native receipt must be an object')
    if name.startswith('readiness-'):
        reason = {'readiness-no-ack':'no-ack', 'readiness-wrong-child':'wrong-child',
                  'readiness-failed-worker':'worker-failed'}[name]
        expected = dict(kind='readiness', name=name, reason=reason, readerStarted=False, ownedChildReaped=True)
        if json.dumps(data,sort_keys=True) != json.dumps(expected,sort_keys=True):
            raise ValueError('wrong native readiness refusal')
        return
    if name == 'observer-controls':
        if data != dict(kind='observer-controls', name=name,
                        detected=['missing-state', 'missing-validator-history', 'wrong-state-field', 'wrong-validator-priority']):
            raise ValueError('wrong native observer controls')
        return
    origin = name.startswith('origin-')
    heights, params = ([3,4],3) if origin else ([4,5,6],5)
    mode = 'clean-close' if name.endswith('clean-close') else 'kill-after-ack'
    expected = dict(kind='persistence', name=name, case='origin-base' if origin else 'current-base',
                    mode=mode, directory='/tmp/output/databases/' + name,
                    bootstrapCompleted=True, writerStop='closed' if mode == 'clean-close' else 'SIGKILL',
                    readerReopened=True, statePresent=not mutant, missingRows=heights if mutant else [],
                    paramsPresent=not mutant, validatorRows=heights, paramsRow=params)
    if set(data) != set(expected) | {'parentPID','writerPID','readerPID','observation'}:
        raise ValueError('missing/extra native persistence fields')
    # bool is an int subclass; process identities must be actual positive ints.
    pids = [data[k] for k in ('parentPID','writerPID','readerPID')]
    if any(type(pid) is not int or pid <= 0 for pid in pids) or len(set(pids)) != 3:
        raise ValueError('writer/reader process identities are not distinct')
    if any(type(data[k]) is not type(value) or data[k] != value for k,value in expected.items()):
        raise ValueError('wrong native completed-write/same-directory/reopen/row receipt')
    observation = data['observation']
    if mutant:
        if observation is not None:
            raise ValueError('missing Bootstrap batch gained a successful observation')
    else:
        # This public-only literal output fixture was frozen after the original
        # F04 observer checked every selected native state and independent row.
        # It records expected bytes; F04 remains the sole mapper/field oracle.
        literal = json.loads((ROOT/'comet_restart/literal_observations.json').read_bytes(),
                             object_pairs_hook=COMET.EXECUTION.unique_object)
        if json.dumps(observation,sort_keys=True) != json.dumps(literal[expected['case']],sort_keys=True):
            raise ValueError('missing/wrong complete literal state and independent row observation')



def require_go_outcomes(raw, returncode, phase, scenario='persistence'):
    if scenario not in SCENARIOS: raise ValueError('unknown execution scenario')
    parent,names=SCENARIOS[scenario]
    identities=tuple(parent+'/'+name for name in names)
    filename='handshake_test.go' if scenario=='handshake' else 'restart_test.go'
    fault_names=HANDSHAKE_FAULT_NAMES if scenario=='handshake' else set(names[:4])
    if phase not in ('normal','mutant','restored'):
        raise ValueError('unknown execution phase')
    try:
        rows = [json.loads(line, object_pairs_hook=COMET.EXECUTION.unique_object)
                for line in raw.decode().splitlines() if line.strip()]
    except (ValueError, UnicodeError) as error:
        raise ValueError('invalid Go JSON stream') from error
    if not rows or any(type(row) is not dict or row.get('Package') != PACKAGE for row in rows):
        raise ValueError('missing/unexpected Go package')
    mutant = phase == 'mutant'
    wanted = {identity:'fail' if mutant and identity.rsplit('/',1)[1] in fault_names else 'pass' for identity in identities}
    parent_action = 'fail' if mutant else 'pass'
    allowed = {parent,*identities}
    runs, endings, package_actions = Counter(), {}, []
    output_by_scope, scopes = {}, []
    for row in rows:
        action,identity = row.get('Action'),row.get('Test')
        if action not in ('start','run','output','pass','fail'):
            raise ValueError('skipped/unexpected Go event')
        if identity is not None:
            if identity not in allowed:
                raise ValueError('unexpected native test identity')
            if action == 'run': runs[identity] += 1
            elif action in ('pass','fail'):
                if identity in endings: raise ValueError('duplicate native terminal')
                endings[identity] = action
        elif action != 'output': package_actions.append(action)
        if action == 'output':
            payload = row.get('Output')
            if type(payload) is not str:
                raise ValueError('missing native output payload')
            frame = payload.startswith(('=== RUN   ','--- PASS: ','--- FAIL: ','PASS\n','FAIL\n','ok  \t','FAIL\t'))
            diagnostic = re.match(r'[ \t]+'+re.escape(filename)+r':[1-9][0-9]*: (?:missing-bootstrap-batch |missing-handshake-apphash-guard )', payload) is not None
            kind = 'frame' if frame else 'error' if diagnostic else ''
            if 'OutputType' in row and row['OutputType'] != kind:
                raise ValueError('unexpected native OutputType')
            if not scopes or scopes[-1] != identity: scopes.append(identity)
            output_by_scope[identity] = output_by_scope.get(identity,'') + payload
    if runs != Counter({name:1 for name in allowed}) or endings != {**wanted,parent:parent_action}:
        raise ValueError('missing/duplicate/wrong native test outcome')
    if package_actions != ['start',parent_action] or returncode != int(mutant):
        raise ValueError('wrong package outcome/return code')
    if scopes != [parent,*identities,parent,None]:
        raise ValueError('unexpected native output ordering/scopes')
    duration = r'[0-9]+(?:\.[0-9]+)?s'
    parent_lines = output_by_scope[parent].splitlines(keepends=True)
    expected_parent = ['=== RUN   '+parent+'\n']
    if (len(parent_lines) != 2 or parent_lines[:1] != expected_parent or
            not re.fullmatch('--- '+parent_action.upper()+': '+parent+r' \('+duration+r'\)\n', parent_lines[1])):
        raise ValueError('unexpected parent output diagnostic/frame')
    for name,identity in zip(names,identities):
        lines = output_by_scope[identity].splitlines(keepends=True)
        failed = wanted[identity] == 'fail'
        if len(lines) != (4 if failed else 3) or lines[0] != '=== RUN   '+identity+'\n':
            raise ValueError('missing/extra native output diagnostics or frames')
        match = re.fullmatch(r'[ \t]+'+re.escape(filename)+r':[1-9][0-9]*: receipt=(.+)\n', lines[1])
        if not match:
            raise ValueError('wrong native receipt diagnostic')
        try:
            data = json.loads(match[1], object_pairs_hook=COMET.EXECUTION.unique_object)
            (require_handshake_receipt if scenario=='handshake' else require_receipt)(data,name,failed)
        except (ValueError,TypeError,KeyError,AttributeError) as error:
            raise ValueError('invalid native receipt: '+str(error)) from error
        if failed:
            origin = name.startswith('origin-')
            message = 'missing-bootstrap-batch id='+('origin-base state=absent validators=3,4 params=3' if origin else 'current-base state=absent validators=4,5,6 params=5')
            if scenario=='handshake': message='missing-handshake-apphash-guard id='+name+' expected=panic got=success'
            if not re.fullmatch(r'[ \t]+'+re.escape(filename)+r':[1-9][0-9]*: '+re.escape(message+'\n'),lines[2]):
                raise ValueError('wrong native missing Bootstrap batch diagnostic')
        if not re.fullmatch('--- '+wanted[identity].upper()+': '+re.escape(identity)+r' \('+duration+r'\)\n',lines[-1]):
            raise ValueError('wrong native leaf terminal frame')
    package = output_by_scope[None]
    pattern = ('FAIL\nFAIL\t' if mutant else 'PASS\nok  \t')+re.escape(PACKAGE)+r'\t'+duration+r'\n'
    if not re.fullmatch(pattern,package):
        raise ValueError('unexpected package output diagnostic/frame')
    return wanted


def inputs():
    old_pins,manifest,watched = BOOT.inputs()
    pins_path = ROOT/'comet_restart/pins.json'
    pins = json.loads(pins_path.read_bytes(), object_pairs_hook=COMET.EXECUTION.unique_object)
    if (pins.get('schema') != 'etna-comet-restart-pins-1' or pins.get('source') != old_pins['source']
            or pins.get('receipt') != old_pins['receipt'] or pins.get('expectedSubtests') != list(NAMES)
            or pins.get('handshakeSubtests') != list(HANDSHAKE_NAMES)):
        raise ValueError('wrong restart pins/source/receipt/native identities')
    for relative,value in pins['inputsSha256'].items():
        if COMET.digest((ROOT/relative).read_bytes()) != value:
            raise ValueError('wrong frozen restart build input bytes: '+relative)
    fixture=json.loads((ROOT/'comet_restart/handshake_observations.json').read_bytes(),
                       object_pairs_hook=COMET.EXECUTION.unique_object)
    if (fixture.get('sourceCommit')!=pins['source']['commit']
            or fixture.get('receiptSha256')!=pins['receipt']['sha256']
            or set(fixture.get('cases',{}))!=set(HANDSHAKE_NAMES)):
        raise ValueError('wrong handshake observation provenance/case identities')
    watched.update({p:COMET.digest(p.read_bytes()) for p in [Path(__file__),ROOT/'tests/test_comet_restart.py',
                    ROOT/'COMET_RESTART.md',*(p for p in (ROOT/'comet_restart').iterdir() if p.is_file())]})
    return pins,manifest,watched


def private_fault(source,destination,manifest,scenario='persistence'):
    fault_path,before,after=fault_selector(scenario)
    shutil.copytree(source,destination)
    path = destination/fault_path
    text = path.read_text()
    if text.count(before) != 1:
        raise ValueError('upstream source fault selector does not match exactly once')
    path.chmod(0o644)
    path.write_text(text.replace(before,after))
    mutant = json.loads(json.dumps(manifest))
    mutant['files'][fault_path] = COMET.file_entry(path.read_bytes())
    return mutant


def restore_source(private,original,manifest,commit,scenario='persistence'):
    fault_path,before,after=fault_selector(scenario)
    raw = (original/fault_path).read_bytes()
    path = private/fault_path
    if path.read_bytes() != raw.decode().replace(before,after).encode() or path.read_bytes() == raw:
        raise ValueError('exact faulted source was not present before restoration')
    path.write_bytes(raw)
    return COMET.verify_snapshot(private,manifest,commit)


def run_trial(phase,source,manifest,args,pins,tool_hashes,watched):
    BOOT.require_stable(watched,'adapter/receipt/provenance inputs')
    before = COMET.verify_snapshot(source,manifest,pins['source']['commit'])
    trial = args.output/phase
    work = trial/'work'; (work/'build').mkdir(parents=True)
    build_inputs = trial/'inputs'; build_inputs.mkdir()
    extra_sources=[ROOT/'comet_restart/handshake_test.go'] if args.scenario=='handshake' else []
    for source_path in [*extra_sources,ROOT/'comet_restart/restart_test.go',ROOT/'comet_restart/go.mod',ROOT/'comet_restart/go.sum',
                        ROOT/'comet_bootstrap/bootstrap_test.go',ROOT/'comet_bootstrap/mapping_vectors.json']:
        (build_inputs/source_path.name).write_bytes(source_path.read_bytes())
    # The original F04 helpers are copied verbatim, never edited or regenerated.
    modfiles = trial/'modfiles'; modfiles.mkdir()
    (modfiles/'go.mod').write_bytes((ROOT/'comet_restart/go.mod').read_bytes()+b'\nreplace github.com/cometbft/cometbft => /tmp/upstream\n')
    (modfiles/'go.sum').write_bytes((ROOT/'comet_restart/go.sum').read_bytes())
    executed = {p:COMET.digest(p.read_bytes()) for p in [*build_inputs.iterdir(),*modfiles.iterdir()]}
    command = [sys.executable,'-B',str(ROOT/'run_isolated.py')]
    for flag,binding in [('read',str(build_inputs)+'=/tmp/replay'),('read',str(ROOT/pins['receipt']['file'])+'=/tmp/receipt.json'),
                         ('read',str(source)+'=/tmp/upstream'),('read',str(modfiles)+'=/tmp/modfiles'),
                         ('read',str(args.go_root)+'=/tmp/go'),('read',str(args.module_cache)+'=/tmp/gomodcache'),
                         ('write',str(args.build_cache)+'=/tmp/gocache'),('write',str(work)+'=/tmp/output')]:
        command += ['--'+flag+'-bind',binding]
    command += ['--cwd','/tmp/replay','--timeout',str(args.timeout)]
    environment = {'GOROOT':'/tmp/go','GOMODCACHE':'/tmp/gomodcache','GOCACHE':'/tmp/gocache','GOPATH':'/tmp/gopath',
                   'GOTMPDIR':'/tmp/output/build','GOENV':'off','GOTOOLCHAIN':'local','GOPROXY':'off','GOSUMDB':'off',
                   'GOVCS':'*:off','GOWORK':'off','CGO_ENABLED':'0','GOTELEMETRY':'off','GOMAXPROCS':'2',
                   'ETNA_CHECKPOINT_IMPORT_FIXTURE':'/tmp/receipt.json','ETNA_CHECKPOINT_IMPORT_SHA256':pins['receipt']['sha256'],
                   'ETNA_RESTART_OUTPUT':'/tmp/output'}
    for key,value in environment.items(): command += ['--env',key+'='+value]
    parent,_ = SCENARIOS[args.scenario]
    command += ['--','/tmp/go/bin/go','test','-json','-count=1','-parallel=1','-p=2','-mod=readonly',
                '-modfile=/tmp/modfiles/go.mod','-timeout=90s','-run=^'+parent+'$','.']
    started = time.monotonic()
    result = COMET.EXECUTION.execute(command,ROOT,args.timeout+10)
    combined = result['output'].encode('utf-8')
    (trial/'combined.log').write_bytes(combined)
    report = dict(phase=phase,scenario=args.scenario,sourceRoot=str(source),command=command,supervisorCommand=result['supervisor_argv'],
                  returncode=result['returncode'],timedOut=result['timeout'],elapsedSeconds=round(time.monotonic()-started,3),
                  combinedOutputFile='combined.log',combinedOutputSha256=COMET.digest(combined),streamsCombined=True,
                  outputDecoding='utf-8-errors-replace',storedEncoding='utf-8-reencoded-text',sourceBefore=before,
                  manifestSha256=COMET.digest(json.dumps(manifest,sort_keys=True).encode()),toolsSha256=tool_hashes,
                  executedInputsBefore={str(p.relative_to(trial)):h for p,h in executed.items()},
                  reusedF04TestsCompiledOnly=True,selectedParent=parent)
    record = trial/'execution.json'; record.write_text(json.dumps(report,sort_keys=True,indent=2)+'\n')
    if result['returncode'] == 125:
        raise ValueError('supervisor initialization or descendant cleanup failed (125)')
    if result['timeout']:
        raise ValueError('supervisor reported execution timeout')
    BOOT.require_stable(executed,'executed private build inputs/modfiles')
    report['executedInputsAfter'] = {str(p.relative_to(trial)):COMET.digest(p.read_bytes()) for p in executed}
    report['outcomes'] = require_go_outcomes(combined,result['returncode'],phase,scenario=args.scenario)
    report['sourceAfter'] = COMET.verify_snapshot(source,manifest,pins['source']['commit'])
    BOOT.require_stable(watched,'adapter/receipt/provenance inputs')
    BOOT.require_stable({args.go_root/p:h for p,h in tool_hashes.items()},'Go toolchain')
    record.write_text(json.dumps(report,sort_keys=True,indent=2)+'\n')
    print(phase+': '+str(len(SCENARIOS[args.scenario][1]))+' exact '+args.scenario+' outcomes verified',flush=True)
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('source','go-root','module-cache','build-cache','build-lock','output'):
        parser.add_argument('--'+name,type=Path,required=True)
    parser.add_argument('--scenario',choices=SCENARIOS,default='persistence')
    parser.add_argument('--timeout',type=int,default=180)
    args = parser.parse_args(argv)
    try:
        pins,manifest,watched = inputs()
        COMET.validate_layout(args,watched)
        tools = [args.go_root/'bin/go',args.go_root/'VERSION',
                 *(p for name in ('asm','compile','link','vet') for p in sorted((args.go_root/'pkg/tool').glob('*/'+name)))]
        tool_hashes = {str(p.relative_to(args.go_root)):COMET.digest(p.read_bytes()) for p in tools}
        args.build_lock = args.build_lock.resolve()
        with args.build_lock.open('a') as lock:
            COMET.EXECUTION.acquire_lock(lock,min(args.timeout,60))
            COMET.verify_snapshot(args.source,manifest,pins['source']['commit'])
            args.output.mkdir(parents=True)
            fault_path,_,_=fault_selector(args.scenario)
            private = args.output/'private-upstream-fault'
            mutant_manifest = private_fault(args.source,private,manifest,scenario=args.scenario)
            (args.output/'mutant-manifest.json').write_text(json.dumps(mutant_manifest,sort_keys=True,indent=2)+'\n')
            (args.output/('mutant-replay.go' if args.scenario=='handshake' else 'mutant-store.go')).write_bytes((private/fault_path).read_bytes())
            reports = [run_trial('mutant',private,mutant_manifest,args,pins,tool_hashes,watched),
                       run_trial('normal',args.source,manifest,args,pins,tool_hashes,watched)]
            restored = restore_source(private,args.source,manifest,pins['source']['commit'],scenario=args.scenario)
            reports.append(run_trial('restored',private,manifest,args,pins,tool_hashes,watched))
            BOOT.require_stable(watched,'adapter/receipt/provenance inputs')
            BOOT.require_stable({args.go_root/p:h for p,h in tool_hashes.items()},'Go toolchain')
            summary = dict(schema='etna-comet-restart-execution-1',status='PASS',scenario=args.scenario,
                sourceCommit=pins['source']['commit'],sourceVerifiedAfter=COMET.verify_snapshot(args.source,manifest,pins['source']['commit']),
                actualRestoredSource=restored,samePrivateSourceRestored=reports[0]['sourceRoot']==reports[2]['sourceRoot'],
                goToolchainVersion=(args.go_root/'VERSION').read_text().strip(),
                inputSha256={str(p.relative_to(ROOT.parent)):h for p,h in watched.items()},reports=reports,
                fault=dict(path=fault_path,originalSha256=manifest['files'][fault_path]['sha256'],mutantSha256=mutant_manifest['files'][fault_path]['sha256']),
                boundaries=['Selected actual GoLevelDB Bootstrap completed-write ACK, owned writer SIGKILL without Close, distinct reader PID same directory',
                            'Clean Close/reopen baseline; unmodified frozen F03/F04 public-point/literal field and independent row oracle',
                            'Process restart only; no power-loss, multi-store atomicity, Etna importer, App/EL, signing, node, WAL or committee authentication'] if args.scenario=='persistence' else ['Actual exported HandshakeWithContext over real state/block stores and explicit mock ABCI responses', 'Selected height/AppHash/error/panic/replay-call branches; unsigned structural block storage fixtures only', 'Known CONS-3.1-9/Q3.1-8 high-initial-height expected stop; no repair procedure or newly discovered protocol defect', 'No real EL/STF, signed history, node/P2P, WAL, power-loss or multi-store atomicity'])
            (args.output/'summary.json').write_text(json.dumps(summary,sort_keys=True,indent=2)+'\n')
            print('PASS: stock '+args.scenario+' scenario; exact source fault and same-copy restoration')
    except (OSError,ValueError,subprocess.SubprocessError) as error:
        print('Comet '+args.scenario+' scenario failed: '+str(error),file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__': raise SystemExit(main())
