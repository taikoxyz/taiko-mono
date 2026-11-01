"""Real Lean/kernel mutations of canonical archive, reference and transition evidence."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def combined_canonical(model_only=False):
    imports, bodies = [], []
    for library in (('EtnaModel',) if model_only else ('EtnaModel', 'EtnaProofs')):
        lines = (ROOT/library/'CanonicalHistory.lean').read_text().splitlines()
        end = 0
        while end < len(lines) and lines[end].startswith('import '):
            imports.append(lines[end])
            end += 1
        bodies.append('\n'.join(lines[end:]).replace('Etna.Design.CanonicalHistory',
                                                     'Etna.Design.CanonicalHistoryMutation'))
    return '\n'.join(dict.fromkeys(imports))+'\n'+'\n'.join(bodies)


class CanonicalHistoryKernelTests(unittest.TestCase):
    def compile(self, source):
        with tempfile.NamedTemporaryFile(dir=ROOT/'.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT, capture_output=True, text=True)

    def rejected(self, old, new, source=None):
        if source is None:
            # Mutate corresponding explicit Run and implicit Submitted binders together.
            def mutate(text):
                self.assertIn(old, text)
                text = text.replace(old, new)
                if old.startswith('(') and old.endswith(')'):
                    text = text.replace('{'+old[1:-1]+'}', '{'+new[1:-1]+'}')
                return text
            model = self.compile(mutate(combined_canonical(model_only=True)))
            self.assertEqual(model.returncode, 0, model.stdout+model.stderr)
            self.assertEqual(model.stdout+model.stderr, '')
            original_model = combined_canonical(model_only=True)
            model_body = original_model[original_model.index('namespace Etna.Design.CanonicalHistoryMutation'):]
            source = combined_canonical()
            self.assertEqual(source.count(model_body), 1)
            # The proof layer, including all theorem hypothesis types, is unchanged.
            source = source.replace(model_body, mutate(model_body), 1)
        else:
            self.assertIn(old, source)
            source = source.replace(old, new, 1)
        result = self.compile(source)
        output = result.stdout+result.stderr
        self.assertNotEqual(result.returncode, 0, 'real historical evidence must remain necessary')
        self.assertIn('error:', output)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, output)

    def test_unmodified_history_compiles_silently(self):
        result = self.compile(combined_canonical())
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')

    def test_unmodified_initialized_landing_signing_compiles_silently(self):
        result = self.compile((ROOT/'tests/CanonicalHistory.lean').read_text())
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')

    def test_canonical_archive_cannot_discard_accepted_prefix(self):
        self.rejected('Deployment.build w w.inbox.configuration (old ++ more) template',
                      'Deployment.build w w.inbox.configuration more template')

    def test_actual_decoded_header_binding_is_required(self):
        self.rejected('(headers : ∀ b ∈ blocks, (old ++ more)[b.header.height]? = some b.header.anchor.number)',
                      '(headers : True)')

    def test_reference_must_cover_authenticated_anchor_numbers(self):
        self.rejected('(anchors : ∀ a ∈ old ++ more, a ≤ r.referenceNumber)', '(anchors : True)')

    def test_reference_must_contain_actual_origin(self):
        self.rejected('(origin : w.inbox.origin.l1Block ≤ r.referenceNumber)', '(origin : True)')

    def test_actual_accepted_landing_cannot_be_omitted(self):
        self.rejected('(accepted : Etna.Design.land w.inbox i leaves e = some s)', '(accepted : True)')

    def test_certificate_must_bind_actual_decoded_batch(self):
        self.rejected('(binding : e.certificate = Settlement.statement r parent blocks blobs)', '(binding : True)')

    def test_actual_recovery_cannot_be_omitted(self):
        self.rejected('(accepted : Recovery.recover (recoveryView w) a w.adapters.recovery origin owner externalOK = some s)',
                      '(accepted : True)')

    def test_recovery_cannot_precede_prior_l1_clock(self):
        self.rejected('(time : w.l1Block ≤ origin.l1Block)', '(time : True)')

    def test_witness_recovery_landing_cannot_use_old_generation(self):
        source = (ROOT/'EtnaWitnesses/Regressions/CanonicalHistory.lean').read_text().replace(
            'Etna.Design.CanonicalHistoryRegression', 'Etna.Design.CanonicalHistoryWitnessMutation')
        self.rejected('⟨49,4800,true,[111],NonVacuity.proofs,statement⟩',
                      '⟨49,4800,true,[111],NonVacuity.proofs,{ statement with generation := 0 }⟩', source)
