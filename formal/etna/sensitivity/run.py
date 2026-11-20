#!/usr/bin/env python3
"""Execute a reviewed finite fault inventory; runtime paths are supplied externally."""
import argparse
from contextlib import nullcontext
import fcntl
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time

SCHEMA = 'etna-fault-campaign-1'
IDENTIFIER = re.compile(r'[A-Za-z_][A-Za-z_0-9]*\Z')
STATS = re.compile(r'([\d,]+) states generated, ([\d,]+) distinct states found, ([\d,]+) states left on queue\.')
VIOLATION = re.compile(r'^Error: Invariant (\w+) is violated\.$', re.M)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate JSON key: ' + key)
        result[key] = value
    return result


def read_json(path):
    return json.loads(Path(path).read_text(), object_pairs_hook=unique_object)


def safe_relative(value):
    path = PurePosixPath(value)
    if (not isinstance(value, str) or not value or path.is_absolute() or
            any(x in ('', '.', '..', '.git') for x in value.split('/'))):
        raise ValueError('unsafe relative path: ' + str(value))
    return path


def replace_once(text, old, new):
    if not old or old == new or text.count(old) != 1:
        raise ValueError('replacement must change exactly one unique target')
    return text.replace(old, new, 1)


def load_manifest(path):
    manifest = read_json(path)
    if manifest.get('schema') != SCHEMA or not isinstance(manifest.get('obligations'), list):
        raise ValueError('invalid campaign schema/inventory')
    ids = set()
    for item in manifest['obligations']:
        name = item.get('id', '')
        if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', name) or name in ids:
            raise ValueError('missing/duplicate/unsafe obligation id')
        ids.add(name)
        if item.get('unassessed_reason'):
            continue
        if item.get('engine') not in ('tlc', 'forge') or item.get('source') not in ('formal', 'contracts'):
            raise ValueError('unknown engine/source')
        if not isinstance(item.get('required'), bool):
            raise ValueError('required must be explicit')
        safe_relative(item['path'])
        replacement = item['replace']
        if not isinstance(replacement.get('old'), str) or not replacement['old'] or not isinstance(replacement.get('new'), str) or replacement['old'] == replacement['new']:
            raise ValueError('invalid exact replacement')
        workloads = item.get('workloads', [])
        if not workloads or len(workloads) != len(set(workloads)):
            raise ValueError('missing/duplicate workload targets')
        failure = item['failure']
        if item['engine'] == 'tlc':
            for workload in workloads:
                safe_relative(workload)
                if not workload.endswith('.cfg'): raise ValueError('TLC target must be .cfg')
            if failure.get('kind') not in ('invariant', 'property') or not IDENTIFIER.fullmatch(failure.get('name', '')):
                raise ValueError('TLC failure needs a named invariant/property')
        else:
            if failure.get('kind') != 'forge' or not failure.get('failures'):
                raise ValueError('Forge needs exact failing test identities/reasons')
            if not set(failure['failures']).issubset(workloads) or any(not isinstance(x, str) or not x for x in failure['failures'].values()):
                raise ValueError('failure test outside workload or missing reason')
    return manifest


def properties(config_text):
    # Config sections terminate a PROPERTY/PROPERTIES list. Strip TLA line comments.
    tokens = re.sub(r'\\\*[^\n]*', '', config_text).split()
    sections = {'SPECIFICATION', 'INIT', 'NEXT', 'INVARIANT', 'INVARIANTS', 'PROPERTY', 'PROPERTIES', 'CONSTANT', 'CONSTANTS', 'CONSTRAINT', 'CONSTRAINTS', 'ACTION_CONSTRAINT', 'ACTION_CONSTRAINTS', 'SYMMETRY', 'VIEW', 'CHECK_DEADLOCK', 'ALIAS', 'POSTCONDITION'}
    result = []
    active = False
    for token in tokens:
        if token in sections:
            active = token in ('PROPERTY', 'PROPERTIES')
        elif active:
            result.append(token)
    return result


