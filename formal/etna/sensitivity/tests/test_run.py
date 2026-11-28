import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('campaign', Path(__file__).parents[1] / 'run.py')
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)

STATS = '3 states generated, 2 distinct states found, 0 states left on queue.\n'
PASS = 'Model checking completed. No error has been found.\n' + STATS
FAIL = 'Error: Invariant Binding is violated.\nError: The behavior up to this point is:\n' + STATS

class Classification(unittest.TestCase):
    def test_tlc_named_only(self):
        intended = {'kind': 'invariant', 'name': 'Binding'}
        self.assertEqual(r.classify_tlc(12, FAIL, intended), 'KILLED')
        self.assertEqual(r.classify_tlc(0, PASS, intended), 'SURVIVED')
        for code, text in [(12, FAIL.replace('Binding', 'Other')), (1, 'parsing error'),
                           (12, FAIL + 'Error: Parsing failed\n'), (124, FAIL), (12, 'Error: Invariant Binding is violated.\n')]:
            self.assertEqual(r.classify_tlc(code, text, intended), 'INCONCLUSIVE')
    def test_temporal_sole_declared_property(self):
        intended = {'kind': 'property', 'name': 'EventuallyConnected'}
        out = 'Error: Temporal properties were violated.\n\nError: The following behavior constitutes a counter-example:\nState 2: Stuttering\n' + STATS
        self.assertEqual(r.classify_tlc(13, out, intended, config_text='PROPERTY EventuallyConnected'), 'KILLED')
        for cfg in ['PROPERTY Other', 'PROPERTIES\n EventuallyConnected\n Other', '', 'PROPERTY EventuallyConnected\nPROPERTY EventuallyConnected']:
            self.assertEqual(r.classify_tlc(13, out, intended, config_text=cfg), 'INCONCLUSIVE')
    def test_forge_requires_exact_ids_and_reason(self):
        test = 'a.sol:A::test_x()'
        failure = {'kind': 'forge', 'failures': {test: 'publication mismatch'}}
        def output(status, reason=None):
            return json.dumps({'a.sol:A': {'test_results': {'test_x()': {'status': status, 'reason': reason}}}})
        self.assertEqual(r.classify_forge(0, output('Success'), [test], failure), 'SURVIVED')
        self.assertEqual(r.classify_forge(1, output('Failure', 'publication mismatch'), [test], failure), 'KILLED')
        for code, out, ids in [(0, '{}', [test]), (1, output('Failure', 'other'), [test]),
                               (1, output('Failure', 'publication mismatch'), ['wrong']),
                               (124, output('Failure', 'publication mismatch'), [test]),
                               (0, '{}', []), (0, output('Skipped'), [test])]:
            self.assertEqual(r.classify_forge(code, out, ids, failure), 'INCONCLUSIVE')
    def test_duplicate_json_test_rejected(self):
        out = '{"a":{"test_results":{"x":{"status":"Success"},"x":{"status":"Success"}}}}'
        self.assertEqual(r.classify_forge(0, out, ['a::x'], {}), 'INCONCLUSIVE')

