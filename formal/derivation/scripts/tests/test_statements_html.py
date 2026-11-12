"""Regression checks for stale HTML excerpts and theorem navigation."""
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'check_statements.py'
spec = importlib.util.spec_from_file_location('check_statements', SCRIPT)
html_gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(html_gate)
ROOT = SCRIPT.parents[1]


class StatementsHTMLTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for path in [*html_gate.SOURCES, 'spec-coverage.json', 'STATEMENTS.html']:
            target = self.root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / path, target)

    def rewrite_html(self, old, new):
        path = self.root / 'STATEMENTS.html'
        original = path.read_text()
        self.assertIn(old, original)
        path.write_text(original.replace(old, new, 1))

    def test_current_html_matches_sources(self):
        self.assertEqual(html_gate.check(self.root), [])

    def test_stale_statement_is_rejected(self):
        self.rewrite_html('def Claims : Prop := DerivationSafety', 'def Claims : Prop := True ∧ DerivationSafety')
        self.assertTrue(html_gate.check(self.root))

    def test_stale_theorem_line_is_rejected(self):
        source = (self.root / html_gate.PROPERTIES).read_text()
        line = html_gate.declarations(source)['rust_order_agrees'][2]
        self.rewrite_html(f'{html_gate.PROPERTIES}#L{line}', f'{html_gate.PROPERTIES}#L{line + 1}')
        self.assertTrue(html_gate.check(self.root))

    def test_missing_property_excerpt_is_rejected(self):
        self.rewrite_html('data-declaration="rust_order_agrees"', 'data-declaration="not_a_property"')
        self.assertTrue(html_gate.check(self.root))

    def test_new_property_requires_html_entry(self):
        path = self.root / html_gate.PROPERTIES
        path.write_text(path.read_text() + '\ntheorem added_property : True := True.intro\n')
        self.assertTrue(html_gate.check(self.root))

    def test_record_update_content_is_checked(self):
        path = self.root / html_gate.PROPERTIES
        original = path.read_text()
        self.assertIn('transactions := b.transactions', original)
        path.write_text(original.replace('transactions := b.transactions', 'transactions := []', 1))
        self.assertTrue(html_gate.check(self.root))


if __name__ == '__main__':
    unittest.main()
