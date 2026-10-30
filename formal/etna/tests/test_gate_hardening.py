"""Regressions for proof-gate bypasses: build-time code, foreign libraries, manifest-type
injection, name shadowing, unchecked Lean tests, manifest modules and self-assigned roles
(including vacuous-binder `property` laundering, Rule P, the derived-proof rule in both
directions and dead `have`/`let` bindings that would fake a derivation), what each library may
hold, and the headline layer (exact claim types, every premise read by a headline proof)."""
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT/path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


AUDIT = load('gate_audit', 'scripts/audit_proofs.py')
LINT = load('gate_lint', 'scripts/lint_sources.py')
COVERAGE = load('gate_coverage', 'scripts/check_spec_coverage.py')
MANIFEST = json.loads((ROOT/'manifests/design.json').read_text())
ENTRIES = {e['declaration']: e for e in MANIFEST['theorems']}


def scratch():
    (ROOT/'.scratch').mkdir(exist_ok=True)
    return tempfile.TemporaryDirectory(dir=ROOT/'.scratch')


def copy_package(tmp, build=False):
    """Copy the package (optionally with its Lake build) for an on-disk mutation."""
    root = Path(tmp)/'etna'
    ignore = shutil.ignore_patterns('.scratch', '__pycache__', *(() if build else ('.lake',)))
    shutil.copytree(ROOT, root, ignore=ignore)
    return root


def edit(path, old, new):
    text = path.read_text()
    if old not in text:
        raise AssertionError(f'mutation anchor missing in {path}: {old!r}')
    path.write_text(text.replace(old, new, 1))


def combined_source(stem):
    """One compilable file: EtnaModel/<stem>.lean followed by the theorems of EtnaProofs/<stem>.lean,
    so a weakened definition must break a theorem proved about it (imports hoisted)."""
    parts = [(ROOT/lib/f'{stem}.lean').read_text().split('\n') for lib in ('EtnaModel', 'EtnaProofs')]
    imports, bodies = [], []
    for lines in parts:
        k = 0
        while k < len(lines) and lines[k].startswith('import '):
            imports.append(lines[k])
            k += 1
        bodies.append('\n'.join(lines[k:]))
    own = f'import EtnaModel.{stem}'
    return '\n'.join(dict.fromkeys(i for i in imports if i != own))+'\n'+'\n'.join(bodies)


class SourceLintTests(unittest.TestCase):
    """M6/M7/M10 at the first CI step: nothing in the package runs before this lint."""

    def lint_errors(self, mutate):
        with scratch() as tmp:
            root = copy_package(tmp)
            mutate(root)
            return '\n'.join(LINT.lint(root))

    def test_current_sources_pass(self):
        self.assertEqual(LINT.lint(ROOT), [])

    def test_m7_build_time_eval_rejected(self):
        payload = ('\nnamespace Etna.Design.Deployment\n#eval show IO Unit from do\n'
                   '  IO.FS.writeFile "scripts/audit_proofs.py" ""\nend Etna.Design.Deployment\n')
        errors = self.lint_errors(lambda r: (r/'EtnaModel/Deployment.lean').write_text(
            (r/'EtnaModel/Deployment.lean').read_text()+payload))
        self.assertIn('forbidden command `#eval`', errors)

    def test_m6_second_library_and_foreign_import_rejected(self):
        def mutate(root):
            (root/'lakefile.toml').write_text((root/'lakefile.toml').read_text()+'\n[[lean_lib]]\nname = "Helper"\n')
            (root/'Helper.lean').write_text('import Lean\nset_option debug.skipKernelTC true in\n'
                                            'run_elab Lean.addDecl default\n')
            edit(root/'EtnaModel/Deployment.lean', 'import EtnaModel.ProtocolState', 'import Helper\nimport EtnaModel.ProtocolState')
        errors = self.lint_errors(mutate)
        self.assertIn("library 'Helper' is not one of the Etna libraries", errors)
        self.assertIn('one plain [[lean_lib]] per Etna library', errors)
        self.assertIn('import `Helper` is outside Init/Std and the Etna libraries', errors)

    def test_lake_options_and_lakefile_lean_rejected(self):
        def mutate(root):
            (root/'lakefile.toml').write_text((root/'lakefile.toml').read_text()
                                              + 'moreLeanArgs = ["-Ddebug.skipKernelTC=true"]\n')
            (root/'lakefile.lean').write_text('import Lake\n')
        errors = self.lint_errors(mutate)
        self.assertIn('lakefile.lean is not allowed', errors)
        self.assertIn('one plain [[lean_lib]] per Etna library', errors)

    def test_tracked_build_outputs_rejected(self):
        def mutate(root):
            forged = root/'.lake/build/lib/lean/Etna/Forged.olean'
            forged.parent.mkdir(parents=True)
            forged.write_bytes(b'forged')
            subprocess.run(['git', 'init', '-q'], cwd=root, check=True)
            subprocess.run(['git', 'add', '-f', str(forged.relative_to(root))], cwd=root, check=True)
        self.assertIn('tracked build outputs are not allowed', self.lint_errors(mutate))

    def test_m10_sorry_and_axiom_in_lean_tests_rejected(self):
        def mutate(root):
            path = root/'tests/ReviewFixes.lean'
            edit(path, 'old_signatures_check_only_old_key : SecondBatch.verifyEvidence 7 SecondBatch.oldA 101 = true ∧\n'
                       '    SecondBatch.verifyEvidence 8 SecondBatch.oldA 101 = false := by decide +kernel',
                 'old_signatures_check_only_old_key : SecondBatch.verifyEvidence 7 SecondBatch.oldA 101 = true ∧\n'
                 '    SecondBatch.verifyEvidence 8 SecondBatch.oldA 101 = false := by sorry')
            edit(path, 'end Etna.Design.ReviewFixes', 'axiom poison : False\nend Etna.Design.ReviewFixes')
        errors = self.lint_errors(mutate)
        self.assertIn('forbidden keyword `sorry`', errors)
        self.assertIn('forbidden keyword `axiom`', errors)

    def test_elaboration_hooks_and_trust_escapes_rejected(self):
        cases = {
            '@[macro Lean.Parser.Term.paren] def evil : Lean.Macro := fun _ => default': 'attribute `macro`',
            'attribute [implemented_by foo] bar': 'attribute `implemented_by`',
            'set_option debug.skipKernelTC true in\ntheorem t : True := trivial': 'forbidden option',
            'theorem t : True := by decide +native': 'forbidden keyword `native`',
            'theorem t : True := Lean.ofReduceBool _ _ rfl': 'forbidden identifier',
            'run_cmd pure ()': 'forbidden keyword `run_cmd`',
            'notation "x" => 1': 'forbidden keyword `notation`',
            'export Nat (succ)': 'forbidden keyword `export`',
            'def s := s!"{1}"': 'interpolation',
            '#check Nat': 'forbidden command `#check`',
            'unsafe def u : Nat := 1': 'forbidden keyword `unsafe`',
            'opaque o : Nat': 'forbidden keyword `opaque`',
        }
        for source, message in cases.items():
            self.assertIn(message, '\n'.join(LINT.lint_text(source)), source)

    def test_lexer_matches_lean_on_hiding_tricks(self):
        # Each payload makes Lean execute `#eval` (checked against Lean itself when written);
        # a lexer that disagrees with Lean on comments/literals would miss it.
        for source in ('/-/- -/\n#eval 1\n-- -/\n', 'def r := r"\\" \n#eval 1 -- "\n',
                       "def c := '\"' \n#eval 1 -- \"\n", 'def «"» := 1\n#eval 1 -- "\n',
                       'def x := 0x1Fsorry\n'):
            self.assertTrue(LINT.lint_text(source), source)
        clean = ('-- sorry axiom #eval\n/- run_elab /- nested -/ unsafe -/\n/--/ #eval 1 -/\n'
                 'def external := 1\ndef initialized := "sorry axiom"\n'
                 "def f (b : Array Nat) (h : 0 < b.size) := b[0]'h\ndef v := #v[1]\n"
                 '@[simp, local simp ←] theorem t : True := trivial\nset_option maxHeartbeats 1 in\ndef y := 1\n')
        self.assertEqual(LINT.lint_text(clean), [])


