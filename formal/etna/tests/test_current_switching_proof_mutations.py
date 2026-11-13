"""Compile-first mutations against the full switching proof dependency chain.

Unlike test_current_guards, this recompiles the actual trace_switching_fence proof
and its journal, certificate and custody dependencies, with no executable fixture.
The mutants retain conjunction shape so failures cannot be caused by shifting
guard projections. Proof rejection measures the existing derivation's sensitivity;
it does not prove every written guard independently necessary on reachable states.
"""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
import os


def setUpModule():
    if os.environ.get('ETNA_FULL_TESTS') != '1':
        raise unittest.SkipTest('mutation suite: set ETNA_FULL_TESTS=1 (CI job etna-formal-full)')

ROOT = Path(__file__).resolve().parents[1]
MODELS = ('CurrentProtocol', 'CurrentCustody', 'CurrentCoherentCustody',
          'CurrentUnzen', 'CurrentJournal', 'CurrentProtocolFinality',
          'CurrentEconomics', 'CurrentMetadata')
PROOFS = ('CurrentReference', 'CurrentHistory', 'CurrentProtocolFinality',
          'CurrentEconomics', 'CurrentMetadata', 'CurrentFootprintHistory',
          'CurrentCertificate', 'CurrentSettlement', 'CurrentJournal', 'CurrentCustody',
          'CurrentCoherentCustody', 'CurrentUnzen')

REACHABLE_REDUNDANCY = r'''
namespace Etna.Design.Current.Protocol.Custody

-- Ordinary Unzen calls write these three fields atomically; every other call
-- frames them. This explains why independently corrupting either hash is off-trace.
theorem mutation_trace_unzen_storage_shape {env : Environment}
    {registry : RegistryMachine.State} {w : World}
    (trace : Trace env (empty env registry) w) :
    w.unzen.finalizedHash = w.unzen.checkpointHash ∧
    (w.unzen.checkpointExists = false → w.unzen.finalizedHash = 0) := by
  induction trace with
  | refl => exact ⟨rfl,fun _ => rfl⟩
  | @step previous current prior change ih =>
    cases change with
    | call call =>
      cases ok : execute env previous call with
      | none => simpa [transact,ok] using ih
      | some result =>
        have shape : result.unzen.finalizedHash = result.unzen.checkpointHash ∧
            (result.unzen.checkpointExists = false → result.unzen.finalizedHash = 0) := by
          by_cases legacy : ∃ p h b, call = .unzenProve p h b
          · obtain ⟨p,h,b,rfl⟩ := legacy
            change unzenProve env previous p h b = some result at ok
            unfold unzenProve at ok
            split at ok
            next =>
              cases Option.some.inj ok
              exact ⟨rfl,by simp⟩
            next => simp at ok
          · have frame := execute_unzen_frame (fun p h b eq => legacy ⟨p,h,b,eq⟩) ok
            simpa only [frame.1] using ih
        simpa [transact,ok] using shape
    | node after checked => exact ih

theorem mutation_reachable_hash_guards_equivalent {env : Environment}
    {registry : RegistryMachine.State} {w : World}
    (trace : Trace env (empty env registry) w) (hash : Hash) :
    (w.unzen.finalizedHash = hash) ↔ (w.unzen.checkpointHash = hash) := by
  rw [(mutation_trace_unzen_storage_shape trace).1]

theorem mutation_reachable_present_from_nonzero_hash {env : Environment}
    {registry : RegistryMachine.State} {w : World} {hash : Hash}
    (trace : Trace env (empty env registry) w)
    (finalized : w.unzen.finalizedHash = hash) (nonzero : hash ≠ 0) :
    w.unzen.checkpointExists = true := by
  cases present : w.unzen.checkpointExists with
  | false => exact (nonzero (finalized.symm.trans
      ((mutation_trace_unzen_storage_shape trace).2 present))).elim
  | true => rfl

end Etna.Design.Current.Protocol.Custody
'''


