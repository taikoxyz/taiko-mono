"""Opt-in random vectors: determinism, well-formed output, and an unchanged default output."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def generate(out, *extra):
    """Run the generator into `out`; returns {file name: bytes}."""
    subprocess.run(['lake', 'exe', 'etna-vectors', '--write', str(out), *extra], cwd=ROOT, check=True,
                   capture_output=True, text=True)
    return {p.name: p.read_bytes() for p in sorted(Path(out).iterdir())}


class RandomVectorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        (ROOT/'.scratch').mkdir(exist_ok=True)
        cls.tmp = tempfile.TemporaryDirectory(dir=ROOT/'.scratch')
        base = Path(cls.tmp.name)
        cls.first = generate(base/'first', '--random', '7', '--count', '60')
        cls.second = generate(base/'second', '--random', '7', '--count', '60')
        cls.other = generate(base/'other', '--random', '8', '--count', '60')
        cls.default = generate(base/'default')

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_same_seed_is_byte_identical(self):
        self.assertEqual(self.first, self.second)

    def test_seeds_differ(self):
        self.assertNotEqual(self.first['random-land.json'], self.other['random-land.json'])
        self.assertNotEqual(self.first['random-forced.json'], self.other['random-forced.json'])

    def test_only_random_files_are_written(self):
        self.assertEqual(sorted(self.first), ['random-forced.json', 'random-land.json'])

    def test_files_parse_with_unique_ids_and_both_outcomes(self):
        for name, data in self.first.items():
            doc = json.loads(data)
            ids = [v['id'] for v in doc['vectors']]
            self.assertEqual(doc['vectorCount'], 60, name)
            self.assertEqual(len(ids), len(set(ids)), name)
            self.assertEqual({v['expect']['revert'] for v in doc['vectors']}, {True, False}, name)

    def test_default_output_has_no_random_files(self):
        self.assertEqual(len(self.default), 8)
        self.assertFalse(any(name.startswith('random-') for name in self.default))

    def test_random_header_names_seed_and_count(self):
        for name, data in self.first.items():
            self.assertIn('--random 7 --count 60', json.loads(data)['generator'], name)

    def test_land_vectors_are_not_mostly_reverts(self):
        doc = json.loads(self.first['random-land.json'])
        accepted = sum(1 for v in doc['vectors'] if not v['expect']['revert'])
        self.assertGreaterEqual(4*accepted, len(doc['vectors']))

    def test_setups_are_accepted_across_seeds(self):
        """A rejected setup step makes generation fail; no seed in the sweep may hit one."""
        for seed in range(10):
            with tempfile.TemporaryDirectory(dir=ROOT/'.scratch') as tmp:
                run = subprocess.run(['lake', 'exe', 'etna-vectors', '--write', tmp, '--random', str(seed),
                                      '--count', '40'], cwd=ROOT, capture_output=True, text=True)
                self.assertEqual(run.returncode, 0, f'seed {seed}: {run.stderr}')

    def rejected(self, *args):
        with tempfile.TemporaryDirectory(dir=ROOT/'.scratch') as tmp:
            run = subprocess.run(['lake', 'exe', 'etna-vectors', '--write', tmp, *args], cwd=ROOT,
                                 capture_output=True, text=True)
            written = sorted(p.name for p in Path(tmp).iterdir())
        return run.returncode, written

    def test_provenance_with_random_is_rejected(self):
        self.assertEqual(self.rejected('--random', '7', '--provenance', 'abc'), (2, []))

    def test_count_without_random_is_rejected(self):
        self.assertEqual(self.rejected('--count', '5'), (2, []))

    def test_random_with_families_is_rejected(self):
        with tempfile.TemporaryDirectory(dir=ROOT/'.scratch') as tmp:
            run = subprocess.run(['lake', 'exe', 'etna-vectors', '--write', tmp, '--random', '7',
                                  '--families', 'land'], cwd=ROOT, capture_output=True, text=True)
        self.assertNotEqual(run.returncode, 0)


if __name__ == '__main__':
    unittest.main()