class ManifestTypeTests(unittest.TestCase):
    """M8 and P4 on a single-entry audit (exact type, syntax policy and mechanical role)."""

    def audit(self, entry, declarations=''):
        text = AUDIT.render_audit([entry], complete=False)
        text = text.replace('set_option pp.universes false', declarations+'\nset_option pp.universes false', 1)
        with scratch() as tmp, open(Path(tmp)/'GateAudit.lean', 'w') as file:
            file.write(text)
            file.flush()
            AUDIT.check_axioms([entry], AUDIT.check_kernel_file(file.name))

    def synthetic(self, typ, role='regression'):
        return {'declaration': 'Etna.Design.AuditTest.checked', 'module': 'EtnaProofs.Common', 'type': typ,
                'bridge_level': 'spec-proved', 'role': role, 'sources': ['synthetic'], 'scope': 'audit test only',
                'assumptions': ['synthetic audit regression; not a protocol obligation']}

    def real(self, name, **changes):
        return {**ENTRIES[name], **changes}

    def audit_many(self, cases, declarations):
        """Audit several synthetic `property` entries in one Lean run; returns the output."""
        entries = [{**self.synthetic(typ, 'property'), 'declaration': 'Etna.Design.AuditTest.'+name}
                   for name, typ in cases.items()]
        text = AUDIT.render_audit(entries, complete=False)
        text = text.replace('set_option pp.universes false', declarations+'\nset_option pp.universes false', 1)
        with scratch() as tmp, open(Path(tmp)/'GateAudit.lean', 'w') as file:
            file.write(text)
            file.flush()
            try:
                AUDIT.check_axioms(entries, AUDIT.check_kernel_file(file.name))
            except ValueError as exc:
                return str(exc)
        return ''

    def test_m8_type_of_echo_rejected(self):
        name = 'Etna.Design.Deployment.constructed_configuration_unique'
        with self.assertRaisesRegex(ValueError, 'forbidden syntax `type_of%`'):
            self.audit(self.real(name, type='type_of% @'+name))

    def test_m8_newline_injection_stays_data(self):
        name = 'Etna.Design.Deployment.constructed_configuration_unique'
        injected = ENTRIES[name]['type']+'))\n  set_option debug.skipKernelTC true\n#exit\n-- "\\'
        self.assertIn('\\"\\\\"', AUDIT.lean_string(injected))
        with self.assertRaisesRegex(ValueError, 'not exactly one Lean term'):
            self.audit(self.real(name, type=injected))

    def test_lean_string_escapes_and_rejects_controls(self):
        self.assertEqual(AUDIT.lean_string('a\\"b\n∀ x'), '"a\\\\\\"b\\n∀ x"')
        for bad in ('a\rb', 'a‮b', 'a\x00b', 'a\tb'):
            with self.assertRaises(ValueError):
                AUDIT.lean_string(bad)

    def test_self_reference_and_tactics_rejected(self):
        decl = 'namespace Etna.Design.AuditTest\ntheorem checked : True := True.intro\nend Etna.Design.AuditTest'
        with self.assertRaisesRegex(ValueError, 'refers to the theorem itself'):
            self.audit(self.synthetic('(fun (_ : True) => True) checked'), decl)
        with self.assertRaisesRegex(ValueError, 'forbidden syntax `by`'):
            self.audit(self.synthetic('(by exact True)'), decl)

    def test_p4_closed_regression_cannot_be_property(self):
        with self.assertRaisesRegex(ValueError, 'role property requires'):
            self.audit(self.real('Etna.Design.FirstBatch.ordinary_handover', role='property'))

    def test_p4_constant_cannot_be_property(self):
        with self.assertRaisesRegex(ValueError, 'role property requires'):
            self.audit(self.real('Etna.Design.Budget.cap_derivation', role='property'))

    def test_bare_claim_theorem_cannot_be_constant(self):
        # `fund_safety : FundSafety` shows no binder until the claim is unfolded; the constant
        # role reads statements through `statementView`, as Rule P does.
        with self.assertRaisesRegex(ValueError, 'role constant requires a closed statement without leading binders: '
                                    'Etna.Proofs.fund_safety'):
            self.audit(self.real('Etna.Proofs.fund_safety', role='constant'))

    def test_p4_weakened_conclusion_cannot_be_property(self):
        # mut3: hypotheses kept, conclusion weakened to a closed `True`.
        decl = ('namespace Etna.Design.AuditTest\n'
                'theorem checked {a b : Nat} (h : a = b) : True := trivial\nend Etna.Design.AuditTest')
        with self.assertRaisesRegex(ValueError, 'role property requires'):
            self.audit(self.synthetic('∀ {a b : Nat} (h : a = b), True', 'property'), decl)
        with self.assertRaisesRegex(ValueError, 'role constant requires'):
            self.audit(self.synthetic('∀ {a b : Nat} (h : a = b), True', 'constant'), decl)

    def test_mechanical_roles_accept_current_examples(self):
        self.audit(self.real('Etna.Design.Budget.cap_derivation'))
        self.audit(self.real('Etna.Design.Consensus.election_valid_iff'))
        self.audit(self.real('Etna.Design.Accountability.conflicting_commits_double_sign'))

    def test_rule_p_vacuous_binders_cannot_launder_closed_facts(self):
        # Each statement quantifies over something, yet its content is the closed fact C
        # (or a reflexivity/witness-only atom). Rule P rejects every one, naming the atom.
        closed = 'SecondBatch.editedWorld.inbox.epochLen = 3'
        cases = {
            'launder_unit': f'∀ _u : Unit, _u = _u ∧ {closed}',
            'launder_hypothesis': f'∀ n : Nat, n < n + 1 → {closed}',
            'launder_or': f'∀ x : Nat, {closed} ∨ x = x',
            'launder_exists': f'∀ _x : Nat, ∃ y : Nat, y = y ∧ {closed}',
            'launder_witness_only': '∀ _x : Nat, ∃ y : Nat, y = 0',
            'launder_iff': '∀ x : Nat, (x < 1 ↔ x < 1)',
            'launder_heq': '∀ x : Nat, HEq x x',
            'launder_true': '∀ x : Nat, x < x + 1 ∧ True',
            'launder_beta': f'∀ x : Nat, (fun (_ : Nat) => {closed}) x',
            'launder_no_binders': closed,
        }
        decl = ('namespace Etna.Design.AuditTest\n'
                f'theorem closed_fact : {closed} := by decide +kernel\n'
                'theorem launder_unit : ∀ _u : Unit, _u = _u ∧ SecondBatch.editedWorld.inbox.epochLen = 3 :=\n'
                '  fun _ => ⟨rfl, closed_fact⟩\n'
                'theorem launder_hypothesis : ∀ n : Nat, n < n + 1 → SecondBatch.editedWorld.inbox.epochLen = 3 :=\n'
                '  fun _ _ => closed_fact\n'
                'theorem launder_or : ∀ x : Nat, SecondBatch.editedWorld.inbox.epochLen = 3 ∨ x = x :=\n'
                '  fun _ => .inl closed_fact\n'
                'theorem launder_exists : ∀ _x : Nat, ∃ y : Nat, y = y ∧ SecondBatch.editedWorld.inbox.epochLen = 3 :=\n'
                '  fun _ => ⟨0, rfl, closed_fact⟩\n'
                'theorem launder_witness_only : ∀ _x : Nat, ∃ y : Nat, y = 0 := fun _ => ⟨0, rfl⟩\n'
                'theorem launder_iff : ∀ x : Nat, (x < 1 ↔ x < 1) := fun _ => .rfl\n'
                'theorem launder_heq : ∀ x : Nat, HEq x x := fun _ => .rfl\n'
                'theorem launder_true : ∀ x : Nat, x < x + 1 ∧ True := fun x => ⟨Nat.lt_succ_self x, trivial⟩\n'
                'theorem launder_beta : ∀ x : Nat, (fun (_ : Nat) => SecondBatch.editedWorld.inbox.epochLen = 3) x :=\n'
                '  fun _ => closed_fact\n'
                'theorem launder_no_binders : SecondBatch.editedWorld.inbox.epochLen = 3 := closed_fact\n'
                'end Etna.Design.AuditTest')
        output = self.audit_many(cases, decl)
        closed_atom = 'SecondBatch.editedWorld.inbox.epochLen'
        expected = {
            'launder_unit': ('is trivially true', '_u _u'),
            'launder_hypothesis': ('uses none', closed_atom),
            'launder_or': ('uses none', closed_atom),
            'launder_exists': ('uses none', 'y y'),
            'launder_witness_only': ('uses none', 'y'),
            'launder_iff': ('is trivially true', 'Iff'),
            'launder_heq': ('is trivially true', 'HEq'),
            'launder_true': ('uses none', 'True'),
            'launder_beta': ('uses none', closed_atom),
            'launder_no_binders': ('uses none', closed_atom),
        }
        errors = {}
        for block in output.split('error: ')[1:]:
            for name in cases:
                if f'Etna.Design.AuditTest.{name}:' in block:
                    errors[name] = ' '.join(block.split())
        self.assertEqual(set(errors), set(cases), output[:2000])
        for name, (reason, atom) in expected.items():
            self.assertIn('role property requires every conclusion atom', errors[name])
            self.assertIn(reason, errors[name], name)
            self.assertIn(atom, errors[name].split('atom `', 1)[1], name)

    def test_rule_p_accepts_genuine_properties(self):
        # Witnesses tied to outer binders, hypotheses, disjunctions and `↔` all pass Rule P;
        # each proof is derived (induction, or a derived Etna theorem), so `property` holds.
        cases = {
            'genuine_exists': '∀ x : Nat, ∃ y : Nat, x < y ∧ y = x + 1',
            'genuine_hypothesis': '∀ (n : Nat) (_h : 0 < n), n - 1 < n ∨ n = 0',
            'genuine_iff': '∀ x : Nat, (x < 1 ↔ x = 0)',
            'genuine_via_etna': '∀ ws : List Encoding.Word, (Encoding.flatBytes ws).length = 32*ws.length',
        }
        decl = ('namespace Etna.Design.AuditTest\n'
                'theorem genuine_exists : ∀ x : Nat, ∃ y : Nat, x < y ∧ y = x + 1 := by\n'
                '  intro x; induction x with\n'
                '  | zero => exact ⟨1, Nat.zero_lt_one, rfl⟩\n'
                '  | succ n _ => exact ⟨n + 2, Nat.lt_succ_self _, rfl⟩\n'
                'theorem genuine_hypothesis : ∀ (n : Nat) (_h : 0 < n), n - 1 < n ∨ n = 0 := by\n'
                '  intro n h; induction n with\n'
                '  | zero => exact .inr rfl\n'
                '  | succ m _ => exact .inl (Nat.sub_lt h Nat.one_pos)\n'
                'theorem genuine_iff : ∀ x : Nat, (x < 1 ↔ x = 0) := by\n'
                '  intro x; induction x <;> exact Nat.lt_one_iff\n'
                'theorem genuine_via_etna : ∀ ws : List Encoding.Word, (Encoding.flatBytes ws).length = 32*ws.length :=\n'
                '  fun ws => Encoding.flatBytes_length ws\n'
                'end Etna.Design.AuditTest')
        self.assertEqual(self.audit_many(cases, decl), '')

    def test_underived_property_shapes_rejected(self):
        # Rule P holds, but no proof is derived: a direct witness, a core lemma proved by
        # induction (`List.append_nil`) and `unfold` of a structurally recursive Etna
        # definition (its generated `eq_def` is proved from `List.brecOn`) all count as none.
        cases = {
            'shallow_exists': '∀ x : Nat, ∃ y : Nat, x < y ∧ y = x + 1',
            'core_induction_only': '∀ l : List Nat, (l ++ []).length = l.length',
            'unfold_only': '∀ a : Cut, cursorSteps [a] = true',
        }
        decl = ('namespace Etna.Design.AuditTest\n'
                'theorem shallow_exists : ∀ x : Nat, ∃ y : Nat, x < y ∧ y = x + 1 :=\n'
                '  fun x => ⟨x + 1, Nat.lt_succ_self x, rfl⟩\n'
                'theorem core_induction_only : ∀ l : List Nat, (l ++ []).length = l.length :=\n'
                '  fun _ => by rw [List.append_nil]\n'
                'theorem unfold_only : ∀ a : Cut, cursorSteps [a] = true := fun _ => by unfold cursorSteps; rfl\n'
                'end Etna.Design.AuditTest')
        output = ' '.join(self.audit_many(cases, decl).split())
        for name in cases:
            self.assertIn(f'role property requires a derived proof: Etna.Design.AuditTest.{name}: not derived',
                          output, name)


