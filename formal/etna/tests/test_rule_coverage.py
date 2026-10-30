"""Rule-level traceability: pins, overrides, narrowing and report freshness."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('rule_coverage', ROOT/'scripts/rule_coverage.py')
rules = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rules)
DOCS = 'packages/protocol/docs/etna'
CONFIG = json.loads((ROOT/rules.CONFIG).read_text())


def repinned(config, repo):
    """The same config with both raw pins moved to the bytes in `repo`."""
    value = copy.deepcopy(config)
    for key, path in (('spec', rules.SPEC_PATH), ('index', rules.INDEX_PATH)):
        value[key]['sha256'] = hashlib.sha256((repo/path).read_bytes()).hexdigest()
    return value


class RuleCoverageTests(unittest.TestCase):
    def rows(self, edit_docs=None, edit_config=None, repin=False):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            shutil.copytree(rules.REPO/DOCS, repo/DOCS)
            if edit_docs:
                edit_docs(repo)
            config = repinned(CONFIG, repo) if repin else copy.deepcopy(CONFIG)
            if edit_config:
                edit_config(config)
            return rules.rule_rows(ROOT, repo, config)

    def test_committed_report_is_fresh(self):
        self.assertEqual((ROOT/rules.REPORT).read_text(), rules.render(rules.rule_rows()))

    def test_every_index_id_has_one_row(self):
        rows = self.rows()
        self.assertEqual(len(rows), len({r['rule'] for r in rows}))
        index = rules.index_rows((rules.REPO/rules.INDEX_PATH).read_text())
        self.assertEqual({r['rule'] for r in rows}, {k for k, v in index.items() if v['type'] != 'retired'})

    def test_index_edit_is_rejected(self):
        def edit(repo):
            path = repo/rules.INDEX_PATH
            path.write_text(path.read_text().replace('Proof completeness', 'Proof soundness', 1))
        with self.assertRaisesRegex(ValueError, 'index digest mismatch'):
            self.rows(edit_docs=edit)

    def test_marker_only_edit_is_rejected(self):
        """The clause pin strips markers; the rule pin must still see a renamed marker."""
        def edit(repo):
            path = repo/rules.SPEC_PATH
            path.write_text(path.read_text().replace('**[FI-7.2-1]**', '**[FI-7.2-1a]**', 1))
        with self.assertRaisesRegex(ValueError, 'spec digest mismatch'):
            self.rows(edit_docs=edit)

    def test_markers_must_match_index(self):
        def edit(repo):
            path = repo/rules.INDEX_PATH
            text = path.read_text()
            row = next(line for line in text.splitlines() if line.startswith('| FI-7.2-1 '))
            path.write_text(text.replace(row+'\n', '', 1))
        with self.assertRaisesRegex(ValueError, 'markers and INDEX rows differ'):
            self.rows(edit_docs=edit, repin=True)

    def test_override_must_route_to_a_partial_clause(self):
        def edit(config):
            config['via']['LAND-6.1-1'] = {'clause': 'EN-f0ba7de0b6221621', 'reason': 'same block'}
        with self.assertRaisesRegex(ValueError, 'routes to a deferred clause'):
            self.rows(edit_config=edit)

    def test_redundant_override_is_rejected(self):
        def edit(config):
            config['via']['BACKP-6.4-1'] = {'clause': 'EN-976a8c89163f509a', 'reason': 'already partial'}
        with self.assertRaisesRegex(ValueError, 'redundant override'):
            self.rows(edit_config=edit)

    def test_override_needs_a_reason(self):
        def edit(config):
            config['via']['LAND-6.1-2']['reason'] = ' '
        with self.assertRaisesRegex(ValueError, 'needs a reason'):
            self.rows(edit_config=edit)

    def test_override_for_unknown_rule_is_rejected(self):
        def edit(config):
            config['via']['LAND-6.1-99'] = {'clause': 'EN-976a8c89163f509a', 'reason': 'no such rule'}
        with self.assertRaisesRegex(ValueError, 'unknown rule'):
            self.rows(edit_config=edit)

    def test_narrowing_must_be_a_proper_subset(self):
        def everything(config):
            config['narrow']['EN-b8d78ca3f1f77e84'] = [f'BACKP-6.4-{n}' for n in range(1, 9)]
        with self.assertRaisesRegex(ValueError, 'proper subset'):
            self.rows(edit_config=everything)

        def outsider(config):
            config['narrow']['EN-b8d78ca3f1f77e84'] = ['BACKP-6.4-1', 'BACKP-6.4-10']
        with self.assertRaisesRegex(ValueError, 'proper subset'):
            self.rows(edit_config=outsider)

    def test_empty_narrowing_defers_every_rule(self):
        """An empty list says the clause's theorems address none of its rule IDs."""
        def edit(config):
            config['narrow']['EN-b8d78ca3f1f77e84'] = []
        rows = {r['rule']: r for r in self.rows(edit_config=edit)}
        for n in range(1, 9):
            self.assertEqual(rows[f'BACKP-6.4-{n}']['status'], 'deferred')
            self.assertEqual(rows[f'BACKP-6.4-{n}']['theorems'], [])

    def test_narrowing_needs_a_shared_clause(self):
        """A clause with one rule ID is not narrowed: an empty list would silently demote it."""
        def edit(config):
            config['narrow']['EN-b88b6b1e1d0a93b8'] = []
        with self.assertRaisesRegex(ValueError, 'shared by several rules'):
            self.rows(edit_config=edit)

    def test_narrowed_rules_lose_their_theorems(self):
        rows = {r['rule']: r for r in self.rows()}
        self.assertEqual(rows['BACKP-6.4-2']['status'], 'deferred')
        self.assertEqual(rows['BACKP-6.4-2']['theorems'], [])
        self.assertEqual(rows['BACKP-6.4-1']['status'], 'partial')
        self.assertIn('Etna.Design.ProtocolState.anchored_unsettled_bound', rows['BACKP-6.4-1']['theorems'])


if __name__ == '__main__':
    unittest.main()