def sources():
    cloned = {f'EtnaModel.{name}' for name in MODELS}
    cloned.update(f'EtnaProofs.{name}' for name in PROOFS)
    imports, models, proofs = [], [], []
    for library, names, bodies in (('EtnaModel', MODELS, models), ('EtnaProofs', PROOFS, proofs)):
        for name in names:
            body = []
            for line in (ROOT / library / f'{name}.lean').read_text().splitlines():
                if line.startswith('import '):
                    if line.removeprefix('import ') not in cloned:
                        imports.append(line)
                else:
                    body.append(line)
            bodies.append(f'-- BEGIN cloned {library}.{name}\n' + '\n'.join(body))
    current = (ROOT / 'EtnaModel/Current.lean').read_text()
    fence = current.split('def firstLanding ', 1)[1].split('\nstructure Origin', 1)[0]
    fence = ('namespace Etna.Design.Current.SwitchProofFirstFence\nopen Start\n'
             'def firstLanding ' + fence + '\nend Etna.Design.Current.SwitchProofFirstFence\n')

    def rename(text):
        for name in ('Protocol', 'Journal', 'ProtocolFinality', 'Economics'):
            text = re.sub(r'\b' + name + r'\b', 'SwitchProofMutation' + name, text)
        return text

    models = rename(fence + '\n'.join(models)).replace(
        'Start.firstLanding', 'SwitchProofFirstFence.firstLanding')
    proofs = rename('\n'.join(proofs) + '\n' + REACHABLE_REDUNDANCY).replace(
        'Start.firstLanding', 'SwitchProofFirstFence.firstLanding')
    header = '\n'.join(dict.fromkeys(imports)) + '\n'
    return header, models, proofs


class CurrentSwitchingProofMutationTests(unittest.TestCase):
    def compile(self, source):
        (ROOT / '.scratch').mkdir(exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=ROOT / '.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True, timeout=240)

    def test_unmodified_full_switching_derivation_compiles(self):
        header, model, proofs = sources()
        self.assertIn('theorem trace_switching_fence ', proofs)
        result = self.compile(header + model + '\n' + proofs)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def reject(self, old, new, required_theorem):
        header, model, proofs = sources()
        self.assertEqual(model.count(old), 1, old)
        mutant = model.replace(old, new, 1)
        result = self.compile(header + mutant)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')
        source = header + mutant + '\n' + proofs
        result = self.compile(source)
        self.assertNotEqual(result.returncode, 0, 'unchanged switching derivation accepted mutant')
        errors = [line for line in (result.stdout + result.stderr).splitlines() if 'error:' in line]
        self.assertTrue(errors, result.stdout + result.stderr)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token',
                           'Unknown identifier', 'Invalid projection'):
            self.assertNotIn(accidental, errors[0])
        # Require a failure in a substantive preservation lemma, even if an
        # earlier helper also rejects the same semantic change.
        lines, rejected = source.splitlines(), set()
        for error in errors:
            location = re.search(r'\.lean:(\d+):\d+: error:', error)
            self.assertIsNotNone(location, error)
            declarations = (re.match(r'\s*(?:private )?theorem (\S+)', line)
                            for line in reversed(lines[:int(location.group(1))]))
            rejected.add(next(match.group(1) for match in declarations if match))
        self.assertIn(required_theorem, rejected, result.stdout + result.stderr)

    def test_correction_after_landing_breaks_start_freezing(self):
        self.reject('env.core.unzenInbox ≠ 0 ∧ w.everLanded = false ∧',
                    'env.core.unzenInbox ≠ 0 ∧ True ∧', 'execute_frozen')

    def test_unfiltered_rollback_breaks_retained_signal_custody(self):
        self.reject('w.inbox.signals.filter (fun s => s.height ≤ trusted.height)',
                    'w.inbox.signals', 'rollback_coherent')

    def test_open_unzen_frontier_breaks_first_fence_derivation(self):
        self.reject('u.nextProposal = u.finalizedProposal+1', 'True', 'pending_parent_fence')

    def test_missing_checkpoint_root_breaks_first_fence_derivation(self):
        self.reject('u.checkpointRoot = root)', 'root = root)', 'pending_parent_fence')

    # This mutant fails only because `Custody.FirstFence` restates the height conjunct, so
    # `pending_parent_fence` can no longer derive it. H1's other conclusions do not need the
    # height check; the behavioural regression (a shifted start refused by `land`) is in
    # tests/CurrentGuards.lean.
    def test_missing_checkpoint_height_breaks_first_fence_derivation(self):
        self.reject('u.checkpointHeight = start ∧', 'start = start ∧', 'pending_parent_fence')


if __name__ == '__main__':
    unittest.main()