class DerivedRoleTests(unittest.TestCase):
    """`property` iff Rule P and a derived proof, `supporting` otherwise, on real entries:
    twins with the same shallow proof are both supporting; induction lemmas and their
    users are property. One Lean run per direction, no package copy."""

    WRONG = {
        'Etna.Design.Committee.exited_not_chosen': 'property',
        'Etna.Design.Committee.covered_exit_never_chosen': 'property',
        'Etna.Design.ProtocolState.trace_generation_monotone': 'supporting',
        'Etna.Design.Deployment.trace_preserves_constraints': 'supporting',
    }

    def audit(self, entries):
        text = AUDIT.render_audit(entries, complete=False)
        with scratch() as tmp, open(Path(tmp)/'GateAudit.lean', 'w') as file:
            file.write(text)
            file.flush()
            try:
                AUDIT.check_axioms(entries, AUDIT.check_kernel_file(file.name))
            except ValueError as exc:
                return ' '.join(str(exc).split())
        return ''

    def test_wrong_roles_rejected_both_ways(self):
        output = self.audit([{**ENTRIES[name], 'role': role} for name, role in self.WRONG.items()])
        errors = {name: block for block in output.split('error: ')[1:] for name in self.WRONG
                  if f'{name}:' in block}
        self.assertEqual(set(errors), set(self.WRONG), output[:2000])
        for name in ('Etna.Design.Committee.exited_not_chosen', 'Etna.Design.Committee.covered_exit_never_chosen'):
            self.assertIn(f'role property requires a derived proof: {name}: not derived', errors[name])
        self.assertIn('role supporting is wrong for a derived Rule P statement: '
                      'Etna.Design.ProtocolState.trace_generation_monotone: derived via '
                      'Etna.Design.ProtocolState.trace_generation_monotone -> Etna.Design.ProtocolState.Trace.rec',
                      errors['Etna.Design.ProtocolState.trace_generation_monotone'])
        self.assertIn('derived via Etna.Design.Deployment.trace_preserves_constraints -> '
                      'Etna.Design.ProtocolState.trace_preserves_immutables -> Etna.Design.ProtocolState.Trace.rec',
                      errors['Etna.Design.Deployment.trace_preserves_constraints'])

    def test_true_roles_accepted(self):
        for name, wrong in self.WRONG.items():
            self.assertNotEqual(ENTRIES[name]['role'], wrong, name)
        self.assertEqual(self.audit([ENTRIES[name] for name in self.WRONG]), '')


