"""Review regressions for evidence linkage and stable clause IDs."""
import importlib.util
import json
from pathlib import Path
import tempfile
import shutil
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('coverage', ROOT/'scripts/check_spec_coverage.py')
coverage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(coverage)


class EvidencePackageTests(unittest.TestCase):
    def test_claim_pairs_have_reviewed_edges(self):
        rows = coverage.inventory()
        self.assertEqual(len([r for r in rows if r['language'] in ('live_en', 'live_acceptance')]),393)
        self.assertEqual(len([r for r in rows if r['language'] == 'live_anchorless']),102)
        self.assertEqual(len([r for r in rows if r['language'] == 'live_switch']),84)
        self.assertEqual(len(rows),579)
        # inventory() checks each explicit claim edge and its general-property role.

    def test_clause_ids_survive_line_insertion(self):
        text = (coverage.REPO/coverage.SPEC_PATH).read_text()
        self.assertEqual([c['id'] for c in coverage.clauses(text,'en')],
                         [c['id'] for c in coverage.clauses('\n\n'+text,'en')])

    def test_details_wrappers_do_not_become_requirement_clauses(self):
        text = "# Section\n\n<details>\n<summary>Explanation</summary>\n\n- Rule A\n\n</details>\n\n## Next\n\n- Rule B"
        rows = coverage.clauses(text, 'en')
        self.assertEqual([r['summary'] for r in rows], ['- Rule A', '- Rule B'])
        self.assertEqual([r['section'] for r in rows], ['Section', 'Next'])
        self.assertEqual([(r['start_line'], r['end_line']) for r in rows], [(6, 6), (12, 12)])

    def test_details_markup_inside_fence_is_literal_requirement_text(self):
        text = '## Encodings\n\n```txt\n<details>\n<summary>literal</summary>\n</details>\n```'
        rows = coverage.clauses(text, 'en')
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['summary'], text.split('\n\n', 1)[1])

    def test_generated_duplicates_are_untracked(self):
        for name in ('Audit.lean','proof-policy.json','coverage.json'):
            self.assertFalse((ROOT/name).exists(), name+' must be generated outside tracked inputs or removed')

    def test_normative_change_gets_new_identity(self):
        self.assertNotEqual(coverage.clauses('- Rule A','en')[0]['id'],
                            coverage.clauses('- Rule B','en')[0]['id'])

    def test_rule_reference_markers_are_not_clause_text(self):
        marked = '- **[FI-7.2-1]** Rule A\n```txt\n// [ENC-A-6]\nx = 1\n```\n'
        plain = '- Rule A\n```txt\nx = 1\n```\n'
        stripped = coverage.strip_markers(marked)
        self.assertEqual(stripped, plain)
        self.assertEqual([(r['id'], r['start_line']) for r in coverage.clauses(stripped,'en')],
                         [(r['id'], r['start_line']) for r in coverage.clauses(plain,'en')])

    def test_generated_inventory_fingerprints_all_authorities(self):
        import subprocess
        with tempfile.TemporaryDirectory() as tmp:
            result = subprocess.run(['python3', str(ROOT/'scripts/generate_artifacts.py'), '--out', tmp],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            hashes = json.loads((Path(tmp)/'coverage.json').read_text())['source_sha256']
            self.assertEqual(hashes['packages/protocol/docs/etna/SPEC.md'],
                             '0068d2f88da75fdd81dada64baf99e21ff059865e66f67563484609be9b04fc4')
            self.assertEqual(hashes['packages/protocol/docs/etna/ACCEPTANCE.md'],
                             '285a6bba4f4244a83234d804593b7f2f8a6c897b610dd338d4736c8d24072812')
            self.assertEqual(hashes['packages/protocol/docs/etna/ANCHORLESS.md'],
                             '0dd8cfb602df22f03849749a6fb045f44e2bc4c3bf19e4c8ee051b0b810a7d98')
            self.assertEqual(hashes['packages/protocol/docs/etna/SWITCH.md'],
                             '265aba1cb6fb45b89999298df0a2655029f3aba8d7a4b382995362a2098fd22c')
            self.assertNotIn('packages/protocol/docs/etna/sources/manifest.json', hashes)

    def test_generator_detects_stale_outputs(self):
        import subprocess
        with tempfile.TemporaryDirectory() as tmp:
            command = ['python3',str(ROOT/'scripts/generate_artifacts.py'),'--out',tmp]
            result = subprocess.run(command,capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            original = (Path(tmp)/'Audit.lean').read_bytes()
            self.assertEqual(subprocess.run(command,capture_output=True).returncode,0)
            self.assertEqual(original,(Path(tmp)/'Audit.lean').read_bytes())
            (Path(tmp)/'Audit.lean').write_text('changed')
            result = subprocess.run(command+['--check'],capture_output=True,text=True)
            self.assertNotEqual(result.returncode,0)
            self.assertIn('stale generated artifact',result.stderr)

    def test_execution_plans_are_not_tracked(self):
        import subprocess
        paths = subprocess.check_output(['git','ls-files','reports/*-plan.md'],cwd=ROOT,text=True)
        self.assertEqual(paths,'')
