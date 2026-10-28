"""Validate canonical evidence through real on-disk source/claim mutations."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import importlib.util

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('coverage',ROOT/'scripts/check_spec_coverage.py')
coverage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(coverage)


class SpecCoverageTests(unittest.TestCase):
    def check(self,mutate=None):
        """Run the checker on copies: `root` is formal/etna inside a scratch repo holding the spec."""
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            root = repo/'formal/etna'
            root.mkdir(parents=True)
            shutil.copytree(ROOT/'manifests',root/'manifests')
            shutil.copyfile(ROOT/'spec-coverage.json',root/'spec-coverage.json')
            shutil.copytree(coverage.REPO/coverage.SPEC_DIR,repo/coverage.SPEC_DIR)
            if mutate: mutate(root)
            return subprocess.run(['python3',str(ROOT/'scripts/check_spec_coverage.py'),'--root',str(root),'--repo',str(repo)],
                                  capture_output=True,text=True)

    def edit(self,root,name,change):
        file = root/name
        value = json.loads(file.read_text())
        change(value)
        file.write_text(json.dumps(value))

    def rejected(self,mutate,diagnostic):
        result = self.check(mutate)
        self.assertNotEqual(result.returncode,0)
        self.assertIn(diagnostic,result.stderr)

    def test_current_inventory_passes(self):
        result = self.check()
        self.assertEqual(result.returncode,0,result.stderr)

    def test_claim_cannot_reference_unrecorded_source(self):
        self.rejected(lambda r:self.edit(r,'spec-coverage.json',lambda x:x['claims'][0].update(evidence={'EN-missing':['Etna.Design.dual_count']})),'unknown source clause')

    def test_claim_cannot_drop_external_boundaries(self):
        self.rejected(lambda r:self.edit(r,'spec-coverage.json',lambda x:x['claims'][0].update(assumptions=[])),'named boundaries')

    def test_duplicate_theorem_rejected(self):
        self.rejected(lambda r:self.edit(r,'manifests/design.json',lambda x:x['theorems'].append(x['theorems'][0])),'duplicate theorem')

    def test_unknown_role_rejected(self):
        self.rejected(lambda r:self.edit(r,'manifests/design.json',lambda x:x['theorems'][0].update(role='full-coverage')),'theorem role')

    def test_unknown_source_rejected(self):
        self.rejected(lambda r:self.edit(r,'manifests/design.json',lambda x:x['theorems'][0].update(sources=['EN-missing'])),'theorem source')

    def test_only_unsourced_plumbing_may_cite_no_clause(self):
        self.rejected(lambda r:self.edit(r,'manifests/design.json',lambda x:x['theorems'][0].update(sources=[])),
                      'empty or duplicate theorem source list: Etna.Design.dual_count')

    def test_unsourced_entry_cannot_cite_clauses(self):
        # run_trace (Run ⊆ Trace plumbing) backs no clause; restoring its old 6.1 land edge fails.
        def cite(x):
            entry = next(e for e in x['theorems'] if e['declaration']=='Etna.Proofs.run_trace')
            self.assertEqual(entry['sources'],[])
            entry['sources'] = ['EN-976a8c89163f509a']
        self.rejected(lambda r:self.edit(r,'manifests/design.json',cite),
                      'Etna.Proofs.run_trace is listed in UNSOURCED (backs no clause) but cites EN-976a8c89163f509a')

    def test_spec_bytes_are_pinned(self):
        self.rejected(lambda r:(r.parents[1]/coverage.SPEC_PATH).write_text('changed'),'spec digest mismatch')

    def test_pinned_revision_matches_spec_manifest(self):
        def bump(root):
            file = root.parents[1]/coverage.SPEC_DIR/'manifest.json'
            value = json.loads(file.read_text())
            value['revision'] = '2000-01-01'
            file.write_text(json.dumps(value))
        self.rejected(bump,'pinned spec revision differs')

    def test_spec_source_path_is_fixed(self):
        self.rejected(lambda r:self.edit(r,'spec-coverage.json',lambda x:x['source'].update(path='spec.md')),
                      'the spec source must be')

    def test_claim_edge_not_in_theorem_map_is_rejected(self):
        entries = json.loads((ROOT/'manifests/design.json').read_text())['theorems']
        source = next(s for e in entries if e['role']=='property' for s in e['sources']
                      if s not in entries[0]['sources'])
        self.rejected(lambda r:self.edit(r,'spec-coverage.json',lambda x:x['claims'][0].update(evidence={source:['Etna.Design.dual_count']})),'claim edge missing')

    def test_claim_cannot_target_deferred_local_trust_clause(self):
        source = next(r['id'] for r in coverage.inventory() if 'Reject a latest checkpoint conflicting with local history' in r['summary'])
        self.rejected(lambda r:self.edit(r,'spec-coverage.json',lambda x:x['claims'][0].update(evidence={source:['Etna.Design.dual_count']})),'deferred/design-pending')

    def test_claim_cannot_use_unknown_theorem(self):
        def change(x):
            source = next(iter(x['claims'][0]['evidence']))
            x['claims'][0]['evidence'] = {source:['Etna.Design.missing']}
        self.rejected(lambda r:self.edit(r,'spec-coverage.json',change),'unknown theorem')

    def test_used_boundary_cannot_disappear(self):
        self.rejected(lambda r:self.edit(r,'spec-coverage.json',lambda x:x['boundaries'].pop('l1')),'named boundaries')

    def test_concrete_only_clause_cannot_support_proof_claim(self):
        # A clause backed only by regressions stays deferred and cannot back a claim; a
        # theorem left without sources (the constant cap_derivation) leaves the graph.
        rows = coverage.inventory()
        source = next(r['id'] for r in rows if 'The bound leaves headroom within the 130,044' in r['summary'])
        name = 'Etna.Design.Budget.grid_calldata_examples'
        def mutate(root):
            def edit_manifest(x):
                for e in x['theorems']:
                    e['sources'] = [s for s in e['sources'] if s != source]
                    if e['declaration']==name: e['sources'].append(source)
                x['theorems'] = [e for e in x['theorems'] if e['sources'] or e['declaration'] in coverage.UNSOURCED]
            self.edit(root,'manifests/design.json',edit_manifest)
            self.edit(root,'spec-coverage.json',lambda x:x['claims'][0].update(evidence={source:[name]}))
        self.rejected(mutate,'deferred/design-pending')


class ReviewedMappingTests(unittest.TestCase):
    def setUp(self):
        self.entries = {e['declaration']:e for e in json.loads((ROOT/'manifests/design.json').read_text())['theorems']}

    def test_local_history_and_dao_prechecks_remain_unproved(self):
        phrases = ('Reject a latest checkpoint conflicting with local history','Before authorizing')
        rows = [r for r in coverage.inventory() if any(p in r['summary'] for p in phrases)]
        # Exact node-fence and DAO pre-check paragraphs, without line-number IDs.
        rows = [r for r in rows if r['summary'].startswith(('- <b>Reject','- <b>Before'))]
        self.assertEqual(len(rows),2)
        for row in rows: self.assertEqual(row['status'],'deferred',row['id'])

    def test_concrete_vectors_are_regression_evidence(self):
        for short in ('Budget.grid_calldata_examples','Budget.schedule_arithmetic','Budget.data_worst_case_landing_rate',
                      'Keys.generator_even_prefix','Keys.generator_odd_prefix','Keys.leading_zero_x_kept',
                      'Keys.non_residue_rejected','Keys.unreduced_x_rejected','Keys.other_prefixes_rejected','Keys.wrong_lengths_rejected'):
            self.assertEqual(self.entries['Etna.Design.'+short]['role'],'regression',short)

    def test_registry_trace_scope_matches_exact_conclusion(self):
        for name in ('step_preserves_registry','trace_preserves_registry'):
            scope = self.entries['Etna.Design.RegistryHistory.'+name]['scope']
            self.assertNotIn('current entry projection',scope)
            for predicate in ('KeysValid','IdentitiesValid','Ordered'): self.assertIn(predicate,scope)