class BuiltProbes:
    """Probe modules (`PROBES`: module name -> source) compiled into a copy of the built
    package's oleans (no rebuild), so each sits in its library as a real module would."""
    PROBES = {}

    @classmethod
    def setUpClass(cls):
        cls.tmp = scratch()
        cls.root = Path(cls.tmp.name)
        shutil.copytree(ROOT/'.lake/build/lib/lean', cls.root, dirs_exist_ok=True)
        cls.env = AUDIT.lean_env(ROOT, [cls.root, AUDIT.build_audit_library()])
        for module, source in cls.PROBES.items():
            path = cls.root/(module.replace('.', '/')+'.lean')
            path.write_text(source)
            AUDIT.run(cls.env+['lean', '--root='+str(cls.root), '-o', str(path.with_suffix('.olean')), str(path)])

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()


class DeadBindingTests(BuiltProbes, unittest.TestCase):
    """An unused `have`/`let` cannot make a shallow proof derived: the binding is removed
    before the proof's constants are read. The probe module sits in the built package (no
    rebuild), so its private induction lemma is an Etna source theorem as in the model."""

    SHALLOW = '∀ x : Nat, ∃ y : Nat, x < y ∧ y = x + 1'
    WITNESS = 'fun x => ⟨x + 1, Nat.lt_succ_self x, rfl⟩'
    PROBE = f'''import EtnaProofs
namespace Etna.Design.AuditProbe
private theorem pad_zero : ∀ n : Nat, n + 0 = n := by
  intro n; induction n with
  | zero => rfl
  | succ _ _ => rfl
theorem dead_private_lemma : {SHALLOW} := by
  have _ := pad_zero
  exact {WITNESS}
theorem dead_inline_rec : {SHALLOW} := by
  have _ : True := Nat.rec (motive := fun _ => True) trivial (fun _ _ => trivial) 0
  exact {WITNESS}
theorem dead_derived_property : {SHALLOW} := by
  have _ := @HistoricalContext.prefix_floor
  exact {WITNESS}
theorem dead_nested : {SHALLOW} :=
  have h := pad_zero
  (fun (_ : ∀ n : Nat, n + 0 = n) (x : Nat) =>
    (⟨x + 1, Nat.lt_succ_self x, rfl⟩ : ∃ y : Nat, x < y ∧ y = x + 1)) h
theorem dead_let : {SHALLOW} :=
  let _ := pad_zero
  {WITNESS}
theorem live_lemma : ∀ n : Nat, n + 0 = n := fun n => pad_zero n
end Etna.Design.AuditProbe
'''
    PROBES = {'EtnaProofs.AuditProbe': PROBE}
    DEAD = ('dead_private_lemma', 'dead_inline_rec', 'dead_derived_property', 'dead_nested', 'dead_let')
    LEMMA = '_private.EtnaProofs.AuditProbe.0.Etna.Design.AuditProbe.pad_zero'

    def audit(self, roles):
        """Role-check probe theorems; returns (property chains, flattened error text)."""
        entries = [{'declaration': 'Etna.Design.AuditProbe.'+name, 'module': 'EtnaProofs.AuditProbe',
                    'type': '∀ n : Nat, n + 0 = n' if name == 'live_lemma' else self.SHALLOW,
                    'bridge_level': 'spec-proved', 'role': role, 'sources': ['synthetic'],
                    'scope': 'audit test only', 'assumptions': ['synthetic audit regression; not a protocol obligation']}
                   for name, role in roles.items()]
        probe = self.root/'ProbeAudit.lean'
        probe.write_text(AUDIT.render_audit(entries, complete=False).replace(
            'import EtnaAudit\n', 'import EtnaAudit\nimport EtnaProofs.AuditProbe\n', 1))
        try:
            return AUDIT.check_axioms(entries, AUDIT.run(self.env+['lean', str(probe)])), ''
        except ValueError as exc:
            return {}, ' '.join(str(exc).split())

    def test_dead_bindings_cannot_make_property(self):
        # Before the fix each dead binding made its theorem derived (`dead_nested` needs two
        # passes: the beta-redex goes first, then the `have` it was the only user of).
        _, output = self.audit({**{name: 'property' for name in self.DEAD}, 'live_lemma': 'supporting'})
        errors = {name: block for block in output.split('error: ')[1:] for name in (*self.DEAD, 'live_lemma')
                  if f'Etna.Design.AuditProbe.{name}:' in block}
        self.assertEqual(set(errors), {*self.DEAD, 'live_lemma'}, output[:2000])
        for name in self.DEAD:
            self.assertIn(f'role property requires a derived proof: Etna.Design.AuditProbe.{name}: not derived',
                          errors[name])
        self.assertIn('role supporting is wrong for a derived Rule P statement: Etna.Design.AuditProbe.live_lemma: '
                      f'derived via Etna.Design.AuditProbe.live_lemma -> {self.LEMMA} -> Nat.recAux',
                      errors['live_lemma'])

    def test_live_induction_lemma_is_property_with_recorded_chain(self):
        chains, output = self.audit({**{name: 'supporting' for name in self.DEAD}, 'live_lemma': 'property'})
        self.assertEqual(output, '')
        self.assertEqual(chains, {'Etna.Design.AuditProbe.live_lemma':
                                  ['Etna.Design.AuditProbe.live_lemma', self.LEMMA, 'Nat.recAux']})

    def test_chain_reports_are_exact(self):
        entry = {'declaration': 'Etna.Design.X.t', 'role': 'property'}
        axioms = "'Etna.Design.X.t' does not depend on any axioms\n"
        chain = 'derivation chain: Etna.Design.X.t -> Etna.Design.X.lemma -> List.rec\n'
        self.assertEqual(AUDIT.check_axioms([entry], axioms+chain),
                         {'Etna.Design.X.t': ['Etna.Design.X.t', 'Etna.Design.X.lemma', 'List.rec']})
        self.assertEqual(AUDIT.summarize_chains(AUDIT.check_axioms([entry], axioms+chain)),
                         '1 property derivation chains (0 use induction directly, 1 through derived Etna '
                         'theorems, longest 2 steps)')
        for output, role in ((axioms, 'property'), (axioms+chain, 'supporting'), (axioms+chain+chain, 'property')):
            with self.assertRaisesRegex(ValueError, 'derivation chain report'):
                AUDIT.check_axioms([{**entry, 'role': role}], output)


