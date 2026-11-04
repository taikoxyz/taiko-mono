"""Real funded history and evidence windows, plus physical immutable-guard mutants."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CurrentEconomicsTests(unittest.TestCase):
    def compile(self, source):
        with tempfile.NamedTemporaryFile(dir=ROOT / '.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True)

    def protocol(self):
        source = (ROOT / 'EtnaModel/CurrentProtocol.lean').read_text()
        return source.replace('Etna.Design.Current.Protocol', 'Etna.Design.Current.ProtocolEconomicsMutation')

    def fixture(self, assertion):
        source = (ROOT / 'tests/CurrentEconomics.lean').read_text()
        source = source[source.index('namespace Etna.EconomicsRegression'):source.index('theorem genesis :')]
        source = re.sub(r'\bProtocol\b', 'ProtocolEconomicsMutation', source)
        source = source.replace(' ProtocolFinality', '')
        return source + '\n' + assertion + '\nend Etna.EconomicsRegression\n'

    def reject(self, old, assertion):
        source = self.protocol()
        self.assertEqual(source.count(old), 1, old)
        fixture = self.fixture(assertion)
        baseline = self.compile(source + '\n' + fixture)
        self.assertEqual(baseline.returncode, 0, baseline.stdout + baseline.stderr)
        self.assertEqual(baseline.stdout + baseline.stderr, '')
        mutated = source.replace(old, '')
        model = self.compile(mutated)
        self.assertEqual(model.returncode, 0, model.stdout + model.stderr)
        result = self.compile(mutated + '\n' + fixture)
        self.assertNotEqual(result.returncode, 0, 'semantic mutant accepted unchanged evidence')
        first = next(line for line in (result.stdout + result.stderr).splitlines() if 'error:' in line)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, first)

    def test_actual_funded_economic_history(self):
        result = subprocess.run(['lake', 'env', 'lean', 'tests/CurrentEconomics.lean'], cwd=ROOT,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def test_immutable_activation_delay_is_checked(self):
        self.reject('w.registry.registry.config.valid w.registry.registry.ledger = true ∧', '''
def invalid := {registry with ledger := {registry.ledger with activationDelay := 0}}
example : (ProtocolEconomicsMutation.execute env
    (ProtocolEconomicsMutation.transact env (ProtocolEconomicsMutation.empty env invalid) (.advance 2))
    (.initializeInbox 1)).isNone = true := by decide +kernel
''')

    def test_token_registry_address_is_bound(self):
        self.reject('env.token.registryAddress = env.core.domain.registry ∧', '''
def aliasEnv := {env with token := RegistryPayments.standardEnvironment 41 90}
example : (ProtocolEconomicsMutation.execute aliasEnv
    (ProtocolEconomicsMutation.transact aliasEnv (ProtocolEconomicsMutation.empty aliasEnv registry) (.advance 2))
    (.initializeInbox 1)).isNone = true := by decide +kernel
''')

    def test_slash_sink_must_be_nonzero(self):
        self.reject('∧\n      env.token.slashSink ≠ 0', '''
def zeroEnv := {env with core := {env.core with slashSink := 0}, token := RegistryPayments.standardEnvironment 40 0}
example : (ProtocolEconomicsMutation.execute zeroEnv
    (ProtocolEconomicsMutation.transact zeroEnv (ProtocolEconomicsMutation.empty zeroEnv registry) (.advance 2))
    (.initializeInbox 1)).isNone = true := by decide +kernel
''')


if __name__ == '__main__':
    unittest.main()
