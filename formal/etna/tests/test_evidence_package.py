"""Review regressions for evidence linkage, stable IDs and public source hygiene."""
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
        self.assertEqual(len(rows),619)
        # inventory() checks each explicit claim edge and its general-property role.

    def test_clause_ids_survive_line_insertion(self):
        text = (ROOT/'specs/2026-10-27.en.md').read_text()
        self.assertEqual([c['id'] for c in coverage.clauses(text,'en')],
                         [c['id'] for c in coverage.clauses('\n\n'+text,'en')])

    def test_public_snapshots_have_no_internal_links(self):
        for path in (ROOT/'specs').glob('*.md'):
            text = path.read_text()
            self.assertFalse('https://app.notion.com/' in text, path.name)
            self.assertFalse('discussion://' in text, path.name)

    def test_generated_duplicates_are_untracked(self):
        for name in ('Audit.lean','proof-policy.json','coverage.json'):
            self.assertFalse((ROOT/name).exists(), name+' must be generated outside tracked inputs or removed')

    def test_normative_change_gets_new_identity(self):
        self.assertNotEqual(coverage.clauses('- Rule A','en')[0]['id'],
                            coverage.clauses('- Rule B','en')[0]['id'])

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

    def test_public_sanitizer_retains_normative_text(self):
        spec = importlib.util.spec_from_file_location('prepare',ROOT/'scripts/prepare_spec.py')
        prepare = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(prepare)
        raw = '<page url="https://app.notion.com/p/test"><content>\n- A <span discussion-urls="discussion://test">normative rule</span>.\n</content></page>'
        public = prepare.sanitize(raw)
        self.assertIn('normative rule',public)
        self.assertFalse('discussion://' in public)
        self.assertFalse('notion.com' in public)
        self.assertEqual(public,prepare.sanitize(public))
        label = prepare.sanitize('<b>English</b>: <mention url="https://app.notion.com/p/test" />\n')
        self.assertEqual(label,'<b>English</b>: [internal reference omitted]\n')