class HeadlineGateTests(BuiltProbes, unittest.TestCase):
    """The headline layer and the statement view, on probe modules placed in EtnaStatements and
    EtnaProofs (no rebuild) and on the real package."""

    STATEMENTS = """import EtnaModel
namespace Etna.Statements.AuditTest
def Genuine : Prop := ∀ x : Nat, ∃ y : Nat, x < y ∧ y = x + 1
def Closed : Prop := ∀ _x : Nat, 2 + 2 = 4
end Etna.Statements.AuditTest
"""
    # `direct` is read by a headline proof, `viaLemma` through an Etna theorem it uses,
    # `deadOnly` only by an unused `have`, `unused` by nothing.
    PREMISES = """import EtnaStatements
namespace Etna.Design.AuditProbe
structure Assumed : Prop where
  direct : 1 = 1
  viaLemma : 2 = 2
  deadOnly : 3 = 3
  unused : 4 = 4
theorem lemma_reads (p : Assumed) : 2 = 2 := p.viaLemma
theorem headline_direct (p : Assumed) : 1 = 1 := p.direct
theorem headline_indirect (p : Assumed) : 2 = 2 := by
  have _ := p.deadOnly
  exact lemma_reads p
end Etna.Design.AuditProbe
"""
    PROBES = {'EtnaStatements.AuditProbe': STATEMENTS, 'EtnaProofs.AuditProbe': PREMISES}
    PREMISE_USE = {
        'genesis': ['Etna.Proofs.fund_safety', 'Etna.Proofs.accountable_finality',
                    'Etna.Proofs.forced_inclusion_integrity'],
        'verifierSound': ['Etna.Proofs.fund_safety', 'Etna.Proofs.forced_inclusion_integrity'],
        'authenticatedInputs': ['Etna.Proofs.forced_inclusion_integrity'],
        'hashSeparation': ['Etna.Proofs.fund_safety', 'Etna.Proofs.forced_inclusion_integrity'],
        'headerHashes': ['Etna.Proofs.fund_safety'],
        'headerSeparation': ['Etna.Proofs.fund_safety'],
        'signatureAgreement': ['Etna.Proofs.accountable_finality'],
    }

    def run_lean(self, text):
        """Run a Lean file in the probe environment; returns (failed, raw output)."""
        path = self.root/'Probe.lean'
        path.write_text(text)
        result = subprocess.run(self.env+['lean', str(path)], cwd=ROOT, text=True, capture_output=True)
        return result.returncode != 0, result.stdout+result.stderr

    def lean(self, body, imports=('EtnaProofs',)):
        """`body` after the audit library and `imports`."""
        return self.run_lean('import Lean\nimport EtnaAudit\n'+''.join(f'import {m}\n' for m in imports)+body+'\n')

    def test_headline_layer_passes_and_every_premise_is_read(self):
        # Each field is read by the headlines the manifest's assumptions name for it.
        failed, output = self.lean('\n'.join(AUDIT.render_headline_check()))
        self.assertFalse(failed, output)
        uses, rest = AUDIT.premise_uses(output)
        self.assertEqual(uses, self.PREMISE_USE)
        self.assertEqual(rest.strip(), '')

    def test_unused_premise_field_rejected(self):
        # Without H3's proof, no headline reads authenticatedInputs.
        partial = {k: v for k, v in AUDIT.HEADLINES.items() if k != 'Etna.Proofs.forced_inclusion_integrity'}
        failed, output = self.lean(AUDIT.render_headline_check(headlines=partial)[1])
        self.assertTrue(failed, output)
        self.assertIn('premise fields of Etna.Statements.Premises read by no headline proof (after unused '
                      'bindings are removed): [authenticatedInputs]', ' '.join(output.split()))

    def test_premise_read_only_by_dead_binding_is_unused(self):
        call = 'run_elab _root_.EtnaAudit.checkPremiseUse "Etna.Design.AuditProbe.Assumed" ' + AUDIT.lean_string(
            'Etna.Design.AuditProbe.headline_direct\nEtna.Design.AuditProbe.headline_indirect')
        failed, output = self.lean(call, ('EtnaProofs', 'EtnaProofs.AuditProbe'))
        self.assertTrue(failed, output)
        uses, _ = AUDIT.premise_uses(output)
        self.assertEqual(uses, {'direct': ['Etna.Design.AuditProbe.headline_direct'],
                                'viaLemma': ['Etna.Design.AuditProbe.headline_indirect']})
        self.assertIn('read by no headline proof (after unused bindings are removed): [deadOnly, unused]',
                      ' '.join(output.split()))

    def test_weaker_or_missing_claims_theorem_rejected(self):
        weak = ('namespace Etna.AuditProbe\n'
                'theorem claims : Etna.Statements.FundSafety ∧ Etna.Statements.AccountableFinality :=\n'
                '  ⟨Etna.Proofs.fund_safety, Etna.Proofs.accountable_finality⟩\nend Etna.AuditProbe\n')
        failed, output = self.lean(weak+AUDIT.render_headline_check(claims=('Etna.AuditProbe.claims',
                                                                            'Etna.Statements.Claims'))[0])
        self.assertTrue(failed, output)
        self.assertIn('headline theorem Etna.AuditProbe.claims must have exactly type Etna.Statements.Claims, not',
                      output)
        failed, output = self.lean(AUDIT.render_headline_check(claims=('Etna.Proofs.missing',
                                                                       'Etna.Statements.Claims'))[0])
        self.assertTrue(failed, output)
        self.assertIn('missing headline theorem Etna.Proofs.missing : Etna.Statements.Claims', output)

    def test_statement_definitions_unfold_only_from_statements(self):
        # A theorem stated as a statement-layer claim is checked on the claim's body, as if
        # written inline: a genuine body passes, a closed one still fails. An `Etna.Statements`
        # name declared outside EtnaStatements and other definitions stay folded.
        cases = {
            'statement_genuine': 'Etna.Statements.AuditTest.Genuine',
            'statement_closed': 'Etna.Statements.AuditTest.Closed',
            'foreign_statement': 'Etna.Statements.AuditTest.Foreign',
            'folded_elsewhere': 'Etna.Design.AuditTest.Elsewhere',
        }
        decl = ('namespace Etna.Statements.AuditTest\n'
                'def Foreign : Prop := ∀ x : Nat, ∃ y : Nat, x < y ∧ y = x + 1\n'
                'end Etna.Statements.AuditTest\n'
                'namespace Etna.Design.AuditTest\n'
                'def Elsewhere : Prop := ∀ x : Nat, ∃ y : Nat, x < y ∧ y = x + 1\n'
                'theorem statement_genuine : Etna.Statements.AuditTest.Genuine := by\n'
                '  intro x; induction x with\n'
                '  | zero => exact ⟨1, Nat.zero_lt_one, rfl⟩\n'
                '  | succ n _ => exact ⟨n + 2, Nat.lt_succ_self _, rfl⟩\n'
                'theorem statement_closed : Etna.Statements.AuditTest.Closed := fun _ => rfl\n'
                'theorem foreign_statement : Etna.Statements.AuditTest.Foreign := statement_genuine\n'
                'theorem folded_elsewhere : Elsewhere := statement_genuine\n'
                'end Etna.Design.AuditTest')
        entries = [{'declaration': 'Etna.Design.AuditTest.'+name, 'module': 'EtnaProofs.Common', 'type': typ,
                    'bridge_level': 'spec-proved', 'role': 'property', 'sources': ['synthetic'],
                    'scope': 'audit test only', 'assumptions': ['synthetic audit regression; not a protocol obligation']}
                   for name, typ in cases.items()]
        text = AUDIT.render_audit(entries, complete=False).replace(
            'import EtnaAudit\n', 'import EtnaAudit\nimport EtnaStatements.AuditProbe\n', 1).replace(
            'set_option pp.universes false', decl+'\nset_option pp.universes false', 1)
        _, output = self.run_lean(text)
        output = ' '.join(output.split())
        self.assertNotIn('Etna.Design.AuditTest.statement_genuine:', output)
        self.assertIn('Etna.Design.AuditTest.statement_closed: atom `@Eq Nat (@HAdd.hAdd', output)
        self.assertIn('(instOfNatNat (nat_lit 4)))` uses none', output)
        self.assertIn('Etna.Design.AuditTest.foreign_statement: atom `Etna.Statements.AuditTest.Foreign` uses none',
                      output)
        self.assertIn('Etna.Design.AuditTest.folded_elsewhere: atom `Etna.Design.AuditTest.Elsewhere` uses none',
                      output)


