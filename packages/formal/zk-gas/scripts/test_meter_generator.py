"""Exercise the built Lean exporter, including drift, missing files and coverage loss."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BINARY = ROOT / '.lake/build/bin/generate-meter-vectors'
CORPUS = ROOT.parents[2] / 'testdata/zk_gas_vectors/meter-vectors.json'


class MeterGeneratorTests(unittest.TestCase):
    def run_generator(self, *args):
        return subprocess.run([str(BINARY), *map(str, args)], capture_output=True, text=True)

    def test_export_and_check_are_reproducible(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'meter.json'
            result = self.run_generator(path)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(path.read_bytes(), CORPUS.read_bytes())
            result = self.run_generator('--check', path)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_check_rejects_missing_or_changed_expectations(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'meter.json'
            result = self.run_generator('--check', path)
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertFalse(path.exists())
            data = json.loads(CORPUS.read_text())
            expected = data['vectors'][0]['expected'][0]
            expected['ok'] = not expected['ok']
            changed = json.dumps(data)
            path.write_text(changed)
            result = self.run_generator('--check', path)
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertEqual(path.read_text(), changed)

    def test_bad_arguments_fail(self):
        for args in [[], ['--check'], ['--check', 'a', 'b']]:
            result = self.run_generator(*args)
            self.assertEqual(result.returncode, 2, result.stderr)

    def test_all_meter_entry_points_are_covered(self):
        data = json.loads(CORPUS.read_text())
        self.assertEqual(data['schema_version'], 1)
        self.assertEqual(data['schedule'], 'unzen')
        vectors = data['vectors']
        self.assertTrue(vectors)
        self.assertEqual(len({v['id'] for v in vectors}), len(vectors))
        self.assertTrue({'addition.block_and_transaction', 'budget.block_and_transaction'} <=
                        {v['id'] for v in vectors})
        actions = [action for vector in vectors for action in vector['actions']]
        self.assertEqual({a['op'] for a in actions if a['kind'] == 'opcode'}, set(range(256)))
        self.assertEqual({a['op'] for a in actions if a['kind'] == 'spawn'},
                         {0xf0, 0xf1, 0xf2, 0xf4, 0xf5, 0xfa})
        addresses = {int(a['address'], 16) for a in actions if a['kind'] == 'precompile'}
        self.assertTrue(set(range(1, 18)) | {256, 18, 2**159 + 2} <= addresses)
        self.assertEqual({a['kind'] for a in actions},
                         {'opcode', 'spawn', 'precompile', 'intrinsic', 'commit', 'reset'})
        for vector in vectors:
            self.assertTrue(vector['actions'], vector['id'])
            self.assertEqual(len(vector['actions']), len(vector['expected']), vector['id'])


if __name__ == '__main__':
    unittest.main()
