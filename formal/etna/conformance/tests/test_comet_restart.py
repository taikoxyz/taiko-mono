"""Restart collector controls: incomplete/wrong-reason native evidence is rejected."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'run_comet_restart.py'
PARENT = 'TestCheckpointRestart'
PACKAGE = 'example.org/etna-comet-restart'
NAMES = ('origin-clean-close', 'current-clean-close', 'origin-kill-after-ack',
         'current-kill-after-ack', 'readiness-no-ack', 'readiness-wrong-child',
         'readiness-failed-worker', 'observer-controls')


def event(action, identity=None, output=None):
    row = dict(Action=action, Package=PACKAGE)
    if identity is not None:
        row['Test'] = identity
    if output is not None:
        row['Output'] = output
    return row


def receipt(name, mutant=False):
    if name.startswith('readiness-'):
        return dict(kind='readiness', name=name, reason={'readiness-no-ack': 'no-ack',
                    'readiness-wrong-child': 'wrong-child', 'readiness-failed-worker': 'worker-failed'}[name],
                    readerStarted=False, ownedChildReaped=True)
    if name == 'observer-controls':
        return dict(kind='observer-controls', name=name,
                    detected=['missing-state', 'missing-validator-history', 'wrong-state-field', 'wrong-validator-priority'])
    origin = name.startswith('origin-')
    rows = [3, 4] if origin else [4, 5, 6]
    mode = 'clean-close' if name.endswith('clean-close') else 'kill-after-ack'
    return dict(kind='persistence', name=name, case='origin-base' if origin else 'current-base',
                mode=mode, directory='/tmp/output/databases/' + name,
                parentPID=10, writerPID=11, readerPID=12, bootstrapCompleted=True,
                writerStop='closed' if mode == 'clean-close' else 'SIGKILL', readerReopened=True,
                statePresent=not mutant, missingRows=rows if mutant else [],
                paramsPresent=not mutant, validatorRows=rows, paramsRow=3 if origin else 5,
                observation=None if mutant else copy.deepcopy(json.loads((ROOT/'comet_restart/literal_observations.json').read_bytes())['origin-base' if origin else 'current-base']))


def events(mutant=False):
    rows = [event('start'), event('run', PARENT), event('output', PARENT, '=== RUN   ' + PARENT + '\n')]
    for name in NAMES:
        identity = PARENT + '/' + name
        failed = mutant and name in NAMES[:4]
        rows += [event('run', identity), event('output', identity, '=== RUN   ' + identity + '\n'),
                 event('output', identity, '    restart_test.go:42: receipt=' + json.dumps(receipt(name, failed), separators=(',', ':')) + '\n')]
        if failed:
            origin = name.startswith('origin-')
            message = 'missing-bootstrap-batch id=' + ('origin-base state=absent validators=3,4 params=3' if origin else 'current-base state=absent validators=4,5,6 params=5')
            rows.append(event('output', identity, '    restart_test.go:99: ' + message + '\n'))
        action = 'FAIL' if failed else 'PASS'
        rows += [event('output', identity, '--- ' + action + ': ' + identity + ' (0.01s)\n'),
                 event(action.lower(), identity)]
    action = 'FAIL' if mutant else 'PASS'
    rows += [event('output', PARENT, '--- ' + action + ': ' + PARENT + ' (0.10s)\n'),
             event(action.lower(), PARENT), event('output', output=action + '\n')]
    rows.append(event('output', output=('FAIL\t' if mutant else 'ok  \t') + PACKAGE + '\t0.100s\n'))
    rows.append(event(action.lower()))
    return rows


def stream(rows):
    return '\n'.join(json.dumps(row) for row in rows).encode()


class RestartCollectorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module = None
        if PATH.exists():
            spec = importlib.util.spec_from_file_location('etna_restart_tests', PATH)
            cls.module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(cls.module)

    def setUp(self):
        self.assertIsNotNone(self.module, 'restart collector has not been implemented')
        self.m = self.module

    def test_exact_native_phases_require_all_eight(self):
        for phase in ('normal', 'mutant', 'restored'):
            result = self.m.require_go_outcomes(stream(events(phase == 'mutant')), int(phase == 'mutant'), phase)
            self.assertEqual(set(result), {PARENT + '/' + name for name in NAMES})

    def test_empty_duplicate_skipped_missing_unexpected_wrong_package_fail_closed(self):
        base = events()
        variants = [[], base[1:], base + [base[3]], base[:3] + base[8:]]
        for index, field, value in [(3, 'Action', 'skip'), (3, 'Test', 'TestOther'),
                                    (3, 'Package', 'other'), (7, 'Action', 'fail')]:
            rows = copy.deepcopy(base); rows[index][field] = value; variants.append(rows)
        for rows in variants:
            with self.assertRaises(ValueError):
                self.m.require_go_outcomes(stream(rows), 0, 'normal')
        with self.assertRaises(ValueError):
            self.m.require_go_outcomes(b'not JSON', 0, 'normal')
        with self.assertRaises(ValueError):
            self.m.require_go_outcomes(stream(base), 0, 'unknown')
        raw = stream(base).replace(b'"Action": "start"', b'"Action":"fail","Action":"start"', 1)
        with self.assertRaises(ValueError):
            self.m.require_go_outcomes(raw, 0, 'normal')

    def test_extra_diagnostics_frames_and_wrong_outputtype_rejected_in_all_scopes(self):
        for mutant in (False, True):
            base = events(mutant)
            phase = 'mutant' if mutant else 'normal'
            for scope in (PARENT, None, PARENT + '/' + NAMES[-1]):
                rows = copy.deepcopy(base)
                index = next(i for i, row in enumerate(rows) if row.get('Test') == scope and row['Action'] == 'output')
                rows.insert(index, event('output', scope, '    restart_test.go:91: unrelated cleanup error\n'))
                with self.assertRaises(ValueError):
                    self.m.require_go_outcomes(stream(rows), int(mutant), phase)
                rows = copy.deepcopy(base); rows[index]['OutputType'] = 'error'
                with self.assertRaises(ValueError):
                    self.m.require_go_outcomes(stream(rows), int(mutant), phase)

    def test_ack_identity_same_disk_reopen_and_row_contracts_are_required(self):
        for name in NAMES[:4]:
            for field, value in [('writerPID', 12), ('readerPID', 10), ('directory', '/tmp/fresh-database'),
                                 ('bootstrapCompleted', False), ('readerReopened', False),
                                 ('writerStop', 'SIGTERM'), ('statePresent', False), ('paramsRow', 99),
                                 ('missingRows', [4]), ('validatorRows', []), ('observation', None)]:
                rows = events(); index = next(i for i,r in enumerate(rows) if 'receipt=' in r.get('Output', '') and r.get('Test') == PARENT + '/' + name)
                data = receipt(name); data[field] = value
                rows[index]['Output'] = '    restart_test.go:42: receipt=' + json.dumps(data) + '\n'
                with self.assertRaises(ValueError, msg=(name, field)):
                    self.m.require_go_outcomes(stream(rows), 0, 'normal')

    def test_complete_literal_observation_is_required_not_only_height_and_row_metadata(self):
        data=receipt('current-clean-close')
        data['observation']['state']['AppHash']='wrong-app-hash'
        with self.assertRaises(ValueError):
            self.m.require_receipt(data,'current-clean-close',False)
        data=receipt('current-clean-close')
        data['observation']['validators'][0]['set']={'Members':[],'Total':0,'Proposer':{}}
        with self.assertRaises(ValueError):
            self.m.require_receipt(data,'current-clean-close',False)

    def test_mutant_only_exact_all_missing_batch_diagnostics_are_admissible(self):
        base = events(True)
        for fragment, replacement in [('state=absent', 'state=corrupt'), ('validators=3,4', 'validators=3'),
                                      ('params=5', 'params=4'), ('missing-bootstrap-batch', 'setup-failed')]:
            rows = copy.deepcopy(base)
            for row in rows:
                if fragment in row.get('Output', ''):
                    row['Output'] = row['Output'].replace(fragment, replacement, 1); break
            with self.assertRaises(ValueError):
                self.m.require_go_outcomes(stream(rows), 1, 'mutant')
        for code in (0, 2, 124, 125):
            with self.assertRaises(ValueError):
                self.m.require_go_outcomes(stream(base), code, 'mutant')

    def test_recorded_actual_mutant_stream_and_optional_outputtype(self):
        raw=(ROOT/'comet_restart/mutant.jsonl').read_bytes()
        self.assertEqual(self.m.COMET.digest(raw), 'ba79b8472fd43af9934bf899762ae46ba5e9c5dbbfbd71fcdc72c0d29295401c')
        self.assertEqual(len(self.m.require_go_outcomes(raw,1,'mutant')),8)
        rows=[json.loads(line) for line in raw.splitlines()]
        for row in rows: row.pop('OutputType',None)
        self.assertEqual(len(self.m.require_go_outcomes(stream(rows),1,'mutant')),8)

    def test_readiness_boolean_fields_cannot_be_numeric_aliases(self):
        for field,value in [('readerStarted',0),('ownedChildReaped',1)]:
            data=receipt('readiness-no-ack');data[field]=value
            with self.assertRaises(ValueError): self.m.require_receipt(data,'readiness-no-ack',False)

    def test_frozen_inputs_reuse_exact_old_helpers_and_literal_fixture(self):
        pins,manifest,watched=self.m.inputs()
        self.assertEqual(manifest['commit'],pins['source']['commit'])
        for relative in ('comet_bootstrap/bootstrap_test.go','comet_bootstrap/mapping_vectors.json','comet_restart/literal_observations.json'):
            self.assertEqual(self.m.COMET.digest((ROOT/relative).read_bytes()),pins['inputsSha256'][relative])
            self.assertIn(ROOT/relative,watched)

    def test_shared_layout_rejects_canonical_output_cache_aliases(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); paths={name:root/name for name in ('source','go_root','module_cache','build_cache')}
            for path in paths.values(): path.mkdir()
            args=SimpleNamespace(**paths,output=paths['build_cache']/'output',timeout=1)
            with self.assertRaises(ValueError): self.m.COMET.validate_layout(args,{})
            alias=root/'alias';alias.symlink_to(paths['build_cache'],target_is_directory=True)
            args.output=alias/'output'
            with self.assertRaises(ValueError): self.m.COMET.validate_layout(args,{})
            args.output=root/'output';self.m.COMET.validate_layout(args,{})
            self.assertFalse(args.output.exists())

    def test_private_fault_omits_entire_call_and_restores_same_copy(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); source = root/'source'; path = source/'state/store.go'; path.parent.mkdir(parents=True)
            path.write_text('before\n' + self.m.FAULT_BEFORE + 'after\n')
            raw = path.read_bytes(); manifest = {'schema':'etna-source-snapshot-1','commit':'a'*40,
                'files':{'state/store.go':self.m.COMET.file_entry(raw)}}
            private = root/'private'; mutant = self.m.private_fault(source, private, manifest)
            self.assertEqual(path.read_bytes(), raw)
            self.assertNotIn('batch.WriteSync()', (private/'state/store.go').read_text())
            self.m.restore_source(private, source, manifest, 'a'*40)
            self.assertEqual((private/'state/store.go').read_bytes(), raw)
            self.m.COMET.verify_snapshot(private, manifest, 'a'*40)
            with self.assertRaises(ValueError): self.m.restore_source(private, source, manifest, 'a'*40)
            path.write_text(self.m.FAULT_BEFORE * 2)
            with self.assertRaises(ValueError): self.m.private_fault(source, root/'duplicate', manifest)

    def test_private_build_root_contains_unmodified_module_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); source=root/'source'; source.mkdir(); p=source/'sample.go'; p.write_text('package sample\n')
            manifest={'schema':'etna-source-snapshot-1','commit':'a'*40,'files':{'sample.go':self.m.COMET.file_entry(p.read_bytes())}}
            args=SimpleNamespace(output=root/'output',go_root=root/'sdk',module_cache=root/'modules',build_cache=root/'cache',timeout=1,scenario='persistence')
            def inspect(*unused):
                for name in ('go.mod','go.sum'):
                    path=args.output/'normal/inputs'/name
                    self.assertTrue(path.is_file(), 'private build root needs '+name)
                    self.assertEqual(path.read_bytes(),(ROOT/'comet_restart'/name).read_bytes())
                return dict(returncode=0,timeout=False,supervisor_argv=['shared-supervisor'],output=stream(events()).decode())
            with mock.patch.object(self.m.COMET.EXECUTION,'execute',side_effect=inspect):
                self.m.run_trial('normal',source,manifest,args,{'source':{'commit':'a'*40},'receipt':{'file':'checkpoint_import_cases.json','sha256':'a'*64}}, {}, {})

    def test_reported_timeout_cannot_earn_outcomes_even_with_a_pass_stream(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);source=root/'source';source.mkdir();p=source/'sample.go';p.write_text('package sample\n')
            manifest={'schema':'etna-source-snapshot-1','commit':'a'*40,'files':{'sample.go':self.m.COMET.file_entry(p.read_bytes())}}
            args=SimpleNamespace(output=root/'output',go_root=root/'sdk',module_cache=root/'modules',build_cache=root/'cache',timeout=1,scenario='persistence')
            result=dict(returncode=0,timeout=True,supervisor_argv=['shared-supervisor'],output=stream(events()).decode())
            with mock.patch.object(self.m.COMET.EXECUTION,'execute',return_value=result):
                with self.assertRaisesRegex(ValueError,'timeout'):
                    self.m.run_trial('normal',source,manifest,args,{'source':{'commit':'a'*40},'receipt':{'file':'checkpoint_import_cases.json','sha256':'a'*64}}, {}, {})
            self.assertNotIn('outcomes',json.loads((args.output/'normal/execution.json').read_bytes()))

    def test_changed_private_build_input_or_supervisor125_cannot_earn_outcomes(self):
        for code, drift in [(125, None),*[(0, name) for name in ('inputs/bootstrap_test.go','inputs/restart_test.go','inputs/mapping_vectors.json','inputs/go.mod','inputs/go.sum','modfiles/go.mod','modfiles/go.sum')]]:
            with tempfile.TemporaryDirectory() as directory:
                root=Path(directory); source=root/'source'; source.mkdir(); p=source/'sample.go'; p.write_text('package sample\n')
                manifest={'schema':'etna-source-snapshot-1','commit':'a'*40,'files':{'sample.go':self.m.COMET.file_entry(p.read_bytes())}}
                args=SimpleNamespace(output=root/'output',go_root=root/'sdk',module_cache=root/'modules',build_cache=root/'cache',timeout=1,scenario='persistence')
                def result(*unused):
                    if drift: (args.output/'normal'/drift).write_text('changed')
                    return dict(returncode=code, timeout=False, supervisor_argv=['shared-supervisor'], output=stream(events()).decode())
                with mock.patch.object(self.m.COMET.EXECUTION,'execute',side_effect=result):
                    with self.assertRaises(ValueError):
                        self.m.run_trial('normal',source,manifest,args,{'source':{'commit':'a'*40},'receipt':{'file':'checkpoint_import_cases.json','sha256':'a'*64}}, {}, {})
                self.assertFalse((args.output/'summary.json').exists())


if __name__ == '__main__': unittest.main()
