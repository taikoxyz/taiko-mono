"""Cross-generation rollback witnesses and type-correct mutations of real guards."""
from pathlib import Path
import subprocess
import tempfile
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def combined(module, model_only=False):
    """Rename only the local namespace; keep the complete theorem layer unchanged."""
    original = 'Etna.Design' if module == 'Landing' else 'Etna.Design.'+module
    replacement = original+'RollbackMutation'
    imports, bodies = [], []
    for library in (('EtnaModel',) if model_only else ('EtnaModel', 'EtnaProofs')):
        lines = (ROOT/library/(module+'.lean')).read_text().splitlines()
        end = 0
        while end < len(lines) and lines[end].startswith('import '):
            imports.append(lines[end])
            end += 1
        body = '\n'.join(lines[end:])
        # Landing must stay nested under Etna.Design for inherited State/Hash names.
        if module == 'Landing':
            replacement = 'Etna.Design.LandingRollbackMutation'
            body = body.replace('namespace '+original+'\n', 'namespace '+replacement+'\n')
            body = body.replace('end '+original, 'end '+replacement)
        else:
            body = body.replace(original, replacement)
        bodies.append(body)
    source = '\n'.join(dict.fromkeys(imports))+'\n'+'\n'.join(bodies)
    if not model_only and module in ('Landing', 'Recovery'):
        name = 'origin_gap_rejects_landing' if module == 'Landing' else 'rollback_consumes_nonce'
        proofs = (ROOT/'EtnaProofs/TrustedRollback.lean').read_text()
        probe = re.search(r'(?:private )?theorem '+name+r' .*?(?=\n\n)', proofs, re.S).group()
        probe = probe.replace('Etna.Design.land', 'land').replace('Recovery.rollbackInbox', 'rollbackInbox')
        source += '\nnamespace '+replacement+'\n'+probe+'\nend '+replacement+'\n'
    return source


class CrossGenerationRollbackKernelTests(unittest.TestCase):
    def compile(self, source):
        with tempfile.NamedTemporaryFile(dir=ROOT/'.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True)

    def silent(self, source):
        result = self.compile(source)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')

    def rejected(self, module, old, new):
        model = combined(module, model_only=True)
        self.assertEqual(model.count(old), 1)
        # A malformed Model is never accepted as a semantic mutation.
        self.silent(model.replace(old, new, 1))
        source = combined(module)
        body = model[model.index('namespace '):]
        self.assertEqual(source.count(body), 1)
        source = source.replace(body, body.replace(old, new, 1), 1)
        result = self.compile(source)
        output = result.stdout+result.stderr
        self.assertNotEqual(result.returncode, 0, 'guard mutation must break unchanged theorem layer')
        self.assertIn('error:', output)
        for accidental in ('unexpected token', 'Unknown identifier', 'already been declared', 'unknown module prefix'):
            self.assertNotIn(accidental, output)

    def test_model_and_proof_baselines_are_silent(self):
        for module in ('Recovery', 'Staking', 'Landing'):
            self.silent(combined(module, model_only=True))
            self.silent(combined(module))

    def test_actual_rollback_and_signing_witnesses_are_silent(self):
        self.silent((ROOT/'tests/CrossGenerationRollback.lean').read_text())

    def test_rollback_cannot_rewind_generation(self):
        self.rejected('Recovery', 'checkpoint := trusted,head := trusted.cursor,snapshot := trustedSnapshot,',
                      'generation := 0,checkpoint := trusted,head := trusted.cursor,snapshot := trustedSnapshot,')

    def test_rollback_cannot_rewrite_fixed_origin(self):
        self.rejected('Recovery', 'checkpoint := trusted,head := trusted.cursor,snapshot := trustedSnapshot,',
                      'origin := { s.origin with height := trusted.height },checkpoint := trusted,head := trusted.cursor,snapshot := trustedSnapshot,')

    def test_rollback_cannot_retain_later_records(self):
        self.rejected('Recovery', 'records := s.records.filter (fun r => r.height ≤ trusted.height),',
                      'records := s.records,')

    def test_rollback_must_consume_authorization_nonce(self):
        self.rejected('Recovery', 'recoveryNonce := s.recoveryNonce+1,\n    checkpoint := trusted',
                      'recoveryNonce := s.recoveryNonce,\n    checkpoint := trusted')

    def test_recovery_origin_must_equal_current_checkpoint(self):
        self.rejected('Recovery', 'r.height = w.inbox.checkpoint.height ∧ r.l1Block < limit48',
                      'True ∧ r.l1Block < limit48')

    def test_recovery_must_preserve_stored_snapshot(self):
        self.rejected('Recovery', 'origin := r,origins := w.inbox.origins ++ [(w.inbox.generation+1,r)]',
                      'snapshot := r.l1Block,origin := r,origins := w.inbox.origins ++ [(w.inbox.generation+1,r)]')

    def test_confirmation_requires_restored_snapshot_coverage(self):
        self.rejected('Staking', 'b.exitAt ≠ noExit ∧ b.exitAt ≤ s.snapshot',
                      'b.exitAt ≠ noExit ∧ True')

    def test_rollback_recheck_must_use_exit_snapshot(self):
        self.rejected('Staking', 'if restored < b.exitAt then { b with confirmedAt := none } else b',
                      'if restored < b.activeFrom then { b with confirmedAt := none } else b')

    def test_landing_requires_parent_at_or_above_origin(self):
        self.rejected('Landing', 's.origin.height ≤ i.parentHeight ∧ i.parentHeight ≤ c',
                      'True ∧ i.parentHeight ≤ c')

    def test_landing_requires_parent_at_or_below_checkpoint(self):
        self.rejected('Landing', 's.origin.height ≤ i.parentHeight ∧ i.parentHeight ≤ c',
                      's.origin.height ≤ i.parentHeight ∧ True')
