#!/usr/bin/env python3
"""Record selected stock Bootstrap serialization, exact missing-row fault and restoration.

No fetching, node startup, signing, Etna importer or power-loss experiment.
"""
import argparse
from collections import Counter
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location('etna_bootstrap_shared_comet', ROOT / 'run_comet.py')
COMET = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(COMET)
PACKAGE = 'example.org/etna-comet-bootstrap'
PARENT = 'TestCheckpointBootstrap'
NAMES = ('origin-base', 'origin-landed-alternate', 'current-base',
         'current-first-alternate', 'current-second-alternate',
         'last-validator-lookup', 'observer-controls')
IDENTITIES = tuple(PARENT + '/' + name for name in NAMES)
FAULT_PATH = 'state/store.go'
FAULT_BEFORE = '''\tif height > 1 && !state.LastValidators.IsNilOrEmpty() {
\t\tif err := store.saveValidatorsInfo(height-1, height-1, state.LastValidators, batch); err != nil {
\t\t\treturn err
\t\t}
\t}
'''
FAULT_AFTER = '\t// Private conformance fault: omit only Bootstrap LastValidators row.\n'


def require_mutant_evidence(rows):
    """Admit only this fixed experiment's entire native output sequence.

    Parent/package FAIL terminals already follow from the intended child fault;
    they cannot distinguish an additional cleanup/setup diagnostic. Validate all
    output channels, with or without Go's optional OutputType metadata.
    """
    duration = r'[0-9]+(?:\.[0-9]+)?s'
    expected = [(PARENT, re.escape('=== RUN   ' + PARENT + '\n'), 'frame')]
    for name in NAMES:
        identity = PARENT + '/' + name
        expected.append((identity, re.escape('=== RUN   ' + identity + '\n'), 'frame'))
        fault = name == 'last-validator-lookup'
        if fault:
            for case in NAMES[2:5]:
                message = ('missing-bootstrap-last id=' + case +
                           ' height=4 typed=ErrNoValSetForHeight nilset=true row=absent serialized-last=preserved')
                expected.append((identity, r'[ \t]+bootstrap_test\.go:[1-9][0-9]*: ' +
                                 re.escape(message + '\n'), 'error'))
        action = 'FAIL' if fault else 'PASS'
        expected.append((identity, re.escape('--- ' + action + ': ' + identity) +
                         r' \(' + duration + r'\)\n', 'frame'))
    expected.extend([
        (PARENT, re.escape('--- FAIL: ' + PARENT) + r' \(' + duration + r'\)\n', 'frame'),
        (None, re.escape('FAIL\n'), 'frame'),
        (None, re.escape('FAIL\t' + PACKAGE + '\t') + duration + r'\n', 'frame'),
    ])
    outputs = [row for row in rows if row.get('Action') == 'output']
    if len(outputs) != len(expected):
        raise ValueError('missing/extra native output diagnostics or frames')
    for row, (identity, pattern, output_type) in zip(outputs, expected):
        payload = row.get('Output')
        if (row.get('Test') != identity or not isinstance(payload, str)
                or not re.fullmatch(pattern, payload)
                or ('OutputType' in row and row['OutputType'] != output_type)):
            raise ValueError('unexpected native output diagnostic, frame or OutputType')


def require_go_outcomes(raw, returncode, phase):
    if phase not in ('normal', 'mutant', 'restored'):
        raise ValueError('unknown execution phase')
    try:
        rows = [json.loads(line, object_pairs_hook=COMET.EXECUTION.unique_object)
                for line in raw.decode().splitlines() if line.strip()]
    except (ValueError, UnicodeError) as error:
        raise ValueError('invalid Go JSON stream') from error
    if not rows or any(type(row) is not dict or row.get('Package') != PACKAGE for row in rows):
        raise ValueError('missing or unexpected Go package')
    wanted = {identity: 'fail' if phase == 'mutant' and identity.endswith('/last-validator-lookup') else 'pass'
              for identity in IDENTITIES}
    parent_action = 'fail' if phase == 'mutant' else 'pass'
    allowed = set(IDENTITIES) | {PARENT}
    runs, endings, package_actions = Counter(), {}, []
    for row in rows:
        action, identity = row.get('Action'), row.get('Test')
        if action not in ('start', 'run', 'output', 'pass', 'fail'):
            raise ValueError('skipped or unexpected Go event')
        if identity:
            if identity not in allowed:
                raise ValueError('unexpected test identity')
            if action == 'run':
                runs[identity] += 1
            elif action in ('pass', 'fail'):
                if identity in endings:
                    raise ValueError('duplicate terminal test outcome')
                endings[identity] = action
        elif action != 'output':
            package_actions.append(action)
    if runs != Counter({name: 1 for name in allowed}) or endings != {**wanted, PARENT: parent_action}:
        raise ValueError('missing, duplicate or wrong test outcome')
    if package_actions != ['start', parent_action] or returncode != int(phase == 'mutant'):
        raise ValueError('wrong package outcome or command return code')
    if phase == 'mutant':
        require_mutant_evidence(rows)
    return wanted


