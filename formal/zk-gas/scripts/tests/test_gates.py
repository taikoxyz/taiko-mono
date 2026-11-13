"""Mutation tests for the package's bounded source/import/spec checks, and table checks."""
import importlib.util
from pathlib import Path
import re
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
        self.root = Path(self.temp.name) / 'formal/zk-gas'
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
                self.assertTrue(gate.source_errors('ZkGasProofs.X', token))

    def test_nested_comments_and_strings(self):
        self.assertEqual(gate.source_errors('ZkGasProofs.X',
                         '/- sorry /- unsafe -/ axiom -/\ndef x := "admit" -- native_decide\n'), [])

    def test_unterminated_lexemes(self):
        for text in ['/- unclosed', '"unclosed', '«unclosed']:
            with self.subTest(text=text):
                self.assertTrue(gate.source_errors('ZkGasProofs.X', text))

    def test_guard_allowlist(self):
        self.assertEqual(gate.source_errors('ZkGasWitnesses.Tests', '#guard true'), [])
        self.assertTrue(gate.source_errors('ZkGasWitnesses.Examples', '#guard true'))
        self.assertTrue(gate.source_errors('ZkGasProofs.Claims', '#guard true'))
        self.assertTrue(gate.source_errors('ZkGasWitnesses.Tests', '#eval 1'))

    def test_upward_import(self):
        self.mutate('ZkGasModel.lean', 'import ZkGasProofs')
        self.assertTrue(gate.check(self.root))

    def test_multiple_and_multiline_import(self):
        self.mutate('ZkGasModel.lean', 'import\n ZkGasModel.Meter ZkGasProofs')
        self.assertTrue(gate.check(self.root))

    def test_unknown_import(self):
        self.mutate('ZkGasProofs.lean', 'import ZkGasProofs.Missing')
        self.assertTrue(gate.check(self.root))

    def test_metaprogramming_import(self):
        self.mutate('ZkGasModel.lean', 'import Lean.Data.Json')
        self.assertTrue(gate.check(self.root))

    def test_orphan_module(self):
        (self.root / 'ZkGasProofs/Orphan.lean').write_text('def orphan := 1')
        self.assertTrue(gate.check(self.root))

    def test_missing_root(self):
        (self.root / 'ZkGasTraces.lean').unlink()
        self.assertTrue(gate.check(self.root))

    def test_proof_in_definition_layer(self):
        for lib in ['ZkGasModel', 'ZkGasStatements']:
            self.assertTrue(gate.source_errors(lib, 'theorem bad : True := by trivial'))
            self.assertTrue(gate.source_errors(lib, 'example : True := by trivial'))

    def test_spec_drift(self):
        path = self.root.parents[1] / gate.SPEC_PATHS[0]
        path.write_text(path.read_text() + '\nChanged\n')
        self.assertTrue(gate.check(self.root))

    def test_missing_claim_link(self):
        data = gate.read_manifest(self.root)
        del data['claims']['AbortContributesNothing']
        self.assertTrue(gate.spec_errors(self.root, data))

    def test_bad_section_and_weak_exclusions(self):
        data = gate.read_manifest(self.root)
        data['claims']['TotalIsSum']['sections'][0]['heading'] = 'Invented heading'
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


    def test_wrong_claim_link(self):
        data = gate.read_manifest(self.root)
        data['claims']['TotalIsSum']['theorem'] = 'TaikoSpec.ZkGas.Proofs.block_within_limit'
        self.assertTrue(gate.spec_errors(self.root, data))

    def test_changed_executable(self):
        path = self.root / 'lakefile.toml'
        path.write_text(path.read_text().replace('root = "ZkGasTraces.Main"', 'root = "ZkGasModel.Meter"'))
        self.assertTrue(gate.check(self.root))

    def test_json_only_in_trace_parser_and_checker(self):
        allowed = 'import Lean.Data.Json\ndef f (j : Lean.Json) (n : Lean.JsonNumber) := Lean.Json.parse'
        self.assertEqual(gate.JSON_MODULES, {'ZkGasTraces.Json', 'ZkGasTraces.Check'})
        for module in sorted(gate.JSON_MODULES):
            with self.subTest(module=module):
                self.assertEqual(gate.source_errors(module, allowed), [])
                # Only the JSON names; no other Lean name and no proof escape behind one.
                for text in ['def f := Lean.Elab.Command', 'def f := Lean.ofReduceBool',
                             'def f := Lean.Json.partial', 'def f := Lean.Data.Json']:
                    self.assertTrue(gate.source_errors(module, text), text)
        for module in ['ZkGasModel.Pre', 'ZkGasStatements.Claims', 'ZkGasProofs.Claims',
                       'ZkGasWitnesses.Tests', 'ZkGasTraces.Main']:
            with self.subTest(module=module):
                self.assertTrue(gate.source_errors(module, 'import Lean.Data.Json'))
                self.assertTrue(gate.source_errors(module, 'def f := Lean.Json.parse'))

    def test_json_import_graph(self):
        for path, line in [('ZkGasTraces/Main.lean', 'import Lean.Data.Json'),
                           ('ZkGasModel/Pre.lean', 'import Lean.Data.Json'),
                           ('ZkGasTraces/Json.lean', 'import Lean.Elab'),
                           ('ZkGasTraces/Check.lean', 'import Lean')]:
            with self.subTest(path=path, line=line):
                original = (self.root / path).read_text()
                (self.root / path).write_text(line + '\n' + original)
                self.assertTrue(gate.check(self.root))
                (self.root / path).write_text(original)