def classify_tlc(returncode, output, failure, normal='PASS', config_text=''):
    counts = list(STATS.finditer(output))
    if not counts or int(counts[-1][2].replace(',', '')) < 1 or returncode in (124, 125, 126, 127):
        return 'INCONCLUSIVE'
    if re.search(r'(?:parsing|semantic) errors?|Exception|OutOfMemoryError|ISOLATED COMMAND TIMEOUT', output, re.I):
        return 'INCONCLUSIVE'
    errors = [line for line in re.findall(r'^Error:.*$', output, re.M) if line not in ('Error: The behavior up to this point is:', 'Error: The following behavior constitutes a counter-example:')]
    violations = VIOLATION.findall(output)
    if returncode == 0 and not errors and 'Model checking completed. No error has been found.' in output and counts[-1][3].replace(',', '') == '0' and normal == 'PASS':
        return 'SURVIVED'
    if returncode == 12 and errors == ['Error: Invariant ' + normal + ' is violated.'] and violations == [normal] and normal != 'PASS':
        return 'SURVIVED'
    if returncode == 12 and failure.get('kind') == 'invariant' and violations == [failure.get('name')] and errors == ['Error: Invariant ' + failure['name'] + ' is violated.']:
        return 'KILLED'
    if returncode == 13 and failure.get('kind') == 'property' and properties(config_text) == [failure.get('name')] and errors == ['Error: Temporal properties were violated.']:
        return 'KILLED'
    return 'INCONCLUSIVE'


def forge_rows(output):
    data = json.loads(output, object_pairs_hook=unique_object)
    rows = {}
    for suite, result in data.items():
        for test, details in result['test_results'].items():
            identity = suite + '::' + test
            if identity in rows:
                raise ValueError('duplicate full Forge test identity')
            rows[identity] = details
    return rows


def classify_forge(returncode, output, test_ids, failure):
    try:
        rows = forge_rows(output)
        if not test_ids or len(test_ids) != len(set(test_ids)) or set(rows) != set(test_ids):
            return 'INCONCLUSIVE'
        if returncode == 0 and all(row['status'] == 'Success' for row in rows.values()):
            return 'SURVIVED'
        failed = {key: row.get('reason') for key, row in rows.items() if row['status'] == 'Failure'}
        if returncode == 1 and failed and failed == failure.get('failures') and all(row['status'] in ('Success', 'Failure') for row in rows.values()):
            return 'KILLED'
    except (ValueError, KeyError, TypeError, AttributeError):
        pass
    return 'INCONCLUSIVE'


def trial_status(baseline, mutated, restored, stable):
    if (not stable or not baseline or len(baseline) != len(mutated) or len(baseline) != len(restored)
            or any(x != 'SURVIVED' for x in baseline + restored) or any(x not in ('KILLED', 'SURVIVED') for x in mutated)):
        return 'INCONCLUSIVE'
    return 'KILLED' if 'KILLED' in mutated else 'SURVIVED'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def snapshot(root):
    root = Path(root)
    result = {}
    for path in sorted(root.rglob('*')):
        if any(x in ('.git', '__pycache__') for x in path.relative_to(root).parts): continue
        if path.is_symlink():
            if not path.resolve().is_relative_to(root.resolve()):
                raise ValueError('snapshot symlink escapes source root: ' + str(path))
            result[str(path.relative_to(root))] = {'symlink': os.readlink(path)}
            continue
        if path.is_file(): result[str(path.relative_to(root))] = sha(path)
    return result


def _children(pid):
    try:
        return [int(value) for value in Path(f'/proc/{pid}/task/{pid}/children').read_text().split()]
    except FileNotFoundError:
        return []