class Validation(unittest.TestCase):
    def test_unique_replacement_and_paths(self):
        self.assertEqual(r.replace_once('guard', 'guard', 'FALSE'), 'FALSE')
        for text in ['', 'guard guard']:
            with self.assertRaises(ValueError): r.replace_once(text, 'guard', 'FALSE')
        for path in ['/abs', '../x', 'x/../y', '.', '.git/config', 'x//y']:
            with self.assertRaises(ValueError): r.safe_relative(path)
    def test_manifest_duplicate_or_missing_targets(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'manifest.json'
            valid = {'schema': 'etna-fault-campaign-1', 'obligations': [{'id': 'a', 'required': True, 'engine': 'tlc', 'source': 'formal', 'path': 'A.tla', 'replace': {'old': 'x', 'new': 'y'}, 'workloads': ['configs/a.cfg'], 'failure': {'kind': 'invariant', 'name': 'Binding'}}]}
            path.write_text(json.dumps(valid)); r.load_manifest(path)
            for entries in [[valid['obligations'][0]] * 2, [{**valid['obligations'][0], 'path': '../x'}], [{**valid['obligations'][0], 'workloads': []}], [{**valid['obligations'][0], 'replace': {'old': '', 'new': 'y'}}]]:
                path.write_text(json.dumps({**valid, 'obligations': entries}))
                with self.assertRaises(ValueError): r.load_manifest(path)
    def test_status_requires_baseline_restoration_and_no_drift(self):
        self.assertEqual(r.trial_status(['SURVIVED'], ['KILLED'], ['SURVIVED'], True), 'KILLED')
        self.assertEqual(r.trial_status(['SURVIVED'], ['SURVIVED'], ['SURVIVED'], True), 'SURVIVED')
        for baseline, mutated, restored, stable in [([], ['KILLED'], ['SURVIVED'], True),
              (['SURVIVED'], ['KILLED'], ['INCONCLUSIVE'], True),
              (['SURVIVED'], ['INCONCLUSIVE'], ['SURVIVED'], True),
              (['SURVIVED'], ['KILLED'], ['SURVIVED'], False)]:
            self.assertEqual(r.trial_status(baseline, mutated, restored, stable), 'INCONCLUSIVE')
    def test_timeout_process_group_is_reaped(self):
        with tempfile.TemporaryDirectory() as tmp:
            result = r.execute(['/usr/bin/sleep', '5'], Path(tmp), .05)
            self.assertTrue(result['timeout'])
            self.assertEqual(result['returncode'], 124)


class CampaignLifecycle(unittest.TestCase):
    def test_restoration_runs_after_phase_failure_and_original_unchanged(self):
        for problem in ['timeout', 'exception', 'restore', 'drift']:
            with self.subTest(problem=problem), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                source = root / 'formal'; source.mkdir()
                (source / 'A.tla').write_text('guard')
                (source / 'conformance').mkdir()
                for file in ['run_isolated.py', 'run_baseline.py']:
                    (source / 'conformance' / file).write_text('fixture')
                java = root / 'java/bin/java'; java.parent.mkdir(parents=True); java.write_text('fixture')
                runtime = {'schema': 'etna-fault-runtime-1', 'timeout': 1, 'sources': {'formal': str(source)},
                           'tlc': {'java': str(java), 'jar': '/usr/bin/true'}}
                item = {'id': 'fixture', 'required': True, 'engine': 'tlc', 'source': 'formal', 'path': 'A.tla', 'replace': {'old': 'guard', 'new': 'FALSE'}, 'workloads': ['config.cfg'], 'failure': {'kind': 'invariant', 'name': 'Binding'}}
                phases = []
                def fake_phase(item, runtime, copied, tests, directory, formal):
                    name = directory.name; phases.append(name); directory.mkdir()
                    self.assertEqual((copied / 'A.tla').read_text(), 'FALSE' if name == 'mutated' else 'guard')
                    if name == 'mutated' and problem == 'exception': raise ValueError('fixture failure')
                    if name == 'mutated' and problem == 'drift': (source / 'external-change').write_text('changed')
                    status = 'INCONCLUSIVE' if (name == 'mutated' and problem == 'timeout') or (name == 'restored' and problem == 'restore') else ('KILLED' if name == 'mutated' else 'SURVIVED')
                    return [{'status': status, 'output': 'fixture', 'argv': [], 'returncode': 124 if status == 'INCONCLUSIVE' else 0}]
                with patch.object(r, 'phase', side_effect=fake_phase):
                    result = r.run_campaign({'schema': r.SCHEMA, 'obligations': [item]}, runtime, [], root / 'output')
                self.assertEqual(phases, ['baseline', 'mutated', 'restored'])
                self.assertEqual((source / 'A.tla').read_text(), 'guard')
                self.assertEqual(result['inventory'][0]['status'], 'INCONCLUSIVE')
                self.assertFalse(result['ready'])


class EvidencePersistence(unittest.TestCase):
    def test_execution_log_and_argv_persist_before_later_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            argv = ['/usr/bin/printf', 'evidence']
            result = r.execute_logged(argv, directory, 2, directory, 0)
            self.assertEqual((directory / '0.log').read_text(), 'evidence')
            self.assertEqual(json.loads((directory / '0-command.json').read_text()), argv)
            r.finish_record(result, directory, 0)
            self.assertNotIn('output', result)
            self.assertTrue((directory / '0-result.json').is_file())
            self.assertEqual(r.execute_logged(['/missing-executable'], directory, 2, directory, 1)['returncode'], 125)
            self.assertEqual(json.loads((directory / '1-command.json').read_text()), ['/missing-executable'])
    def test_shared_lock_held_during_all_three_phases(self):
        import fcntl
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); source = root / 'contracts'; source.mkdir()
            (source / 'A.sol').write_text('guard')
            formal = root / 'formal'; (formal / 'conformance/solidity').mkdir(parents=True)
            for file in ['run_isolated.py', 'run_baseline.py']:
                (formal / 'conformance' / file).write_text('fixture')
            lock = root / '.formal-cache.lock'
            runtime = {'schema': 'etna-fault-runtime-1', 'timeout': 1, 'sources': {'formal': str(formal), 'contracts': str(source)}, 'forge': {'lock': str(lock), 'argv': []}}
            item = {'id': 'lock-fixture', 'required': True, 'engine': 'forge', 'source': 'contracts', 'path': 'A.sol', 'replace': {'old': 'guard', 'new': 'FALSE'}, 'workloads': ['a:A::test()'], 'failure': {'kind': 'forge', 'failures': {'a:A::test()': 'assertion'}}}
            calls=[]
            def fake_phase(item, runtime, copied, tests, directory, formal):
                calls.append(directory.name); directory.mkdir()
                with lock.open('a') as observer:
                    with self.assertRaises(BlockingIOError): fcntl.flock(observer, fcntl.LOCK_EX | fcntl.LOCK_NB)
                self.assertEqual((copied / 'A.sol').read_text(), 'FALSE' if directory.name == 'mutated' else 'guard')
                return [{'status': 'KILLED' if directory.name == 'mutated' else 'SURVIVED', 'output': 'fixture'}]
            with patch.object(r, 'phase', side_effect=fake_phase), patch.object(r, 'verify_contracts', return_value={'status': 'INPUTS_VERIFIED'}):
                result=r.run_campaign({'schema':r.SCHEMA,'obligations':[item]},runtime,[],root/'output')
            self.assertEqual(calls, ['baseline','mutated','restored'])
            self.assertTrue(result['ready'])
            self.assertEqual((source/'A.sol').read_text(),'guard')


