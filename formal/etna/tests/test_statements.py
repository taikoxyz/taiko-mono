"""The headline statements elaborate and have the reviewed shape.

`Etna.Statements.Claims` is the conjunction of the three headline claims; each is a `Prop`
definition with a docstring whose definitions reach the deployment-built rules
(`Deployment.build`), the full protocol step relation and traces, block validity and the
premise record; and no field of `Etna.Statements.Premises` is `True` or undocumented.
scripts/EtnaAudit.lean's `checkStatement` performs the check against the built package; a
probe with a vacuous premise record shows that it rejects. One generated Lean file runs every
check (plus the compile of the audit library the other gate tests use too).
"""
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT/path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


AUDIT = load('statements_audit', 'scripts/audit_proofs.py')

PREMISES = 'Etna.Statements.Premises'
# Every headline names the premise record and the deployment-built rules; each names the
# objects its prose is about.
REQUIRED = {
    'Etna.Statements.Claims': [
        'Etna.Design.Deployment.build', 'Etna.Design.ProtocolState.Trace', 'Etna.Design.ProtocolState.Step',
        'Etna.Design.BlockValidity.Valid', PREMISES],
    # Continuity: segments meet in full headers, from block 0's header, through the EL header hash.
    'Etna.Statements.FundSafety': [
        'Etna.Design.Deployment.build', 'Etna.Design.ProtocolState.Step', 'Etna.Design.BlockValidity.Valid',
        'Etna.Design.Settlement.BatchValid', 'Etna.Design.Deployment.Genesis', 'Etna.Design.BlockValidity.terminal',
        'Etna.Statements.Environment.genesisHeader', 'Etna.Statements.Environment.headerHash', PREMISES],
    'Etna.Statements.AccountableFinality': [
        'Etna.Design.Deployment.build', 'Etna.Design.ProtocolState.Trace', 'Etna.Design.Consensus.CommitValid',
        'Etna.Design.RegistryHistory.edit', PREMISES],
    # The FI head: only landings advance it, and only through blocks that consume entries.
    'Etna.Statements.ForcedInclusionIntegrity': [
        'Etna.Design.Deployment.build', 'Etna.Design.ProtocolState.Trace', 'Etna.Design.ProtocolState.Step',
        'Etna.Design.BlockValidity.Valid', 'Etna.Design.Forced.step', 'Etna.Design.State.head', PREMISES],
}
# The premise record's fields, in order (a field added or dropped is a statement change to review).
PREMISE_FIELDS = ['genesis', 'verifierSound', 'authenticatedInputs', 'hashSeparation', 'headerHashes',
                  'headerSeparation', 'signatureAgreement']


def lean_string(text):
    return AUDIT.lean_string(text)


def render_probe():
    lines = ['import Lean', 'import EtnaAudit', 'import EtnaStatements', '',
             'example : Etna.Statements.Claims =',
             '    (Etna.Statements.FundSafety ∧ Etna.Statements.AccountableFinality ∧',
             '      Etna.Statements.ForcedInclusionIntegrity) := rfl', '',
             '-- H3 says the FI head moves forward only in landings (steps that advance lastCheckpoint).',
             'example : Etna.Statements.ForcedInclusionIntegrity → ∀ env w0, Etna.Statements.Premises w0 env →',
             '    ∀ w t, Etna.Design.ProtocolState.Trace w0 w → Etna.Design.ProtocolState.Step w t →',
             '      t.inbox.checkpoint.height ≤ w.inbox.checkpoint.height → t.inbox.head ≤ w.inbox.head :=',
             '  fun h env w0 premises => (h env w0 premises).2.1', '']
    for claim, names in REQUIRED.items():
        lines.append('run_elab EtnaAudit.checkStatement '+' '.join(
            lean_string(x) for x in (claim, PREMISES, ' '.join(names))))
    lines += ['', 'run_elab do',
              '  let some info := Lean.getStructureInfo? (← Lean.getEnv) `Etna.Statements.Premises',
              '    | throwError "Etna.Statements.Premises is not a structure"',
              '  Lean.logInfo m!"premise fields: {" ".intercalate (info.fieldNames.toList.map toString)}"',
              '', 'namespace StatementsProbe',
              'structure Premises (n : Nat) : Prop where',
              '  /-- Documented, but it constrains nothing. -/',
              '  vacuous : True',
              '  undocumented : n = n',
              '/-- A claim over the vacuous record that names none of the required constants. -/',
              'def Claims : Prop := ∀ n, Premises n → n = n',
              'end StatementsProbe', '',
              'run_elab do',
              '  let rejected ← try',
              '      EtnaAudit.checkStatement "StatementsProbe.Claims" "StatementsProbe.Premises"',
              '        "Etna.Design.Deployment.build"',
              '      pure none',
              '    catch e => pure (some (← e.toMessageData.toString))',
              '  match rejected with',
              '  | some msg => Lean.logInfo m!"rejected probe: {msg}"',
              '  | none => throwError "the vacuous probe was accepted"', '']
    return '\n'.join(lines)


