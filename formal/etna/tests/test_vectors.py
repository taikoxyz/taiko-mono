"""The conformance-vector generator: `lake exe etna-vectors` (library EtnaVectors).

Two runs write byte-identical files, and the committed testdata/etna_conformance files
equal a fresh run. The vectors are well formed: unique ids, and hand-written vectors cite an
English spec line. They record only what the model decides: no vector carries a known
divergence, which each consumer's harness lists itself. The four Inbox families (the Etna
contracts' Foundry harness) share one schema; the four client-rule families (the Rust client's
harness) share another. `--families` writes only the named families, byte for byte as a full run. The gate relaxations it needs are
narrow: only EtnaVectors' non-interpolated string literals may contain `{` (every other lint rule
still applies to it, and the rule still applies everywhere else), and the only package
declaration outside the `Etna` namespace the audit admits is the root `main` of
`EtnaVectors.Main`.
"""
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
COMMITTED = ROOT.parents[1]/'testdata/etna_conformance'
FAMILIES = ['forced', 'land', 'recover', 'registry']
CLIENT_FAMILIES = ['block_rules', 'block_size', 'forced_step', 'schedule']


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT/path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


AUDIT = load('vectors_audit', 'scripts/audit_proofs.py')
LINT = load('vectors_lint', 'scripts/lint_sources.py')
CHECK = load('vectors_check', 'scripts/check_vectors.py')


def scratch():
    (ROOT/'.scratch').mkdir(exist_ok=True)
    return tempfile.TemporaryDirectory(dir=ROOT/'.scratch')


def generate(out, *extra):
    """Run the generator into `out`; returns {file name: bytes}."""
    subprocess.run(['lake', 'exe', 'etna-vectors', '--write', str(out), *extra], cwd=ROOT, check=True,
                   capture_output=True, text=True)
    return {p.name: p.read_bytes() for p in sorted(Path(out).iterdir())}


class GeneratorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = scratch()
        base = cls.base = Path(cls.tmp.name)
        cls.first = generate(base/'first')
        cls.second = generate(base/'second')
        cls.stamped = generate(base/'stamped', '--provenance', '0123abcd')

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_two_runs_are_byte_identical(self):
        self.assertEqual(sorted(self.first), sorted(f'{f}.json' for f in FAMILIES + CLIENT_FAMILIES))
        self.assertEqual(self.first, self.second)

    def test_committed_vectors_equal_a_fresh_run(self):
        committed = {p.name: p.read_bytes() for p in sorted(COMMITTED.glob('*.json'))}
        self.assertEqual(sorted(committed), sorted(self.first))
        for name, data in self.first.items():
            self.assertEqual(committed[name], data, f'{name} is stale: run `lake exe etna-vectors --write '
                             '../../testdata/etna_conformance` in formal/etna')

    def test_freshness_check_rejects_stale_missing_and_extra_files(self):
        # scripts/check_vectors.py (CI and the audit) compares the committed files with a fresh run.
        fresh = self.base/'first'
        self.assertEqual(CHECK.differences(fresh, COMMITTED), [])
        with scratch() as tmp:
            committed = Path(tmp)/'committed'
            shutil.copytree(COMMITTED, committed)
            land = committed/'land.json'
            land.write_bytes(land.read_bytes().replace(b'"vectorCount": ', b'"vectorCount": 1', 1))
            (committed/'forced.json').unlink()
            (committed/'old.json').write_text('{}')
            errors = '\n'.join(CHECK.differences(fresh, committed))
        self.assertIn('land.json is stale: run `lake exe etna-vectors --write ../../testdata/etna_conformance`', errors)
        self.assertIn('forced.json is missing', errors)
        self.assertIn('old.json is not generated', errors)
        self.assertNotIn('recover.json', errors)

    def test_provenance_adds_only_the_commit(self):
        for name, data in self.first.items():
            stamped = json.loads(self.stamped[name])
            self.assertEqual(stamped.pop('provenance'), {'formalCommit': '0123abcd'})
            self.assertEqual(stamped, json.loads(data), name)

    def test_family_filter_writes_only_the_named_families(self):
        with scratch() as tmp:
            out = Path(tmp)/'inbox'
            only = generate(out, '--families', 'forced,land,recover,registry')
            self.assertEqual(sorted(only), [f'{f}.json' for f in FAMILIES])
            for name, data in only.items():
                self.assertEqual(data, self.first[name], name)
            result = subprocess.run(['lake', 'exe', 'etna-vectors', '--write', str(Path(tmp)/'bad'),
                                     '--families', 'forced,nope'], cwd=ROOT, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('unknown family nope', result.stderr)
            self.assertFalse((Path(tmp)/'bad').exists())

    def test_vectors_are_well_formed(self):
        for family in FAMILIES:
            document = json.loads(self.first[f'{family}.json'])
            self.assertEqual(document['schema'], 'etna-conformance-1')
            self.assertEqual(document['family'], family)
            vectors = document['vectors']
            self.assertEqual(document['vectorCount'], len(vectors))
            ids = [v['id'] for v in vectors]
            self.assertEqual(len(ids), len(set(ids)), family)
            for v in vectors:
                self.assertTrue(v['id'].startswith(family+'.'), v['id'])
                self.assertEqual(v['family'], family)
                self.assertEqual(v['setup']['callCount'], len(v['setup']['calls']), v['id'])
                handwritten = v['source'] == 'handwritten'
                self.assertEqual(handwritten, 'spec' in v, v['id'])
                if handwritten:
                    self.assertRegex(v['spec'], r'^EN L\d+$', v['id'])
                self.assertEqual(sorted(v), sorted({'id', 'family', 'source', 'setup', 'call', 'expect'}
                                                   | ({'spec'} if handwritten else set())), v['id'])

    def test_client_vectors_are_well_formed(self):
        for family in CLIENT_FAMILIES:
            document = json.loads(self.first[f'{family}.json'])
            self.assertEqual(document['schema'], 'etna-client-conformance-1')
            self.assertEqual(document['family'], family)
            vectors = document['vectors']
            self.assertEqual(document['vectorCount'], len(vectors))
            self.assertTrue(vectors, family)
            ids = [v['id'] for v in vectors]
            self.assertEqual(len(ids), len(set(ids)), family)
            for v in vectors:
                self.assertTrue(v['id'].startswith(family+'.'), v['id'])
                self.assertEqual(v['family'], family)
                self.assertTrue(v['input'] and v['expect'], v['id'])
                handwritten = v['source'] == 'handwritten'
                self.assertEqual(handwritten, 'spec' in v, v['id'])
                self.assertEqual(handwritten, '.hw.' in v['id'], v['id'])
                if handwritten:
                    self.assertRegex(v['spec'], r'^EN L\d+$', v['id'])
                self.assertEqual(sorted(v), sorted({'id', 'family', 'source', 'input', 'expect'}
                                                   | ({'spec'} if handwritten else set())), v['id'])

    def test_every_number_is_exact_in_a_double(self):
        # Readers that parse JSON numbers as doubles (and forge's JSON cheatcodes) stay exact.
        def walk(value):
            if isinstance(value, bool):
                return
            if isinstance(value, int):
                self.assertLess(value, 2**53)
            elif isinstance(value, list):
                for item in value:
                    walk(item)
            elif isinstance(value, dict):
                for item in value.values():
                    walk(item)
        for data in self.first.values():
            walk(json.loads(data))


class VectorsLintTests(unittest.TestCase):
    def test_vectors_plain_strings_may_hold_braces(self):
        for source in ('def s := "{"', 'def s := "{}"', 'def s := "}, {\\n"'):
            self.assertEqual(LINT.lint_text(source, vectors=True), [], source)
            self.assertIn('interpolation', '\n'.join(LINT.lint_text(source)), source)

    def test_interpolation_still_rejected_in_vectors(self):
        for source in ('def s := s!"{1}"', 'def s := s! "{"', 'def s := "{x}"', 'def s := f!"{"',
                       'def s : Nat := dbg_trace "{"; 1', 'def s := "{ sorry }"'):
            self.assertIn('interpolation', '\n'.join(LINT.lint_text(source, vectors=True)), source)

    def test_other_rules_still_apply_to_vectors(self):
        cases = {
            '#eval 1': 'forbidden command `#eval`',
            'unsafe def u : Nat := 1': 'forbidden keyword `unsafe`',
            'partial def p : Nat → Nat | n => p n': 'forbidden keyword `partial`',
            'theorem t : True := sorry': 'forbidden keyword `sorry`',
            'axiom a : False': 'forbidden keyword `axiom`',
            'run_cmd pure ()': 'forbidden keyword `run_cmd`',
            '@[implemented_by f] def g := 1': 'attribute `implemented_by`',
            'import Lean\n': 'outside Init/Std and the Etna libraries',
        }
        for source, message in cases.items():
            self.assertIn(message, '\n'.join(LINT.lint_text(source, vectors=True)), source)

    def test_braces_rejected_outside_vectors_in_the_package(self):
        line = '\ndef Etna.Design.braceProbe : String := "{"\n'
        with scratch() as tmp:
            root = Path(tmp)/'etna'
            shutil.copytree(ROOT, root, ignore=shutil.ignore_patterns('.lake', '.scratch', '__pycache__'))
            for path in ('EtnaModel/Common.lean', 'EtnaProofs/Common.lean', 'EtnaWitnesses.lean'):
                (root/path).write_text((root/path).read_text()+line)
            (root/'EtnaVectors/Json.lean').write_text((root/'EtnaVectors/Json.lean').read_text()+line)
            errors = '\n'.join(LINT.lint(root))
        for path in ('EtnaModel/Common.lean', 'EtnaProofs/Common.lean', 'EtnaWitnesses.lean'):
            self.assertIn(path+':', errors)
        self.assertNotIn('EtnaVectors/Json.lean', errors)


class EntryPointAuditTests(unittest.TestCase):
    """The package audit admits a root `main` only as EtnaVectors.Main's own declaration."""

    def test_root_main_elsewhere_rejected(self):
        with scratch() as tmp:
            tmp = Path(tmp)
            shutil.copytree(ROOT/'.lake/build/lib/lean', tmp, dirs_exist_ok=True)
            env = AUDIT.lean_env(ROOT, [tmp, AUDIT.build_audit_library()])
            module = tmp/'EtnaProofs/AuditProbe.lean'
            module.write_text('import EtnaModel\ndef main (_ : List String) : IO UInt32 := pure 0\n')
            AUDIT.run(env+['lean', '--root='+str(tmp), '-o', str(module.with_suffix('.olean')), str(module)])
            libraries = [lib for lib in AUDIT.GRAPH.declared_libraries() if lib != 'EtnaVectors']
            probe = tmp/'Probe.lean'
            probe.write_text('import Lean\nimport EtnaAudit\n' + ''.join(f'import {lib}\n' for lib in libraries)
                             + 'import EtnaProofs.AuditProbe\n'
                             + AUDIT.render_package_check(json.loads((ROOT/'manifests/design.json').read_text())
                                                          ['theorems'])+'\n')
            result = subprocess.run(env+['lean', str(probe)], cwd=ROOT, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0, 'a root main outside EtnaVectors.Main must fail the audit')
        self.assertIn('main in EtnaProofs.AuditProbe is outside the Etna namespace', result.stdout+result.stderr)


if __name__ == '__main__':
    unittest.main()
