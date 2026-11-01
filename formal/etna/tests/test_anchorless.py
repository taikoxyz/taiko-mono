"""Type-correct model mutations followed by the unchanged root/migration proof layer."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def layers():
    imports, bodies = [], []
    for library in ('EtnaModel', 'EtnaProofs'):
        lines = (ROOT/library/'Anchorless.lean').read_text().splitlines()
        end = 0
        while end < len(lines) and lines[end].startswith('import '):
            imports.append(lines[end])
            end += 1
        bodies.append('\n'.join(lines[end:]).replace('Etna.Design.Anchorless',
                                                     'Etna.Design.AnchorlessMutation'))
    return '\n'.join(dict.fromkeys(imports))+'\n', *bodies


class AnchorlessKernelTests(unittest.TestCase):
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
        self.assertEqual(baseline.stdout+baseline.stderr, '', 'mutated model must compile silently')
        result = self.compile(imports+changed+'\n'+proofs)
        output = result.stdout+result.stderr
        self.assertNotEqual(result.returncode, 0, 'the unchanged theorem layer must reject the semantic mutation')
        self.assertIn('error:', output)
        # Later tactic branches can cascade after the real proof failure. The first
        # diagnostic must be a substantive proof failure, never a setup/name error.
        first = output.splitlines()[0]
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, first)
        logs = ROOT/'.scratch/safety-completion/task5-mutants'
        logs.mkdir(parents=True, exist_ok=True)
        (logs/(self._testMethodName+'.log')).write_text(
            'MODEL-ONLY: exit 0, empty diagnostics\nUNCHANGED PROOFS: exit '+str(result.returncode)+'\n'+output)

    def test_unmodified_model_and_proofs_compile_silently(self):
        result = self.compile('\n'.join(layers()))
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')

    def test_boundary_and_migration_witnesses_compile_silently(self):
        result = self.compile((ROOT/'tests/Anchorless.lean').read_text())
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')

    def test_canonical_l1_root_binding_required(self):
        self.rejected('h.root = l1 h.anchorNumber', 'h.root = l1 h.root')

    def test_encoded_anchor_binding_required(self):
        self.rejected('h.encodedNumber = h.anchorNumber', 'h.encodedNumber = h.encodedNumber')

    def test_el_shape_required(self):
        self.rejected('h.extraBytes = 13', 'h.extraBytes = h.extraBytes')

    def test_prefork_root_remains_zero(self):
        self.rejected('h.root = 0 ∧ h.extraBytes = 7', 'h.root = h.root ∧ h.extraBytes = 7')

    def test_checkpoint_l1_binding_required(self):
        self.rejected('(binding : root = l1 number)', '(binding : root = l1 root)')

    def test_checkpoint_fork_cutoff_required(self):
        self.rejected('(before : s.clock < fork)', '(before : s.clock ≤ fork)')

    def test_monotone_header_write_required(self):
        self.rejected('(later : s.clock < h.timestamp)', '(later : s.clock < h.timestamp + 2)')

    def test_getter_exact_timestamp_required(self):
        self.rejected('if entry.timestamp = timestamp then', 'if entry.timestamp % 8191 = timestamp % 8191 then')

    def test_anchor_nonzero_root_required(self):
        self.rejected('if root ≠ 0 then some root else none', 'if root = root then some root else none')

    def test_provider_failure_is_closed(self):
        self.rejected('if !provider then none else do', 'if !provider && provider then none else do')

    def test_missing_beacon_code_is_closed(self):
        self.rejected('if code && decide (timestamp ≠ 0) then', 'if (code || !code) && decide (timestamp ≠ 0) then')

    def test_verifier_time_selects_mode(self):
        self.rejected('let root ← if s.clock < fork then', 'let root ← if blockId < fork then')

    def test_postfork_timestamp_floor_required(self):
        self.rejected('else if fork ≤ blockId then beaconGet', 'else if 0 ≤ blockId then beaconGet')

    def test_prefork_uint48_required(self):
        self.rejected('if blockId < limit48 then', 'if blockId ≤ limit48 then')

    def test_current_checkpoint_namespace_cannot_fallback(self):
        self.rejected('then s.checkpoints blockId else none',
                      'then (match s.checkpoints blockId with | some root => some root | none => s.flatCheckpoints blockId) else none')

    def test_current_cache_cannot_fallback(self):
        self.rejected('decide (slot ∈ cache.current)', 'decide (slot ∈ cache.current ++ cache.flat)')

    def test_root_hash_binding_required(self):
        self.rejected('resolve fork s provider p.blockId = some p.root',
                      'resolve fork s provider p.blockId ≠ none')

    def test_source_chain_required(self):
        self.rejected('decide (p.chain = domain.chain)', 'decide (p.chain = p.chain)')

    def test_source_account_required(self):
        self.rejected('decide (p.account = domain.signalService)', 'decide (p.account = p.account)')

    def test_source_slot_required(self):
        self.rejected('decide (p.slot = slot)', 'decide (p.slot ≤ slot)')

    def test_anchor_v4_timestamp_gate_required(self):
        self.rejected('decide (now < fork) && ancestorsPass', 'decide (now ≤ fork) && ancestorsPass')

    def test_both_proxies_required_atomically(self):
        self.rejected('{ s with anchor := true, signal := true }', '{ s with anchor := false, signal := true }')

    def test_anchor_timestamp_probe_required(self):
        self.rejected('s.images && anchorOK && signalOK', 's.images && (anchorOK || !anchorOK) && signalOK')

    def test_signal_upgrade_failure_reverts(self):
        self.rejected('s.images && anchorOK && signalOK', 's.images && anchorOK && (signalOK || !signalOK)')

    def test_images_must_precede_proxy_batch(self):
        self.rejected('s.dualReaders && s.images && anchorOK', 's.dualReaders && (s.images || !s.images) && anchorOK')

    def test_flat_implementation_rollback_prohibited(self):
        self.rejected('if s.signal then none else some s', 'if s.signal && !s.signal then none else some s')

    def test_engine_call_order_required(self):
        self.rejected('(ready : s.identicalCalls = true)', '(ready : s.identicalCalls = s.identicalCalls)')

    def test_guest_readers_precede_images(self):
        self.rejected('(ready : s.dualReaders = true)', '(ready : s.dualReaders = s.dualReaders)')

    def test_client_anchor_fork_times_must_match(self):
        self.rejected('decide (s.forkTime = clientFork)', 'decide (s.forkTime ≤ clientFork)')

    def test_getter_timestamp_zero_rejected(self):
        self.rejected('if code && decide (timestamp ≠ 0) then', 'if code && decide (0 ≤ timestamp) then')

    def test_genesis_has_no_preexecution_write(self):
        self.rejected('⟨0,false,fun _ => none,fun _ => none,fun _ => none⟩',
                      '⟨0,false,fun _ => some ⟨1,1007⟩,fun _ => none,fun _ => none⟩')

    def test_workflow_triggers_anchorless_authority_changes(self):
        workflow = (ROOT.parents[1]/'.github/workflows/formal--etna.yml').read_text()
        self.assertEqual(workflow.count('      - "packages/protocol/docs/etna/ANCHORLESS.md"'), 2)

    def test_proxy_batch_must_precede_fork(self):
        self.rejected('decide (s.clock < s.forkTime)', 'decide (s.clock ≤ s.forkTime)')

    def test_clock_cannot_change_installed_fork_time(self):
        self.rejected('InstallStep s { s with clock := now }', 'InstallStep s { s with clock := now, forkTime := now }')

    def test_service_source_chain_is_bound(self):
        self.rejected('decide (request.sourceChain = config.domain.chain)',
                      'decide (request.sourceChain = request.sourceChain)')

    def test_service_app_derives_slot(self):
        self.rejected('config.slotOf request.sourceChain request.app request.signal',
                      'config.slotOf request.sourceChain 0 request.signal')

    def test_service_signal_derives_slot(self):
        self.rejected('config.slotOf request.sourceChain request.app request.signal',
                      'config.slotOf request.sourceChain request.app 0')

    def test_service_cache_uses_same_derived_slot(self):
        self.rejected('current := requestSlot config request :: cache.current',
                      'current := (requestSlot config request + 1) :: cache.current')
