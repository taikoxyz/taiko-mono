"""The library split: Model/Statements hold no proofs and imports only point down the graph
EtnaWitnesses -> EtnaProofs -> EtnaStatements -> EtnaModel (EtnaVectors -> EtnaModel)."""
import importlib.util
from pathlib import Path
import re
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT/path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


CHECK = load('graph_check', 'scripts/check_imports.py')
LINT = load('graph_lint', 'scripts/lint_sources.py')


def edit(path, old, new):
    text = path.read_text()
    if old not in text:
        raise AssertionError(f'mutation anchor missing in {path}: {old!r}')
    path.write_text(text.replace(old, new, 1))


class LibraryGraphTests(unittest.TestCase):
    def errors(self, mutate, check=CHECK.errors):
        """Errors of `check` on a source-only package copy after `mutate(root)`."""
        (ROOT/'.scratch').mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT/'.scratch') as tmp:
            root = Path(tmp)/'etna'
            shutil.copytree(ROOT, root, ignore=shutil.ignore_patterns('.lake', '.scratch', '__pycache__'))
            mutate(root)
            return '\n'.join(check(root))

    def test_current_tree_passes(self):
        self.assertEqual(CHECK.errors(ROOT), [])
        self.assertEqual(CHECK.declared_libraries(ROOT), [*CHECK.REQUIRED_LIBRARIES, 'EtnaVectors'])
        for library in CHECK.declared_libraries(ROOT):
            self.assertTrue((ROOT/f'{library}.lean').exists(), library)

    def test_model_importing_proofs_rejected(self):
        errors = self.errors(lambda r: edit(r/'EtnaModel/Common.lean', 'import Std', 'import Std\nimport EtnaProofs.Common'))
        self.assertIn('EtnaModel/Common.lean:2: EtnaModel may import only Init, Std and EtnaModel; '
                      '`EtnaProofs.Common` is not allowed', errors)

    def test_statements_importing_witnesses_rejected(self):
        errors = self.errors(lambda r: (r/'EtnaStatements.lean').write_text(
            'import EtnaWitnesses\n'+(r/'EtnaStatements.lean').read_text()))
        self.assertIn('`EtnaWitnesses` is not allowed', errors)

    def test_theorem_in_statements_rejected(self):
        def mutate(root):
            path = root/'EtnaStatements.lean'
            path.write_text(path.read_text()+'\nnamespace Etna.Statements\ntheorem sneaky : True := trivial\n'
                            'end Etna.Statements\n')
        self.assertIn('theorem `Etna.Statements.sneaky` in EtnaStatements', self.errors(mutate))

    def test_theorem_in_model_rejected(self):
        def mutate(root):
            path = root/'EtnaModel/Common.lean'
            edit(path, 'end Etna.Design', 'namespace Inner\nprivate theorem hidden : True := trivial\nend Inner\n'
                 'end Etna.Design')
        self.assertIn('theorem `Etna.Design.Inner.hidden` in EtnaModel', self.errors(mutate))

    def test_sixth_library_rejected(self):
        def mutate(root):
            (root/'lakefile.toml').write_text((root/'lakefile.toml').read_text()+'\n[[lean_lib]]\nname = "EtnaExtra"\n')
            (root/'EtnaExtra.lean').write_text('import EtnaModel\n')
        self.assertIn("library 'EtnaExtra' is not one of the Etna libraries", self.errors(mutate))
        self.assertIn("library 'EtnaExtra' is not one of the Etna libraries", self.errors(mutate, LINT.lint))

    def test_missing_required_library_rejected(self):
        errors = self.errors(lambda r: edit(r/'lakefile.toml', '[[lean_lib]]\nname = "EtnaWitnesses"\n', ''))
        self.assertIn('required library EtnaWitnesses is missing', errors)
        self.assertIn('EtnaWitnesses.lean: no [[lean_lib]] EtnaWitnesses in lakefile.toml builds it', errors)

    def test_vectors_library_may_read_only_the_model(self):
        self.assertIn('EtnaVectors may import only Init, Std and EtnaVectors, EtnaModel; `EtnaProofs` is not allowed',
                      self.errors(lambda r: edit(r/'EtnaVectors/Machine.lean', 'import EtnaModel\n',
                                                 'import EtnaModel\nimport EtnaProofs\n')))

    def test_nothing_imports_the_vectors_library(self):
        errors = self.errors(lambda r: edit(r/'EtnaWitnesses.lean', 'import ', 'import EtnaVectors\nimport '))
        self.assertIn('EtnaWitnesses may import only Init, Std and EtnaWitnesses, EtnaProofs, EtnaStatements, '
                      'EtnaModel; `EtnaVectors` is not allowed', errors)

    def test_lint_accepts_the_vectors_library_and_executable(self):
        self.assertEqual('\n'.join(LINT.lint(ROOT)), '')
        def other_root(root):
            edit(root/'lakefile.toml', 'root = "EtnaVectors.Main"', 'root = "EtnaVectors.Json"')
        self.assertIn('the [[lean_exe]] etna-vectors rooted at EtnaVectors.Main', self.errors(other_root, LINT.lint))

    def test_allowlisted_model_theorem_accepted_and_stale_entry_rejected(self):
        name = 'Etna.Design.Inner.needed'
        saved = dict(CHECK.ALLOWED_MODEL_THEOREMS)
        try:
            CHECK.ALLOWED_MODEL_THEOREMS[name] = 'cited by a definition (test)'
            self.assertIn(f'stale entry {name}', self.errors(lambda r: None))
            self.assertEqual(self.errors(lambda r: edit(
                r/'EtnaModel/Common.lean', 'end Etna.Design',
                'namespace Inner\ntheorem needed : True := trivial\nend Inner\nend Etna.Design')), '')
        finally:
            CHECK.ALLOWED_MODEL_THEOREMS.clear()
            CHECK.ALLOWED_MODEL_THEOREMS.update(saved)

    def test_module_outside_root_closure_rejected(self):
        errors = self.errors(lambda r: (r/'EtnaProofs/Orphan.lean').write_text('import EtnaModel\n'))
        self.assertIn('EtnaProofs/Orphan.lean: not imported from EtnaProofs.lean', errors)

    def test_lint_reports_graph_errors(self):
        errors = self.errors(lambda r: edit(r/'EtnaModel/Common.lean', 'import Std', 'import Std\nimport EtnaProofs.Common'),
                             LINT.lint)
        self.assertIn('`EtnaProofs.Common` is not allowed', errors)

    def test_audit_library_list_matches(self):
        # scripts/EtnaAudit.lean enumerates package modules by these library prefixes, and checks
        # the built declarations of the theorem-free ones.
        audit = (ROOT/'scripts/EtnaAudit.lean').read_text()
        for name, expected in (('packageLibraries', CHECK.LIBRARIES), ('definitionLibraries', CHECK.THEOREM_FREE_LIBRARIES)):
            listed = re.search(rf'def {name} : List Name :=\s*\[([^\]]*)\]', audit)
            self.assertIsNotNone(listed, name)
            self.assertEqual([n.strip().lstrip('`') for n in listed.group(1).split(',')], list(expected))


if __name__ == '__main__':
    unittest.main()