class LockTimeout(unittest.TestCase):
    def test_busy_lock_wait_is_bounded(self):
        with tempfile.TemporaryDirectory() as tmp:
            lock = Path(tmp) / 'lock'
            with lock.open('a') as owner, lock.open('a') as contender:
                r.acquire_lock(owner, 1)
                with self.assertRaisesRegex(ValueError, 'timed out'):
                    r.acquire_lock(contender, .02)


class NestedSessionCleanup(unittest.TestCase):
    def _script(self, root, closed):
        import sys
        script = root / 'nested.py'
        script.write_text('import pathlib, subprocess, sys, time\n'
                          'child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"], start_new_session=True' +
                          (', stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL' if closed else '') + ')\n'
                          'pathlib.Path(sys.argv[1]).write_text(str(child.pid))\n'
                          'time.sleep(30)\n')
        return [sys.executable, '-B', str(script), str(root / 'child.pid')]
    def test_timeout_reaps_nested_session_with_inherited_or_closed_pipe(self):
        import subprocess
        import time
        for closed in (False, True):
            with self.subTest(closed=closed), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                sentinel = subprocess.Popen(['/usr/bin/sleep', '30'])
                try:
                    result = r.execute(self._script(root, closed), root, .3)
                    self.assertEqual(result['returncode'], 124)
                    self.assertLess(result['seconds'], 3)
                    pid = int((root / 'child.pid').read_text())
                    self.assertFalse(Path('/proc', str(pid)).exists())
                    self.assertIsNone(sentinel.poll())
                finally:
                    sentinel.terminate(); sentinel.wait(timeout=2)
    def test_interrupt_and_termination_clean_before_return(self):
        import signal
        import subprocess
        import sys
        import time
        for sig in (signal.SIGINT, signal.SIGTERM):
            with self.subTest(signal=sig), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                argv = self._script(root, True)
                worker = root / 'worker.py'
                worker.write_text('import importlib.util, pathlib\n'
                                  f's=importlib.util.spec_from_file_location("r", {str(Path(r.__file__).resolve())!r})\n'
                                  'r=importlib.util.module_from_spec(s);s.loader.exec_module(r)\n'
                                  'try:\n'
                                  f' r.execute({argv!r}, pathlib.Path({str(root)!r}), 30)\n'
                                  'except BaseException:\n print("cancelled after cleanup")\n')
                process = subprocess.Popen([sys.executable, '-B', str(worker)], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                try:
                    deadline = time.monotonic() + 3
                    while not (root / 'child.pid').exists() and time.monotonic() < deadline: time.sleep(.01)
                    self.assertTrue((root / 'child.pid').exists())
                    process.send_signal(sig)
                    output = process.communicate(timeout=3)[0].decode()
                    self.assertIn('cancelled after cleanup', output)
                    self.assertFalse(Path('/proc', (root / 'child.pid').read_text()).exists())
                finally:
                    if process.poll() is None: process.kill(); process.communicate(timeout=7)

class DependencyDrift(unittest.TestCase):
    def test_read_bound_directory_drift_is_inconclusive(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); source = root / 'contracts'; source.mkdir()
            (source / 'A.sol').write_text('guard')
            formal = root / 'formal'; (formal / 'conformance/solidity').mkdir(parents=True)
            for file in ['run_isolated.py', 'run_baseline.py']:
                (formal / 'conformance' / file).write_text('fixture')
            dependency=root/'dependency';dependency.mkdir();(dependency/'Library.sol').write_text('original')
            runtime = {'schema': 'etna-fault-runtime-1', 'timeout': 1, 'sources': {'formal': str(formal), 'contracts': str(source)}, 'forge': {'lock': str(root / '.formal-cache.lock'), 'argv': ['--read-bind', str(dependency)+'=/tmp/dependency']}}
            item = {'id': 'dependency-fixture', 'required': True, 'engine': 'forge', 'source': 'contracts', 'path': 'A.sol', 'replace': {'old': 'guard', 'new': 'FALSE'}, 'workloads': ['a:A::test()'], 'failure': {'kind': 'forge', 'failures': {'a:A::test()': 'assertion'}}}
            def fake_phase(item, runtime, copied, tests, directory, formal):
                directory.mkdir()
                if directory.name=='mutated':(dependency/'Library.sol').write_text('changed')
                return [{'status':'KILLED' if directory.name=='mutated' else 'SURVIVED','output':'fixture'}]
            with patch.object(r,'phase',side_effect=fake_phase),patch.object(r,'verify_contracts',return_value={'status':'INPUTS_VERIFIED'}):
                result=r.run_campaign({'schema':r.SCHEMA,'obligations':[item]},runtime,[],root/'output')
            self.assertEqual(result['inventory'][0]['status'],'INCONCLUSIVE')
            self.assertFalse(result['ready'])
            self.assertIn('Library.sol',result['tool_hashes'][str(dependency)]['files'])

if __name__ == "__main__": unittest.main()
