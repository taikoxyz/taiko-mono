"""Coverage-policy regressions do not mutate production source or paired protocol state."""
import copy
import importlib.util
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
spec=importlib.util.spec_from_file_location('check_coverage',ROOT/'scripts/check_coverage.py')
coverage=importlib.util.module_from_spec(spec)
spec.loader.exec_module(coverage)


class CoverageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ledger=json.loads((ROOT/'coverage.json').read_text())
        cls.entries=coverage.load_entries()

    def check(self, ledger=None, entries=None):
        # Protocol source digest semantics are exercised by the actual paired command;
        # here virtual reads provide the exact committed source-symbol inputs, keeping
        # these policy unit tests independent of a developer-specific dependency path.
        ledger=copy.deepcopy(self.ledger if ledger is None else ledger)
        entries=copy.deepcopy(self.entries if entries is None else entries)
        by_path={}
        for r in ledger['obligations']:
            for s in r['source_symbols']:
                if s['path'].startswith('packages/protocol/'):
                    by_path.setdefault(Path('/paired')/s['path'],[]).append(s)
        original_read=Path.read_text
        original_sha=coverage.sha
        def read(path,*args,**kwargs):
            if path in by_path:
                return '\n'.join(s['symbol'] for s in by_path[path])
            return original_read(path,*args,**kwargs)
        def digest(path):
            return by_path[path][-1]['sha256'] if path in by_path else original_sha(path)
        with patch.object(Path,'read_text',read),patch.object(coverage,'sha',digest):
            return coverage.check_ledger(ledger,entries,Path('/paired'))

    def test_current_ledger_covers_all_261_theorems_and_21_exact_functions(self):
        result=self.check()
        self.assertEqual(result['theorems'],261)
        self.assertEqual(result['exact_rust_functions'],21)
        self.assertEqual(len(result['pending']),3)

    def test_delete_id_from_both_manifest_and_ledger_fails(self):
        ledger=copy.deepcopy(self.ledger); entries=copy.deepcopy(self.entries)
        removed=entries.pop()['id']
        ledger['obligations']=[r for r in ledger['obligations'] if r['id']!=removed]
        with self.assertRaisesRegex(ValueError,'mandatory theorem IDs'):
            self.check(ledger,entries)

    def test_downgrade_refinement_in_both_files_fails(self):
        ledger=copy.deepcopy(self.ledger); entries=copy.deepcopy(self.entries)
        entry=next(e for e in entries if e['bridge_level']=='rust-refinement-proved')
        entry['bridge_level']='spec-proved'
        next(r for r in ledger['obligations'] if r['id']==entry['id'])['bridge_level']='spec-proved'
        with self.assertRaisesRegex(ValueError,'downgraded'):
            self.check(ledger,entries)

    def test_coordinated_manifest_ledger_weakening_is_rejected(self):
        ledger=copy.deepcopy(self.ledger); entries=copy.deepcopy(self.entries)
        entry=next(e for e in entries if e['id']=='INT-fees-nonvacuity')
        entry['type']='True'
        next(r for r in ledger['obligations'] if r['id']==entry['id'])['type_sha256']=coverage.canonical(entry['type'])
        with self.assertRaisesRegex(ValueError,'mandatory full theorem contract'):
            self.check(ledger,entries)

    def test_coordinated_manifest_ledger_added_premise_is_rejected(self):
        ledger=copy.deepcopy(self.ledger); entries=copy.deepcopy(self.entries)
        entry=next(e for e in entries if e['id']=='LAND-07')
        entry['type']='False → ('+entry['type']+')'
        next(r for r in ledger['obligations'] if r['id']==entry['id'])['type_sha256']=coverage.canonical(entry['type'])
        with self.assertRaisesRegex(ValueError,'mandatory full theorem contract'):
            self.check(ledger,entries)

    def test_missing_renamed_duplicate_theorem_fails(self):
        for mutate in [lambda rows:rows.pop(),lambda rows:rows.append(rows[0]),
                       lambda rows:rows[0].update(declaration='Etna.DoesNotExist')]:
            entries=copy.deepcopy(self.entries);mutate(entries)
            with self.subTest(mutate=mutate),self.assertRaises(ValueError): self.check(entries=entries)

    def test_missing_theorem_file_fails(self):
        path=ROOT/(self.entries[0]['module'].replace('.','/')+'.lean')
        original=Path.is_file
        with patch.object(Path,'is_file',lambda p:False if p==path else original(p)):
            with self.assertRaisesRegex(ValueError,'theorem source missing'): self.check()

    def test_stale_type_model_generated_and_source_digests_fail(self):
        for kind in ['type','model','generated','source']:
            ledger=copy.deepcopy(self.ledger)
            if kind=='type': ledger['obligations'][0]['type_sha256']='0'*64
            elif kind=='model': ledger['files']['Etna/FI/Model.lean']='0'*64
            elif kind=='generated': ledger['files']['Etna/Refinement/Rust/EtnaConsensusCore.lean']='0'*64
            else:
                row=next(r for r in ledger['obligations'] if r['source_symbols'] and not r['source_symbols'][0]['path'].startswith('packages/protocol/'))
                row['source_symbols'][0]['sha256']='0'*64
            with self.subTest(kind=kind),self.assertRaises(ValueError): self.check(ledger)

    def test_removing_source_symbol_or_named_premise_fails(self):
        for key in ['source_symbols','premises']:
            ledger=copy.deepcopy(self.ledger)
            row=next(r for r in ledger['obligations'] if r[key])
            row[key]=[]
            with self.subTest(key=key),self.assertRaises(ValueError): self.check(ledger)

    def test_generated_or_transitive_model_digest_cannot_disappear(self):
        for name in ['Etna/FI/Model.lean','Etna/Refinement/Rust/EtnaConsensusCore.lean',
                     'adapters/solidity/L2FeeVaultLeanConformance.t.sol','corpus/claim.jsonl']:
            ledger=copy.deepcopy(self.ledger);del ledger['files'][name]
            with self.subTest(name=name),self.assertRaisesRegex(ValueError,'mandatory source/generated'): self.check(ledger)

    def test_claim_theorems_cite_the_actual_vault_harness(self):
        rows={r['id']:r for r in self.ledger['obligations']}
        for name in ['CLAIM-01','CLAIM-02','CLAIM-03','CLAIM-AUX-01','CLAIM-AUX-03','CLAIM-AUX-04']:
            with self.subTest(name=name):
                self.assertIn('adapters/solidity/L2FeeVaultLeanConformance.t.sol',rows[name]['tests'])
                self.assertIn('scripts/claim_conformance.py',rows[name]['tests'])

    def test_all_three_unimplemented_boundaries_are_mandatory(self):
        for index in range(3):
            ledger=copy.deepcopy(self.ledger);ledger['pending'].pop(index)
            with self.subTest(index=index),self.assertRaisesRegex(ValueError,'mandatory pending'): self.check(ledger)

    def test_pending_cannot_be_silently_upgraded(self):
        ledger=copy.deepcopy(self.ledger);ledger['pending'][0]['status']='proved'
        with self.assertRaisesRegex(ValueError,'hidden or upgraded'): self.check(ledger)

    def test_upstream_protocol_overlay_identities_are_not_interchangeable(self):
        ledger=copy.deepcopy(self.ledger)
        ledger['identities']['upstream_client']=ledger['identities']['paired_protocol']
        with self.assertRaisesRegex(ValueError,'three source identities'): self.check(ledger)


if __name__=='__main__': unittest.main()