def load_receipt(path, pins):
    # Reuse F03's actual external-JSON boundary before any lossy parsing.
    exporter = COMET.load_module('etna_bootstrap_import_receipt', ROOT / 'export_checkpoint_import.py')
    data = exporter.load_fixture(path)
    if COMET.digest(Path(path).read_bytes()) != pins['receipt']['sha256']:
        raise ValueError('wrong frozen receipt bytes')
    exporter.validate(data)
    return exporter


def inputs():
    pins = json.loads((ROOT / 'comet-bootstrap-pins.json').read_bytes())
    if pins.get('schema') != 'etna-comet-bootstrap-pins-1' or pins.get('expectedSubtests') != list(NAMES):
        raise ValueError('wrong Bootstrap pin/schema/native identities')
    for relative, expected in pins['inputsSha256'].items():
        if COMET.digest((ROOT / relative).read_bytes()) != expected:
            raise ValueError('wrong pinned input bytes: ' + relative)
    source_pins = json.loads((ROOT / 'comet-pins.json').read_bytes())
    manifest = json.loads((ROOT / 'manifests/comet.json').read_bytes())
    if (source_pins.get('schema') != 'etna-comet-conformance-pins-1'
            or pins['source'] != source_pins['source']
            or COMET.digest((ROOT / 'manifests/comet.json').read_bytes()) != pins['source']['manifestSha256']):
        raise ValueError('wrong existing Comet source pin/manifest')
    exporter = load_receipt(ROOT / pins['receipt']['file'], pins)
    watched = {ROOT / relative for relative in pins['inputsSha256']}
    watched.update(exporter.INPUTS)
    watched.update([Path(__file__), ROOT / 'run_comet.py', ROOT / 'run_isolated.py',
                    ROOT / 'run_baseline.py', COMET.EXECUTION_PATH,
                    ROOT / 'comet-bootstrap-pins.json', ROOT / 'tests/test_comet_bootstrap.py',
                    ROOT / 'tests/fixtures/comet-bootstrap-mutant.jsonl'])
    watched.update(p for p in (ROOT / 'comet_bootstrap').iterdir() if p.is_file())
    return pins, manifest, {p: COMET.digest(p.read_bytes()) for p in watched}


def require_stable(watched, label):
    try:
        if any(COMET.digest(path.read_bytes()) != value for path, value in watched.items()):
            raise ValueError(label + ' changed')
    except OSError as error:
        raise ValueError(label + ' changed or disappeared') from error


def private_fault(source, destination, manifest):
    shutil.copytree(source, destination)
    path = destination / FAULT_PATH
    text = path.read_text()
    if text.count(FAULT_BEFORE) != 1:
        raise ValueError('upstream Bootstrap fault selector does not match exactly once')
    path.chmod(0o644)
    path.write_text(text.replace(FAULT_BEFORE, FAULT_AFTER))
    mutant = json.loads(json.dumps(manifest))
    mutant['files'][FAULT_PATH] = COMET.file_entry(path.read_bytes())
    return mutant


def restore_source(private, original, manifest, commit):
    path, raw = private / FAULT_PATH, (original / FAULT_PATH).read_bytes()
    expected_fault = raw.decode().replace(FAULT_BEFORE, FAULT_AFTER).encode()
    if path.read_bytes() != expected_fault or path.read_bytes() == raw:
        raise ValueError('exact faulted source was not present before restoration')
    path.write_bytes(raw)
    return COMET.verify_snapshot(private, manifest, commit)


