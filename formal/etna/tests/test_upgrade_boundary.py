"""Conditional upgrades: real fixtures plus model-only type-correct semantic mutants."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def layers():
    imports, bodies = [], []
    for library in ('EtnaModel', 'EtnaProofs'):
        lines = (ROOT/library/'UpgradeBoundary.lean').read_text().splitlines()
        end = 0
        while end < len(lines) and lines[end].startswith('import '):
            imports.append(lines[end])
            end += 1
        bodies.append('\n'.join(lines[end:]).replace('Etna.Design.UpgradeBoundary',
                                                     'Etna.Design.UpgradeBoundaryMutation'))
    return '\n'.join(dict.fromkeys(imports))+'\n', *bodies


class UpgradeBoundaryKernelTests(unittest.TestCase):
    def compile(self, source):
        with tempfile.NamedTemporaryFile(dir=ROOT/'.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT, capture_output=True, text=True)

    def rejected(self, old, new):
        imports, model, proofs = layers()
        self.assertEqual(model.count(old), 1, old)
        changed = model.replace(old, new, 1)
        baseline = self.compile(imports+changed)
        self.assertEqual(baseline.returncode, 0, baseline.stdout+baseline.stderr)
        self.assertEqual(baseline.stdout+baseline.stderr, '', 'model-only must compile silently')
        result = self.compile(imports+changed+'\n'+proofs)
        output = result.stdout+result.stderr
        self.assertNotEqual(result.returncode, 0, 'unchanged proofs must reject semantic mutant')
        self.assertIn('error:', output)
        first = next(line for line in output.splitlines() if 'error:' in line)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, first)
        logs = ROOT/'.scratch/safety-completion/task8/mutants'
        logs.mkdir(parents=True, exist_ok=True)
        (logs/(self._testMethodName+'.log')).write_text(
            'MODEL-ONLY: exit 0, empty diagnostics\nUNCHANGED PROOFS: exit '+str(result.returncode)+'\n'+output)

    def test_unmodified_layers(self):
        result = self.compile('\n'.join(layers()))
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')

    def test_real_boundaries_and_session(self):
        result = self.compile((ROOT/'tests/UpgradeBoundary.lean').read_text())
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')

    def test_stopped_plan_cannot_be_replaced(self):
        self.rejected('s.staged.isNone && auth.plan p &&', 'true && auth.plan p &&')

    def test_exact_plan_authenticated(self):
        self.rejected('auth.plan p && planFits s p &&', 'true && planFits s p &&')

    def test_current_checkpoint_authenticated(self):
        self.rejected('auth.checkpoint s.world.inbox.domain s.world.inbox.checkpoint &&', 'true &&')

    def test_checkpoint_exactly_at_boundary(self):
        self.rejected('decide (s.world.inbox.checkpoint.height = p.height) &&', 'true &&')

    def test_atomic_switch_failure(self):
        self.rejected('if persisted && readyToSwitch auth s p then', 'if (persisted || true) && readyToSwitch auth s p then')

    def test_old_jobs_closed(self):
        self.rejected('s.jobs.all (fun w => w.status != .pending)', 'true')

    def test_current_generation_log_ceiling(self):
        self.rejected('&& logBelow s p.height', '&& true')

    def test_existing_unsettled_production(self):
        self.rejected('s.produced ≤ p.height)', 's.produced ≤ s.produced)')

    def test_new_grid_common_boundary(self):
        self.rejected('p.height % p.next.grid = 0 ∧', 'p.height = p.height ∧')

    def test_unchanged_u_compatible(self):
        self.rejected('s.world.inbox.configuration.unsettled % p.next.grid = 0 ∧', 'p.height = p.height ∧')

    def test_immutable_configuration(self):
        self.rejected('p.next.config = s.world.inbox.committeeConfig ∧', 'p.next.config = p.next.config ∧')

    def test_prior_rule_history_not_flattened(self):
        self.rejected('if h ≤ height then s.versionAt h else next', 'if h ≤ height then s.versionAt height else next')

    def test_new_rule_height_selection(self):
        self.rejected('if h ≤ height then s.versionAt h else next', 'if next = next then s.versionAt h else next')

    def test_all_prior_boundaries_retained(self):
        self.rejected('s.boundaries ++ [height]', '[height]')

    def test_crossing_even_repeated_rules(self):
        self.rejected('noCrossing s.schedule j.first j.last &&', 'true &&')

    def test_interior_heights_checked(self):
        self.rejected("(List.range' (j.first+1) (j.last-j.first)).all (fun h => decide (s.schedule.versionAt h = j.version)) &&", 'true &&')

    def test_only_accepted_image(self):
        self.rejected('j.image ∈ j.version.images ∧', 'j.image = j.image ∧')

    def test_full_statement_identity(self):
        self.rejected('w.job.statement = e.certificate ∧', 'w.job.statement = w.job.statement ∧')

    def test_original_land_required(self):
        self.rejected('(land s.world.inbox i leaves e).map fun inbox =>', '((land s.world.inbox i leaves e).orElse fun _ => some (applyLanding s.world.inbox i)).map fun inbox =>')

    def test_jobs_never_rewritten(self):
        self.rejected('material := p.next :: s.material, staged := none',
                      'material := p.next :: s.material, jobs := [], staged := none')

    def test_node_and_hrs_preserved(self):
        self.rejected('material := p.next :: s.material, staged := none',
                      'material := p.next :: s.material, node := TrustState.startup s.node.signer, staged := none')

    def test_old_replay_material_kept(self):
        self.rejected('material := p.next :: s.material, staged := none',
                      'material := [p.next], staged := none')

    def test_fresh_signing_stops(self):
        self.rejected('decide (m.height ≤ p.height)', 'decide (m.height ≤ max p.height m.height)')

    def test_exact_cached_retry_exception(self):
        self.rejected('(cached s encode m || (match s.staged', '((cached s encode m && false) || (match s.staged')

    def test_requested_height_rule_binding(self):
        self.rejected('v = s.schedule.versionAt m.height ∧', 'v = v ∧')

    def test_existing_session_authorization(self):
        self.rejected('then TrustState.sign s.node encode m signature persisted else none',
                      'then Signer.sign s.node.signer (messageRequest encode m true) signature persisted else none')

    def test_actual_world_landing_clock(self):
        self.rejected('ProtocolState.landed s.world inbox e.blockNumber', '{ s.world with inbox := inbox }')

    def test_landing_clock_never_rewinds(self):
        self.rejected('s.world.l1Block ≤ e.blockNumber then', 's.world.l1Block ≤ s.world.l1Block then')