class PackageCheckTests(unittest.TestCase):
    """M9/M11, namespace containment and shadow allowlist on a probe module (no rebuild)."""

    def package(self, source, entries=None, shadows=None, module='EtnaProofs.AuditProbe'):
        """Package check with probe `source` compiled as `module` (no rebuild)."""
        entries = MANIFEST['theorems'] if entries is None else entries
        with scratch() as tmp:
            tmp = Path(tmp)
            shutil.copytree(ROOT/'.lake/build/lib/lean', tmp, dirs_exist_ok=True)
            env = AUDIT.lean_env(ROOT, [tmp, AUDIT.build_audit_library()])
            if source is not None:
                path = tmp/(module.replace('.', '/')+'.lean')
                path.write_text(source)
                AUDIT.run(env+['lean', '--root='+str(tmp), '-o', str(path.with_suffix('.olean')), str(path)])
            probe = tmp/'Probe.lean'
            probe.write_text('import Lean\nimport EtnaAudit\n'
                             + ''.join(f'import {lib}\n' for lib in AUDIT.GRAPH.declared_libraries())
                             + (f'import {module}\n' if source is not None else '')
                             + AUDIT.render_package_check(entries, shadows)+'\n')
            return subprocess.run(env+['lean', str(probe)], cwd=ROOT, text=True, capture_output=True)

    def rejected(self, result, message):
        self.assertNotEqual(result.returncode, 0, 'package audit must fail')
        self.assertIn(message, result.stdout+result.stderr)

    def test_current_package_passes(self):
        result = self.package(None)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)

    def test_m9_decoy_shadowing_rejected(self):
        self.rejected(self.package('import EtnaModel\nnamespace Etna.Design.Consensus\n'
                                   'def Committee.election := @Etna.Design.Committee.election\n'
                                   'end Etna.Design.Consensus\n'),
                      'unreviewed name shadowing (declaration -> shadowed name): '
                      '[Etna.Design.Consensus.Committee.election -> Etna.Design.Committee.election]')

    def test_m9_decoy_breaks_root_qualified_pin(self):
        source = combined_source('Consensus')
        decoy = ('def Committee.election (unit minimum cutoff nMax : Nat) (entries : List Committee.Entry) :\n'
                 '    Option (List Committee.Entry) :=\n'
                 '  some (Committee.chosen unit minimum cutoff nMax entries)\n\n')
        source = source.replace('def ElectionValid', decoy+'def ElectionValid', 1)
        with tempfile.NamedTemporaryFile(dir=ROOT, suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            result = subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0, 'a decoy election must not satisfy election_valid_iff')
        self.assertIn('Iff.rfl', result.stdout+result.stderr)

    def test_shadow_allowlist_is_exact(self):
        shadows = AUDIT.load_shadow_allowlist()
        (name, shadowed), rest = shadows[0], shadows[1:]
        result = self.package(None, shadows=rest+[('Etna.Design.Unused', 'Unused')])
        self.rejected(result, f'unreviewed name shadowing (declaration -> shadowed name): [{name} -> {shadowed}]')
        self.assertIn('stale shadowing allowlist entries: [Etna.Design.Unused -> Unused]', result.stdout+result.stderr)

    def test_m11_module_of_rangeless_declaration_checked(self):
        source = ('import Lean\nimport EtnaModel\nrun_elab Lean.addDecl (.thmDecl { name := `Etna.Design.Common.ghost, '
                  'levelParams := [], type := Lean.mkConst ``True, value := Lean.mkConst ``True.intro })\n')
        ghost = {**ENTRIES['Etna.Design.dual_count'], 'declaration': 'Etna.Design.Common.ghost',
                 'module': 'EtnaProofs.Common', 'type': 'True', 'role': 'constant'}
        self.rejected(self.package(source, MANIFEST['theorems']+[ghost]), 'manifest module mismatch')

    def test_declarations_outside_etna_namespace_rejected(self):
        self.rejected(self.package('import EtnaModel\ndef rootDecoy : Nat := 1\n'), 'outside the Etna namespace')

    def test_public_definition_in_proofs_rejected(self):
        self.rejected(self.package('import EtnaModel\nnamespace Etna.Design.AuditProbe\ndef helper : Nat := 1\n'
                                   'end Etna.Design.AuditProbe\n'),
                      'public definition Etna.Design.AuditProbe.helper in EtnaProofs.AuditProbe: EtnaProofs holds '
                      'theorems and private helpers')

    def test_private_definition_in_proofs_accepted(self):
        result = self.package('import EtnaModel\nnamespace Etna.Design.AuditProbe\nprivate def helper : Nat := 1\n'
                              'private theorem helper_eq : helper = 1 := rfl\nend Etna.Design.AuditProbe\n')
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)

    def test_theorem_in_model_rejected(self):
        # Built declarations, not source keywords: a private theorem is a proof too.
        self.rejected(self.package('import EtnaModel\nnamespace Etna.Design.AuditProbe\n'
                                   'private theorem hidden : True := trivial\nend Etna.Design.AuditProbe\n',
                                   module='EtnaModel.AuditProbe'),
                      'Etna.Design.AuditProbe.hidden in EtnaModel.AuditProbe: EtnaModel and EtnaStatements hold '
                      'definitions, not proofs')

    def test_proof_definition_in_statements_rejected(self):
        # A definition whose type is a proposition is a proof; one of type `Prop` is a statement.
        self.rejected(self.package('import EtnaModel\nnamespace Etna.Statements.AuditProbe\n'
                                   'def Holds : Prop := 1 = 1\ndef holds : Holds := rfl\n'
                                   'end Etna.Statements.AuditProbe\n', module='EtnaStatements.AuditProbe'),
                      'definition Etna.Statements.AuditProbe.holds in EtnaStatements.AuditProbe: EtnaModel and '
                      'EtnaStatements hold definitions, not proofs')

    def test_headline_namespace_outside_headline_modules_rejected(self):
        self.rejected(self.package('import EtnaModel\nnamespace Etna.Proofs\nprivate theorem stray : True := trivial\n'
                                   'end Etna.Proofs\n'),
                      'in EtnaProofs.AuditProbe: the Etna.Proofs namespace (the headline proofs) lives in '
                      'EtnaProofs.Headline')

    def test_model_instances_cannot_alter_audit_checks(self):
        # An inline audit after importing the libraries would use this instance for `contains`.
        self.rejected(self.package('import EtnaModel\nnamespace Etna.Design.AuditProbe\n'
                                   'instance (priority := high) evil : BEq Lean.Name := ⟨fun _ _ => true⟩\n'
                                   'axiom poison : False\nend Etna.Design.AuditProbe\n'), 'forbidden axioms')


