"""Regressions for the exact first hosted-run tool identity/parser failures."""
import json
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
SCRIPT=ROOT.parents[1]/'packages/taiko-client-rs/script'


class HostedFoundryTests(unittest.TestCase):
    """The pinned release archive checksum authenticates the binary; fixtures pin its commit only."""
    def test_fixture_identity_is_the_commit_line_shared_by_both_release_labels(self):
        expected=json.loads((ROOT.parents[1]/'packages/taiko-client-rs/crates/lander/tests/fixtures/contracts/manifest.json').read_text())['foundryVersion']
        self.assertEqual(len(expected),1)
        self.assertTrue(expected[0].startswith('Commit SHA: '))

    def test_checker_and_generator_compare_only_the_commit(self):
        checker=(SCRIPT/'check_lander_artifacts.sh').read_text()
        generator=(SCRIPT/'gen_lander_artifacts.sh').read_text()
        self.assertIn("grep '^Commit SHA:'",checker)
        self.assertIn('if line.startswith("Commit SHA:")',generator)
        self.assertNotIn('forge --version | head -n 1',checker)

    def test_ci_downloads_the_checksummed_release_archive(self):
        bootstrap=(ROOT/'scripts/bootstrap_ci.sh').read_text()
        self.assertIn('checksum 73640b01bd9ed29fdb4965085099371f8cf0dbbec3e2086cf54564efc4dcfe88',bootstrap)


class HostedOpamTests(unittest.TestCase):
    def test_all_operations_use_subcommand_first_and_the_verified_executable(self):
        bootstrap=(ROOT/'scripts/bootstrap_ci.sh').read_text()
        self.assertIn('"$etna_tools/bin/opam" init --root=',bootstrap)
        self.assertIn('"$etna_tools/bin/opam" switch import --root=',bootstrap)
        self.assertIn('"$etna_tools/bin/opam" exec --root=',bootstrap)
        self.assertNotIn('opam --root=',bootstrap)


if __name__=='__main__':unittest.main()
