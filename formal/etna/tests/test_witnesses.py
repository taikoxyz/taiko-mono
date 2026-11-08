"""The current non-vacuity and trap witnesses build and are audited.

`EtnaWitnesses/NonVacuity` shows the current headline premise record and the switch, risk,
import and honest-agreement profiles are jointly satisfiable by concrete accepting runs, and
(`NonVacuity/CurrentRecovery`) that one environment meets H1-H3's and H4's premises together,
where H4's proof reaches an accepted landing;
`EtnaWitnesses/Traps/RollbackGrid` reaches the rollback-across-K-change trap. Every
module builds without warnings, and every public theorem in them has a `regression` manifest
entry (so none backs a proof claim or changes a clause's status) that passes the proof audit's
exact-type and transitive-axiom checks. The facts each witness exists to show are pinned by the
kernel-replayed tests/Current*.lean files (for example CurrentPremises.lean and
CurrentAgreement.lean).
"""
import importlib.util
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT/path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


AUDIT = load('witnesses_audit', 'scripts/audit_proofs.py')

MODULES = [*(f'EtnaWitnesses.NonVacuity.{n}' for n in ('Current', 'CurrentAgreement', 'CurrentRecovery', 'CurrentRisk',
                                                          'CurrentSwitch')),
           'EtnaWitnesses.Traps.RollbackGrid']
# The accepting witness and the profile and trap witnesses the proof audit requires.
EXPECTED = {AUDIT.CURRENT_ACCEPTING_WITNESS, *AUDIT.CURRENT_PROFILE_WITNESSES, *AUDIT.CURRENT_TRAP_WITNESSES}


def witness_entries():
    entries = json.loads((ROOT/'manifests/design.json').read_text())['theorems']
    return [e for e in entries if e['module'] in MODULES]


class WitnessTests(unittest.TestCase):
    def test_the_witness_modules_exist(self):
        found = sorted('.'.join(p.relative_to(ROOT).with_suffix('').parts)
                       for p in (ROOT/'EtnaWitnesses').rglob('*.lean'))
        self.assertEqual(found, sorted(MODULES))
        root = (ROOT/'EtnaWitnesses.lean').read_text()
        for module in MODULES:
            self.assertIn('import '+module+'\n', root)

    def test_witness_modules_build(self):
        result = subprocess.run(['lake', 'build', *MODULES], cwd=ROOT, text=True, capture_output=True)
        output = result.stdout+result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertNotIn('warning', output.lower(), output)

    def test_witness_theorems_are_audited_regressions(self):
        entries = witness_entries()
        names = {e['declaration'] for e in entries}
        self.assertLessEqual(EXPECTED, names)
        for entry in entries:
            self.assertEqual(entry['role'], 'regression', entry['declaration'])
        out = ROOT/'.scratch/witnesses'
        out.mkdir(parents=True, exist_ok=True)
        audit = out/'WitnessesAudit.lean'
        audit.write_text(AUDIT.render_audit(entries, complete=False))
        # Exact manifest types, roles and only the standard axioms (propext, Classical.choice,
        # Quot.sound).
        AUDIT.check_axioms(entries, AUDIT.check_kernel_file(audit))

    def test_axiom_check_rejects_sorry(self):
        fake = dict(declaration='Etna.Design.Current.Protocol.NonVacuity.fake', role='regression')
        with self.assertRaisesRegex(ValueError, 'forbidden axioms'):
            AUDIT.check_axioms([fake], "'Etna.Design.Current.Protocol.NonVacuity.fake' depends on axioms: "
                                       "[propext, sorryAx]")


if __name__ == '__main__':
    unittest.main()
