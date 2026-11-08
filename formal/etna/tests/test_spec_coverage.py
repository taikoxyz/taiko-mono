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


ENTRIES = json.loads((ROOT/'manifests/design.json').read_text())['theorems']
# The first manifest entry that cites a clause (shared/plumbing entries cite none).
SOURCED = next(e for e in ENTRIES if e['sources'])
PROPERTY = next(e for e in ENTRIES if e['role']=='property' and e['sources'])


class PinnedSourceTests(unittest.TestCase):
    """A redirected pin or an edit to any authority must fail before evidence loads."""
    def check_sources(self, mutate=None):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            root = repo/'formal/etna'
            root.mkdir(parents=True)
            directory = 'packages/protocol/docs/etna'
            shutil.copytree(coverage.REPO/directory, repo/directory)
            value = json.loads((ROOT/'spec-coverage.json').read_text())
            if mutate:
                mutate(repo, value)
            (root/'spec-coverage.json').write_text(json.dumps(value))
            return coverage.source_rows(root, repo)

    def test_current_sources_need_no_external_manifest(self):
        rows = self.check_sources()
        for prefix in ('LIVE_EN-', 'LIVE_ACCEPTANCE-', 'LIVE_ANCHORLESS-', 'LIVE_SWITCH-'):
            self.assertTrue(any(r['id'].startswith(prefix) for r in rows), prefix)

    def test_anchorless_has_independent_exact_inventory(self):
        rows = self.check_sources()
        self.assertEqual(len([r for r in rows if r['language'] in ('live_en', 'live_acceptance')]), 362)
        self.assertEqual(len([r for r in rows if r['language'] == 'live_anchorless']), 93)
        self.assertEqual(len([r for r in rows if r['language'] == 'live_switch']), 113)

    def test_anchorless_edit_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'anchorless digest mismatch'):
            self.check_sources(lambda repo, value:
                (repo/'packages/protocol/docs/etna/ANCHORLESS.md').write_text('changed'))

    def test_anchorless_pin_cannot_redirect_to_identical_bytes(self):
        def redirect(repo, value):
            shutil.copyfile(repo/value['anchorless_source']['path'], repo/'copied-anchorless.md')
            value['anchorless_source']['path'] = 'copied-anchorless.md'
        with self.assertRaisesRegex(ValueError, 'the anchorless source must be'):
            self.check_sources(redirect)

    def test_anchorless_pin_is_required(self):
        with self.assertRaisesRegex(ValueError, 'anchorless reviewed source pin required'):
            self.check_sources(lambda repo, value: value.pop('anchorless_source'))

    def test_anchorless_pin_metadata_is_validated(self):
        for field, bad, diagnostic in [('commit', 'abc', 'full Git commit'),
                                      ('revision', 'yesterday', 'ISO revision date'),
                                      ('sha256', 'xyz', 'digest mismatch')]:
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, diagnostic):
                self.check_sources(lambda repo, value: value['anchorless_source'].update({field: bad}))
        with self.assertRaisesRegex(ValueError, 'anchorless reviewed source pin required'):
            self.check_sources(lambda repo, value: value.update(anchorless_source=[]))

    def test_spec_edit_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'spec digest mismatch'):
            self.check_sources(lambda repo, value:
                (repo/'packages/protocol/docs/etna/SPEC.md').write_text('changed'))

    def test_acceptance_edit_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'acceptance digest mismatch'):
            self.check_sources(lambda repo, value:
                (repo/'packages/protocol/docs/etna/ACCEPTANCE.md').write_text('changed'))

    def test_spec_pin_cannot_redirect_to_identical_bytes(self):
        def redirect(repo, value):
            target = repo/'copied-spec.md'
            shutil.copyfile(repo/value['source']['path'], target)
            value['source']['path'] = 'copied-spec.md'
        with self.assertRaisesRegex(ValueError, 'the spec source must be'):
            self.check_sources(redirect)

    def test_acceptance_pin_cannot_redirect_to_identical_bytes(self):
        def redirect(repo, value):
            target = repo/'copied-acceptance.md'
            shutil.copyfile(repo/value['acceptance_source']['path'], target)
            value['acceptance_source']['path'] = 'copied-acceptance.md'
        with self.assertRaisesRegex(ValueError, 'the acceptance source must be'):
            self.check_sources(redirect)

    def test_switch_edit_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'switch digest mismatch'):
            self.check_sources(lambda repo, value:
                (repo/'packages/protocol/docs/etna/SWITCH.md').write_text('changed'))

    def test_every_reviewed_hash_is_required(self):
        for key, label, _, _ in coverage.SOURCE_INPUTS:
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, label+' digest mismatch'):
                self.check_sources(lambda repo, value: value[key].update(sha256='0'*64))

    def test_every_source_requires_a_full_reviewed_commit(self):
        for key, _, _, _ in coverage.SOURCE_INPUTS:
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'full Git commit'):
                self.check_sources(lambda repo, value: value[key].update(commit='39ebefb'))


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
        self.rejected(lambda r:self.edit(r,'spec-coverage.json',lambda x:x['claims'][0].update(evidence={'LIVE_EN-missing':[PROPERTY['declaration']]})),'unknown source clause')

    def test_claim_cannot_drop_external_boundaries(self):
        self.rejected(lambda r:self.edit(r,'spec-coverage.json',lambda x:x['claims'][0].update(assumptions=[])),'named boundaries')

    def test_duplicate_theorem_rejected(self):
        self.rejected(lambda r:self.edit(r,'manifests/design.json',lambda x:x['theorems'].append(x['theorems'][0])),'duplicate theorem')

    def test_unknown_role_rejected(self):
        self.rejected(lambda r:self.edit(r,'manifests/design.json',lambda x:x['theorems'][0].update(role='full-coverage')),'theorem role')

    def sourced(self, change):
        """Apply `change` to the manifest entry SOURCED."""
        def edit(x):
            change(next(e for e in x['theorems'] if e['declaration']==SOURCED['declaration']))
        return lambda r:self.edit(r,'manifests/design.json',edit)

    def test_unknown_source_rejected(self):
        self.rejected(self.sourced(lambda e:e.update(sources=['LIVE_EN-missing'])),'theorem source')

    def test_only_unsourced_plumbing_may_cite_no_clause(self):
        self.rejected(self.sourced(lambda e:e.update(sources=[])),
                      'empty or duplicate theorem source list: '+SOURCED['declaration'])

    def test_unsourced_entry_cannot_cite_clauses(self):
        # A shared lemma and a reviewed current plumbing declaration back no clause; giving
        # either one a clause edge fails.
        plumbing = json.loads((ROOT/'scripts/current-plumbing.json').read_text())['theorems']
        source = SOURCED['sources'][0]
        for name in ('Etna.Design.Staking.fraction_bounded', next(iter(plumbing))):
            def cite(x):
                entry = next(e for e in x['theorems'] if e['declaration']==name)
                self.assertEqual(entry['sources'],[])
                entry['sources'] = [source]
            with self.subTest(name=name):
                self.rejected(lambda r:self.edit(r,'manifests/design.json',cite),
                              f'{name} is listed in UNSOURCED (backs no clause) but cites {source}')

    def test_spec_bytes_are_pinned(self):
        self.rejected(lambda r:(r.parents[1]/coverage.SPEC_PATH).write_text('changed'),'spec digest mismatch')

    def test_reviewed_source_revision_is_required(self):
        self.rejected(lambda r:self.edit(r,'spec-coverage.json',lambda x:x['source'].update(revision='unreviewed')),
                      'ISO revision date')

    def test_spec_source_path_is_fixed(self):
        self.rejected(lambda r:self.edit(r,'spec-coverage.json',lambda x:x['source'].update(path='spec.md')),
                      'the spec source must be')

    def test_claim_edge_not_in_theorem_map_is_rejected(self):
        # A partial clause and a real property theorem that does not cite it.
        source = PROPERTY['sources'][0]
        other = next(e['declaration'] for e in ENTRIES if e['role']=='property' and source not in e['sources'])
        self.rejected(lambda r:self.edit(r,'spec-coverage.json',lambda x:x['claims'][0].update(evidence={source:[other]})),'claim edge missing')

    def test_claim_cannot_target_deferred_local_trust_clause(self):
        source = next(r['id'] for r in coverage.inventory() if 'Reject a latest checkpoint conflicting with local history' in r['summary'])
        self.rejected(lambda r:self.edit(r,'spec-coverage.json',lambda x:x['claims'][0].update(evidence={source:[PROPERTY['declaration']]})),'deferred/design-pending')

    def test_claim_cannot_use_unknown_theorem(self):
        def change(x):
            source = next(iter(x['claims'][0]['evidence']))
            x['claims'][0]['evidence'] = {source:['Etna.Design.missing']}
        self.rejected(lambda r:self.edit(r,'spec-coverage.json',change),'unknown theorem')

    def test_used_boundary_cannot_disappear(self):
        self.rejected(lambda r:self.edit(r,'spec-coverage.json',lambda x:x['boundaries'].pop('current')),'named boundaries')

    def test_concrete_only_clause_cannot_support_proof_claim(self):
        # A clause backed only by a regression edge stays deferred and cannot back a claim; a
        # theorem left without sources leaves the graph. (The current concrete witnesses are
        # reviewed plumbing that cite no clause, so a sourced theorem is relabelled regression.)
        rows = coverage.inventory()
        source = next(r['id'] for r in rows if r['language']=='live_en' and 'The bound leaves headroom within the 130,044' in r['summary'])
        name = SOURCED['declaration']
        def mutate(root):
            def edit_manifest(x):
                for e in x['theorems']:
                    e['sources'] = [s for s in e['sources'] if s != source]
                    if e['declaration']==name: e.update(role='regression', sources=[source])
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
        rows = [r for r in rows if r['language']=='live_en' and r['summary'].startswith(('- **Reject','- **Before'))]
        self.assertEqual(len(rows),2)
        for row in rows: self.assertEqual(row['status'],'deferred',row['id'])

    def test_concrete_witnesses_are_regression_evidence(self):
        # Concrete accepting/non-vacuity instances never become property/constant clause evidence.
        witnesses = [e for e in self.entries.values() if e['module'].startswith('EtnaWitnesses.')]
        self.assertTrue(witnesses)
        for entry in witnesses:
            self.assertEqual(entry['role'],'regression',entry['declaration'])