def _cleanup_descendants(timeout=5):
    """Own supervisor only: freeze descendants, kill by pidfd, reap adopted orphans."""
    deadline = time.monotonic() + timeout
    handles = {}
    try:
        while True:
            pending = _children(os.getpid())
            while pending:
                pid = pending.pop()
                if pid in handles:
                    try: signal.pidfd_send_signal(handles[pid], 0)
                    except ProcessLookupError:
                        os.close(handles.pop(pid))
                if pid not in handles:
                    fd = None
                    try:
                        fd = os.pidfd_open(pid)
                        # pidfd pins identity; confirm ancestry before signalling anything.
                        status = Path(f'/proc/{pid}/status').read_text()
                        parent = int(re.search(r'^PPid:\s+(\d+)', status, re.M)[1])
                        if parent in handles:
                            try: signal.pidfd_send_signal(handles[parent], 0)
                            except ProcessLookupError: parent = -1
                        if parent != os.getpid() and parent not in handles:
                            os.close(fd)
                            continue
                        handles[pid] = fd
                        signal.pidfd_send_signal(fd, signal.SIGSTOP)
                    except (ProcessLookupError, FileNotFoundError):
                        if fd is not None and pid not in handles: os.close(fd)
                        continue
                pending.extend(_children(pid))
            for fd in handles.values():
                try: signal.pidfd_send_signal(fd, signal.SIGKILL)
                except ProcessLookupError: pass
            while True:
                try:
                    if os.waitpid(-1, os.WNOHANG)[0] == 0: break
                except ChildProcessError:
                    return True
            if time.monotonic() >= deadline:
                return False
            time.sleep(.01)
    finally:
        for fd in handles.values(): os.close(fd)


class ExecutionCancelled(BaseException):
    pass


def _interrupted(signum, frame):
    raise ExecutionCancelled('execution terminated')


def supervise(argv):
    """Private Linux subreaper scopes adopted children to this one command."""
    import ctypes
    def interrupted(signum, frame):
        raise InterruptedError('command interrupted')
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    libc = ctypes.CDLL(None, use_errno=True)
    if not hasattr(os, 'pidfd_open') or not hasattr(signal, 'pidfd_send_signal') or libc.prctl(36, 1, 0, 0, 0) != 0:
        return 125
    signal.signal(signal.SIGTERM, _interrupted)
    signal.signal(signal.SIGINT, _interrupted)
    # Parent death requests the same cleanup, including when the caller is killed.
    if libc.prctl(1, signal.SIGTERM, 0, 0, 0) != 0 or os.getppid() != int(argv[0]):
        return 125
    timeout, cwd, command = float(argv[1]), argv[2], argv[3:]
    code = 125
    try:
        child = subprocess.Popen(command, cwd=cwd, stdin=subprocess.DEVNULL)
        code = child.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        code = 124
    except ExecutionCancelled:
        code = 130
    except OSError as error:
        print(str(error), file=sys.stderr)
    finally:
        # Repeated cancellation must not interrupt cleanup and release the lock early.
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        if not _cleanup_descendants():
            print('ETNA DESCENDANT CLEANUP FAILED', file=sys.stderr)
            code = 125
    return code


def execute(argv, cwd, timeout):
    if not isinstance(argv, list) or not argv or not all(isinstance(x, str) for x in argv):
        raise ValueError('execution requires argv array')
    start = time.monotonic()
    supervisor = [sys.executable, '-B', str(Path(__file__).resolve()), '--_supervise', str(os.getpid()), str(timeout), str(cwd), *argv]
    process = subprocess.Popen(supervisor, env={'PATH': '/usr/bin:/bin', 'LANG': 'C.UTF-8', 'LC_ALL': 'C.UTF-8'}, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True)
    previous = None
    try:
        previous = signal.signal(signal.SIGTERM, _interrupted)
    except ValueError:
        pass  # Library calls from a non-main thread still have the supervisor deadline.
    try:
        output, _ = process.communicate(timeout=timeout + 10)
    except BaseException:
        process.send_signal(signal.SIGTERM)
        process.communicate(timeout=7)
        raise
    finally:
        if previous is not None: signal.signal(signal.SIGTERM, previous)
    return {'argv': argv, 'supervisor_argv': supervisor, 'returncode': process.returncode, 'timeout': process.returncode == 124,
            'seconds': time.monotonic() - start, 'output': output.decode(errors='replace')}


