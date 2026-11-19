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

AUTHORITY_PATH = PATH.with_name('spec_authority.py')
authority_spec = importlib.util.spec_from_file_location('spec_authority', AUTHORITY_PATH)
AUTHORITY = importlib.util.module_from_spec(authority_spec)
authority_spec.loader.exec_module(AUTHORITY)


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

    def test_workspace_spec_preserves_the_historical_correspondence_boundary(self):
        root = PATH.parent
        pins = json.loads((root / 'pins.json').read_text())
        ledger = AUTHORITY.load_spec_correspondence(root / 'spec_correspondence.json')
        current = (root.parents[2] / ledger['path']).read_bytes()
        sha256 = hashlib.sha256(current).hexdigest()
        if sha256 == 'b331b3af7b42a4645ebe3e2b4f42e912e33508893a091c3c3c289c8fdbd53a70':
            with self.assertRaisesRegex(ValueError, 'workspace SPEC bytes have no reviewed correspondence'):
                AUTHORITY.verify_workspace_spec(current, pins['spec'], ledger)
        else:
            result = AUTHORITY.verify_workspace_spec(current, pins['spec'], ledger)
            self.assertEqual(result['status'], 'SPEC_CORRESPONDENCE_VERIFIED')

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


class SpecCorrespondenceTests(unittest.TestCase):
    def setUp(self):
        self.original = b'canonical specification\n'
        self.reviewed = b'reviewed scoped specification\n'
        self.authority = self.identity(self.original, 'a' * 40)
        self.ledger = {'schema': 'etna-spec-correspondence-1',
                       'path': 'packages/protocol/docs/etna/SPEC.md',
                       'authority': copy.deepcopy(self.authority),
                       'reviewedWorkspace': self.identity(self.reviewed, 'b' * 40),
                       'classification': 'reviewed-scoped-correspondence',
                       'rationale': 'Exact reviewed fixture pair within selected scope.'}

    @staticmethod
    def identity(raw, commit):
        return {'commit': commit, 'sha256': hashlib.sha256(raw).hexdigest(),
                'blob': hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()}

    def verify(self, raw=None, ledger=None, authority=None):
        return AUTHORITY.verify_workspace_spec(self.original if raw is None else raw,
                    self.authority if authority is None else authority,
                    self.ledger if ledger is None else ledger)

    def test_canonical_and_exact_reviewed_bytes_are_distinguished(self):
        self.assertEqual(self.verify()['relation'], 'canonical')
        self.assertEqual(self.verify(self.reviewed)['relation'], 'reviewed-scoped')

    def test_unknown_or_one_byte_tampered_spec_is_rejected(self):
        for raw in (self.original + b' ', self.reviewed + b' ', b'future specification\n'):
            with self.subTest(raw=raw), self.assertRaises(ValueError): self.verify(raw)

    def test_replaced_reviewed_identity_is_not_an_implicit_allowlist(self):
        previous = b'previously reviewed specification\n'
        with self.assertRaises(ValueError): self.verify(previous)
        replaced = copy.deepcopy(self.ledger)
        replaced['reviewedWorkspace'] = self.identity(previous, 'c' * 40)
        with self.assertRaises(ValueError): self.verify(self.reviewed, replaced)

    def test_wrong_historical_authority_identity_is_rejected(self):
        for name, size in (('commit', 40), ('blob', 40), ('sha256', 64)):
            bad = copy.deepcopy(self.ledger); bad['authority'][name] = 'c' * size
            with self.subTest(field=name), self.assertRaises(ValueError): self.verify(ledger=bad)

    def test_reviewed_hash_and_blob_must_both_match(self):
        for name, size in (('blob', 40), ('sha256', 64)):
            bad = copy.deepcopy(self.ledger); bad['reviewedWorkspace'][name] = 'c' * size
            with self.subTest(field=name), self.assertRaises(ValueError): self.verify(self.reviewed, bad)

    def test_invalid_metadata_rejected_even_for_canonical_bytes(self):
        changes = [('schema', 'unknown'), ('path', '../SPEC.md'),
                   ('classification', 'unreviewed'),
                   ('classification', 'reviewed-editorial-correspondence'), ('rationale', ''), ('rationale', None)]
        for name, value in changes:
            bad = copy.deepcopy(self.ledger); bad[name] = value
            with self.subTest(field=name, value=value), self.assertRaises(ValueError): self.verify(ledger=bad)
        for name in self.ledger:
            bad = copy.deepcopy(self.ledger); del bad[name]
            with self.subTest(missing=name), self.assertRaises(ValueError): self.verify(ledger=bad)
        bad = copy.deepcopy(self.ledger); bad['extra'] = 'unreviewed'
        with self.assertRaises(ValueError): self.verify(ledger=bad)

    def test_identity_shapes_types_and_hash_formats_are_closed(self):
        for key in ('authority', 'reviewedWorkspace'):
            for value in ([], None, {'commit': 'a' * 40}):
                bad = copy.deepcopy(self.ledger); bad[key] = value
                with self.subTest(key=key, value=value), self.assertRaises(ValueError): self.verify(ledger=bad)
            for value in ('A' * 40, 'z' * 40, 'a' * 39, None, 12):
                bad = copy.deepcopy(self.ledger); bad[key]['blob'] = value
                with self.subTest(key=key, value=value), self.assertRaises(ValueError): self.verify(ledger=bad)
            bad = copy.deepcopy(self.ledger); bad[key]['extra'] = 'ignored'
            with self.assertRaises(ValueError): self.verify(ledger=bad)
        with self.assertRaises(ValueError): self.verify(authority={})
        with self.assertRaises(ValueError): self.verify(raw='decoded text')

    def test_canonical_identity_cannot_be_relabelled_as_reviewed(self):
        bad = copy.deepcopy(self.ledger); bad['reviewedWorkspace'] = copy.deepcopy(self.authority)
        with self.assertRaises(ValueError): self.verify(ledger=bad)

    def test_duplicate_top_level_and_nested_metadata_keys_are_rejected(self):
        valid = json.dumps(self.ledger)
        nested = valid.replace('"commit":', '"commit":"' + 'c' * 40 + '","commit":', 1)
        top = valid.replace('{', '{"schema":"etna-spec-correspondence-1",', 1)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'correspondence.json'
            for raw in (nested, top):
                path.write_text(raw)
                with self.subTest(raw=raw), self.assertRaises(ValueError): AUTHORITY.load_spec_correspondence(path)
            path.write_text(valid)
            self.assertEqual(AUTHORITY.load_spec_correspondence(path), self.ledger)


if __name__ == '__main__': unittest.main()
