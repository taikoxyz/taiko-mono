"""Focused current headline contracts; no package build, global audit or full-suite run."""
from copy import deepcopy
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('current_headline_audit', ROOT / 'scripts/audit_proofs.py')
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)

CLAIMS = ('Etna.Design.Current.Headlines.claims', 'Etna.Statements.Current.Claims')
HEADLINES = {
    'Etna.Design.Current.Headlines.fund_safety': 'Etna.Statements.Current.FundSafety',
    'Etna.Design.Current.Headlines.accountable_finality': 'Etna.Statements.Current.AccountableFinality',
    'Etna.Design.Current.Headlines.forced_inclusion_integrity': 'Etna.Statements.Current.ForcedInclusionIntegrity',
}
PREMISES = 'Etna.Statements.Current.Premises'
FUND_PREMISES = 'Etna.Statements.Current.FundPremises'
H1, H2, H3 = HEADLINES
# Premises extends FundPremises: H2 and H3 read H1's five fields through `toFundPremises`,
# and H1's proof alone must read each of the five.
PREMISE_USES = {
    'toFundPremises': [H2,H3],
    'currentStandardToken': [H2],
    'currentSignatureAgreement': [H2],
    'currentBountyBound': [H2],
    'currentCodec': [H2],
    'currentVoteAttribution': [H2],
    'currentClock': [H3],
    'currentCatalogueHash': [H3],
    'currentSignatureSound': [H2],
    'currentSelfAllowance': [H2],
    'currentEvidenceWindow': [H2],
    'currentPrimitives': [H1],
    'currentVerifierSound': [H1],
    'currentReferenceBinding': [H1],
    'currentRegistryGenesis': [H1],
    'currentUnzenExtension': [H1],
}


def contract_fixture():
    """A complete validator input, independently of the root's manifest-writing phase.

    Existing real entries remain untouched. Missing current records are filled only in
    this in-memory fixture so removal tests exercise the validator rather than depend
    on whether integration has already written the reviewed current declarations.
    The full audit separately validates the real manifest without this fixture.
    """
    manifest = deepcopy(json.loads((ROOT / 'manifests/design.json').read_text()))
    names = {entry['declaration'] for entry in manifest['theorems']}
    source = next(entry['sources'] for entry in manifest['theorems'] if entry['sources'])
    for name, claim in (CLAIMS, *HEADLINES.items()):
        if name not in names:
            manifest['theorems'].append({
                'module': 'EtnaProofs.Headline.Current', 'declaration': name, 'type': claim,
                'assumptions': ['explicit current primitive premises'], 'bridge_level': 'spec-proved',
                'role': 'property', 'sources': source[:1], 'scope': 'Current headline validator fixture.',
            })
    return manifest


class CurrentHeadlineTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.scratch = tempfile.TemporaryDirectory(prefix='current-headlines-', dir=ROOT / '.scratch')
        cls.directory = Path(cls.scratch.name)
        cls.library = cls.directory / 'lib'
        cls.library.mkdir()
        result = subprocess.run([
            'lake', 'env', 'lean', '--root=' + str(ROOT / 'scripts'),
            '-o', str(cls.library / 'EtnaAudit.olean'), str(ROOT / 'scripts/EtnaAudit.lean'),
        ], cwd=ROOT, capture_output=True, text=True)
        if result.returncode or (result.stdout + result.stderr).strip():
            raise AssertionError(result.stdout + result.stderr)
        cls.command = AUDIT.lean_env(ROOT, [cls.library])

    @classmethod
    def tearDownClass(cls):
        cls.scratch.cleanup()

    def compile(self, source):
        with tempfile.NamedTemporaryFile(dir=self.directory, suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(self.command + ['lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True)

    def checked(self, body):
        return self.compile('import Lean\nimport EtnaAudit\nimport EtnaProofs.Headline.Current\n'
                            'set_option maxRecDepth 30000\n' + body + '\n')

    def assert_success(self, result, silent=True):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        if silent:
            self.assertEqual(result.stdout + result.stderr, '')

    def test_symbolic_full_conjunction_and_normalized_hash_counterexample(self):
        result = subprocess.run(['lake', 'env', 'lean', 'tests/CurrentHeadlines.lean'], cwd=ROOT,
                                capture_output=True, text=True)
        self.assert_success(result)

    def test_exact_current_types_and_all_primitive_fields_used(self):
        result = self.checked('\n'.join(AUDIT.render_headline_check(CLAIMS, HEADLINES, PREMISES)))
        self.assert_success(result, silent=False)
        uses, rest = AUDIT.premise_uses(result.stdout + result.stderr)
        self.assertEqual(len(uses), 16, 'current headline audit lost a primitive field')
        self.assertEqual(uses, PREMISE_USES)
        self.assertEqual(rest.strip(), '')

    def test_only_cross_round_agreement_has_an_honesty_dependency(self):
        # Traverse definitions and structure constructors, so hiding the assumption
        # behind a renamed shared field also fails this contract.
        body = '''run_elab do
  for claim in [`Etna.Statements.Current.Premises,
      `Etna.Statements.Current.FundSafety,
      `Etna.Statements.Current.ForcedInclusionIntegrity,
      `Etna.Statements.Current.EconomicAccountability,
      `Etna.Design.Current.Economics.Safety,
      `Etna.Design.Current.Economics.HistoricalStakeFunded,
      `Etna.Statements.Current.TemporalAuthority] do
    let reached ← EtnaAudit.dependencies [`Etna] [claim]
    for forbidden in [`Etna.Design.Current.ProtocolFinality.HonestExecutions,
        `Etna.Design.Locking.HonestRules, `Etna.Design.Locking.Minority] do
      if reached.contains forbidden then
        throwError "{claim} must not depend on {forbidden}"
  let h2 ← EtnaAudit.dependencies [`Etna] [`Etna.Statements.Current.AccountableFinality]
  unless h2.contains `Etna.Design.Current.ProtocolFinality.HonestExecutions do
    throwError "cross-round agreement lost its explicit honest-execution condition"
'''
        self.assert_success(self.checked(body))
        # Ensure the dependency probe detects an assumption inserted under a new name.
        mutation = '''def Etna.CurrentHeadlineProbe.HiddenHonesty : Prop :=
  ∀ env registry engine, Etna.Statements.Current.Premises env registry engine →
    ∀ w, Etna.Design.Current.ProtocolFinality.HonestExecutions engine env w
'''
        changed = body.replace('`Etna.Statements.Current.Premises,',
                               '`Etna.CurrentHeadlineProbe.HiddenHonesty,')
        result = self.checked(mutation + changed)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('must not depend on', result.stdout + result.stderr)

    def test_primitive_record_does_not_supply_headline_outcomes(self):
        body = '''run_elab do
  let reached ← EtnaAudit.dependencies [`Etna] [`Etna.Statements.Current.Premises]
  for forbidden in [`Etna.Statements.Current.Claims,
      `Etna.Statements.Current.FundSafety,
      `Etna.Statements.Current.AccountableFinality,
      `Etna.Statements.Current.ForcedInclusionIntegrity,
      `Etna.Design.Current.Protocol.Custody.Coherent,
      `Etna.Design.Current.Economics.Safety,
      `Etna.Design.Current.Economics.HistoricalStakeFunded,
      `Etna.Design.Current.Economics.EconomicallyAccountable,
      `Etna.Design.Current.Economics.FundedFutureLiability,
      `Etna.Design.Current.RegistryPayments.Backed,
      `Etna.Design.Current.ProtocolFinality.CurrentAgreement,
      `Etna.Design.Current.ProtocolFinality.PaidFutureLiability] do
    if reached.contains forbidden then
      throwError "primitive record supplies derived outcome {forbidden}"
'''
        self.assert_success(self.checked(body))
        hidden = '''def Etna.CurrentHeadlineProbe.HiddenBacking : Prop :=
  ∀ env registry engine, Etna.Statements.Current.Premises env registry engine →
    ∀ w, Etna.Design.Current.Protocol.Trace env
      (Etna.Design.Current.Protocol.empty env registry) w →
      Etna.Design.Current.RegistryPayments.Backed env.token w.registry
'''
        changed = body.replace('[`Etna.Statements.Current.Premises]',
                               '[`Etna.CurrentHeadlineProbe.HiddenBacking]')
        result = self.checked(hidden + changed)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('primitive record supplies derived outcome', result.stdout + result.stderr)

    def test_complete_renderer_executes_current_exact_and_premise_checks(self):
        entries = contract_fixture()['theorems']
        rendered = AUDIT.render_audit(entries, complete=True, libraries=[])
        current_checks = [line for line in rendered.splitlines()
                          if ('EtnaAudit.checkHeadline ' in line and CLAIMS[1] in line)
                          or ('EtnaAudit.checkPremiseUse ' in line and (PREMISES in line or FUND_PREMISES in line))]
        self.assertEqual(len(current_checks), 3, 'complete audit omitted current headline checks')
        result = self.checked('\n'.join(current_checks))
        self.assert_success(result, silent=False)
        uses, rest = AUDIT.premise_uses(result.stdout + result.stderr)
        self.assertEqual(uses, PREMISE_USES)
        self.assertEqual(rest.strip(), '')

    def test_removing_any_mandatory_current_manifest_entry_is_rejected(self):
        manifest = contract_fixture()
        AUDIT.validate_contract(manifest)
        for declaration in (CLAIMS[0], *HEADLINES):
            with self.subTest(declaration=declaration):
                changed = deepcopy(manifest)
                changed['theorems'] = [entry for entry in changed['theorems']
                                       if entry['declaration'] != declaration]
                with self.assertRaisesRegex(ValueError, 'missing manifest entry: ' + re.escape(declaration)):
                    AUDIT.validate_contract(changed)

    def test_without_h3_catalogue_hash_and_clock_are_unconsumed(self):
        partial = {name: claim for name, claim in HEADLINES.items() if name != H3}
        body = AUDIT.render_headline_check(CLAIMS, partial, PREMISES)[1]
        result = self.checked(body)
        self.assertNotEqual(result.returncode, 0)
        output = ' '.join((result.stdout + result.stderr).split())
        self.assertIn('read by no headline proof', output)
        self.assertIn('currentClock', output)
        self.assertIn('currentCatalogueHash', output)

    def test_without_h2_token_and_reverse_signature_are_unconsumed(self):
        partial = {name: claim for name, claim in HEADLINES.items() if name != H2}
        body = AUDIT.render_headline_check(CLAIMS, partial, PREMISES)[1]
        result = self.checked(body)
        self.assertNotEqual(result.returncode, 0)
        output = ' '.join((result.stdout + result.stderr).split())
        self.assertIn('read by no headline proof', output)
        for field in ('currentStandardToken', 'currentSignatureSound', 'currentSelfAllowance'):
            self.assertIn(field, output)

    def test_every_fund_premise_is_needed_by_h1_itself(self):
        # H2 reads three of H1's fields through toFundPremises, but only H1 needs the
        # reference binding and the Unzen extension: checking H1's record against H2 fails.
        body = AUDIT.render_headline_check(fund=(FUND_PREMISES, H2))[2]
        result = self.checked(body)
        self.assertNotEqual(result.returncode, 0)
        output = ' '.join((result.stdout + result.stderr).split())
        self.assertIn('premise fields of Etna.Statements.Current.FundPremises read by no headline proof '
                      '(after unused bindings are removed): [currentReferenceBinding, currentUnzenExtension]', output)
        uses, _ = AUDIT.premise_uses(result.stdout + result.stderr)
        self.assertEqual(uses, {field: [H2] for field in
                                ('currentPrimitives', 'currentVerifierSound', 'currentRegistryGenesis')})

    def test_h1_rests_on_no_consensus_premise(self):
        body = '''run_elab do
  let reached ← EtnaAudit.dependencies [`Etna] [`Etna.Statements.Current.FundSafety]
  for forbidden in [`Etna.Statements.Current.Premises,
      `Etna.Design.Current.Finality.SignatureSound,
      `Etna.Design.Current.Finality.SignatureRefinement,
      `Etna.Design.Current.ProtocolFinality.CodecSound,
      `Etna.Design.Current.ProtocolFinality.VoteAttribution,
      `Etna.Design.Current.ProtocolFinality.HonestExecutions,
      `Etna.Design.Locking.HonestRules, `Etna.Design.Locking.Minority] do
    unless (← Lean.getEnv).contains forbidden do
      throwError "unknown probe constant {forbidden}"
    if reached.contains forbidden then
      throwError "H1 must not depend on {forbidden}"
'''
        self.assert_success(self.checked(body))

    def test_cross_record_headline_mapping_is_rejected(self):
        crossed = dict(HEADLINES)
        crossed[H1], crossed[H2] = crossed[H2], crossed[H1]
        check = AUDIT.render_headline_check(CLAIMS, crossed, PREMISES)[0]
        result = self.checked(check)
        self.assertNotEqual(result.returncode, 0)
        output = result.stdout + result.stderr
        self.assertIn('must have exactly type Etna.Statements.Current.AccountableFinality, not', output)

    def test_weakened_current_conjunction_is_not_the_current_claim(self):
        proof = '''namespace Etna.CurrentHeadlineProbe
 theorem weakened : Etna.Statements.Current.FundSafety ∧ Etna.Statements.Current.AccountableFinality :=
   ⟨Etna.Design.Current.Headlines.fund_safety,Etna.Design.Current.Headlines.accountable_finality⟩
 end Etna.CurrentHeadlineProbe
'''
        check = AUDIT.render_headline_check(('Etna.CurrentHeadlineProbe.weakened', CLAIMS[1]), HEADLINES, PREMISES)[0]
        result = self.checked(proof + check)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('must have exactly type Etna.Statements.Current.Claims, not', result.stdout + result.stderr)

    def test_definitionally_equal_restatement_still_fails_exact_type_contract(self):
        proof = '''namespace Etna.CurrentHeadlineProbe
 theorem restated : Etna.Statements.Current.FundSafety ∧ Etna.Statements.Current.AccountableFinality ∧
     Etna.Statements.Current.ForcedInclusionIntegrity := Etna.Design.Current.Headlines.claims
 end Etna.CurrentHeadlineProbe
'''
        check = AUDIT.render_headline_check(('Etna.CurrentHeadlineProbe.restated', CLAIMS[1]), HEADLINES, PREMISES)[0]
        result = self.checked(proof + check)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('must have exactly type Etna.Statements.Current.Claims, not', result.stdout + result.stderr)

    def test_selected_interpreter_needs_catalogue_hash_refinement(self):
        source = (ROOT / 'EtnaProofs/Headline/Current.lean').read_text()
        source = source.replace('Etna.Design.Current.Headlines', 'Etna.Design.Current.HeadlinesMutation')
        self.assert_success(self.compile(source))
        old = '(hashes : CatalogueHash env)'
        self.assertEqual(source.count(old), 1)
        changed = source.replace(old, '(hashes : True)')
        result = self.compile(changed)
        self.assertNotEqual(result.returncode, 0, 'normalization accepted without catalogue hash refinement')
        first = next(line for line in (result.stdout + result.stderr).splitlines() if 'error:' in line)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, first)


if __name__ == '__main__':
    unittest.main()
