"""Run real Lean, including poisoned declarations, to exercise the proof trust gate."""
import copy
import importlib.util
import json
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
AUDIT = ROOT / 'scripts' / 'audit_proofs.py'


class ProofAuditTests(unittest.TestCase):
    def audit(self, source, theorem='Fixture.sound', type_='∀ (n : Nat), n = n', imports=True, bridge='spec-proved', refinement=None):
        with tempfile.TemporaryDirectory(dir=ROOT) as tmp:
            path = pathlib.Path(tmp)
            module = path.name + '.Fixture'
            (path / 'Fixture.lean').write_text(source)
            manifest = {'schema_version': 1, 'theorems': [{
                'id': 'TEST-01', 'module': module if imports else '',
                'declaration': theorem, 'type': type_, 'assumptions': [],
                'bridge_level': bridge, 'production': [], 'tests': [], **({'refinement': refinement} if refinement else {})}]}
            (path / 'manifest.json').write_text(json.dumps(manifest))
            return subprocess.run(['python3', str(AUDIT), '--manifest', str(path / 'manifest.json'),
                                   '--output', str(path / 'Audit.lean')], cwd=ROOT,
                                  text=True, capture_output=True)

    def refinement(self, **changes):
        return {
            'generated_module': 'Etna.Refinement.Rust.EtnaConsensusCore',
            'generated_definition': 'etna_consensus_core.forced.is_due',
            'rust_symbol': 'etna_consensus_core::forced::is_due',
            'source': 'packages/taiko-client-rs/crates/etna-consensus-core/src/forced.rs',
            'provenance': 'Etna/Refinement/Rust/provenance.json',
            **changes,
        }

    def test_accepts_actual_total_refinement(self):
        result = self.audit(
            'import Etna.Refinement.Rust.Forced\n'
            'namespace Fixture\n'
            'theorem sound (t d a : Aeneas.Std.U64) : etna_consensus_core.forced.is_due t d a = '
            'Aeneas.Std.Result.ok (Etna.FI.isDue t.val d.val a.val) := '
            'Etna.Refinement.Rust.rust_is_due_refines t d a\nend Fixture\n',
            type_='∀ (t d a : Aeneas.Std.U64), etna_consensus_core.forced.is_due t d a = '
                  'Aeneas.Std.Result.ok (Etna.FI.isDue t.val d.val a.val)',
            bridge='rust-refinement-proved', refinement=self.refinement())
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_refinement_without_provenance(self):
        result = self.audit('namespace Fixture\ntheorem sound (n : Nat) : n = n := rfl\nend Fixture\n',
                            bridge='rust-refinement-proved')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('refinement metadata', result.stderr)

    def test_rejects_falsely_labelled_refinement(self):
        result = self.audit('namespace Fixture\ntheorem sound (n : Nat) : n = n := rfl\nend Fixture\n',
                            bridge='rust-refinement-proved', refinement=self.refinement())
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('generated function', result.stderr)

    def test_rejects_forged_source_symbol(self):
        result = self.audit('namespace Fixture\ntheorem sound (n : Nat) : n = n := rfl\nend Fixture\n',
                            bridge='rust-refinement-proved',
                            refinement=self.refinement(rust_symbol='forged::symbol'))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('source symbol', result.stderr)

    def test_rejects_wrong_production_file(self):
        result = self.audit('namespace Fixture\ntheorem sound (n : Nat) : n = n := rfl\nend Fixture\n',
                            bridge='rust-refinement-proved', refinement=self.refinement(
                                source='packages/taiko-client-rs/crates/etna-consensus-core/src/lib.rs'))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('wrong production file', result.stderr)

    def test_rejects_stale_source_digest(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as tmp:
            path = pathlib.Path(tmp) / 'provenance.json'
            data = json.loads((ROOT / 'Etna/Refinement/Rust/provenance.json').read_text())
            data['source_sha256'][self.refinement()['source']] = '0' * 64
            path.write_text(json.dumps(data))
            result = self.audit('namespace Fixture\ntheorem sound (n : Nat) : n = n := rfl\nend Fixture\n',
                                bridge='rust-refinement-proved', refinement=self.refinement(
                                    provenance=str(path.relative_to(ROOT))))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('source digest mismatch', result.stderr)

    def test_rejects_truncated_roots_constants_or_declaration_kinds(self):
        for mutation in ['empty-roots', 'missing-constant', 'constant-as-function', 'inflated-count']:
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory(dir=ROOT) as tmp:
                path = pathlib.Path(tmp) / 'provenance.json'
                data = json.loads((ROOT / 'Etna/Refinement/Rust/provenance.json').read_text())
                if mutation == 'empty-roots':
                    data['root_symbols'] = []
                elif mutation == 'missing-constant':
                    data['generated_definitions'] = [d for d in data['generated_definitions']
                                                     if not d['lean_definition'].endswith('.UINT48_MAX')]
                elif mutation == 'constant-as-function':
                    next(d for d in data['generated_declarations'] if d['kind'] == 'constant')['kind'] = 'function'
                else:
                    data['counts']['production_function_roots'] = 23
                path.write_text(json.dumps(data))
                result = self.audit('namespace Fixture\ntheorem sound (n : Nat) : n = n := rfl\nend Fixture\n',
                                    bridge='rust-refinement-proved',
                                    refinement=self.refinement(provenance=str(path.relative_to(ROOT))))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('provenance', result.stderr)

    def test_rejects_native_decide_trust(self):
        result = self.audit('import Mathlib\nnamespace Fixture\n'
                            'theorem sound : (1 : Nat) = 1 := by native_decide\nend Fixture\n',
                            type_='(1 : Nat) = 1')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('forbidden axioms', result.stderr)

    def test_accepts_kernel_checked_theorem(self):
        result = self.audit('namespace Fixture\ntheorem sound (n : Nat) : n = n := rfl\nend Fixture\n')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_deleted_theorem(self):
        result = self.audit('namespace Fixture\nend Fixture\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Unknown constant `Fixture.sound`', result.stderr)

    def test_rejects_sorry(self):
        result = self.audit('namespace Fixture\ntheorem sound (n : Nat) : n = n := by sorry\nend Fixture\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('sorryAx', result.stderr)

    def test_rejects_transitive_custom_axiom(self):
        result = self.audit('namespace Fixture\naxiom injected : ∀ (n : Nat), n = n\ntheorem sound (n : Nat) : n = n := injected n\nend Fixture\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Fixture.injected', result.stderr)

    def test_rejects_missing_import(self):
        self.assertNotEqual(self.audit('namespace Fixture\ntheorem sound (n : Nat) : n = n := rfl\nend Fixture\n', imports=False).returncode, 0)

    def test_rejects_hidden_default_premise(self):
        result = self.audit('namespace Fixture\ntheorem sound (h : True := by trivial) : True := h\nend Fixture\n', type_='True')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('full type mismatch', result.stderr)

    def test_rejects_hidden_implicit_premise(self):
        result = self.audit('namespace Fixture\ntheorem sound {h : True} : True := h\nend Fixture\n', type_='True')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_changed_full_type(self):
        self.assertNotEqual(self.audit('namespace Fixture\ntheorem sound (n : Nat) (h : n = n) : n = n := h\nend Fixture\n').returncode, 0)


class ProvenanceCompletenessTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('fi_audit', AUDIT)
        self.audit = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.audit)
        self.provenance = json.loads((ROOT / 'Etna/Refinement/Rust/provenance.json').read_text())

    def validate(self, data):
        with tempfile.TemporaryDirectory(dir=ROOT) as tmp:
            path = pathlib.Path(tmp) / 'provenance.json'
            path.write_text(json.dumps(data))
            ref = ProofAuditTests().refinement(provenance=str(path.relative_to(ROOT)))
            self.audit.validate_refinement({'refinement': ref})

    def test_accepts_complete_pinned_producer(self):
        self.validate(self.provenance)

    def test_rejects_empty_and_truncated_provenance_sections(self):
        for section in ['tools', 'source_sha256', 'cargo_sha256', 'generated_sha256']:
            for removed in [None, *self.provenance[section]]:
                with self.subTest(section=section, removed=removed):
                    data = copy.deepcopy(self.provenance)
                    if removed is None:
                        data[section] = {}
                    else:
                        del data[section][removed]
                    with self.assertRaisesRegex(ValueError, 'mandatory.*keys'):
                        self.validate(data)

    def test_rejects_extra_or_missing_sections(self):
        for section in ['tools', 'source_sha256', 'cargo_sha256', 'generated_sha256']:
            with self.subTest(section=section):
                data = copy.deepcopy(self.provenance)
                del data[section]
                with self.assertRaisesRegex(ValueError, 'producer schema'):
                    self.validate(data)
                data = copy.deepcopy(self.provenance)
                data[section]['forged'] = '0' * 64
                with self.assertRaisesRegex(ValueError, 'mandatory.*keys'):
                    self.validate(data)

    def test_rejects_wrong_producer_schema(self):
        for field, value in [('schema_version', 0), ('schema_version', True),
                             ('crate', 'unrelated/crate'), ('charon_llbc_version', 'unknown')]:
            with self.subTest(field=field, value=value):
                data = copy.deepcopy(self.provenance)
                data[field] = value
                with self.assertRaisesRegex(ValueError, 'producer schema'):
                    self.validate(data)


if __name__ == '__main__':
    unittest.main()
