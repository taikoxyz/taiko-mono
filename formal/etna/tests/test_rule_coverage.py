"""Exact reviewed rule edges never inherit a neighboring rule's clause evidence."""
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


class RuleCoverageTests(unittest.TestCase):
    def rows(self, edit_docs=None, edit_config=None, repin=False):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            shutil.copytree(rules.REPO/DOCS, repo/DOCS)
            shutil.copytree(ROOT/'legacy/2026-10-30', repo/'formal/etna/legacy/2026-10-30', dirs_exist_ok=True)
            if edit_docs:
                edit_docs(repo)
            config = copy.deepcopy(CONFIG)
            if repin:
                for key, path in (('spec',rules.SPEC_PATH),('index',rules.INDEX_PATH)):
                    config[key]['sha256'] = hashlib.sha256((repo/path).read_bytes()).hexdigest()
            if edit_config:
                edit_config(config)
            return rules.rule_rows(ROOT, repo, config)

    def exact(self, config):
        config['schema_version'] = 2
        config.pop('via', None)
        config.pop('narrow', None)
        config['evidence'] = {'STAKE-4.1-13a': {
            'theorems': ['Etna.Design.Current.Registry.trace_keys_permanent'],
            'reason': 'Issued key identities remain registered along the decoded registry trace.'}}

    def test_shared_clause_does_not_cover_unlisted_neighbor(self):
        rows = {r['rule']:r for r in self.rows(edit_config=self.exact)}
        self.assertEqual(rows['STAKE-4.1-13a']['status'], 'partial')
        for rule in ('STAKE-4.1-14a','STAKE-4.1-14b'):
            self.assertEqual(rows[rule]['status'], 'deferred')
            self.assertEqual(rows[rule]['theorems'], [])

    def test_empty_whitelist_defers_all_binding_rules(self):
        def edit(config):
            self.exact(config)
            config['evidence'] = {}
        rows = [r for r in self.rows(edit_config=edit) if r['type']=='rule']
        self.assertTrue(rows)
        self.assertTrue(all(r['status']=='deferred' and not r['theorems'] for r in rows))

    def test_generic_list_agreement_is_plumbing_not_stock_consensus(self):
        def edit(config):
            self.exact(config)
            config['evidence']['CONS-3.1-1'] = {
                'theorems': ['Etna.Design.Current.Finality.agreement_get'],
                'reason': 'Deliberately invalid list-algebra claim about a stock consensus process.'}
        with self.assertRaisesRegex(ValueError, 'plumbing'):
            self.rows(edit_config=edit)

    def test_unrelated_theorem_is_rejected(self):
        def edit(config):
            self.exact(config)
            config['evidence']['CONS-3.1-1'] = config['evidence']['STAKE-4.1-13a']
        with self.assertRaisesRegex(ValueError, 'does not cite'):
            self.rows(edit_config=edit)

    def test_supporting_guard_is_visible_without_becoming_partial(self):
        def edit(config):
            self.exact(config)
            config['evidence']['START-10.1-5a'] = {
                'theorems': ['Etna.Design.Current.Rules.schedule_rules_result'],
                'reason': 'Exact accepted schedule field result only.'}
        row = next(r for r in self.rows(edit_config=edit) if r['rule']=='START-10.1-5a')
        self.assertEqual(row['status'], 'supporting')
        self.assertEqual(row['theorems'], ['Etna.Design.Current.Rules.schedule_rules_result'])

    def test_unknown_theorem_is_rejected(self):
        def edit(config):
            self.exact(config)
            config['evidence']['STAKE-4.1-13a']['theorems'] = ['Etna.Design.Current.not_a_theorem']
        with self.assertRaisesRegex(ValueError, 'unknown theorem'):
            self.rows(edit_config=edit)

    def test_unknown_rule_is_rejected(self):
        def edit(config):
            self.exact(config)
            config['evidence']['LAND-6.1-99'] = config['evidence']['STAKE-4.1-13a']
        with self.assertRaisesRegex(ValueError, 'unknown rule'):
            self.rows(edit_config=edit)

    def test_review_reason_required(self):
        def edit(config):
            self.exact(config)
            config['evidence']['STAKE-4.1-13a']['reason'] = ' '
        with self.assertRaisesRegex(ValueError, 'needs a reason'):
            self.rows(edit_config=edit)

    def test_duplicate_evidence_is_rejected(self):
        def edit(config):
            self.exact(config)
            edge = config['evidence']['STAKE-4.1-13a']['theorems']
            edge += edge
        with self.assertRaisesRegex(ValueError, 'duplicate theorem'):
            self.rows(edit_config=edit)

    def test_historical_evidence_is_rejected(self):
        def edit(config):
            self.exact(config)
            config['evidence']['STAKE-4.1-13a']['theorems'] = ['Etna.Proofs.evidence_stays_slashable']
        with self.assertRaisesRegex(ValueError, 'current theorem'):
            self.rows(edit_config=edit)

    def test_index_edit_is_rejected(self):
        def edit(repo):
            path = repo/rules.INDEX_PATH
            path.write_text(path.read_text().replace('Proof completeness','Proof soundness',1))
        with self.assertRaisesRegex(ValueError, 'index digest mismatch'):
            self.rows(edit_docs=edit)

    def test_marker_only_edit_is_rejected(self):
        def edit(repo):
            path = repo/rules.SPEC_PATH
            path.write_text(path.read_text().replace('**[FI-7.2-1]**','**[FI-7.2-1a]**',1))
        with self.assertRaisesRegex(ValueError, 'spec digest mismatch'):
            self.rows(edit_docs=edit)

    def test_markers_must_match_index(self):
        def edit(repo):
            path = repo/rules.INDEX_PATH
            text = path.read_text()
            row = next(line for line in text.splitlines() if line.startswith('| FI-7.2-1 '))
            path.write_text(text.replace(row+'\n','',1))
        with self.assertRaisesRegex(ValueError, 'markers and INDEX rows differ'):
            self.rows(edit_docs=edit, repin=True)

    def test_committed_report_is_fresh(self):
        self.assertEqual((ROOT/rules.REPORT).read_text(), rules.render(rules.rule_rows()))

    def test_import_failure_signer_and_availability_evidence_are_distinct(self):
        rows = {r['rule']:r for r in self.rows()}
        prefix = 'Etna.Design.Current.'
        self.assertEqual(set(rows['DATA-5.4-5']['theorems']), {
            prefix+'Import.authenticated_conflict_halts',
            prefix+'Import.invalid_data_rejected', prefix+'Import.publish_boundary'})
        self.assertEqual(set(rows['DATA-5.4-7']['theorems']), {
            prefix+'Import.publish_boundary', prefix+'QueueIntegrity.node_import_closed'})
        self.assertEqual(set(rows['DATA-5.4-4']['theorems']), {
            prefix+'QueueIntegrity.import_complete_range', prefix+'QueueIntegrity.node_import_closed'})
        self.assertEqual(rows['DATA-5.4-8']['status'], 'deferred')
        self.assertEqual(rows['DATA-5.4-8']['theorems'], [])

    def test_aggregate_conservation_is_not_a_topup_exit_guard(self):
        row = next(r for r in self.rows() if r['rule']=='STAKE-4.1-20')
        self.assertEqual(row['status'], 'deferred')
        self.assertEqual(row['theorems'], [])

    def test_antecedents_and_unrelated_consequences_do_not_gain_rule_credit(self):
        rows = {r['rule']:r for r in self.rows()}
        for rule in ('COMM-4.3-14','PROOF-6.2-7','PROOF-6.2-17','PROOF-6.2-18',
                     'PROOF-6.2-19','PROOF-6.2-40','FORF-4.4-8','RECOV-8-28',
                     'RECOV-8-46','RECOV-8.3-11','RECOV-8.3-12'):
            with self.subTest(rule=rule):
                self.assertEqual(rows[rule]['status'], 'deferred')
                self.assertEqual(rows[rule]['theorems'], [])

    def test_switching_lane_fragment_requires_its_direct_trace_theorems(self):
        row = next(r for r in self.rows() if r['rule'] == 'START-10-5')
        self.assertEqual(row['status'], 'partial')
        self.assertEqual(set(row['theorems']), {
            'Etna.Design.Current.Protocol.Custody.trace_legacy_prefix',
            'Etna.Design.Current.Protocol.Custody.trace_legacy_etna_disjoint'})
        # This fragment does not establish deployment, storage version or initialization.
        self.assertIn('not SignalService storage/version', row['reason'])

    def test_exact_payment_stop_and_pending_interval_fragments(self):
        rows = {r['rule']:r for r in self.rows()}
        expected = {
            'FORF-4.4-9': 'RegistryPayments.forfeit_payment_exact',
            'RECOV-8-47a': 'Rules.recover_clears_stop',
            'RECOV-8-38': 'QueueIntegrity.recovery_pending_guards',
            'RECOV-8-43': 'QueueIntegrity.recovery_pending_guards',
            'CONS-3.4-2': 'Blocks.chain_parent_hashes',
        }
        for rule, suffix in expected.items():
            self.assertEqual(rows[rule]['theorems'], ['Etna.Design.Current.'+suffix])

    def test_every_live_id_is_present_once(self):
        rows = self.rows()
        index = rules.index_rows((rules.REPO/rules.INDEX_PATH).read_text())
        self.assertEqual(len(rows), len({r['rule'] for r in rows}))
        self.assertEqual({r['rule'] for r in rows}, {k for k,v in index.items() if v['type']!='retired'})


if __name__ == '__main__':
    unittest.main()