class TableTests(unittest.TestCase):
    """The committed tables against the pinned specification. CI has no alethia-reth or revm
    sources, so `gen_tables.py --check` runs only locally; this catches a hand edit of the
    multipliers, spawn estimates or constants, and any disagreement with the specification."""

    @staticmethod
    def entries(text, name):
        body = text.split(f'def {name} : List (Nat × Nat) := [', 1)[1].split(']', 1)[0]
        return {int(k, 16): int(v) for k, v in re.findall(r'\((0x[0-9a-f]+), (\d+)\)', body)}

    def setUp(self):
        self.tables = (ROOT / 'ZkGasModel/Tables.lean').read_text()
        self.spec = (ROOT.parents[1] / gate.SPEC_PATHS[0]).read_text()

    def test_generated_header(self):
        self.assertIn('Generated by `scripts/gen_tables.py`; do not edit by hand.', self.tables)

    def test_multipliers_match_appendix_b(self):
        precompiles = {int(a, 16): int(m) for a, m in
                       re.findall(r'(?m)^\| \w+ \| (0x[0-9a-f]{40}) \| (\d+) \|$', self.spec)}
        opcodes = {int(o, 16): int(m) for o, m in
                   re.findall(r'(?m)^\| \w+ \| (0x[0-9a-f]{2}) \| (\d+) \|$', self.spec)}
        self.assertEqual(len(precompiles), 18)
        self.assertEqual(len(opcodes), 150)
        self.assertEqual(self.entries(self.tables, 'unzenPrecompileMultipliers'), precompiles)
        self.assertEqual(self.entries(self.tables, 'unzenOpcodeMultiplierEntries'), opcodes)

    def test_constants_and_spawn_estimates_match(self):
        names = {'CALL': 0xf1, 'CALLCODE': 0xf2, 'DELEGATECALL': 0xf4, 'STATICCALL': 0xfa,
                 'CREATE': 0xf0, 'CREATE2': 0xf5}
        block = self.spec.split('SPAWN_ESTIMATE = {', 1)[1].split('}', 1)[0]
        spawn = {names[n]: int(v.replace('_', '')) for n, v in re.findall(r'(\w+):\s+([\d_]+),', block)}
        self.assertEqual(self.entries(self.tables, 'unzenSpawnEstimates'), spawn)
        for constant, lean in [('BLOCK_ZK_GAS_LIMIT', 'unzenBlockLimit'), ('TX_INTRINSIC_ZK_GAS', 'unzenTxIntrinsic')]:
            value = re.search(rf'\| `{constant}` \| ([\d,]+) \|', self.spec).group(1).replace(',', '')
            self.assertIn(f'def {lean} : Nat := {value}\n', self.tables)
        self.assertIn('def failsafeMultiplier : Nat := 65535\n', self.tables)

    def test_corpus_readme_lists_the_stack_inputs(self):
        readme = (ROOT.parents[1] / 'testdata/zk_gas_vectors/README.md').read_text()
        section = readme.split('### Stack inputs', 1)[1].split('\n### ', 1)[0]
        rows = re.findall(r'(?m)^\| `([0-9a-f])_` \|(.*)\|$', section)
        self.assertEqual([hi for hi, _ in rows], list('0123456789abcdef'))
        listed = {}
        for hi, cells in rows:
            values = [cell.strip() for cell in cells.split('|')]
            self.assertEqual(len(values), 16)
            listed.update({int(hi, 16) * 16 + lo: int(v) for lo, v in enumerate(values) if v != '–'})
        self.assertEqual(listed, self.entries(self.tables, 'inputsEntries'))

if __name__ == '__main__':
    unittest.main()
