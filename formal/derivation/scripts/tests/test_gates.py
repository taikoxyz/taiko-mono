"""Mutation tests for the package's bounded source/import/spec checks."""
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'check.py'
spec = importlib.util.spec_from_file_location('check', SCRIPT)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
ROOT = SCRIPT.parents[1]


class GateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'formal/derivation'
        shutil.copytree(ROOT, self.root, ignore=shutil.ignore_patterns('.lake', '__pycache__'))
        for item in gate.SPEC_PATHS:
            target = self.root.parents[1] / item
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT.parents[1] / item, target)

    def mutate(self, path, suffix):
        with (self.root / path).open('a') as f:
            f.write('\n' + suffix + '\n')

    def test_current_package(self):
        self.assertEqual(gate.check(self.root), [])

    def test_escape_mutations(self):
        for token in ['sorry', 'admit', 'native_decide', 'axiom', 'unsafe', 'partial',
                      'implemented_by', 'extern', 'debug.skipKernelTC', 'run_elab',
                      'elab', 'macro', 'syntax', '#eval', '#guard', 'initialize',
                      'opaque', 'Lean.ofReduceBool', '«sorry»']:
            with self.subTest(token=token):
                self.assertTrue(gate.source_errors('DerivationProofs.X', token))

    def test_nested_comments_and_strings(self):
        self.assertEqual(gate.source_errors('DerivationProofs.X',
                         '/- sorry /- unsafe -/ axiom -/\ndef x := "admit" -- native_decide\n'), [])

    def test_unterminated_lexemes(self):
        for text in ['/- unclosed', '"unclosed', '«unclosed']:
            with self.subTest(text=text):
                self.assertTrue(gate.source_errors('DerivationProofs.X', text))

    def test_guard_allowlist(self):
        self.assertEqual(gate.source_errors('DerivationWitnesses.Tests.Rlp', '#guard true'), [])
        self.assertTrue(gate.source_errors('DerivationWitnesses.Premises', '#guard true'))
        self.assertTrue(gate.source_errors('DerivationWitnesses.Tests.Rlp', '#eval 1'))

    def test_upward_import(self):
        self.mutate('DerivationModel.lean', 'import DerivationProofs')
        self.assertTrue(gate.check(self.root))

    def test_multiple_and_multiline_import(self):
        self.mutate('DerivationModel.lean', 'import\n DerivationModel.Bytes DerivationProofs')
        self.assertTrue(gate.check(self.root))

    def test_unknown_import(self):
        self.mutate('DerivationProofs.lean', 'import DerivationProofs.Missing')
        self.assertTrue(gate.check(self.root))

    def test_metaprogramming_import(self):
        self.mutate('DerivationModel.lean', 'import Lean.Data.Json')
        self.assertTrue(gate.check(self.root))

    def test_orphan_module(self):
        (self.root / 'DerivationProofs/Orphan.lean').write_text('def orphan := 1')
        self.assertTrue(gate.check(self.root))

    def test_missing_root(self):
        (self.root / 'DerivationVectors.lean').unlink()
        self.assertTrue(gate.check(self.root))

    def test_proof_in_definition_layer(self):
        for lib in ['DerivationModel', 'DerivationStatements']:
            self.assertTrue(gate.source_errors(lib, 'theorem bad : True := by trivial'))
            self.assertTrue(gate.source_errors(lib, 'example : True := by trivial'))

    def test_spec_drift(self):
        path = self.root.parents[1] / gate.SPEC_PATHS[0]
        path.write_text(path.read_text() + '\nChanged\n')
        self.assertTrue(gate.check(self.root))

    def test_missing_claim_link(self):
        data = gate.read_manifest(self.root)
        del data['claims']['HeaderSafety']
        self.assertTrue(gate.spec_errors(self.root, data))

    def test_bad_section_and_weak_exclusions(self):
        data = gate.read_manifest(self.root)
        data['claims']['HeaderSafety']['sections'][0]['heading'] = 'Invented heading'
        self.assertTrue(gate.spec_errors(self.root, data))
        data = gate.read_manifest(self.root)
        data['exclusions'] = []
        self.assertTrue(gate.spec_errors(self.root, data))

    def test_malformed_manifest(self):
        for data in [None, [], {}, {'sources': 'invalid'}]:
            with self.subTest(data=data):
                self.assertTrue(gate.spec_errors(self.root, data))

    def test_unsafe_lake_options(self):
        self.mutate('lakefile.toml', '[leanOptions]\ndebug.skipKernelTC = true')
        self.assertTrue(gate.check(self.root))

    def test_changed_revision(self):
        data = gate.read_manifest(self.root)
        data['sources'][0]['revision'] = '0' * 40
        self.assertTrue(gate.spec_errors(self.root, data))


if __name__ == '__main__':
    unittest.main()
