"""Bootstrap recorder regressions: wrong execution reason must never earn credit."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'run_comet_bootstrap.py'
IDS = ['origin-base', 'origin-landed-alternate', 'current-base',
       'current-first-alternate', 'current-second-alternate',
       'last-validator-lookup', 'observer-controls']
PACKAGE = 'example.org/etna-comet-bootstrap'
PARENT = 'TestCheckpointBootstrap'


REAL_MUTANT = ROOT / 'tests/fixtures/comet-bootstrap-mutant.jsonl'
REAL_MUTANT_SHA = '2c0fb621883576a5cec224500e74b1c06b752d3e37e8522f38242f71961d4fb2'


def events(mutant=False):
    if mutant:
        return [json.loads(line) for line in REAL_MUTANT.read_text().splitlines()]
    rows = [dict(Action='start', Package=PACKAGE), dict(Action='run', Package=PACKAGE, Test=PARENT)]
    for name in IDS:
        identity = PARENT + '/' + name
        rows += [dict(Action='run', Package=PACKAGE, Test=identity),
                 dict(Action='pass', Package=PACKAGE, Test=identity)]
    return rows + [dict(Action='pass', Package=PACKAGE, Test=PARENT),
                   dict(Action='pass', Package=PACKAGE)]


def stream(rows):
    return '\n'.join(json.dumps(row) for row in rows).encode()


class BootstrapRecorderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module = None
        if PATH.exists():
            spec = importlib.util.spec_from_file_location('etna_bootstrap_tests', PATH)
            cls.module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(cls.module)

    def setUp(self):
        if self.module is None:
            self.fail('Bootstrap recorder has not been implemented')
        self.m = self.module

    def test_exact_native_phases_require_all_seven(self):
        for phase in ('normal', 'restored', 'mutant'):
            result = self.m.require_go_outcomes(stream(events(phase == 'mutant')), int(phase == 'mutant'), phase)
            self.assertEqual(len(result), 7)

    def test_package_only_empty_malformed_and_wrong_phase_fail_closed(self):
        for raw, phase in [(b'', 'normal'), (b'not json', 'normal'),
                           (stream([events()[-1]]), 'normal'), (stream(events()), 'unknown')]:
            with self.assertRaises(ValueError):
                self.m.require_go_outcomes(raw, 0, phase)

    def test_missing_duplicate_skipped_unexpected_wrong_package_or_failed_native_rejected(self):
        base = events()
        variants = [base[:2] + base[4:], base + [base[2]]]
        for index, field, value in [(3, 'Action', 'skip'), (2, 'Test', 'TestUnrelated'),
                                    (2, 'Package', 'unrelated/package'), (3, 'Action', 'fail')]:
            rows = copy.deepcopy(base); rows[index][field] = value; variants.append(rows)
        for rows in variants:
            with self.assertRaises(ValueError):
                self.m.require_go_outcomes(stream(rows), 0, 'normal')

    def test_mutant_requires_correct_identity_and_returncode(self):
        bad = events(True); bad[3]['Action'] = 'fail'
        for rows, code in [(events(), 0), (events(True), 0), (events(True), 2), (bad, 1)]:
            with self.assertRaises(ValueError):
                self.m.require_go_outcomes(stream(rows), code, 'mutant')

    def test_mutant_requires_three_exact_ordered_missing_row_semantics(self):
        base = events(True)
        positions = [i for i,r in enumerate(base) if r['Action'] == 'output' and r.get('Test') == PARENT + '/last-validator-lookup']
        variants = [[r for r in base if r['Action'] != 'output'],
                    [r for i,r in enumerate(base) if i != positions[2]],
                    base + [base[positions[1]]]]
        for fragment, replacement in [('typed=ErrNoValSetForHeight', 'typed=UnexpectedError'),
                                      ('height=4', 'height=5'), ('nilset=true', 'nilset=false'),
                                      ('row=absent', 'row=present'),
                                      ('serialized-last=preserved', 'serialized-last=lost'),
                                      ('id=current-base', 'id=origin-base')]:
            rows=copy.deepcopy(base);rows[positions[1]]['Output']=rows[positions[1]]['Output'].replace(fragment,replacement);variants.append(rows)
        rows=copy.deepcopy(base); rows[positions[1]],rows[positions[2]]=rows[positions[2]],rows[positions[1]];variants.append(rows)
        rows=copy.deepcopy(base);rows[positions[1]]['Output']='    bootstrap_test.go:0: unrelated setup failed\n';variants.append(rows)
        rows=copy.deepcopy(base);extra=copy.deepcopy(rows[positions[1]]);extra['Output']='    bootstrap_test.go:42: unrelated observer failure\n';rows.append(extra);variants.append(rows)
        for rows in variants:
            with self.assertRaisesRegex(ValueError, 'diagnostic|semantic'):
                self.m.require_go_outcomes(stream(rows), 1, 'mutant')

    def test_real_mutant_stream_and_missing_optional_outputtype_remain_accepted(self):
        self.assertEqual(self.m.COMET.digest(REAL_MUTANT.read_bytes()), REAL_MUTANT_SHA)
        self.assertEqual(len(self.m.require_go_outcomes(REAL_MUTANT.read_bytes(), 1, 'mutant')), 7)
        rows = events(True)
        for row in rows:
            row.pop('OutputType', None)
        self.assertEqual(len(self.m.require_go_outcomes(stream(rows), 1, 'mutant')), 7)

    def test_real_mutant_rejects_extra_diagnostics_in_parent_package_and_passing_leaf(self):
        base = events(True)
        for scope in (PARENT, None, PARENT + '/origin-base'):
            frame = 'FAIL' if scope is None else '--- FAIL:' if scope == PARENT else '--- PASS:'
            index = next(i for i, row in enumerate(base)
                         if row.get('Action') == 'output' and row.get('Test') == scope
                         and row.get('Output', '').startswith(frame))
            for typed in (True, False):
                with self.subTest(scope=scope, output_type=typed):
                    rows = copy.deepcopy(base)
                    extra = {'Time': rows[index]['Time'], 'Action': 'output', 'Package': PACKAGE,
                             'Output': '    bootstrap_test.go:999: unrelated cleanup diagnostic\n'}
                    if scope is not None:
                        extra['Test'] = scope
                    if typed:
                        extra['OutputType'] = 'error'
                    rows.insert(index, extra)
                    with self.assertRaisesRegex(ValueError, 'diagnostic|native output'):
                        self.m.require_go_outcomes(stream(rows), 1, 'mutant')

    def test_real_mutant_rejects_error_typed_framework_banners_in_every_other_scope(self):
        base = events(True)
        for scope in (PARENT, None, PARENT + '/origin-base'):
            with self.subTest(scope=scope):
                rows = copy.deepcopy(base)
                index = next(i for i, row in enumerate(rows)
                             if row.get('Action') == 'output' and row.get('Test') == scope)
                rows[index]['OutputType'] = 'error'
                with self.assertRaisesRegex(ValueError, 'diagnostic|native output'):
                    self.m.require_go_outcomes(stream(rows), 1, 'mutant')

    def test_strict_f03_external_json_boundary_and_frozen_payload(self):
        pins, _, _ = self.m.inputs()
        with tempfile.TemporaryDirectory() as directory:
            p=Path(directory)/'receipt.json'
            raw=(ROOT/'checkpoint_import_cases.json').read_text()
            p.write_text(raw.replace('{', '{"schema":"conflicting",', 1))
            with self.assertRaisesRegex(ValueError, 'duplicate JSON field'):
                self.m.load_receipt(p, pins)
            p.write_text(raw+' ')
            with self.assertRaisesRegex(ValueError, 'receipt bytes'):
                self.m.load_receipt(p, pins)

    def test_rebound_receipt_provenance_still_rejected(self):
        pins, _, _ = self.m.inputs()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'receipt.json'
            data = json.loads((ROOT / 'checkpoint_import_cases.json').read_bytes())
            data['provenance']['spec']['commit'] = 'b' * 40
            content = {k: v for k, v in data.items() if k != 'content_sha256'}
            data['content_sha256'] = self.m.COMET.digest(json.dumps(content, sort_keys=True, separators=(',', ':'), allow_nan=False).encode())
            path.write_text(json.dumps(data))
            rebound = copy.deepcopy(pins)
            rebound['receipt']['sha256'] = self.m.COMET.digest(path.read_bytes())
            with self.assertRaisesRegex(ValueError, 'source/tool provenance'):
                self.m.load_receipt(path, rebound)

    def test_native_duplicate_json_fields_rejected_before_outcome_classification(self):
        raw = stream(events()).replace(b'"Action": "start"', b'"Action": "fail", "Action": "start"', 1)
        with self.assertRaisesRegex(ValueError, 'invalid Go JSON'):
            self.m.require_go_outcomes(raw, 0, 'normal')

    def test_input_watch_detects_changed_or_missing_file(self):
        with tempfile.TemporaryDirectory() as directory:
            p=Path(directory)/'input';p.write_bytes(b'original')
            watched={p:self.m.COMET.digest(p.read_bytes())}
            self.m.require_stable(watched, 'inputs')
            p.write_bytes(b'changed')
            with self.assertRaisesRegex(ValueError, 'inputs changed'):
                self.m.require_stable(watched, 'inputs')
            p.unlink()
            with self.assertRaises(ValueError):
                self.m.require_stable(watched, 'inputs')

    def test_private_fault_is_unique_and_actual_same_copy_restoration_required(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);source=root/'source';p=source/self.m.FAULT_PATH;p.parent.mkdir(parents=True)
            p.write_text('before\n'+self.m.FAULT_BEFORE+'after\n')
            raw=p.read_bytes();manifest={'schema':'etna-source-snapshot-1','commit':'a'*40,'files':{self.m.FAULT_PATH:self.m.COMET.file_entry(raw)}}
            private=root/'private';mutant=self.m.private_fault(source,private,manifest)
            self.assertEqual(p.read_bytes(),raw)
            self.assertNotEqual((private/self.m.FAULT_PATH).read_bytes(),raw)
            self.m.COMET.verify_snapshot(private,mutant,'a'*40)
            self.m.restore_source(private,source,manifest,'a'*40)
            self.assertEqual((private/self.m.FAULT_PATH).read_bytes(),raw)
            with self.assertRaisesRegex(ValueError, 'faulted source'):
                self.m.restore_source(private,source,manifest,'a'*40)
            p.write_text(self.m.FAULT_BEFORE*2)
            with self.assertRaisesRegex(ValueError, 'exactly once'):
                self.m.private_fault(source,root/'duplicate',manifest)
            p.write_text('selector missing')
            with self.assertRaisesRegex(ValueError, 'exactly once'):
                self.m.private_fault(source,root/'absent',manifest)

    def test_shared_source_verifier_rejects_extra_missing_changed_and_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);p=root/'source.go';p.write_bytes(b'original')
            manifest={'schema':'etna-source-snapshot-1','commit':'a'*40,'files':{'source.go':self.m.COMET.file_entry(p.read_bytes())}}
            self.m.COMET.verify_snapshot(root,manifest,'a'*40)
            extra=root/'extra';extra.write_bytes(b'extra')
            with self.assertRaises(ValueError):self.m.COMET.verify_snapshot(root,manifest,'a'*40)
            extra.unlink();p.write_bytes(b'changed')
            with self.assertRaises(ValueError):self.m.COMET.verify_snapshot(root,manifest,'a'*40)
            p.unlink()
            with self.assertRaises(ValueError):self.m.COMET.verify_snapshot(root,manifest,'a'*40)
            p.symlink_to('absent')
            with self.assertRaises(ValueError):self.m.COMET.verify_snapshot(root,manifest,'a'*40)

    def test_shared_layout_rejects_aliases_and_does_not_create_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);paths={name:root/name for name in ('source','go_root','module_cache','build_cache')}
            for p in paths.values():p.mkdir()
            args=SimpleNamespace(**paths,output=paths['build_cache']/'output',timeout=1)
            with self.assertRaises(ValueError):self.m.COMET.validate_layout(args,{})
            self.assertFalse(args.output.exists())
            alias=root/'alias';alias.symlink_to(paths['build_cache'],target_is_directory=True)
            args.output=alias/'output'
            with self.assertRaises(ValueError):self.m.COMET.validate_layout(args,{})
            args.output=root/'output';self.m.COMET.validate_layout(args,{})
            self.assertFalse(args.output.exists())

    def test_executed_modfile_change_cannot_earn_native_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'source'
            source.mkdir()
            (source / 'sample.go').write_bytes(b'package sample\n')
            manifest = {'schema': 'etna-source-snapshot-1', 'commit': 'a' * 40,
                        'files': {'sample.go': self.m.COMET.file_entry((source / 'sample.go').read_bytes())}}
            args = SimpleNamespace(output=root / 'output', go_root=root / 'sdk',
                                   module_cache=root / 'modules', build_cache=root / 'cache', timeout=1)
            def change_executed_input(*unused):
                (args.output / 'normal/modfiles/go.mod').write_text('changed during execution')
                return {'returncode': 0, 'timeout': False, 'supervisor_argv': ['shared-supervisor'],
                        'output': stream(events()).decode()}
            with mock.patch.object(self.m.COMET.EXECUTION, 'execute', side_effect=change_executed_input):
                with self.assertRaisesRegex(ValueError, 'executed modfile/sum changed'):
                    self.m.run_trial('normal', source, manifest, args, {'source': {'commit': 'a' * 40}}, {}, {})
            record = json.loads((args.output / 'normal/execution.json').read_bytes())
            self.assertNotIn('outcomes', record)
            self.assertFalse((args.output / 'summary.json').exists())

    def test_supervisor125_cannot_emit_admission_outcomes_or_summary(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);source=root/'source';source.mkdir();p=source/'sample.go';p.write_bytes(b'package sample\n')
            manifest={'schema':'etna-source-snapshot-1','commit':'a'*40,'files':{'sample.go':self.m.COMET.file_entry(p.read_bytes())}}
            args=SimpleNamespace(output=root/'output',go_root=root/'sdk',module_cache=root/'modules',build_cache=root/'cache',timeout=1)
            result={'returncode':125,'timeout':False,'supervisor_argv':['shared-supervisor'],'output':stream(events()).decode()}
            with mock.patch.object(self.m.COMET.EXECUTION,'execute',return_value=result):
                with self.assertRaisesRegex(ValueError,'cleanup failed.*125'):
                    self.m.run_trial('normal',source,manifest,args,{'source':{'commit':'a'*40}}, {}, {})
            record=json.loads((args.output/'normal/execution.json').read_bytes())
            self.assertEqual(record['returncode'],125)
            self.assertNotIn('outcomes',record)
            self.assertFalse((args.output/'summary.json').exists())


if __name__ == '__main__':
    unittest.main()
