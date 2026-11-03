"""Kernel-check current heterogeneous chains and mutations against unchanged evidence."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def sources():
    imports, bodies = [], []
    for library in ('EtnaModel', 'EtnaProofs'):
        lines = (ROOT / library / 'CurrentBlocks.lean').read_text().splitlines()
        while lines and lines[0].startswith('import '):
            line = lines.pop(0)
            if line != 'import EtnaModel.CurrentBlocks':
                imports.append(line)
        bodies.append('\n'.join(lines).replace('Etna.Design.Current.Blocks', 'Etna.Design.Current.BlocksMutation'))
    fixture = (ROOT / 'tests/CurrentBlocks.lean').read_text().replace('import EtnaProofs.CurrentBlocks', '')
    fixture = fixture.replace('Etna.Design.Current.Blocks', 'Etna.Design.Current.BlocksMutation')
    return '\n'.join(dict.fromkeys(imports)) + '\n', *bodies, fixture


class CurrentBlocksTests(unittest.TestCase):
    def compile(self, source):
        with tempfile.NamedTemporaryFile(dir=ROOT / '.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True)

    def test_current_examples(self):
        result = subprocess.run(['lake', 'env', 'lean', 'tests/CurrentBlocks.lean'], cwd=ROOT,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def reject(self, old, new):
        imports, model, proofs, fixture = sources()
        self.assertEqual(model.count(old), 1, old)
        changed = model.replace(old, new)
        result = self.compile(imports + changed)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        result = self.compile(imports + changed + '\n' + proofs + '\n' + fixture)
        self.assertNotEqual(result.returncode, 0, 'unchanged evidence accepted semantic mutant')
        first = next(line for line in (result.stdout + result.stderr).splitlines() if 'error:' in line)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, first)

    def test_first_anchor_does_not_inherit_old_floor(self):
        self.reject('then b.body.anchorWitness = true\n',
                    'then b.body.anchorWitness = true ∧ p.anchor.number ≤ b.header.anchor.number\n')

    def test_per_block_timestamp_selection(self):
        self.reject('Rules.select b.schedule b.header.timestamp',
                    'Rules.select b.schedule (b.header.timestamp+1)')

    def test_unknown_definition_rejected(self):
        self.reject('selected : r.catalogue (selectedRules b) = some (definition r b)', 'selected : True')

    def test_actual_payload_fields_required(self):
        self.reject('fields : ∀ w, b.body.forced = some w → ActualQueue.PayloadFields (definition r b).bytes p b.body w b.raw b.first',
                    'fields : True')

    def test_no_unlanded_height_cap(self):
        self.reject('b.header.timestamp < limit256 ∧',
                    'b.header.height < limit48 ∧ b.header.timestamp < limit256 ∧')

    def test_due_delay_is_exact(self):
        self.reject('b.header.anchor.timestamp r.forcedDelay b.body.forced',
                    'b.header.anchor.timestamp (r.forcedDelay+1) b.body.forced')


if __name__ == '__main__':
    unittest.main()
