import copy
import hashlib
import importlib.util
import contextlib
import io
import os
import sys
import json
from pathlib import Path
import tempfile
import unittest

PATH = Path(__file__).resolve().parents[1] / 'run_baseline.py'
MODULE = None
if PATH.exists():
    spec = importlib.util.spec_from_file_location('baseline', PATH)
    MODULE = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(MODULE)


class BaselineTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(MODULE, 'baseline verifier is not implemented')
        self.current = {'schema': 'etna-current-registry-admission-1',
                        'authorityCommit': 'a' * 40, 'model': 'model',
                        'vectors': [{'id': 'case_' + str(i), 'expect': {'balance': i}}
                                    for i in range(8)]}
        self.consumer = copy.deepcopy(self.current)
        self.consumer['authorityCommit'] = 'b' * 40

    def test_checked_in_spec_pin_matches_both_source_manifests(self):
        root = PATH.parent
        pins = json.loads((root / 'pins.json').read_text())
        spec_path = 'packages/protocol/docs/etna/SPEC.md'
        for consumer in ('lean', 'contracts'):
            raw = (root / 'manifests' / (consumer + '.json')).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(), pins[consumer]['manifestSha256'])
            entry = json.loads(raw)['files'][spec_path]
            self.assertEqual(entry['sha256'], pins['spec']['sha256'])
            self.assertEqual(entry['gitBlob'], pins['spec']['blob'])
        current = (root.parents[2] / spec_path).read_bytes()
        self.assertEqual(hashlib.sha256(current).hexdigest(), pins['spec']['sha256'])
        self.assertEqual(hashlib.sha1(b'blob ' + str(len(current)).encode() + b'\0' + current).hexdigest(),
                         pins['spec']['blob'])

    def compare(self, left=None, right=None):
        return MODULE.compare_vectors(left or self.current, right or self.consumer,
                                      current_authority='a' * 40,
                                      consumer_authority='b' * 40)

    def test_exactly_one_declared_metadata_difference(self):
        self.assertEqual(self.compare()['cases'], 8)

    def test_expected_value_change_rejected(self):
        self.consumer['vectors'][7]['expect']['balance'] += 1
        with self.assertRaises(ValueError): self.compare()

    def test_missing_case_rejected(self):
        self.consumer['vectors'].pop()
        with self.assertRaises(ValueError): self.compare()

    def test_duplicate_case_rejected(self):
        self.current['vectors'][7]['id'] = 'case_0'
        self.consumer['vectors'][7]['id'] = 'case_0'
        with self.assertRaises(ValueError): self.compare()

    def test_unknown_top_level_difference_rejected(self):
        self.current['extra'] = 'not authority metadata'
        with self.assertRaises(ValueError): self.compare()

    def test_wrong_authority_rejected(self):
        self.current['authorityCommit'] = 'c' * 40
        with self.assertRaises(ValueError): self.compare()

    def test_source_change_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            p = root / 'model.lean'; p.write_text('original')
            data = p.read_bytes()
            manifest = {'schema': 'etna-source-snapshot-1', 'commit': 'a' * 40,
                        'files': {'model.lean': {'bytes': len(data),
                         'sha256': hashlib.sha256(data).hexdigest(),
                         'gitBlob': hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()}}}
            self.assertEqual(MODULE.verify_source(root, manifest, 'a' * 40)['files'], 1)
            p.write_text('changed')
            with self.assertRaises(ValueError): MODULE.verify_source(root, manifest, 'a' * 40)

    def test_manifest_traversal_rejected(self):
        m = {'schema': 'etna-source-snapshot-1', 'commit': 'a' * 40,
             'files': {'../outside': {'sha256': '0' * 64, 'bytes': 0, 'gitBlob': '0' * 40}}}
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError): MODULE.verify_source(Path(tmp), m, 'a' * 40)

    def test_wrong_source_commit_rejected(self):
        m = {'schema': 'etna-source-snapshot-1', 'commit': 'b' * 40, 'files': {}}
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError): MODULE.verify_source(Path(tmp), m, 'a' * 40)

    def test_missing_or_skipped_execution_is_not_pass(self):
        reports = [{'schema': 'etna-baseline-command-1', 'phase': p,
                    'sourceCommit': c, 'executed': True, 'returncode': 0}
                   for p, c in [('lean-build', 'a'), ('lean-vectors', 'a'), ('contract-registry', 'b')]]
        expected = {'lean-build': 'a', 'lean-vectors': 'a', 'contract-registry': 'b'}
        self.assertEqual(MODULE.require_executions(reports, expected)['status'], 'PASS')
        with self.assertRaises(ValueError): MODULE.require_executions(reports[:2], expected)
        reports[2]['executed'] = False
        with self.assertRaises(ValueError): MODULE.require_executions(reports, expected)

    def test_failed_command_is_not_pass(self):
        r = [{'schema': 'etna-baseline-command-1', 'phase': 'lean-build',
              'sourceCommit': 'a', 'executed': True, 'returncode': 1}]
        with self.assertRaises(ValueError): MODULE.require_executions(r, {'lean-build': 'a'})

    def test_timeout_kills_command_children(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pins = root / 'pins.json'
            source = root / 'input'; source.mkdir(); (source / 'input.txt').write_bytes(b'x')
            manifest = root / 'manifest.json'
            manifest.write_text(json.dumps({'schema': 'etna-source-snapshot-1', 'commit': 'a', 'files': {
                'input.txt': {'bytes': 1, 'sha256': MODULE.digest(b'x'),
                              'gitBlob': hashlib.sha1(b'blob 1\0x').hexdigest()}}}))
            pins.write_text(json.dumps({'lean': {'commit': 'a', 'manifestSha256': MODULE.digest(manifest.read_bytes())}, 'contracts': {'commit': 'b'}}))
            pid_file = root / 'child.pid'
            command = ("import subprocess,sys,time; from pathlib import Path; "
                       "child=subprocess.Popen([sys.executable,'-c','import time; time.sleep(20)'],"
                       "stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL); "
                       "Path(sys.argv[1]).write_text(str(child.pid)); time.sleep(20)")
            try:
                with contextlib.redirect_stdout(io.StringIO()):
                    rc = MODULE.main(['--pins', str(pins), 'record', '--phase', 'lean-build',
                                      '--source-commit', 'a', '--root', str(source), '--manifest', str(manifest),
                                      '--report', str(root / 'run.json'),
                                      '--timeout', '1', '--', sys.executable, '-c', command, str(pid_file)])
                self.assertEqual(rc, 1)
                child = int(pid_file.read_text())
                stat = Path('/proc') / str(child) / 'stat'
                self.assertTrue(not stat.exists() or stat.read_text().split()[2] == 'Z',
                                'timed-out child is still running')
                self.assertIsNone(json.loads((root / 'run.json').read_text())['returncode'])
            finally:
                if pid_file.exists():
                    try: os.kill(int(pid_file.read_text()), 9)
                    except ProcessLookupError: pass

    def test_recorded_artifact_and_source_attestation_required(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            out = root / 'run.stdout.log'; out.write_text('{}')
            err = root / 'run.stderr.log'; err.write_text('')
            report = {'stdoutFile': out.name, 'stderrFile': err.name,
                      'stdoutSha256': MODULE.digest(out.read_bytes()),
                      'stderrSha256': MODULE.digest(err.read_bytes()),
                      'sourceVerifiedBefore': True, 'sourceVerifiedAfter': True,
                      'manifestSha256': 'a' * 64, 'artifacts': []}
            self.assertEqual(MODULE.verify_record(report, root, 'a' * 64)['stdout'], b'{}')
            out.write_text('{"stale":true}')
            with self.assertRaises(ValueError): MODULE.verify_record(report, root, 'a' * 64)
            out.write_text('{}')
            report['sourceVerifiedAfter'] = False
            with self.assertRaises(ValueError): MODULE.verify_record(report, root, 'a' * 64)

    def test_wrong_artifact_or_manifest_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'out').write_text('output'); (root / 'err').write_text('')
            vector = root / 'vector.json'; vector.write_text('new output')
            report = {'stdoutFile': 'out', 'stderrFile': 'err',
                      'stdoutSha256': MODULE.digest(b'output'), 'stderrSha256': MODULE.digest(b''),
                      'sourceVerifiedBefore': True, 'sourceVerifiedAfter': True,
                      'manifestSha256': 'a' * 64,
                      'artifacts': [{'path': str(vector), 'sha256': MODULE.digest(b'new output')}]}
            MODULE.verify_record(report, root, 'a' * 64)
            with self.assertRaises(ValueError): MODULE.verify_record(report, root, 'b' * 64)
            vector.write_text('stale')
            with self.assertRaises(ValueError): MODULE.verify_record(report, root, 'a' * 64)

    def test_one_generated_output_cannot_count_as_two(self):
        entries = [{'path': 'vectors/first.json', 'sha256': 'a' * 64},
                   {'path': 'vectors/second.json', 'sha256': 'a' * 64}]
        MODULE.require_generated_vectors(entries, 'a' * 64)
        entries[1]['path'] = 'vectors/../vectors/first.json'
        with self.assertRaises(ValueError): MODULE.require_generated_vectors(entries, 'a' * 64)

    def test_forge_without_actual_selected_test_rejected(self):
        with self.assertRaises(ValueError): MODULE.require_forge_success({}, 'test_vectors()')
        payload = {'Suite': {'test_results': {'test_vectors()': {'status': 'Failure'}}}}
        with self.assertRaises(ValueError): MODULE.require_forge_success(payload, 'test_vectors()')
        payload['Suite']['test_results']['test_vectors()']['status'] = 'Success'
        self.assertEqual(MODULE.require_forge_success(payload, 'test_vectors()')['tests'], 1)


if __name__ == '__main__': unittest.main()
