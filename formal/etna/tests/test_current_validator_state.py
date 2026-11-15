"""Executable validator-state regressions and semantic mutation checks."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ValidatorStateTests(unittest.TestCase):
    def test_pinned_validator_transitions(self):
        result = subprocess.run(['lake', 'env', 'lean', 'tests/CurrentValidatorState.lean'],
                                cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    @unittest.skipUnless(os.environ.get('ETNA_FULL_TESTS') == '1', 'slow semantic mutations')
    def test_semantic_mutations_are_rejected(self):
        model = (ROOT / 'EtnaModel/CurrentValidatorState.lean').read_text()
        fixture = (ROOT / 'tests/CurrentValidatorState.lean').read_text().replace(
            'import EtnaModel.CurrentValidatorState', '')
        mutants = [
            ('hplus1', 'return ⟨s.height+1,s.next,next,s.current⟩',
             'return ⟨s.height+1,next,next,s.current⟩'),
            ('genesis_next', 'let next ← increment current 1', 'let next := current'),
            ('new_member_penalty', 'let before := total s.members+added-replaced',
             'let before := total s.members+added-replaced-'
             '(s.members.filter (fun v => changes.any (fun c => c.address == v.address && c.power == 0))'
             ' |>.map Validator.power |>.sum)'),
            ('rescale_division', 'priority := truncate v.priority ratio',
             'priority := v.priority / ratio'),
            ('average_division', '(xs.map Validator.priority).sum / xs.length',
             'truncate (xs.map Validator.priority).sum xs.length'),
            ('switch_height', 'if (s.height+2) % c.epochLen = 0 then',
             'if (s.height+1) % c.epochLen = 0 then'),
            ('per_block_hash', 'if hash (snapshot after) = b.header.valStateHash then',
             'if True then'),
            ('origin_exception', 'if height = origin then', 'if height ≤ origin then'),
            ('stale_genesis', 'then some fresh else none', 'then some supplied else none'),
            ('later_preimage', 'hash (snapshot supplied) = stored then', 'stored = stored then'),
            ('stored_proposer', 's.proposer.any (fun address => s.members.any (·.address == address))',
             'true'),
        ]
        for name, old, new in mutants:
            with self.subTest(name=name):
                self.assertEqual(model.count(old), 1, old)
                changed = model.replace(old, new).replace('ValidatorState', 'ValidatorStateMutation')
                evidence = fixture.replace('ValidatorState', 'ValidatorStateMutation')
                for source, should_pass in ((changed, True), (changed + '\n' + evidence, False)):
                    with tempfile.NamedTemporaryFile(dir=ROOT / '.scratch', suffix='.lean',
                                                     mode='w') as file:
                        file.write(source)
                        file.flush()
                        result = subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                                capture_output=True, text=True, timeout=120)
                    output = result.stdout + result.stderr
                    if should_pass:
                        self.assertEqual(result.returncode, 0, output)
                    else:
                        self.assertNotEqual(result.returncode, 0, 'semantic mutant survived')
                        first = next(line for line in output.splitlines() if 'error:' in line)
                        for accidental in ('already been declared', 'unknown module prefix',
                                           'unexpected token', 'Unknown identifier'):
                            self.assertNotIn(accidental, first)


if __name__ == '__main__':
    unittest.main()
