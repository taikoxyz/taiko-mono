"""Validate canonical evidence through real on-disk source/claim mutations."""
from collections import Counter
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
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name in ('specs','manifests','spec-coverage.json'):
                src = ROOT/name
                if src.is_dir(): shutil.copytree(src,root/name)
                else: shutil.copyfile(src,root/name)
            if mutate: mutate(root)
            return subprocess.run(['python3',str(ROOT/'scripts/check_spec_coverage.py'),'--root',str(root)],capture_output=True,text=True)

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
            entry['sources'] = ['EN-d9391f6926e651b1','ZH-d7b29cda33f26d67']
        self.rejected(lambda r:self.edit(r,'manifests/design.json',cite),
                      'Etna.Proofs.run_trace is listed in UNSOURCED (backs no clause) but cites EN-d9391f6926e651b1')

    def test_snapshot_bytes_are_authenticated(self):
        self.rejected(lambda r:(r/'specs/2026-10-27.en.md').write_text('changed'),'snapshot digest')

    def test_claim_edge_not_in_theorem_map_is_rejected(self):
        entries = json.loads((ROOT/'manifests/design.json').read_text())['theorems']
        source = next(s for e in entries if e['role']=='property' for s in e['sources']
                      if s not in entries[0]['sources'])
        self.rejected(lambda r:self.edit(r,'spec-coverage.json',lambda x:x['claims'][0].update(evidence={source:['Etna.Design.dual_count']})),'claim edge missing')

    def test_claim_cannot_target_deferred_local_trust_clause(self):
        source = next(r['id'] for r in coverage.inventory() if r['language']=='en' and 'Reject a latest checkpoint conflicting with local history' in r['summary'])
        self.rejected(lambda r:self.edit(r,'spec-coverage.json',lambda x:x['claims'][0].update(evidence={source:['Etna.Design.dual_count']})),'deferred/design-pending')

    def test_claim_cannot_use_unknown_theorem(self):
        def change(x):
            source = next(iter(x['claims'][0]['evidence']))
            x['claims'][0]['evidence'] = {source:['Etna.Design.missing']}
        self.rejected(lambda r:self.edit(r,'spec-coverage.json',change),'unknown theorem')

    def test_used_boundary_cannot_disappear(self):
        self.rejected(lambda r:self.edit(r,'spec-coverage.json',lambda x:x['boundaries'].pop('l1')),'named boundaries')

    def test_concrete_only_clause_cannot_support_proof_claim(self):
        # The EN clause and its ZH twin move together, so EN/ZH symmetry still holds; a
        # theorem left without sources (the constant cap_derivation) leaves the graph.
        rows = coverage.inventory()
        pair = [next(r['id'] for r in rows if r['language']==lang and phrase in r['summary'])
                for lang,phrase in (('en','The bound comes from the 125,948'),('zh','上限的来历：1 个 blob 可用 125,948'))]
        name = 'Etna.Design.Budget.grid_calldata_examples'
        def mutate(root):
            def edit_manifest(x):
                for e in x['theorems']:
                    e['sources'] = [s for s in e['sources'] if s not in pair]
                    if e['declaration']==name: e['sources'].extend(pair)
                x['theorems'] = [e for e in x['theorems'] if e['sources']]
            self.edit(root,'manifests/design.json',edit_manifest)
            self.edit(root,'spec-coverage.json',lambda x:x['claims'][0].update(evidence={s:[name] for s in pair}))
        self.rejected(mutate,'deferred/design-pending')

    def test_theorem_language_counts_must_match(self):
        entry = json.loads((ROOT/'manifests/design.json').read_text())['theorems'][0]
        zh = next(s for s in entry['sources'] if s.startswith('ZH-'))
        def drop(x):
            x['theorems'][0]['sources'].remove(zh)
        en = sum(s.startswith('EN-') for s in entry['sources'])
        self.rejected(lambda r:self.edit(r,'manifests/design.json',drop),
                      f'EN/ZH source clause counts differ ({en} EN, {en-1} ZH): {entry["declaration"]}')

    def zh_pair(self):
        """A claim ZH clause citing two or more theorems, and the last of them."""
        claims = json.loads((ROOT/'spec-coverage.json').read_text())['claims']
        return next((c,s,ds[-1]) for c in claims for s,ds in c['evidence'].items()
                    if s.startswith('ZH-') and len(ds) >= 2)

    def test_claim_theorem_citations_must_match_across_languages(self):
        claim, zh, name = self.zh_pair()
        def drop(x):
            next(c for c in x['claims'] if c['id']==claim['id'])['evidence'][zh].remove(name)
        self.rejected(lambda r:self.edit(r,'spec-coverage.json',drop),
                      f"EN/ZH theorem citations differ in proof claim {claim['id']}: cited more often in EN: ['{name}']")

    def test_claim_clause_counts_must_match_across_languages(self):
        # Same theorem multiset, one more ZH clause: move `name` from `zh` to a fresh ZH
        # clause, linked in the manifest together with a fresh EN clause (theorem stays symmetric).
        claim, zh, name = self.zh_pair()
        rows = coverage.inventory()
        texts = Counter(coverage.content_key(r['id']) for r in rows)
        entry = next(e for e in json.loads((ROOT/'manifests/design.json').read_text())['theorems']
                     if e['declaration']==name)
        fresh = {lang:next(r['id'] for r in rows if r['language']==lang and r['status']!='design-pending'
                           and texts[coverage.content_key(r['id'])]==1 and r['id'] not in entry['sources']
                           and r['id'] not in claim['evidence']) for lang in ('en','zh')}
        def mutate(root):
            def manifest(x):
                next(e for e in x['theorems'] if e['declaration']==name)['sources'].extend(fresh.values())
            def spec(x):
                evidence = next(c for c in x['claims'] if c['id']==claim['id'])['evidence']
                evidence[zh].remove(name)
                evidence[fresh['zh']] = [name]
            self.edit(root,'manifests/design.json',manifest)
            self.edit(root,'spec-coverage.json',spec)
        en = sum(s.startswith('EN-') for s in claim['evidence'])
        self.rejected(mutate,f"EN/ZH clause counts differ in proof claim {claim['id']}: {en} EN, {en+1} ZH")


class ReviewedMappingTests(unittest.TestCase):
    def setUp(self):
        self.entries = {e['declaration']:e for e in json.loads((ROOT/'manifests/design.json').read_text())['theorems']}

    def test_local_history_and_dao_prechecks_remain_unproved(self):
        phrases = ('Reject a latest checkpoint conflicting with local history','Before authorizing','不采纳与本地链冲突','授权前')
        rows = [r for r in coverage.inventory() if any(p in r['summary'] for p in phrases)]
        # Exact EN/ZH node-fence and DAO pre-check paragraphs, without line-number IDs.
        rows = [r for r in rows if r['summary'].startswith(('- <b>Reject','- <b>Before','- <b>不采纳','- <b>授权前'))]
        self.assertEqual(len(rows),4)
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