def run_trial(phase, source, manifest, args, pins, tool_hashes, watched):
    require_stable(watched, 'adapter/receipt/provenance inputs')
    before = COMET.verify_snapshot(source, manifest, pins['source']['commit'])
    trial = args.output / phase
    work = trial / 'work'
    work.mkdir(parents=True)
    (work / 'build').mkdir()
    modfiles = trial / 'modfiles'
    modfiles.mkdir()
    (modfiles / 'go.mod').write_bytes((ROOT / 'comet_bootstrap/go.mod').read_bytes() +
                                b'\nreplace github.com/cometbft/cometbft => /tmp/upstream\n')
    (modfiles / 'go.sum').write_bytes((ROOT / 'comet_bootstrap/go.sum').read_bytes())
    executed_inputs = {p: COMET.digest(p.read_bytes()) for p in (modfiles / 'go.mod', modfiles / 'go.sum')}
    command = [sys.executable, '-B', str(ROOT / 'run_isolated.py')]
    for flag, binding in [('read', str(ROOT / 'comet_bootstrap') + '=/tmp/replay'),
                          ('read', str(ROOT / pins.get('receipt', {}).get('file', 'checkpoint_import_cases.json')) + '=/tmp/receipt.json'),
                          ('read', str(source) + '=/tmp/upstream'), ('read', str(modfiles) + '=/tmp/modfiles'),
                          ('read', str(args.go_root) + '=/tmp/go'),
                          ('read', str(args.module_cache) + '=/tmp/gomodcache'),
                          ('write', str(args.build_cache) + '=/tmp/gocache'), ('write', str(work) + '=/tmp/output')]:
        command += ['--' + flag + '-bind', binding]
    command += ['--cwd', '/tmp/replay', '--timeout', str(args.timeout)]
    environment = {'GOROOT': '/tmp/go', 'GOMODCACHE': '/tmp/gomodcache', 'GOCACHE': '/tmp/gocache',
                   'GOPATH': '/tmp/gopath', 'GOTMPDIR': '/tmp/output/build', 'GOENV': 'off', 'GOTOOLCHAIN': 'local',
                   'GOPROXY': 'off', 'GOSUMDB': 'off', 'GOVCS': '*:off', 'GOWORK': 'off', 'CGO_ENABLED': '0',
                   'GOTELEMETRY': 'off', 'GOMAXPROCS': '2', 'ETNA_CHECKPOINT_IMPORT_FIXTURE': '/tmp/receipt.json',
                   'ETNA_CHECKPOINT_IMPORT_SHA256': pins.get('receipt', {}).get('sha256', '')}
    for key, value in environment.items():
        command += ['--env', key + '=' + value]
    command += ['--', '/tmp/go/bin/go', 'test', '-json', '-count=1', '-parallel=1', '-p=2',
                '-mod=readonly', '-modfile=/tmp/modfiles/go.mod', '-timeout=90s', './...']
    start = time.monotonic()
    result = COMET.EXECUTION.execute(command, ROOT, args.timeout + 10)
    combined = result['output'].encode('utf-8')
    (trial / 'combined.log').write_bytes(combined)
    report = {'phase': phase, 'sourceRoot': str(source), 'command': command,
              'supervisorCommand': result['supervisor_argv'], 'returncode': result['returncode'],
              'timedOut': result['timeout'], 'elapsedSeconds': round(time.monotonic() - start, 3),
              'combinedOutputFile': 'combined.log', 'combinedOutputSha256': COMET.digest(combined),
              'streamsCombined': True, 'outputDecoding': 'utf-8-errors-replace', 'storedEncoding': 'utf-8-reencoded-text',
              'sourceBefore': before, 'manifestSha256': COMET.digest(json.dumps(manifest, sort_keys=True).encode()),
              'toolsSha256': tool_hashes,
              'executedModfileSha256': executed_inputs[modfiles / 'go.mod'],
              'executedSumSha256': executed_inputs[modfiles / 'go.sum'],
              'executedInputsBefore': {p.name: h for p,h in executed_inputs.items()}}
    record = trial / 'execution.json'
    record.write_text(json.dumps(report, sort_keys=True, indent=2) + '\n')
    if result['returncode'] == 125:
        raise ValueError('supervisor initialization or descendant cleanup failed (125)')
    require_stable(executed_inputs, 'executed modfile/sum')
    report['executedInputsAfter'] = {p.name: COMET.digest(p.read_bytes()) for p in executed_inputs}
    report['outcomes'] = require_go_outcomes(combined, result['returncode'], phase)
    report['missingLastRowSemanticsVerified'] = phase == 'mutant'
    report['sourceAfter'] = COMET.verify_snapshot(source, manifest, pins['source']['commit'])
    require_stable(watched, 'adapter/receipt/provenance inputs')
    require_stable({args.go_root / p: h for p,h in tool_hashes.items()}, 'Go toolchain')
    record.write_text(json.dumps(report, sort_keys=True, indent=2) + '\n')
    print(phase + ': seven exact Bootstrap test outcomes verified', flush=True)
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('source', 'go-root', 'module-cache', 'build-cache', 'build-lock', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args(argv)
    try:
        pins, manifest, watched = inputs()
        COMET.validate_layout(args, watched)
        tools = [args.go_root / 'bin/go', args.go_root / 'VERSION',
                 *(p for name in ('asm', 'compile', 'link', 'vet') for p in sorted((args.go_root / 'pkg/tool').glob('*/' + name)))]
        tool_hashes = {str(p.relative_to(args.go_root)): COMET.digest(p.read_bytes()) for p in tools}
        args.build_lock = args.build_lock.resolve()
        with args.build_lock.open('a') as lock:
            COMET.EXECUTION.acquire_lock(lock, min(args.timeout, 60))
            COMET.verify_snapshot(args.source, manifest, pins['source']['commit'])
            args.output.mkdir(parents=True)
            private = args.output / 'private-upstream-fault'
            mutant_manifest = private_fault(args.source, private, manifest)
            (args.output / 'mutant-manifest.json').write_text(json.dumps(mutant_manifest, sort_keys=True, indent=2) + '\n')
            (args.output / 'mutant-store.go').write_bytes((private / FAULT_PATH).read_bytes())
            reports = [run_trial('mutant', private, mutant_manifest, args, pins, tool_hashes, watched),
                       run_trial('normal', args.source, manifest, args, pins, tool_hashes, watched)]
            restored = restore_source(private, args.source, manifest, pins['source']['commit'])
            reports.append(run_trial('restored', private, manifest, args, pins, tool_hashes, watched))
            require_stable(watched, 'adapter/receipt/provenance inputs')
            require_stable({args.go_root / p: h for p,h in tool_hashes.items()}, 'Go toolchain')
            summary = {'schema': 'etna-comet-bootstrap-execution-1', 'status': 'PASS',
                       'sourceCommit': pins['source']['commit'], 'sourceVerifiedAfter': COMET.verify_snapshot(args.source, manifest, pins['source']['commit']),
                       'actualRestoredSource': restored, 'samePrivateSourceRestored': reports[0]['sourceRoot'] == reports[2]['sourceRoot'],
                       'goToolchainVersion': (args.go_root / 'VERSION').read_text().strip(),
                       'inputSha256': {str(p.relative_to(ROOT.parent)): h for p,h in watched.items()},
                       'reports': reports, 'fault': {'path': FAULT_PATH, 'originalSha256': manifest['files'][FAULT_PATH]['sha256'],
                                                  'mutantSha256': mutant_manifest['files'][FAULT_PATH]['sha256']},
                       'boundaries': ['Selected stock Bootstrap/Load/validator/params serialization; fresh MemDB and reopened wrapper',
                                      'Actual F03 symbolic publication receipts; explicit public-point/opaque-hash/params/version premises',
                                      'No concrete Etna importer, signatures/commit admission, EL/STF/archive/committee history or power-loss durability']}
            (args.output / 'summary.json').write_text(json.dumps(summary, sort_keys=True, indent=2) + '\n')
            print('PASS: selected stock Bootstrap/store replay; exact source fault and actual restoration')
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print('Bootstrap replay failed: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