def module_from(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def verify_contracts(formal, contracts):
    verifier = module_from(formal / 'conformance/run_baseline.py', 'etna_source_verifier')
    pins = read_json(formal / 'conformance/pins.json')
    manifest_path = formal / 'conformance/manifests/contracts.json'
    if sha(manifest_path) != pins['contracts']['manifestSha256']:
        raise ValueError('pinned source inventory drift')
    return verifier.verify_source(contracts, read_json(manifest_path), pins['contracts']['commit'])


def execute_logged(argv, cwd, timeout, directory, index):
    (directory / (str(index) + '-command.json')).write_text(json.dumps(argv, indent=2) + '\n')
    result = execute(argv, cwd, timeout)
    log = directory / (str(index) + '.log')
    log.write_text(result['output'])
    result.update(log=str(log), log_sha256=sha(log))
    return result


def finish_record(result, directory, index):
    result.pop('output', None)
    (directory / (str(index) + '-result.json')).write_text(json.dumps(result, indent=2) + '\n')
    return result


def phase(item, runtime, copied, tests, directory, formal):
    directory.mkdir()
    if item['engine'] == 'tlc':
        records = []
        for index, workload in enumerate(item['workloads']):
            config = copied / safe_relative(workload)
            text = config.read_text()
            expected = re.findall(r'^\\\* EXPECT: (PASS|INVARIANT (\w+))\s*$', text, re.M)
            if len(expected) != 1: raise ValueError('exact normal EXPECT required: ' + workload)
            normal = 'PASS' if expected[0][0] == 'PASS' else expected[0][1]
            module = re.findall(r'^\\\* MODULE: (\w+)\s*$', text, re.M)
            if len(module) != 1: raise ValueError('exact MODULE required')
            argv = [runtime['tlc']['java'], '-Xmx' + str(runtime['tlc'].get('heap_mb', 512)) + 'm', '-XX:+UseParallelGC', '-cp', runtime['tlc']['jar'], 'tlc2.TLC', '-workers', '1', '-seed', '1', '-deadlock', '-metadir', str(directory / ('states-' + str(index))), '-config', str(config), str(copied / (module[0] + '.tla'))]
            java_home = Path(runtime['tlc']['java']).resolve().parent.parent
            launcher = formal / 'conformance/run_isolated.py'
            argv = [sys.executable, '-B', str(launcher), '--read-bind', str(copied) + '=' + str(copied),
                    '--read-bind', str(java_home) + '=' + str(java_home),
                    '--read-bind', runtime['tlc']['jar'] + '=' + runtime['tlc']['jar'],
                    '--write-bind', str(directory) + '=/tmp/etna-campaign-output',
                    '--cwd', str(copied), '--timeout', str(runtime['timeout']), '--',
                    *[x.replace(str(directory), '/tmp/etna-campaign-output') for x in argv]]
            result = execute_logged(argv, copied, runtime['timeout'], directory, index)
            result.update(workload=workload, config_sha256=sha(config), status=classify_tlc(result['returncode'], result['output'], item['failure'], normal, text))
            records.append(finish_record(result, directory, index))
        return records
    template = runtime['forge']['argv']
    template = list(template)
    separator = template.index('--')
    if template[:separator].count('--timeout') != 1:
        raise ValueError('Forge launcher needs one explicit timeout')
    template[template.index('--timeout') + 1] = str(runtime['timeout'])
    reads = [template[i + 1] for i in range(separator) if template[i] == '--read-bind']
    writes = [template[i + 1] for i in range(separator) if template[i] == '--write-bind']
    source_binds = [value for value in reads if value.startswith('{contracts}=')]
    test_binds = [value for value in reads if value.startswith('{tests}=')]
    if len(source_binds) != 1 or len(test_binds) != 1:
        raise ValueError('Forge needs exactly one copied source and current test binding')
    source_target = Path(source_binds[0].split('=', 1)[1])
    mutation_target = source_target / item['path']
    for binding in reads + writes:
        origin, target = binding.split('=', 1)
        target = Path(target)
        if origin != '{contracts}' and (target == mutation_target or target in mutation_target.parents):
            raise ValueError('binding masks the actual mutation target')
    lock = Path(runtime['forge']['lock']).resolve()
    if lock.name != '.formal-cache.lock' or not any(Path(value.split('=', 1)[0]).resolve() == lock.parent for value in writes):
        raise ValueError('lock must be the common writable Forge cache .formal-cache.lock')
    # Templates are explicit inspected run_isolated.py argv, never shell programs.
    launcher = formal / 'conformance/run_isolated.py'
    argv = [x.replace('{contracts}', str(copied)).replace('{tests}', str(tests)) for x in template]
    if len(argv) < 4 or Path(argv[2]).resolve() != launcher.resolve() or '--' not in argv or '--write-bind' not in argv or '--offline' not in argv or '--json' not in argv:
        raise ValueError('Forge must use inspected isolated launcher, offline JSON and explicit cache bind')
    result = execute_logged(argv, directory, runtime['timeout'], directory, 0)
    result.update(workload=item['workloads'], status=classify_forge(result['returncode'], result['output'], item['workloads'], item['failure']))
    try: result['test_results'] = {key: {'status': value.get('status'), 'reason': value.get('reason')} for key, value in forge_rows(result['output']).items()}
    except (ValueError, KeyError, TypeError, AttributeError): result['test_results'] = {}
    return [finish_record(result, directory, 0)]


def acquire_lock(handle, timeout):
    deadline = time.monotonic() + timeout
    while True:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return
        except BlockingIOError:
            if time.monotonic() >= deadline:
                raise ValueError('shared Forge cache lock timed out')
            time.sleep(min(.05, max(0, deadline - time.monotonic())))


def run_campaign(manifest, runtime, selected_ids, output_dir):
    if runtime.get('schema') != 'etna-fault-runtime-1' or runtime.get('timeout', 0) <= 0:
        raise ValueError('invalid runtime schema/timeout')
    output_dir = Path(output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    formal = Path(runtime['sources']['formal']).resolve()
    roots = {name: Path(path).resolve() for name, path in runtime['sources'].items()}
    ids = [item['id'] for item in manifest['obligations']]
    selected = set(selected_ids if selected_ids else [item['id'] for item in manifest['obligations'] if not item.get('unassessed_reason')])
    if not selected.issubset(ids) or len(selected_ids or []) != len(set(selected_ids or [])):
        raise ValueError('unknown/duplicate selected obligation')
    if any(output_dir == root or root in output_dir.parents for root in roots.values()):
        raise ValueError('output must be outside original source roots')
    input_paths = [Path(__file__).resolve(), Path(sys.executable), formal / 'conformance/run_isolated.py', formal / 'conformance/run_baseline.py']
    if any(item['engine'] == 'tlc' and item['id'] in selected for item in manifest['obligations'] if not item.get('unassessed_reason')):
        input_paths += [Path(runtime['tlc']['java']).resolve().parent.parent, Path(runtime['tlc']['jar'])]
    if any(item['engine'] == 'forge' and item['id'] in selected for item in manifest['obligations'] if not item.get('unassessed_reason')):
        template = runtime['forge']['argv']
        for index, value in enumerate(template):
            if value == '--read-bind':
                origin = template[index + 1].split('=', 1)[0]
                if '{' not in origin: input_paths.append(Path(origin))
    def identity(path):
        return {'resolved': str(path.resolve(strict=True)), 'files': snapshot(path)} if path.is_dir() else {'resolved': str(path.resolve(strict=True)), 'sha256': sha(path)}
    tool_hashes = {str(path): identity(path) for path in input_paths}
    evidence = {'tool_hashes': tool_hashes, 'schema': SCHEMA, 'manifest_sha256': hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest(), 'runtime': runtime, 'inventory': [], 'ready': False}
    for item in manifest['obligations']:
        row = {'id': item['id'], 'required': item.get('required', False), 'selected': item['id'] in selected, 'status': 'UNASSESSED', 'reason': item.get('unassessed_reason', 'not selected')}
        evidence['inventory'].append(row)
        if item['id'] not in selected or item.get('unassessed_reason'): continue
        trial_dir = output_dir / item['id']
        trial_dir.mkdir(exist_ok=False)
        lock = open(runtime['forge']['lock'], 'a') if item['engine'] == 'forge' else nullcontext()
        with lock as lock_file:
            phases = {}
            row.update(phases=phases, reason='')
            try:
                if lock_file is not None: acquire_lock(lock_file, runtime['timeout'])
                source = roots[item['source']]
                original_hashes = snapshot(source)
                test_original = formal / 'conformance'
                test_hashes = snapshot(test_original) if item['engine'] == 'forge' else None
                if item['engine'] == 'forge': row['source_verification'] = verify_contracts(formal, source)
                with tempfile.TemporaryDirectory(prefix='etna-fault-') as temporary:
                    copied = Path(temporary) / 'source'
                    shutil.copytree(source, copied, symlinks=True, ignore=shutil.ignore_patterns('.git', '__pycache__'))
                    if snapshot(copied) != original_hashes: raise ValueError('source drift while copying')
                    tests = Path(temporary) / 'tests'
                    if item['engine'] == 'forge':
                        shutil.copytree(test_original / 'solidity', tests)
                        shutil.copytree(test_original, tests / 'vectors', ignore=shutil.ignore_patterns('solidity', '__pycache__'))
                    target = copied / safe_relative(item['path'])
                    if target.is_symlink() or not target.resolve().is_relative_to(copied):
                        raise ValueError('mutation target must be a regular contained file')
                    original = target.read_text()
                    mutant = replace_once(original, item['replace']['old'], item['replace']['new'])
                    row['source_hashes'] = original_hashes
                    row['mutation'] = {'path': item['path'], 'original_sha256': sha(target), 'mutant_sha256': hashlib.sha256(mutant.encode()).hexdigest()}
                    try:
                        phases['baseline'] = phase(item, runtime, copied, tests, trial_dir / 'baseline', formal)
                        target.write_text(mutant)
                        phases['mutated'] = phase(item, runtime, copied, tests, trial_dir / 'mutated', formal)
                    finally:
                        target.write_text(original)
                        phases['restored'] = phase(item, runtime, copied, tests, trial_dir / 'restored', formal)
                    stable = snapshot(source) == original_hashes and snapshot(copied) == original_hashes
                    if test_hashes is not None: stable = stable and snapshot(test_original) == test_hashes
                    stable = stable and all(identity(Path(path)) == digest for path, digest in tool_hashes.items())
                    row['inputs_stable'] = stable
                    row['status'] = trial_status(*[[x['status'] for x in phases.get(name, [])] for name in ('baseline', 'mutated', 'restored')], stable)
                    for phase_name, records in phases.items():
                        for index, result in enumerate(records):
                            log = trial_dir / phase_name / (str(index) + '.log')
                            if 'output' in result: log.write_text(result.pop('output'))
                            result['log'] = str(log.relative_to(output_dir))
                            result['log_sha256'] = sha(log)
            except (OSError, ValueError, KeyError, TypeError) as error:
                row.update(status='INCONCLUSIVE', reason=str(error))
        (trial_dir / 'result.json').write_text(json.dumps(row, indent=2) + '\n')
    active = [row for row in evidence['inventory'] if row['selected'] and row['required']]
    evidence['ready'] = bool(active) and all(row['status'] == 'KILLED' for row in active)
    (output_dir / 'campaign.json').write_text(json.dumps(evidence, indent=2) + '\n')
    return evidence


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--runtime', type=Path, required=True)
    parser.add_argument('--only', action='append', default=[])
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        result = run_campaign(load_manifest(args.manifest), read_json(args.runtime), args.only, args.output_dir)
    except (ValueError, OSError, KeyError, TypeError) as error:
        parser.error(str(error))
    print(json.dumps({'ready': result['ready'], 'inventory': [{k: row[k] for k in ('id', 'status', 'selected')} for row in result['inventory']]}))
    return 0 if result['ready'] else 1

if __name__ == '__main__':
    if sys.argv[1:2] == ['--_supervise']:
        raise SystemExit(supervise(sys.argv[2:]))
    raise SystemExit(main())
