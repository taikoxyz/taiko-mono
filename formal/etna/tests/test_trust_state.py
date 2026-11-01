"""Type-correct model guard mutations must fail unchanged trust/signing proofs."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def combined(model_only=False):
    imports, bodies = [], []
    for library in (('EtnaModel',) if model_only else ('EtnaModel', 'EtnaProofs')):
        lines = (ROOT/library/'TrustState.lean').read_text().splitlines()
        end = 0
        while end < len(lines) and lines[end].startswith('import '):
            imports.append(lines[end])
            end += 1
        bodies.append('\n'.join(lines[end:]).replace('Etna.Design.TrustState',
                                                     'Etna.Design.TrustStateMutation'))
    return '\n'.join(dict.fromkeys(imports))+'\n'+'\n'.join(bodies)


class TrustStateKernelTests(unittest.TestCase):
    def compile(self, source):
        with tempfile.NamedTemporaryFile(dir=ROOT/'.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True)

    def rejected(self, old, new):
        model = combined(model_only=True)
        self.assertEqual(model.count(old), 1)
        mutated = model.replace(old, new)
        precheck = self.compile(mutated)
        self.assertEqual(precheck.returncode, 0, precheck.stdout+precheck.stderr)
        self.assertEqual(precheck.stdout+precheck.stderr, '')
        source = combined()
        body = model[model.index('namespace Etna.Design.TrustStateMutation'):]
        self.assertEqual(source.count(body), 1)
        # Proof hypotheses may intentionally repeat a guard; keep them all unchanged.
        source = source.replace(body, body.replace(old, new, 1), 1)
        result = self.compile(source)
        output = result.stdout+result.stderr
        self.assertNotEqual(result.returncode, 0, 'removing a real guard must break its proof')
        self.assertIn('error:', output)
        for incidental in ('unexpected token', 'Unknown identifier', 'already been declared', 'unknown module prefix'):
            self.assertNotIn(incidental, output)

    def test_unmodified_model_and_proofs_are_silent(self):
        for source in (combined(model_only=True), combined(), (ROOT/'tests/TrustState.lean').read_text()):
            result = self.compile(source)
            self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
            self.assertEqual(result.stdout+result.stderr, '')

    def test_exact_target_match_is_required(self):
        self.rejected('(exactMatch : headerMatches target.view.inbox.checkpoint (BlockValidity.terminal target.origin s.replay))',
                      '(exactMatch : True)')

    def test_current_generation_match_is_required(self):
        self.rejected('(generation : target.view.inbox.generation = s.signer.activeGeneration)', '(generation : True)')

    def test_real_replay_validity_is_required(self):
        self.rejected('(valid : BlockValidity.Chain target.rules target.origin (s.replay ++ more))', '(valid : True)')

    def test_real_node_checkpoint_fence_is_required(self):
        self.rejected('(accepted : nodes target (s.replay ++ more))', '(accepted : True)')

    def test_live_extension_checks_are_required(self):
        self.rejected('(accepted : nodes target (s.replay ++ (s.extension ++ more)))', '(accepted : True)')

    def test_stock_signer_cannot_bypass_trust(self):
        self.rejected('messageRequest encode m (s.trusted && !s.restartNeeded)) signature persisted',
                      'messageRequest encode m true) signature persisted')

    def test_timeout_requires_new_supervised_session(self):
        self.rejected('messageRequest encode m (s.trusted && !s.restartNeeded)) signature persisted',
                      'messageRequest encode m s.trusted) signature persisted')

    def test_target_change_revokes_prior_grant(self):
        self.rejected('{ close s with\n    target := some target', '{ s with\n    target := some target')

    def test_restart_requires_new_authentication(self):
        self.rejected('def restart (s : Node) : Node :=\n  { startup s.signer with authenticatedGeneration := s.authenticatedGeneration }',
                      'def restart (s : Node) : Node := { close s with restartNeeded := false }')

    def test_rollback_cannot_erase_hrs(self):
        self.rejected('def rollback (s : Node) : Node :=\n  { startup s.signer with authenticatedGeneration := s.authenticatedGeneration }',
                      'def rollback (s : Node) : Node :=\n  { startup { s.signer with log := [] } with authenticatedGeneration := s.authenticatedGeneration }')

    def test_selected_key_cannot_replace_device_key(self):
        self.rejected('(freshProducer : after.log ≠ s.signer.log → EngineRequest s key m)',
                      '(freshProducer : after.log ≠ s.signer.log → ∃ substitute, EngineRequest s substitute m)')

    def test_encoder_cannot_be_replaced_per_call(self):
        self.rejected('(result : sign s encode m signature persisted = some (after,returned))',
                      '(result : sign s (fun _ => 0) m signature persisted = some (after,returned))')

    def test_trust_promotion_requires_same_deployment(self):
        self.rejected('(deployment : target.view.inbox.domain = s.signer.domain)', '(deployment : True)')

    def test_session_open_requires_same_deployment(self):
        self.rejected('| some target => decide (target.view.inbox.domain = s.signer.domain))',
                      '| some target => decide (target.view.inbox.domain = target.view.inbox.domain))')

    def test_trust_promotion_requires_known_generation(self):
        self.rejected('(notSuperseded : s.authenticatedGeneration ≤ s.signer.activeGeneration)',
                      '(notSuperseded : True)')

    def test_session_open_cannot_ignore_supersession(self):
        self.rejected('decide (s.authenticatedGeneration ≤ s.signer.activeGeneration)',
                      'decide (s.signer.activeGeneration ≤ s.signer.activeGeneration)')

    def test_observation_cannot_discard_newer_known_generation(self):
        self.rejected('max s.authenticatedGeneration target.view.inbox.generation',
                      'target.view.inbox.generation')

    def test_observation_must_record_newer_generation(self):
        self.rejected('max s.authenticatedGeneration target.view.inbox.generation',
                      's.authenticatedGeneration')

    def test_restart_preserves_authenticated_generation(self):
        self.rejected('def restart (s : Node) : Node :=\n  { startup s.signer with authenticatedGeneration := s.authenticatedGeneration }',
                      'def restart (s : Node) : Node := startup s.signer')

    def test_rollback_preserves_authenticated_generation(self):
        self.rejected('def rollback (s : Node) : Node :=\n  { startup s.signer with authenticatedGeneration := s.authenticatedGeneration }',
                      'def rollback (s : Node) : Node := startup s.signer')

    def test_failed_recovery_preserves_new_authentication(self):
        self.rejected('target.view.inbox.generation (target.view.inbox.origin.height+1) true persisted) }',
                      'target.view.inbox.generation (target.view.inbox.origin.height+1) true persisted), authenticatedGeneration := s.authenticatedGeneration }')
