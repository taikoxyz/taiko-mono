"""Regressions for the exact first hosted-run tool identity/parser failures."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
SCRIPT=ROOT.parents[1]/'packages/taiko-client-rs/script'
spec=importlib.util.spec_from_file_location('foundry_identity',SCRIPT/'foundry_identity.py')
foundry=importlib.util.module_from_spec(spec)
spec.loader.exec_module(foundry)
LINUX='a39fc1913b53dde6a35b603756f65d799e13817ef694107ec0d3704c20435cce'
MACOS='f5457831a5740157932b8324cb8fd05390941ad23ef0db092acd074f1753bd07'


def version(label):
    return '\n'.join([label,'Commit SHA: '+foundry.REVISION,
                      'Build Timestamp: 2025-12-19T14:07:55.455914129Z (1766153275)',
                      'Build Profile: maxperf'])


class HostedFoundryTests(unittest.TestCase):
    def test_authenticated_aliases_preserve_exact_committed_manifest_identity(self):
        expected=json.loads((ROOT.parents[1]/'packages/taiko-client-rs/crates/lander/tests/fixtures/contracts/manifest.json').read_text())['foundryVersion']
        for digest,label in [(LINUX,'forge Version: 1.5.1-v1.5.1'),(MACOS,'forge Version: 1.5.1-stable')]:
            receipt=foundry.identity(version(label),digest)
            self.assertEqual(receipt['canonical'],expected)
            self.assertEqual(receipt['observed'][0],label)
            self.assertEqual(receipt['binary_sha256'],digest)

    def test_matching_version_and_revision_do_not_authorize_unknown_binary(self):
        with self.assertRaisesRegex(ValueError,'unreviewed Forge binary'):
            foundry.identity(version('forge Version: 1.5.1-v1.5.1'),'0'*64)

    def test_mismatched_source_version_profile_and_incomplete_identity_fail(self):
        good=version('forge Version: 1.5.1-v1.5.1')
        for bad in [good.replace(foundry.REVISION,'0'*40),good.replace('1.5.1-v1.5.1','1.5.2-v1.5.2'),
                    good.replace('maxperf','debug'),good.replace('1.5.1-v1.5.1','1.5.1-nightly'),
                    good.replace('1.5.1-v1.5.1','1.5.1-stable'),good.splitlines()[0],
                    good+'\nCommit SHA: '+foundry.REVISION]:
            with self.subTest(bad=bad),self.assertRaises(ValueError):foundry.identity(bad,LINUX)

    def test_unknown_executable_is_rejected_before_execution(self):
        with tempfile.TemporaryDirectory() as directory:
            executable=Path(directory)/'forge';executable.write_text('not an approved binary')
            with patch.object(foundry.subprocess,'check_output') as execute:
                with self.assertRaisesRegex(ValueError,'unreviewed Forge binary'):
                    foundry.checked_identity(executable)
                execute.assert_not_called()

    def test_checker_and_generator_both_use_authenticated_identity(self):
        checker=(SCRIPT/'check_lander_artifacts.sh').read_text()
        generator=(SCRIPT/'gen_lander_artifacts.sh').read_text()
        self.assertIn('python3 "$SCRIPT_DIR/foundry_identity.py" --manifest "$MANIFEST"',checker)
        self.assertIn('"foundryVersion": checked_identity()["canonical"]',generator)
        self.assertLess(generator.index('python3 "$SCRIPT_DIR/foundry_identity.py"'),generator.index('forge build'))
        self.assertNotIn('forge --version | head -n 1',checker)


class HostedOpamTests(unittest.TestCase):
    def test_all_operations_use_subcommand_first_and_the_verified_executable(self):
        bootstrap=(ROOT/'scripts/bootstrap_ci.sh').read_text()
        self.assertIn('"$etna_tools/bin/opam" init --root=',bootstrap)
        self.assertIn('"$etna_tools/bin/opam" switch import --root=',bootstrap)
        self.assertIn('"$etna_tools/bin/opam" exec --root=',bootstrap)
        self.assertNotIn('opam --root=',bootstrap)


if __name__=='__main__':unittest.main()