class LeanRegressionFileTests(unittest.TestCase):
    """M10 at the audit: tests/*.lean are compiled warning-free, replayed and axiom-checked."""

    def mutated(self, mutate):
        with scratch() as tmp:
            root = copy_package(tmp, build=True)
            mutate(root/'tests/ReviewFixes.lean')
            with self.assertRaises(ValueError) as caught:
                AUDIT.check_test_modules(root)
            return str(caught.exception)

    def test_sorry_warning_rejected(self):
        message = self.mutated(lambda p: edit(
            p, 'SecondBatch.historicalRules).isNone = true := by decide +kernel\n\ntheorem substituted_genesis_record_rejected',
            'SecondBatch.historicalRules).isNone = true := by sorry\n\ntheorem substituted_genesis_record_rejected'))
        self.assertRegex(message, "warning.*sorry")

    def test_custom_axiom_rejected(self):
        message = self.mutated(lambda p: edit(p, 'end Etna.Design.ReviewFixes',
                                              'axiom poison : False\ntheorem everything_rejected : (1:Nat) = 2 := poison.elim\n'
                                              'end Etna.Design.ReviewFixes'))
        self.assertIn('forbidden axioms', message)


class FreshReplayTests(unittest.TestCase):
    """M6 past the lint: only `leanchecker --fresh` replays a forged import outside the Etna libraries."""

    def test_m6_forged_helper_library_needs_fresh_replay(self):
        with scratch() as tmp:
            root = copy_package(tmp, build=True)
            (root/'lakefile.toml').write_text((root/'lakefile.toml').read_text()+'\n[[lean_lib]]\nname = "Helper"\n')
            (root/'Helper.lean').write_text(
                'import Lean\nset_option debug.skipKernelTC true in\nrun_elab Lean.addDecl (.thmDecl { name := `Helper.bad, '
                'levelParams := [], type := Lean.mkConst ``False, value := Lean.mkConst ``True.intro })\n')
            deployment = root/'EtnaProofs/Deployment.lean'
            edit(deployment, 'import EtnaModel.Deployment', 'import Helper\nimport EtnaModel.Deployment')
            deployment.write_text(deployment.read_text()+'\nnamespace Etna.Design.Deployment\n'
                                  'theorem pwned : False := Helper.bad\nend Etna.Design.Deployment\n')
            self.assertTrue(LINT.lint(root))
            AUDIT.run(['lake', 'build', 'Helper', *AUDIT.GRAPH.declared_libraries(root)], cwd=root)
            plain = subprocess.run(['lake', 'env', 'leanchecker', 'EtnaProofs'], cwd=root, capture_output=True)
            self.assertEqual(plain.returncode, 0, 'plain leanchecker trusts the non-Etna import (why --fresh is needed)')
            fresh = AUDIT.kernel_replay(root)
            output, _ = fresh.communicate()
            self.assertNotEqual(fresh.returncode, 0, output)


