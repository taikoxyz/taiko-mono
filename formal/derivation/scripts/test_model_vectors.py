"""Exercise the real Lean exporter; run after `lake build vectors`."""
from copy import deepcopy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CORPUS = ROOT.parents[1] / 'testdata/derivation_vectors'
BINARY = ROOT / '.lake/build/bin/vectors'
GENERATOR = CORPUS / 'generate_model_inputs.py'


class ModelVectors(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.independent = json.loads((CORPUS / 'boundary_cases.json').read_text())

    def inputs(self):
        return {'schema_version': 1, 'cases': [
            {k: deepcopy(v) for k, v in case.items() if k != 'expected'}
            for case in self.independent['cases']]}

    def export(self, corpus):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        source = Path(directory.name) / 'inputs.json'
        output = Path(directory.name) / 'expected.json'
        source.write_text(json.dumps(corpus))
        before = source.read_bytes()
        result = subprocess.run([BINARY, '--emit-boundaries', source, output],
                                capture_output=True, text=True, check=False)
        self.assertEqual(source.read_bytes(), before, 'export must preserve its inputs')
        return result, output

    def test_export_matches_independent_expected_without_receiving_it(self):
        result, output = self.export(self.inputs())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(output.read_text()), self.independent)

    def test_prefilled_expected_is_rejected(self):
        corpus = self.inputs()
        corpus['cases'][0]['expected'] = {'blocks': ['not a model result']}
        result, output = self.export(corpus)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('expected', result.stderr)
        self.assertFalse(output.exists())

    def test_empty_or_duplicate_cases_are_rejected(self):
        for cases in [[], [self.inputs()['cases'][0]] * 2]:
            with self.subTest(cases=len(cases)):
                result, output = self.export({'schema_version': 1, 'cases': cases})
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(output.exists())

    def test_invalid_late_input_does_not_publish_partial_results(self):
        corpus = self.inputs()
        corpus['cases'][-1]['chain_id'] = 1
        result, output = self.export(corpus)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('unsupported chain ID', result.stderr)
        self.assertFalse(output.exists())

    def test_unsupported_schema_is_rejected(self):
        corpus = self.inputs()
        corpus['schema_version'] = 2
        result, output = self.export(corpus)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(output.exists())

    def test_export_refuses_to_overwrite_an_existing_file(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'inputs.json'
            output = Path(directory) / 'expected.json'
            source.write_text(json.dumps(self.inputs()))
            output.write_text('independent fixture must survive')
            result = subprocess.run([BINARY, '--emit-boundaries', source, output],
                                    capture_output=True, text=True, check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(output.read_text(), 'independent fixture must survive')

    def test_input_generator_is_deterministic_and_contains_no_expected(self):
        with tempfile.TemporaryDirectory() as directory:
            for attempt in range(2):
                output = Path(directory) / f'inputs-{attempt}.json'
                result = subprocess.run(['python3', GENERATOR, '--output', output],
                                        capture_output=True, text=True, check=False)
                self.assertEqual(result.returncode, 0, result.stderr)
                encoded = output.read_bytes()
                if attempt == 0:
                    first = encoded
                else:
                    self.assertEqual(encoded, first)
            corpus = json.loads(encoded)
            cases = corpus['cases']
            self.assertGreater(len(cases), len(self.independent['cases']))
            self.assertEqual(len({case['name'] for case in cases}), len(cases))
            self.assertTrue(all('expected' not in case for case in cases))
            self.assertTrue(all(case in cases for case in self.inputs()['cases']))
            result, exported = self.export(corpus)
            self.assertEqual(result.returncode, 0, result.stderr)
            actual = json.loads(exported.read_text())['cases']
            self.assertEqual([{k: v for k, v in case.items() if k != 'expected'}
                              for case in actual], cases)
            self.assertTrue(all('expected' in case for case in actual))


if __name__ == '__main__':
    unittest.main()
