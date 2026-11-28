#!/usr/bin/env python3
"""Verify pinned inputs and collect separately executed conformance evidence.

No dependency is downloaded by this helper. `record` executes an argv supplied
by the caller; use the isolated launcher for repository code. Input comparison
alone never produces an implementation-conformance verdict.
"""
import argparse
import hashlib
import json
import os
import signal
from pathlib import Path, PurePosixPath
import subprocess
import sys
import time

PINS = Path(__file__).with_name('pins.json')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def verify_source(root, manifest, commit):
    root = Path(root).resolve()
    if manifest.get('schema') != 'etna-source-snapshot-1' or manifest.get('commit') != commit:
        raise ValueError('source schema/commit does not match the pin')
    files = manifest.get('files')
    if not isinstance(files, dict) or not files:
        raise ValueError('source manifest has no files')
    for name, expected in files.items():
        rel = PurePosixPath(name)
        if rel.is_absolute() or '..' in rel.parts or not rel.parts:
            raise ValueError('unsafe source path')
        path = root.joinpath(*rel.parts)
        if not path.resolve().is_relative_to(root):
            raise ValueError('source path escapes snapshot')
        if expected.get('kind') == 'symlink':
            if not path.is_symlink() or os.readlink(path) != expected.get('target'):
                raise ValueError('source symlink differs: ' + name)
            continue
        if path.is_symlink() or not path.is_file():
            raise ValueError('missing or substituted source: ' + name)
        data = path.read_bytes()
        blob = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
        if digest(data) != expected.get('sha256') or len(data) != expected.get('bytes') or blob != expected.get('gitBlob'):
            raise ValueError('source bytes differ: ' + name)
    return {'files': len(files), 'commit': commit, 'status': 'INPUTS_VERIFIED'}


def compare_vectors(current, consumer, *, current_authority, consumer_authority):
    for value, authority in ((current, current_authority), (consumer, consumer_authority)):
        if value.get('schema') != 'etna-current-registry-admission-1' or value.get('authorityCommit') != authority:
            raise ValueError('vector schema/authority mismatch')
        cases = value.get('vectors')
        if not isinstance(cases, list) or len(cases) != 8:
            raise ValueError('exactly eight current cases are required')
        ids = [case.get('id') for case in cases]
        if any(not isinstance(item, str) or not item for item in ids) or len(set(ids)) != 8:
            raise ValueError('case identities must be unique')
    left = {k: v for k, v in current.items() if k != 'authorityCommit'}
    right = {k: v for k, v in consumer.items() if k != 'authorityCommit'}
    if left != right:
        raise ValueError('non-authority vector content differs')
    body = json.dumps(left, sort_keys=True, separators=(',', ':')).encode()
    return {'status': 'VECTOR_CONTENT_COMPATIBLE', 'cases': 8,
            'semanticSha256': digest(body), 'ignoredFields': ['authorityCommit']}


def require_executions(reports, expected):
    if len(reports) != len(expected) or {r.get('phase') for r in reports} != set(expected):
        raise ValueError('missing, duplicate or unexpected execution phase')
    for report in reports:
        phase = report['phase']
        if (report.get('schema') != 'etna-baseline-command-1'
                or report.get('executed') is not True or report.get('returncode') != 0
                or report.get('sourceCommit') != expected[phase]):
            raise ValueError('failed, skipped or wrong-source phase: ' + phase)
    return {'status': 'PASS', 'phases': sorted(expected)}


def verify_record(report, directory, manifest_digest):
    """Check trusted local execution evidence; this is not a signed attestation.

    The command and isolated launcher still require human/independent review.
    Hashes reject accidental stale substitution, not a malicious report author.
    """
    if (report.get('sourceVerifiedBefore') is not True
            or report.get('sourceVerifiedAfter') is not True
            or report.get('manifestSha256') != manifest_digest):
        raise ValueError('source snapshot was not verified before and after execution')
    values = {}
    for stream in ('stdout', 'stderr'):
        name = report.get(stream + 'File')
        if not isinstance(name, str) or Path(name).name != name:
            raise ValueError('invalid recorded stream path')
        data = (Path(directory) / name).read_bytes()
        if digest(data) != report.get(stream + 'Sha256'):
            raise ValueError('recorded stream changed: ' + stream)
        values[stream] = data
    for artifact in report.get('artifacts', []):
        path = Path(artifact['path'])
        if digest(path.read_bytes()) != artifact.get('sha256'):
            raise ValueError('recorded output artifact changed')
    return values


def require_generated_vectors(artifacts, expected_digest):
    paths = [Path(item['path']).resolve() for item in artifacts]
    if (len(paths) != 2 or len(set(paths)) != 2
            or any(item['sha256'] != expected_digest for item in artifacts)):
        raise ValueError('two distinct freshly generated pinned vectors required')


def require_forge_success(payload, selected_test):
    results = []
    for suite in payload.values():
        if isinstance(suite, dict) and isinstance(suite.get('test_results'), dict):
            results.extend(suite['test_results'].items())
    if sum(name == selected_test for name, _ in results) != 1:
        raise ValueError('selected real contract test did not run exactly once')
    if any(result.get('status') != 'Success' for _, result in results):
        raise ValueError('contract test did not succeed')
    return {'tests': len(results), 'selectedTest': selected_test, 'status': 'PASS'}