class CoverageRoleTests(unittest.TestCase):
    """P4 in the evidence graph: constants make clauses partial but never back claims."""

    def inventory(self, change_manifest=None, change_spec=None):
        with scratch() as tmp:
            root = Path(tmp)
            shutil.copytree(ROOT/'manifests', root/'manifests')
            shutil.copyfile(ROOT/'spec-coverage.json', root/'spec-coverage.json')
            for name, change in (('manifests/design.json', change_manifest), ('spec-coverage.json', change_spec)):
                if change:
                    value = json.loads((root/name).read_text())
                    change(value)
                    (root/name).write_text(json.dumps(value))
            return COVERAGE.inventory(root)

    def test_constant_edge_is_partial_but_cannot_back_claim(self):
        source = ENTRIES['Etna.Design.Budget.cap_derivation']['sources'][0]
        rows = {r['id']: r for r in self.inventory()}
        self.assertEqual(ENTRIES['Etna.Design.Budget.cap_derivation']['role'], 'constant')
        self.assertEqual(rows[source]['status'], 'partial')

        def claim(spec):
            spec['claims'][0]['evidence'] = {source: ['Etna.Design.Budget.cap_derivation']}
        with self.assertRaisesRegex(ValueError, 'cap_derivation \\(constant\\)'):
            self.inventory(change_spec=claim)

    def test_regression_edge_cannot_back_claim(self):
        # mut12 also relabels closed traces as `property`; ManifestTypeTests shows the
        # Lean audit rejects that role, so the graph only ever sees `regression` here.
        name = 'Etna.Design.FirstBatch.ordinary_handover'
        rows = {r['id']: r for r in self.inventory()}
        source = next(s for s in ENTRIES[name]['sources'] if rows[s]['status'] == 'partial')

        def claim(spec):
            spec['claims'][0]['evidence'] = {source: [name]}
        with self.assertRaisesRegex(ValueError, f'DV-01 {source} {name} \\(regression\\)'):
            self.inventory(change_spec=claim)

    def test_errors_name_clause_and_theorem(self):
        def unknown(m):
            m['theorems'][0]['sources'] = ['EN-missing']
        with self.assertRaisesRegex(ValueError, 'unknown theorem source EN-missing: Etna.Design.dual_count'):
            self.inventory(change_manifest=unknown)

    def test_linked_duplicate_text_clause_rejected(self):
        # Current Markdown has no duplicated wrapper clauses. Construct reviewed bytes
        # with duplicate real text, then require the linked occurrence ID to fail closed.
        with scratch() as tmp:
            repo = Path(tmp)
            root = repo/'formal/etna'
            root.mkdir(parents=True)
            shutil.copytree(ROOT/'manifests', root/'manifests')
            shutil.copytree(COVERAGE.REPO/COVERAGE.SPEC_DIR, repo/COVERAGE.SPEC_DIR)
            spec = json.loads((ROOT/'spec-coverage.json').read_text())
            source = repo/COVERAGE.SPEC_PATH
            text = source.read_text()+'\nAudit duplicate clause.\n\nAudit duplicate clause.\n'
            source.write_text(text)
            spec['source']['sha256'] = COVERAGE.digest(COVERAGE.strip_markers(text).encode())
            (root/'spec-coverage.json').write_text(json.dumps(spec))
            duplicate = [r for r in COVERAGE.clauses(COVERAGE.strip_markers(text), 'en') if r['summary']=='Audit duplicate clause.']
            self.assertEqual(len(duplicate), 2)
            manifest = json.loads((root/'manifests/design.json').read_text())
            manifest['theorems'][0]['sources'].append(duplicate[-1]['id'])
            (root/'manifests/design.json').write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, duplicate[-1]['id']+' .*order-dependent'):
                COVERAGE.inventory(root, repo)

    def test_unsupported_domain_tag_edge_removed(self):
        rows = [r for r in self.inventory() if 'ETNA_COMET_DOMAIN_V1' in r['summary']]
        self.assertEqual(len(rows), 1)
        for row in rows:
            self.assertNotIn('Etna.Design.Encoding.domain_tags_are_ascii', row['theorems'], row['id'])


if __name__ == '__main__':
    unittest.main()
