"""Each current headline theorem passes the proof audit on its own manifest entry.

The audit of one entry checks the exact type, mechanical role and transitive axioms; the probe
also checks that the declared type is the statement-layer claim constant itself, not a
restatement that is only definitionally equal to it. tests/test_current_headlines.py covers the
conjunction, the premise-field use and the dependency contracts.
"""
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT/path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


AUDIT = load('statements_audit', 'scripts/audit_proofs.py')


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

    def test_headlines_are_the_audited_current_headlines(self):
        self.assertEqual(AUDIT.CURRENT_HEADLINES, {
            'Etna.Design.Current.Headlines.fund_safety': 'Etna.Statements.Current.FundSafety',
            'Etna.Design.Current.Headlines.accountable_finality': 'Etna.Statements.Current.AccountableFinality',
            'Etna.Design.Current.Headlines.forced_inclusion_integrity':
                'Etna.Statements.Current.ForcedInclusionIntegrity'})

    def test_h1_proved(self):
        self.audit_headline('Etna.Design.Current.Headlines.fund_safety', 'Etna.Statements.Current.FundSafety')

    def test_h2_proved(self):
        self.audit_headline('Etna.Design.Current.Headlines.accountable_finality',
                            'Etna.Statements.Current.AccountableFinality')

    def test_h3_proved(self):
        self.audit_headline('Etna.Design.Current.Headlines.forced_inclusion_integrity',
                            'Etna.Statements.Current.ForcedInclusionIntegrity')


if __name__ == '__main__':
    unittest.main()