def load_json(path):
    return json.loads(Path(path).read_text())


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pins', type=Path, default=PINS)
    sub = parser.add_subparsers(dest='operation', required=True)
    source = sub.add_parser('verify-source')
    source.add_argument('--kind', choices=('lean', 'contracts'), required=True)
    source.add_argument('--root', type=Path, required=True)
    source.add_argument('--manifest', type=Path, required=True)
    compare = sub.add_parser('compare')
    compare.add_argument('--current', type=Path, required=True)
    compare.add_argument('--consumer', type=Path, required=True)
    record = sub.add_parser('record')
    record.add_argument('--phase', choices=('lean-build', 'lean-vectors', 'contract-registry'), required=True)
    record.add_argument('--source-commit', required=True)
    record.add_argument('--root', type=Path, required=True)
    record.add_argument('--manifest', type=Path, required=True)
    record.add_argument('--fresh-artifact', type=Path, action='append', default=[])
    record.add_argument('--report', type=Path, required=True)
    record.add_argument('--timeout', type=int, default=900)
    record.add_argument('command', nargs=argparse.REMAINDER)
    collect = sub.add_parser('summarize')
    collect.add_argument('--reports', type=Path, nargs='+', required=True)
    collect.add_argument('--current', type=Path, required=True)
    collect.add_argument('--consumer', type=Path, required=True)
    args = parser.parse_args(argv)
    pins = load_json(args.pins)
    try:
        if args.operation == 'verify-source':
            entry = pins[args.kind]
            if digest(args.manifest.read_bytes()) != entry['manifestSha256']:
                raise ValueError('manifest digest differs from pinned source snapshot')
            result = verify_source(args.root, load_json(args.manifest), entry['commit'])
        elif args.operation == 'compare':
            if digest(args.current.read_bytes()) != pins['lean']['vectorSha256'] or digest(args.consumer.read_bytes()) != pins['contracts']['vectorSha256']:
                raise ValueError('vector bytes differ from pinned files')
            result = compare_vectors(load_json(args.current), load_json(args.consumer),
                                     current_authority=pins['lean']['authorityCommit'],
                                     consumer_authority=pins['contracts']['authorityCommit'])
        elif args.operation == 'record':
            command = args.command[1:] if args.command[:1] == ['--'] else args.command
            if not command or args.timeout <= 0:
                raise ValueError('a command and positive timeout are required')
            entry = pins['contracts' if args.phase == 'contract-registry' else 'lean']
            expected = entry['commit']
            if args.source_commit != expected:
                raise ValueError('command source commit differs from pin')
            if digest(args.manifest.read_bytes()) != entry['manifestSha256']:
                raise ValueError('unrecognized source manifest')
            manifest = load_json(args.manifest)
            verify_source(args.root, manifest, expected)
            if len(set(path.resolve() for path in args.fresh_artifact)) != len(args.fresh_artifact):
                raise ValueError('fresh artifact paths must be distinct')
            if any(path.exists() for path in args.fresh_artifact):
                raise ValueError('fresh artifact already exists')
            args.report.parent.mkdir(parents=True, exist_ok=True)
            out = args.report.with_suffix('.stdout.log'); err = args.report.with_suffix('.stderr.log')
            start = time.monotonic()
            with out.open('w') as stdout_file, err.open('w') as stderr_file:
                proc = subprocess.Popen(command, stdout=stdout_file, stderr=stderr_file,
                                        stdin=subprocess.DEVNULL, start_new_session=True)
                try:
                    code = proc.wait(timeout=args.timeout)
                except subprocess.TimeoutExpired:
                    os.killpg(proc.pid, signal.SIGKILL)
                    proc.wait()
                    code = None
                except BaseException:
                    if proc.poll() is None:
                        os.killpg(proc.pid, signal.SIGKILL)
                    proc.wait()
                    raise
            verify_source(args.root, manifest, expected)
            artifacts = [{'path': str(path.resolve()), 'sha256': digest(path.read_bytes())}
                         for path in args.fresh_artifact]
            stdout = out.read_bytes(); stderr = err.read_bytes()
            result = {'schema': 'etna-baseline-command-1', 'phase': args.phase,
                      'sourceCommit': args.source_commit, 'executed': True, 'returncode': code,
                      'seconds': round(time.monotonic() - start, 3), 'command': command,
                      'stdoutFile': out.name, 'stderrFile': err.name,
                      'stdoutSha256': digest(stdout), 'stderrSha256': digest(stderr),
                      'manifestSha256': entry['manifestSha256'],
                      'sourceVerifiedBefore': True, 'sourceVerifiedAfter': True,
                      'artifacts': artifacts}
            args.report.write_text(json.dumps(result, indent=2) + '\n')
            print(json.dumps(result))
            return 0 if code == 0 else 1
        else:
            result = require_executions([load_json(p) for p in args.reports], {
                'lean-build': pins['lean']['commit'], 'lean-vectors': pins['lean']['commit'],
                'contract-registry': pins['contracts']['commit']})
            evidence = {}
            for path in args.reports:
                report = load_json(path)
                kind = 'contracts' if report['phase'] == 'contract-registry' else 'lean'
                evidence[report['phase']] = (report, verify_record(report, path.parent, pins[kind]['manifestSha256']))
            result['forge'] = require_forge_success(json.loads(evidence['contract-registry'][1]['stdout']),
                                                  'test_conformance_currentRegistryAdmission()')
            generated = evidence['lean-vectors'][0].get('artifacts', [])
            require_generated_vectors(generated, pins['lean']['vectorSha256'])
            if digest(args.current.read_bytes()) != pins['lean']['vectorSha256'] or digest(args.consumer.read_bytes()) != pins['contracts']['vectorSha256']:
                raise ValueError('unrecognized executed vector bytes')
            result['vectors'] = compare_vectors(load_json(args.current), load_json(args.consumer),
                current_authority=pins['lean']['authorityCommit'], consumer_authority=pins['contracts']['authorityCommit'])
        print(json.dumps(result, sort_keys=True))
        return 0
    except (ValueError, OSError, KeyError, TypeError) as error:
        print('baseline check failed: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
