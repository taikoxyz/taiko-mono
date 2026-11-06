"""Each mutant must compile as a model before unchanged proofs/examples reject it."""
from pathlib import Path
import subprocess
import tempfile
import unittest
import os


def setUpModule():
    if os.environ.get('ETNA_FULL_TESTS') != '1':
        raise unittest.SkipTest('mutation suite: set ETNA_FULL_TESTS=1 (CI job etna-formal-full)')

ROOT = Path(__file__).resolve().parents[1]


def layers():
    imports, bodies = [], []
    for library in ('EtnaModel', 'EtnaProofs'):
        lines = (ROOT/library/'Current.lean').read_text().splitlines()
        while lines and lines[0].startswith('import '):
            line = lines.pop(0)
            if line != 'import EtnaModel.Current':
                imports.append(line)
        bodies.append('\n'.join(lines).replace('Etna.Design.Current', 'Etna.Design.CurrentMutation'))
    fixture = (ROOT/'tests/CurrentDesign.lean').read_text().replace('import EtnaProofs.Current', '')
    fixture = fixture.replace('Etna.Design.Current', 'Etna.Design.CurrentMutation')
    light = fixture.split('end Etna.CurrentRegression', 1)[0]+'end Etna.CurrentRegression\n'
    return '\n'.join(dict.fromkeys(imports))+'\n', *bodies, light, fixture


class CurrentSemanticMutationTests(unittest.TestCase):
    def compile(self, source):
        with tempfile.NamedTemporaryFile(dir=ROOT/'.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True)

    def reject(self, old, new, full=False):
        imports, model, proofs, light, fixture = layers()
        self.assertEqual(model.count(old), 1, old)
        changed = model.replace(old, new, 1)
        result = self.compile(imports+changed)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')
        result = self.compile(imports+changed+'\n'+proofs+'\n'+(fixture if full else light))
        self.assertNotEqual(result.returncode, 0, 'unchanged evidence accepted semantic mutant')
        output = result.stdout+result.stderr
        self.assertIn('error:', output)
        first = next(line for line in output.splitlines() if 'error:' in line)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, first)


MUTATIONS = [
    ('stop_cancellation_width', 'now+c.maxAge < limit256 ∧ fits next', 'now+c.maxAge < limit48 ∧ fits next', False),
    ('timestamp_inclusive', 'if s.time ≤ timestamp then', 'if s.time < timestamp then', False),
    ('all_blocks_covered', 'timestamps.all (fun t', '(timestamps.take 1).all (fun t', False),
    ('rules_strict_deadline', 'now+c.maxAge < s.time', 'now+c.maxAge ≤ s.time', False),
    ('owner_authorization', 'caller = c.owner ∧\n      (s.time', 'caller = caller ∧\n      (s.time', False),
    ('stop_strict_deadline', 'now+c.maxAge < s.stopTime', 'now+c.maxAge ≤ s.stopTime', False),
    ('stop_offset', '(parentHeight-start) % s.stopGrid', 'parentHeight % s.stopGrid', False),
    ('fresh_bond_id', 'nextId := s.nextId+1,', 'nextId := s.nextId,', False),
    ('pending_admission_value', 'fun b => b.value.balance', 'fun b => b.value.stake', True),
    ('lowest_slot_tie', 'slotValue s slot < slotValue s best', 'slotValue s slot ≤ slotValue s best', True),
    ('withdrawn_key_identity', 'b.value with owner := 0, stake := 0,', 'b.value with key := 0, owner := 0, stake := 0,', False),
    ('replacement_slot_survives', 'b.slot = some slot ∧ s.slots slot = some id', 'slot = 0', True),
    ('initialized_confirmation', 'initialized = true ∧ b.value.released = false', 'initialized = initialized ∧ b.value.released = false', True),
    ('unissued_id_rejected', 'if id < s.nextId then\n    (s.bonds id).bind fun b => (f b).map', 'if True then\n    (s.bonds id).bind fun b => (f b).map', False),
    ('first_unzen_fully_finalized', 'u.nextProposal = u.finalizedProposal+1', 'True', False),
    ('first_unzen_state_root', 'u.checkpointRoot = root)', 'u.checkpointRoot = u.checkpointRoot ∧ root = root)', False),
    ('origin_fork_time', 's.unzenInbox ≠ 0 ∧ s.forkTime ≤ now', 's.unzenInbox ≠ 0 ∧ True', True),
    ('correction_new_generation', 'generation := s.generation+1, origins', 'generation := s.generation, origins', False),
    ('import_datahash_authentication', 'c.dataHashAuthenticated = false ∨\n', 'False ∨\n', False),
    ('import_val_state_preimage', '(c.origin < c.height ∧ c.valStateAuthenticated = false) then .reject', 'False then .reject', False),
    ('genesis_path_val_state', '(c.origin < c.height ∧ c.valStateAuthenticated = false)', 'c.valStateAuthenticated = false', False),
    ('authenticated_conflict_halt', 'c.envelopeEL ≠ c.checkpointEL ∨ (c.origin < c.height ∧ c.nextValidatorsMatch = false) then .halt', 'c.envelopeEL ≠ c.checkpointEL ∨ (c.origin < c.height ∧ c.nextValidatorsMatch = false) then .reject', False),
    ('next_validators_conflict_halt', ' ∨ (c.origin < c.height ∧ c.nextValidatorsMatch = false) then .halt', ' then .halt', False),
    ('genesis_path_next_validators', '(c.origin < c.height ∧ c.nextValidatorsMatch = false)', 'c.nextValidatorsMatch = false', False),
    ('committee_conflict_halt', 'else if c.origin < c.height ∧ c.committeesMatch = false then .halt', 'else if False then .halt', False),
    ('genesis_path_committees', 'else if c.origin < c.height ∧ c.committeesMatch = false then .halt', 'else if c.committeesMatch = false then .halt', False),
    ('import_checkpoint_finality', 'else if c.checkpointFinalized = false then .retry', 'else if False then .retry', False),
    ('durable_publication', 'if durable = true ∧ inspect', 'if durable = durable ∧ inspect', False),
    ('no_import_trust', ',signer,false⟩', ',signer,true⟩', False),
    ('complete_header_range', "List.range' (retainedFrom c unsettled) (c.height+1-retainedFrom c unsettled),signer", "List.range' (retainedFrom c unsettled) (min 256 (c.height+1-retainedFrom c unsettled)),signer", False),
    ('retained_window', 'max c.origin (c.height+1-unsettled)', 'min c.origin (c.height+1-unsettled)', True),
]


def mutation_test(old, new, full):
    def test(self):
        self.reject(old, new, full)
    return test


for name, old, new, full in MUTATIONS:
    setattr(CurrentSemanticMutationTests, 'test_'+name, mutation_test(old, new, full))
