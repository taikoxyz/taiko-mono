"""Independent source-contract and actual kernel-replay mutation regressions."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('design_audit', ROOT/'scripts/audit_proofs.py')
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)


def combined_source(stem):
    """EtnaModel/<stem>.lean followed by the theorems of EtnaProofs/<stem>.lean in one file
    (imports hoisted), so a weakened definition must break a theorem proved about it."""
    imports, bodies = [], []
    for lib in ('EtnaModel', 'EtnaProofs'):
        lines = (ROOT/lib/f'{stem}.lean').read_text().split('\n')
        k = 0
        while k < len(lines) and lines[k].startswith('import '):
            imports.append(lines[k])
            k += 1
        bodies.append('\n'.join(lines[k:]))
    own = f'import EtnaModel.{stem}'
    return '\n'.join(dict.fromkeys(i for i in imports if i != own))+'\n'+'\n'.join(bodies)


class ContractTests(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads((ROOT/'manifests/design.json').read_text())

    def check(self):
        AUDIT.validate_contract(self.manifest)

    def check_full_manifest(self):
        scratch = ROOT/'.scratch'
        scratch.mkdir(exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=scratch,suffix='.lean',mode='w') as file:
            file.write(AUDIT.render_audit(self.manifest['theorems']))
            file.flush()
            AUDIT.check_kernel_file(file.name)

    def test_current_contract(self):
        self.check()

    def test_removing_public_theorem_contract_rejected(self):
        self.manifest['theorems'].pop()
        with self.assertRaisesRegex(ValueError,'public theorem'):
            self.check_full_manifest()

    def test_duplicate_theorem_rejected(self):
        self.manifest['theorems'].append(copy.deepcopy(self.manifest['theorems'][0]))
        with self.assertRaisesRegex(ValueError,'duplicate'):
            self.check()

    def test_implementation_proof_claim_rejected(self):
        self.manifest['theorems'][0]['bridge_level'] = 'implementation-proved'
        with self.assertRaisesRegex(ValueError,'specification proofs only'):
            self.check()

    def test_missing_boundary_annotations_rejected(self):
        self.manifest['theorems'][0]['assumptions'] = []
        with self.assertRaisesRegex(ValueError,'named proof boundaries'):
            self.check()

    def test_legacy_namespace_is_not_active_design(self):
        self.manifest['theorems'][0]['declaration'] = 'Etna.Landing.old'
        with self.assertRaisesRegex(ValueError,'active module/declaration'):
            self.check()

    def test_source_module_mapping_cannot_be_relabelled(self):
        self.manifest['theorems'][0]['module'] = 'EtnaProofs.Encoding'
        with self.assertRaisesRegex(ValueError,'manifest module mismatch'):
            self.check_full_manifest()

    def test_module_outside_the_libraries_rejected(self):
        self.manifest['theorems'][0]['module'] = 'Etna.Design.Common'
        with self.assertRaisesRegex(ValueError,'active module/declaration'):
            self.check()

    def test_module_outside_the_theorem_libraries_rejected(self):
        # Manifested theorems live in EtnaProofs or EtnaWitnesses; Model/Statements only for an
        # ALLOWED_MODEL_THEOREMS entry (none today).
        for module in ('EtnaModel.Common', 'EtnaStatements.Claims', 'EtnaVectors.Main'):
            self.manifest['theorems'][0]['module'] = module
            with self.assertRaisesRegex(ValueError,f'manifest module {module} of Etna.Design.dual_count: '
                                        'theorems live in EtnaProofs or EtnaWitnesses'):
                self.check()

    def test_headline_proofs_live_in_headline_modules(self):
        entry = next(e for e in self.manifest['theorems'] if e['declaration'] == 'Etna.Proofs.fund_safety')
        entry['module'] = 'EtnaProofs.Common'
        with self.assertRaisesRegex(ValueError,'Etna.Proofs.fund_safety: the Etna.Proofs namespace .* lives in '
                                    'EtnaProofs.Headline'):
            self.check()

    def test_headline_and_unsourced_entries_required(self):
        for name in ('Etna.Proofs.claims', 'Etna.Proofs.fund_safety', 'Etna.Proofs.run_trace', 'Etna.Proofs.trace_run'):
            manifest = copy.deepcopy(self.manifest)
            manifest['theorems'] = [e for e in manifest['theorems'] if e['declaration'] != name]
            with self.assertRaisesRegex(ValueError,'missing manifest entry: '+name):
                AUDIT.validate_contract(manifest)

    def test_only_unsourced_plumbing_may_cite_no_clause(self):
        self.manifest['theorems'][0]['sources'] = []
        with self.assertRaisesRegex(ValueError,'role/source/scope required: Etna.Design.dual_count'):
            self.check()


class KernelAuditTests(unittest.TestCase):
    def entry(self, name='checked', typ='True'):
        return {'declaration':'Etna.Design.AuditTest.'+name,
                'module':'EtnaProofs.Common', 'type':typ, 'bridge_level':'spec-proved',
                'assumptions':['synthetic audit regression; not a protocol obligation'],
                'role':'regression','sources':['synthetic'],'scope':'audit test only'}

    def kernel(self, entry, declarations):
        text = AUDIT.render_audit([entry],complete=False)
        text = text.replace('set_option pp.universes false', declarations+'\nset_option pp.universes false', 1)
        scratch = ROOT/'.scratch'
        scratch.mkdir(exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=scratch, suffix='.lean', mode='w') as file:
            file.write(text)
            file.flush()
            output = AUDIT.check_kernel_file(file.name)
        AUDIT.check_axioms([entry], output)

    def test_kernel_bypass_is_rejected(self):
        forged = """namespace Etna.Design.AuditTest
