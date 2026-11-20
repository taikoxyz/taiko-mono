"""Actual publication identity, typed fields, parser and freshness controls."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest
import tempfile
from types import SimpleNamespace
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]


class CheckpointImportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not (ROOT / 'export_checkpoint_import.py').is_file():
            raise AssertionError('actual checkpoint import exporter missing')
        spec = importlib.util.spec_from_file_location('export_checkpoint_import', ROOT / 'export_checkpoint_import.py')
        cls.export = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.export)

    def fixture(self):
        return json.loads((ROOT / 'checkpoint_import_cases.json').read_text())

    def rehash(self, value):
        value['content_sha256'] = self.export.content_digest(value)
        return value

    def test_inherited_nested_parser_and_set_canonicalization(self):
        parse = self.export.ImportValueParser
        self.assertEqual(parse('[x |-> <<-2, 2..4, {"el", "app"}, {}>>, y |-> ("a" :> <<1,-1>>)]').value(),
                         {'x': [-2, [2, 3, 4], ['app', 'el'], []], 'y': {'a': [1, -1]}})
        self.assertEqual(parse('{<<2,1>>,<<1,2>>}').value(), [[1, 2], [2, 1]])
        self.assertEqual(parse('4..2').value(), [])
        for bad in ('{1,1}', '{[a |-> 1],[a |-> 1]}', '[a |-> 1,a |-> 2]', '2..TRUE', '2..', '{1,}', '<<-2,>>', '0..1000000000'):
            with self.subTest(bad=bad), self.assertRaises(ValueError): parse(bad).value()

    def test_ranges_and_explicit_sets_have_one_canonical_order(self):
        parse = self.export.ImportValueParser
        for lower, upper in ((2, 12), (-2, -1), (-12, 2)):
            explicit = '{' + ','.join(str(n) for n in range(lower, upper + 1)) + '}'
            self.assertEqual(parse(str(lower) + '..' + str(upper)).value(), parse(explicit).value())
        self.assertEqual(parse('<<12,2,-1,-2>>').value(), [12, 2, -1, -2])

    def test_literal_actual_genesis_and_landed_stores(self):
        data = self.fixture(); self.export.validate(data)
        expected = {
            'origin-base': (2, 0, [3, 2], [-2, 2], 1, [3, 2], [1, -1], 2),
            'origin-landed-alternate': (2, 11, [3, 2], [-2, 2], 1, [3, 2], [1, -1], 2),
            'current-base': (4, 0, [3, 2], [-1, 1], 1, [2, 4], [2, -1], 2),
            'current-first-alternate': (4, 11, [3, 5], [4, -4], 2, [2, 4], [-1, 1], 2),
            'current-second-alternate': (4, 20, [3, 2], [-1, 1], 1, [3, 4], [2, -2], 2)}
        for case in data['cases']:
            h, raw, powers, pri, proposer, nxtpowers, nxt, nxtprop = expected[case['id']]
            self.assertEqual((case['import_height'], case['target_height'], case['raw_case']), (h, h, raw))
            o = case['observation']; stores = o['publication']['stores']; c = stores['comet']; p = o['raw']['peer']
            self.assertEqual((c['height'], c['time'], c['initialHeight']), (0, 100, 3) if h == 2 else (4, 102, 3))
            self.assertEqual((c['validators']['priorities'], c['validators']['proposer'], c['next']['priorities'], c['next']['proposer']), (pri, proposer, nxt, nxtprop))
            self.assertEqual(stores['app']['recorded'], {'first': c['validators'], 'second': c['next']})
            self.assertEqual(stores['app']['active'], [[1, 2], powers])
            self.assertEqual(stores['app']['pending'], [[1, 2] if h == 2 else [2, 3], nxtpowers])
            self.assertEqual(stores['el'], {'height': h, 'hash': ['EL', h], 'state': ['State', h], 'ancestors': [2] if h == 2 else [2, 3, 4], 'fi': 1})
            self.assertEqual((stores['app']['appHash'], c['appHash'], c['chain'], stores['app']['chain']), (['EL', h], ['EL', h], ['Chain', 1], ['Chain', 1]))
            self.assertEqual((c['valChanged'], c['paramsChanged']), (3, 3) if h == 2 else (6, 5))
            self.assertEqual((c['last'], c['results']), ([], []) if h == 2 else (['WindowValidators', 4], ['FixedExecTxResult']))
            self.assertEqual(stores['evidence'], {'markers': [] if h == 2 else [['Evidence', 3]], 'validators': [] if h == 2 else ['WindowValidators', 4], 'commits': [] if h == 2 else ['WindowCommits', 4]})
            self.assertEqual((p['header']['height'], p['header']['chain'], p['header']['time']), (2, ['Chain', 0], 20) if h == 2 else (4, ['Chain', 1], 102))
            self.assertEqual((p['preimage']['first']['priorities'], p['preimage']['first']['proposer']), ([4, -4], 2) if raw == 11 else ([-1, 1], 1))
            self.assertEqual(c['blockID'], [] if h == 2 else o['raw']['l1']['comet'])
            self.assertEqual((stores['app']['height'], stores['app']['initialHeight'], stores['app']['fi']), (0 if h == 2 else 4, 3, 1))
            self.assertEqual((c['validators']['keys'], c['validators']['powers']), ([1, 2], powers))
            self.assertEqual((c['next']['keys'], c['next']['powers']), ([1, 2] if h == 2 else [2, 3], nxtpowers))
            raw_first = [3, 5] if raw == 11 else [3, 2]
            raw_second = [3, 4] if raw == 20 else [2, 4]
            entries = [[[1, 2], raw_first], [[2, 3], raw_second]]
            l1 = o['raw']['l1']; header = p['header']; window = p['window']
            self.assertEqual((l1['generation'], l1['origin'], l1['originTime'], l1['recordGeneration'], l1['finalized'], l1['fi']), (1, 2, 100, 0 if h == 2 else 1, True, 1))
            self.assertEqual((l1['el'], l1['state'], p['el'], p['state'], p['computedState'], p['present']), (['EL', h], ['State', h], ['EL', h], ['State', h], ['State', h], True))
            self.assertEqual((p['envelope'], header['data'], header['next'], header['appHash']), ({'execution': ['EL', h]}, ['Hash', {'execution': ['EL', h]}], ['Validators', [[1, 2], raw_first]], ['EL', h - 1]))
            self.assertEqual(window, {'ancestors': [2] if h == 2 else [2, 3, 4], 'evidence': [] if h == 2 else [['Evidence', 3]], 'validators': ['WindowValidators', h], 'commits': ['WindowCommits', h]})
            self.assertEqual((p['ancestors'], p['evidence'], header['window']), (window['ancestors'], window['evidence'], ['Hash', window]))
            self.assertEqual((l1['comet'], l1['val'], l1['registry']), (['Hash', header], ['Hash', p['preimage']], ['Hash', entries]))
            self.assertEqual(p['entries'], entries)
            self.assertEqual((p['preimage']['first']['keys'], p['preimage']['first']['powers'], p['preimage']['second']['keys'], p['preimage']['second']['powers']), ([1, 2], raw_first, [2, 3], raw_second))
            self.assertEqual((p['preimage']['second']['priorities'], p['preimage']['second']['proposer']), ([2, -2], 2) if raw == 20 else ([-1, 1], 2) if raw == 11 else ([2, -1], 2))

    def test_case_completeness_and_typed_observation_requirements(self):
        for edit in (lambda c: c.pop(), lambda c: c.__setitem__(0, c[1]), lambda c: c[0].__setitem__('id', 'unknown')):
            data = self.fixture(); edit(data['cases'])
            with self.assertRaises(ValueError): self.export.validate(self.rehash(data))
        for path, value in [(('raw','l1','height'), True), (('publication','stores','comet','validators','proposer'), True),
                            (('atPublication','trusted'), 0), (('atPublication','hrs'), [1,9,True]),
                            (('terminal','actions'), True), (('steps',0,'enabled'), 1),
                            (('publication','present'), False), (('atPublication','durable'), []),
                            (('steps',), []), (('terminal','pc'), 9)]:
            data = self.fixture(); target = data['cases'][0]['observation']
            for key in path[:-1]: target = target[key]
            target[path[-1]] = value
            with self.subTest(path=path), self.assertRaises(ValueError): self.export.validate(self.rehash(data))
        for path in [('raw','peer','window'), ('publication','stores','evidence','commits')]:
            data = self.fixture(); target = data['cases'][0]['observation']
            for key in path[:-1]: target = target[key]
            del target[path[-1]]
            with self.assertRaises(ValueError): self.export.validate(self.rehash(data))

    def test_provenance_and_rehashed_actual_mismatch(self):
        actual = self.fixture()
        for key in actual['provenance']:
            data = copy.deepcopy(actual); data['provenance'][key] = 'changed'
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'provenance'): self.export.validate(self.rehash(data))
        for section, key in [('sources_sha256','EtnaCheckpointImport.tla'), ('configs_sha256','origin-base')]:
            data = copy.deepcopy(actual); data['provenance'][section][key] = 'changed'
            with self.assertRaisesRegex(ValueError, 'provenance'): self.export.validate(self.rehash(data))
        for path in [('raw','peer','header','time'), ('raw','l1','originTime'), ('raw','peer','preimage','first','priorities',0),
                     ('publication','stores','el','fi'), ('publication','stores','app','height'), ('publication','stores','comet','next','priorities',1)]:
            data = copy.deepcopy(actual); target = data['cases'][2]['observation']
            for key in path[:-1]: target = target[key]
            target[path[-1]] += 1
            with self.subTest(path=path), self.assertRaises(ValueError): self.export.compare_fixture(actual, self.rehash(data))
        self.assertNotEqual(self.export.canonical({'x': True}), self.export.canonical({'x': 1}))
        data = copy.deepcopy(actual); data['cases'][0]['observation']['raw']['l1']['fi'] = 0
        with self.assertRaisesRegex(ValueError, 'changed observations'): self.export.validate(data)

    def test_exact_single_print_and_exhaustion_required(self):
        good = 'Model checking completed. No error has been found.\n0 states left on queue.\n'
        row = '<<"ETNA_CHECKPOINT_IMPORT","origin-base",[terminal |-> [pc |-> 10]]>>\n'
        self.assertEqual(self.export.parse_receipts(row+good, 'origin-base')['terminal']['pc'], 10)
        for bad in (good, row+row+good, row, row+good+'Error: fail\n', row.replace('origin-base','wrong')+good, row.replace('>>\n','>> garbage\n')+good, row+'garbage\n'+good, row+'\"ETNA_CHECKPOINT_IMPORT\" malformed\n'+good):
            with self.subTest(bad=bad[-50:]), self.assertRaises(ValueError): self.export.parse_receipts(bad, 'origin-base')

    def test_source_and_jar_drift_during_execution_fail(self):
        export = self.export
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            paths = {key: work / key for key in ('model', 'parser', 'pins', 'exporter')}
            for path in paths.values(): path.write_text('original')
            jar = work / 'tools.jar'
            for target in (paths['model'], jar):
                jar.write_bytes(b'tool')
                paths['model'].write_text('original')
                def drift(*args, **kwargs):
                    target.write_text('changed')
                    return SimpleNamespace(returncode=0, stdout='', stderr='')
                with mock.patch.object(export, 'INPUTS', tuple(paths.values())), \
                     mock.patch.object(export, 'MODEL', paths['model']), \
                     mock.patch.object(export, 'TLC_SHA', export.digest(jar.read_bytes())), \
                     mock.patch.object(export.subprocess, 'run', side_effect=drift):
                    with self.assertRaisesRegex(ValueError, 'inputs changed'):
                        export.generate('/configured/java', jar)

    def test_check_cli_regenerates_before_comparison(self):
        actual = self.fixture()
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / 'fixture.json'
            fixture.write_text(json.dumps(actual))
            argv = ['export_checkpoint_import', '--java', '/configured/java', '--jar', '/configured/tlc.jar',
                    '--output', str(fixture), '--check']
            with mock.patch.object(self.export, 'generate', return_value=actual) as generate, \
                 mock.patch.object(self.export, 'compare_fixture', wraps=self.export.compare_fixture) as compare, \
                 mock.patch('sys.argv', argv), mock.patch('builtins.print'):
                self.export.main()
            generate.assert_called_once_with('/configured/java', '/configured/tlc.jar', None)
            compare.assert_called_once()

    def test_check_cli_rejects_conflicting_outer_and_nested_json_keys(self):
        actual = self.fixture()
        raw = (ROOT / 'checkpoint_import_cases.json').read_text()
        variants = (
            raw.replace('"schema": "etna-checkpoint-import-replay-1"',
                        '"schema": 0, "schema": "etna-checkpoint-import-replay-1"', 1),
            raw.replace('"finalized": true', '"finalized": 0, "finalized": true', 1),
        )
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / 'fixture.json'
            for value in variants:
                self.assertNotEqual(value, raw)
                fixture.write_text(value)
                argv = ['export_checkpoint_import', '--java', '/configured/java', '--jar', '/configured/tlc.jar',
                        '--output', str(fixture), '--check']
                with self.subTest(outer='"schema": 0' in value), \
                     mock.patch.object(self.export, 'generate', return_value=actual) as generate, \
                     mock.patch('sys.argv', argv), mock.patch('builtins.print'):
                    with self.assertRaisesRegex(ValueError, 'duplicate JSON field'):
                        self.export.main()
                    generate.assert_called_once_with('/configured/java', '/configured/tlc.jar', None)

    def test_executed_copies_are_stable_after_each_run(self):
        observations = {c['id']: c['observation'] for c in self.fixture()['cases']}
        with tempfile.TemporaryDirectory() as directory:
            jar = Path(directory) / 'tools.jar'; jar.write_bytes(b'tool')
            for target in (None, 'EtnaCheckpointImport.tla', 'EtnaCheckpointImportExport.tla', 'Export.cfg'):
                def execute(*args, **kwargs):
                    if target is not None:
                        path = Path(kwargs['cwd']) / target
                        path.write_bytes(path.read_bytes() + b'\n\\* executed-copy drift\n')
                    return SimpleNamespace(returncode=0, stdout='mocked process boundary', stderr='')
                with self.subTest(target=target), \
                     mock.patch.object(self.export, 'TLC_SHA', self.export.digest(jar.read_bytes())), \
                     mock.patch.object(self.export.subprocess, 'run', side_effect=execute) as run, \
                     mock.patch.object(self.export, 'parse_receipts', side_effect=lambda log, name: observations[name]) as parse:
                    if target is None:
                        self.assertEqual(len(self.export.generate('/configured/java', jar)['cases']), 5)
                        self.assertEqual(run.call_count, 5)
                        self.assertEqual(parse.call_count, 5)
                    else:
                        with self.assertRaisesRegex(ValueError, 'executed copies changed'):
                            self.export.generate('/configured/java', jar)
                        parse.assert_not_called()
                        self.assertEqual(run.call_count, 1)

    def test_executed_model_and_wrapper_are_checked_before_next_run(self):
        observations = {c['id']: c['observation'] for c in self.fixture()['cases']}
        with tempfile.TemporaryDirectory() as directory:
            jar = Path(directory) / 'tools.jar'; jar.write_bytes(b'tool')
            for target in ('EtnaCheckpointImport.tla', 'EtnaCheckpointImportExport.tla'):
                work = []
                def execute(*args, **kwargs):
                    work.append(Path(kwargs['cwd']))
                    return SimpleNamespace(returncode=0, stdout='mocked process boundary', stderr='')
                def between_runs(log, name):
                    path = work[-1] / target
                    path.write_bytes(path.read_bytes() + b'\n\\* between-run drift\n')
                    return observations[name]
                with self.subTest(target=target), \
                     mock.patch.object(self.export, 'TLC_SHA', self.export.digest(jar.read_bytes())), \
                     mock.patch.object(self.export.subprocess, 'run', side_effect=execute) as run, \
                     mock.patch.object(self.export, 'parse_receipts', side_effect=between_runs):
                    with self.assertRaisesRegex(ValueError, 'executed copies changed'):
                        self.export.generate('/configured/java', jar)
                    self.assertEqual(run.call_count, 1)


if __name__ == '__main__': unittest.main()
