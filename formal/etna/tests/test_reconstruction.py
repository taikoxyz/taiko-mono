"""Public reconstruction regressions and model-only, type-correct semantic mutants."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def layers():
    imports, bodies = [], []
    for library in ('EtnaModel', 'EtnaProofs'):
        lines = (ROOT/library/'Reconstruction.lean').read_text().splitlines()
        end = 0
        while end < len(lines) and lines[end].startswith('import '):
            imports.append(lines[end])
            end += 1
        bodies.append('\n'.join(lines[end:]).replace('Etna.Design.Reconstruction',
                                                     'Etna.Design.ReconstructionMutation'))
    return '\n'.join(dict.fromkeys(imports))+'\n', *bodies


class ReconstructionKernelTests(unittest.TestCase):
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
        self.assertNotEqual(result.returncode, 0, 'unchanged proofs must reject the semantic mutant')
        self.assertIn('error:', output)
        first = next(line for line in output.splitlines() if 'error:' in line)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, first)
        logs = ROOT/'.scratch/safety-completion/task7/mutants'
        logs.mkdir(parents=True, exist_ok=True)
        (logs/(self._testMethodName+'.log')).write_text(
            'MODEL-ONLY: exit 0, empty diagnostics\nUNCHANGED PROOFS: exit '+str(result.returncode)+'\n'+output)

    def test_unmodified_layers(self):
        result = self.compile('\n'.join(layers()))
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')

    def test_certified_overlap_and_recovery(self):
        result = self.compile((ROOT/'tests/Reconstruction.lean').read_text())
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')

    def test_public_inputs_exclude_private_envelopes(self):
        model = (ROOT/'EtnaModel/Reconstruction.lean').read_text()
        public = model.split('/-- Proof-side local semantics')[0]
        self.assertNotIn(': BlockValidity.Header', public)
        self.assertNotIn(': BlockValidity.Block', public)
        self.assertIn('header : Bytes', public)
        self.assertIn('transactions : List Bytes', public)
        self.assertIn('executeFullBlock : Bytes → PublicBlock → Option Bytes', public)
        self.assertIn('EIP-4788', public)
        self.assertIn('EIP-2935', public)
        overlap = public.split('def verifyOverlap')[1].split('/-- Apply each')[0]
        self.assertNotIn('executeFullBlock', overlap)

    def test_version_required(self):
        self.rejected('l.metadata s ∧ l.version = 6 ∧', 'l.metadata s ∧ l.version = l.version ∧')

    def test_original_material_required(self):
        self.rejected('let raw ← l.original', 'let raw := l.original.getD []')

    def test_blob_commitments_required(self):
        self.rejected('raw.map el.versionedHash = l.blobHashes', 'raw.map el.versionedHash = raw.map el.versionedHash')

    def test_parent_link_required(self):
        self.rejected('h.height = p.height+1 ∧ h.parentHash = p.elHash then',
                      'h.height = p.height+1 ∧ h.parentHash = h.parentHash then')

    def test_overlap_checked(self):
        self.rejected('if (archive.lookup q.height).map el.headerHash = some q.elHash then',
                      'if q.elHash = q.elHash then')

    def test_full_proof_range_required(self):
        self.rejected('if blocks.length = l.input.lastHeight-l.input.parentHeight then',
                      'if blocks.length = blocks.length then')

    def test_only_new_suffix_executed(self):
        self.rejected('executeSuffix el overlap s.state (blocks.drop (l.current.height-l.input.parentHeight))',
                      'executeSuffix el overlap s.state blocks')

    def test_full_public_header_passed_to_el(self):
        self.rejected('let next ← el.executeFullBlock state b',
                      'let next ← el.executeFullBlock state { b with header := [] }')

    def test_result_state_is_applied(self):
        self.rejected('    state := out.state\n', '    state := s.state\n')

    def test_saved_suffix_retained(self):
        self.rejected('    archive := out.headers.reverse ++ s.archive', '    archive := s.archive')

    def test_generation_required(self):
        self.rejected('s.generation = l.generation ∧ s.origin = l.origin',
                      's.generation = s.generation ∧ s.origin = l.origin')

    def test_fixed_origin_required(self):
        self.rejected('s.origin = l.origin ∧', 's.origin = s.origin ∧')

    def test_recovery_origin_is_frontier(self):
        self.rejected('r.nextOrigin.height = r.current.height ∧', 'r.nextOrigin.height = r.nextOrigin.height ∧')

    def test_recovery_increments_generation(self):
        self.rejected('some { s with generation := s.generation+1, origin := r.nextOrigin, order := r.order }',
                      'some { s with generation := s.generation, origin := r.nextOrigin, order := r.order }')

    def test_initial_state_root_authenticated(self):
        self.rejected('h.stateRoot = a.stateRoot ∧ el.stateRoot state = a.stateRoot then',
                      'h.stateRoot = a.stateRoot ∧ el.stateRoot state = el.stateRoot state then')

    def test_record_authentication_required(self):
        self.rejected('if el.authenticateRecord record then', 'if el.authenticateRecord record || true then')

    def test_terminal_state_root_checked(self):
        self.rejected('el.stateRoot out.state = l.input.lastStateRoot then',
                      'el.stateRoot out.state = el.stateRoot out.state then')
