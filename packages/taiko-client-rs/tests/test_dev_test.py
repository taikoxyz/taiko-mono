"""Exercise test-dev against real staged, unstaged, untracked and committed changes."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from test_dev import ROOT


class TestDev(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.repo = Path(temporary.name)
        self.client = self.repo / "packages/taiko-client-rs"
        self.write("README.md", "# Test repo")
        self.write("crates/lander/src/lib.rs", "")
        self.write("crates/test-harness/tests/cleanup.rs", '#[ignore = "docker"]\n')
        self.write("tests/test_dev.py", (ROOT / "tests/test_dev.py").read_text())
        shutil.copy(ROOT / "justfile", self.client / "justfile")
        self.git("init", "--quiet")
        self.git("config", "user.name", "Dev test")
        self.git("config", "user.email", "dev@example.invalid")
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "baseline")

    def git(self, *args):
        subprocess.run(["git", *args], cwd=self.repo, check=True, capture_output=True)

    def write(self, path, value):
        destination = self.client / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(value)

    def selected_commands(self, *args):
        result = subprocess.run(["just", "test-dev", "--dry-run", *args], cwd=self.client,
                                check=True, text=True, capture_output=True)
        return [row[2:] for row in result.stdout.splitlines() if row.startswith("+ ")]

    def test_lander_changes_target_native_and_restart_tests(self):
        self.write("crates/lander/src/lib.rs", "// staged change\n")
        self.git("add", "packages/taiko-client-rs/crates/lander/src/lib.rs")
        self.write("crates/lander/src/new file.rs", "// untracked change\n")
        self.assertEqual(self.selected_commands(), [
            "cargo test -p lander --all-features --lib",
            "just test --test lander_cli lander_cli_recovers_from_sigkill_and_resumes_after_sigterm",
        ])

    def test_explicit_base_includes_commits_and_current_edits(self):
        self.write("crates/test-harness/tests/cleanup.rs", '#[ignore = "docker"]\n// committed\n')
        self.git("commit", "--quiet", "-am", "change cleanup")
        self.write("crates/driver/src/lib.rs", "// worktree\n")
        self.assertEqual(self.selected_commands("HEAD^"), [
            "cargo test -p driver --all-features --lib",
            "cargo test -p test-harness --all-features --test cleanup",
            "just test-full --test cleanup",
        ])

    def test_shared_harness_changes_fall_back_to_unit_and_smoke(self):
        self.write("crates/test-harness/src/boot.rs", "// fixture change\n")
        self.assertEqual(self.selected_commands(), ["just unit", "just test-smoke"])

    def test_unrelated_monorepo_changes_use_clean_worktree_plan(self):
        (self.repo / "unrelated.txt").touch()
        self.assertEqual(self.selected_commands(), ["just test-smoke"])


if __name__ == "__main__":
    unittest.main()