set_option debug.skipKernelTC true in
run_elab do
  Lean.addDecl (.thmDecl { name := `Etna.Design.AuditTest.checked, levelParams := [], type := Lean.mkConst ``False, value := Lean.mkConst ``True.intro })
end Etna.Design.AuditTest"""
        with self.assertRaisesRegex(ValueError, 'leanchecker|kernel'):
            self.kernel(self.entry(typ='False'), forged)

    def test_election_definition_weakening_is_rejected(self):
        import subprocess
        source = combined_source('Consensus')
        source = source.replace('Committee.election c.unit c.minimum r.cutoff c.nMax (c.registry r.cutoff) = some r.members', 'True', 1)
        source = source.replace('inferInstanceAs (Decidable (_ = _))', 'inferInstanceAs (Decidable True)', 1)
        with tempfile.NamedTemporaryFile(dir=ROOT, suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            result = subprocess.run(['lake','env','lean',file.name],cwd=ROOT,text=True,capture_output=True)
        self.assertNotEqual(result.returncode, 0, 'ElectionValid := True must violate an independent semantic contract')

    def test_forged_axiom_stdout_is_rejected(self):
        source = """namespace Etna.Design.AuditTest
axiom poison : False
theorem checked : False := poison
run_elab do
  Lean.logInfo "'Etna.Design.AuditTest.checked' does not depend on any axioms"
end Etna.Design.AuditTest"""
        with self.assertRaisesRegex(ValueError, 'forbidden axioms|ambiguous'):
            self.kernel(self.entry(typ='False'),source)

    def test_real_theorem_passes(self):
        self.kernel(self.entry(), 'namespace Etna.Design.AuditTest\ntheorem checked : True := True.intro\nend Etna.Design.AuditTest')

    def test_axiom_disguised_as_theorem_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'expected theorem declaration'):
            self.kernel(self.entry(), 'namespace Etna.Design.AuditTest\naxiom checked : True\nend Etna.Design.AuditTest')

    def test_hidden_transitive_custom_axiom_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'forbidden axioms'):
            self.kernel(self.entry(), 'namespace Etna.Design.AuditTest\naxiom poison : True\ntheorem checked : True := poison\nend Etna.Design.AuditTest')

    def test_sorry_in_real_proof_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'forbidden axioms'):
            self.kernel(self.entry(), 'namespace Etna.Design.AuditTest\ntheorem checked : True := by sorry\nend Etna.Design.AuditTest')

    def test_added_false_premise_is_not_same_full_type(self):
        with self.assertRaisesRegex(ValueError, 'full theorem type mismatch'):
            self.kernel(self.entry(typ='False → True'), 'namespace Etna.Design.AuditTest\ntheorem checked : True := True.intro\nend Etna.Design.AuditTest')

    def test_specialized_instance_is_not_universal_theorem(self):
        with self.assertRaisesRegex(ValueError, 'full theorem type mismatch'):
            self.kernel(self.entry(typ='0 = 0'), 'namespace Etna.Design.AuditTest\ntheorem checked (n : Nat) : n = n := rfl\nend Etna.Design.AuditTest')

    def test_missing_axiom_report_fails_closed(self):
        with self.assertRaisesRegex(ValueError, 'missing transitive axiom report'):
            AUDIT.check_axioms([self.entry()], '')


if __name__ == '__main__':
    unittest.main()


class PublicCompletenessTests(unittest.TestCase):
    def check_extra(self,declaration):
        import subprocess, shutil
        manifest = json.loads((ROOT/'manifests/design.json').read_text())
        scratch = ROOT/'.scratch'
        scratch.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=scratch) as tmp:
            tmp = Path(tmp)
            shutil.copytree(ROOT/'.lake/build/lib/lean',tmp,dirs_exist_ok=True)
            module = tmp/'EtnaProofs/AuditProbe.lean'
            module.parent.mkdir(parents=True,exist_ok=True)
            module.write_text('import EtnaProofs\nnamespace Etna.Design.AuditProbe\n'+declaration+'\nend Etna.Design.AuditProbe\n')
            AUDIT.run(['lake','env','lean','--root='+str(tmp),'-o',str(module.with_suffix('.olean')),str(module)])
            probe = tmp/'Probe.lean'
            probe.write_text(AUDIT.render_audit(manifest['theorems']).replace('import EtnaAudit\n','import EtnaAudit\nimport EtnaProofs.AuditProbe\n',1))
            search = str(tmp)+':'+str(AUDIT.build_audit_library())+':'+AUDIT.run(['lake','env','printenv','LEAN_PATH']).strip()
            result = subprocess.run(['lake','env','env','LEAN_PATH='+search,'lean',str(probe)],cwd=ROOT,text=True,capture_output=True)
            self.assertNotEqual(result.returncode,0,'unmanifested package declaration must be rejected')
            self.assertRegex(result.stdout+result.stderr,'unmanifested public theorem|forbidden axioms')

    def test_indented_public_theorem_is_not_omitted(self):
        self.check_extra('  theorem omittedIndent : True := True.intro')

    def test_attributed_public_theorem_is_not_omitted(self):
        self.check_extra('@[simp] theorem omittedAttribute : True := True.intro')

    def test_nested_namespace_theorem_is_not_omitted(self):
        self.check_extra('namespace Nested\n theorem omittedNested : True := True.intro\nend Nested')

    def test_omitted_public_poison_cannot_evade_axiom_policy(self):
        self.check_extra('axiom omittedPoison : False\n  theorem omittedPublic : False := omittedPoison')