class StatementTests(unittest.TestCase):
    def test_claims_have_the_reviewed_shape(self):
        lib = AUDIT.build_audit_library()
        out = ROOT/'.scratch/statements'
        out.mkdir(parents=True, exist_ok=True)
        probe = out/'StatementsProbe.lean'
        probe.write_text(render_probe())
        result = subprocess.run(AUDIT.lean_env(ROOT, [lib])+['lean', str(probe)], cwd=ROOT, text=True,
                                capture_output=True)
        output = result.stdout+result.stderr
        self.assertEqual(result.returncode, 0, output)
        # Only the probe's rejection is reported; the real statements pass silently.
        self.assertEqual(output.count('rejected probe:'), 1, output)
        for expected in ('premise field vacuous is `True`', 'premise field undocumented has no docstring',
                         'StatementsProbe.Claims does not depend on Etna.Design.Deployment.build'):
            self.assertIn(expected, output)
        self.assertIn('premise fields: '+' '.join(PREMISE_FIELDS)+'\n', output)


def headline_entry(name):
    return next((e for e in json.loads((ROOT/'manifests/design.json').read_text())['theorems']
                 if e['declaration'] == name), None)


def proved_probe(name, claim):
    """Fails unless `name`'s declared type is literally the constant `claim` (not a restatement
    that is only definitionally equal to it)."""
    return '\n'.join(['run_elab do',
                      f'  let info ← Lean.getConstInfo `{name}',
                      f'  unless info.type == Lean.mkConst `{claim} do',
                      f'    throwError "{name} is not stated as {claim}"', ''])


class HeadlineProofTests(unittest.TestCase):
    def audit_headline(self, name, claim):
        """Audit one headline theorem's manifest entry alone, as the full proof audit does (exact
        type, mechanical role, transitive axioms), and check that the declared type is `claim`
        itself. Returns the derivation chain the audit records."""
        entry = headline_entry(name)
        self.assertIsNotNone(entry, f'{name} has no manifest entry')
        self.assertEqual(entry['type'], claim)
        self.assertEqual(entry['role'], 'property')
        out = ROOT/'.scratch/statements'
        out.mkdir(parents=True, exist_ok=True)
        audit = out/'HeadlineAudit.lean'
        audit.write_text(AUDIT.render_audit([entry], complete=False)+proved_probe(name, claim))
        chains = AUDIT.check_axioms([entry], AUDIT.check_kernel_file(audit))
        self.assertEqual(chains[name][0], name)
        return chains[name]

    def test_h1_proved(self):
        self.audit_headline('Etna.Proofs.fund_safety', 'Etna.Statements.FundSafety')

    def test_h2_proved(self):
        self.audit_headline('Etna.Proofs.accountable_finality', 'Etna.Statements.AccountableFinality')

    def test_h3_proved(self):
        self.audit_headline('Etna.Proofs.forced_inclusion_integrity', 'Etna.Statements.ForcedInclusionIntegrity')


class ReadmeStatementTests(unittest.TestCase):
    """The README's `lean` blocks are copied from the sources, not paraphrased: each claim
    definition is a verbatim part of EtnaStatements/Claims.lean, and each headline signature is
    the start of its theorem in EtnaProofs/Headline (`Claims := …` is the definition in
    Claims.lean)."""

    def test_readme_lean_blocks_match_the_sources(self):
        readme = (ROOT/'README.md').read_text()
        blocks = re.findall(r'^```lean\n(.*?)^```', readme, re.S | re.M)
        claims = (ROOT/'EtnaStatements/Claims.lean').read_text()
        headline = '\n'.join(p.read_text() for p in sorted((ROOT/'EtnaProofs/Headline').glob('*.lean')))
        definitions = signatures = 0
        for block in blocks:
            if block.startswith('def '):
                self.assertTrue(block in claims, f'README block `{block.splitlines()[0]}` differs from Claims.lean')
                definitions += 1
                continue
            for line in block.splitlines():
                signature, _, comment = line.partition('--')
                self.assertTrue(signature.startswith('theorem '), line)
                self.assertIn(signature.strip()+' :=', headline, line)
                signatures += 1
                if comment.strip():
                    name, _, body = comment.strip().partition(' := ')
                    self.assertIn(f'def {name} : Prop := {body}\n', claims, line)
        self.assertEqual((definitions, signatures), (3, 4))


if __name__ == '__main__':
    unittest.main()
