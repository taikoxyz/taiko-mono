"""All 4096 registry slots participate; FI fee tests are a separate subsystem."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def registry_part(path):
    text = path.read_text()
    return text.split('namespace Registry\n', 1)[1].split('end Registry', 1)[0]


def layers():
    model = 'import EtnaProofs.Current\nnamespace Etna.Design.Current.RegistrySlotMutation\n'
    model += registry_part(ROOT/'EtnaModel/Current.lean')
    model += '\nend Etna.Design.Current.RegistrySlotMutation\n'
    old_proofs = 'namespace Etna.Design.Current.RegistrySlotMutation\n'
    old_proofs += registry_part(ROOT/'EtnaProofs/Current.lean')
    whole = (ROOT/'EtnaProofs/Current.lean').read_text()
    old_proofs += 'theorem displacement_keeps_old_bond' + whole.split(
        'theorem displacement_keeps_old_bond',1)[1].split('\nend Etna.Design.Current.Registry',1)[0]
    old_proofs += '\nend Etna.Design.Current.RegistrySlotMutation\n'
    new_proofs = (ROOT/'EtnaProofs/CurrentAdmission.lean').read_text()
    new_proofs = new_proofs.replace('import EtnaProofs.Current', '')
    new_proofs = new_proofs.replace('namespace Etna.Design.Current.Registry',
                                    'namespace Etna.Design.Current.RegistrySlotMutation')
    new_proofs = new_proofs.replace('end Etna.Design.Current.Registry',
                                    'end Etna.Design.Current.RegistrySlotMutation')
    return model, old_proofs, new_proofs


class CurrentAdmissionTests(unittest.TestCase):
    def compile(self, source):
        (ROOT/'.scratch').mkdir(exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=ROOT/'.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake','env','lean',file.name], cwd=ROOT,
                                  capture_output=True, text=True, timeout=240)

    def test_baseline_complete_search_contracts(self):
        result = self.compile('\n'.join(layers()))
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')

    def test_endpoint_pending_and_nonzero_tie_fixtures(self):
        result = subprocess.run(['lake','env','lean','tests/CurrentAdmission.lean'], cwd=ROOT,
                                capture_output=True,text=True,timeout=240)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')

    def reject_length(self, length):
        model, old_proofs, new_proofs = layers()
        anchor = "List.range' 1 4095"
        self.assertEqual(model.count(anchor), 1)
        model = model.replace(anchor, "List.range' 1 "+str(length))
        # Both mutations compile the executable model AND all prior registry proofs.
        result = self.compile(model+'\n'+old_proofs)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')
        result = self.compile(model+'\n'+old_proofs+'\n'+new_proofs)
        self.assertNotEqual(result.returncode, 0, 'unchanged complete-slot contract accepted mutant')
        errors = [line for line in (result.stdout+result.stderr).splitlines() if 'error:' in line]
        self.assertTrue(errors)
        for accidental in ('already been declared','Unknown identifier','unknown module prefix','unexpected token'):
            self.assertNotIn(accidental,errors[0])

    def test_omitting_slot_4095_is_rejected(self):
        self.reject_length(4094)

    def test_including_slot_4096_is_rejected(self):
        self.reject_length(4096)


if __name__ == '__main__':
    unittest.main()
