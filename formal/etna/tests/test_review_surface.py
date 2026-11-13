"""The statement-lock judge reads a pull request head as git data and measures it from the
merge base, so changes that landed on the base branch meanwhile are not attributed to it."""
from pathlib import Path
import importlib.util
import json
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
_spec = importlib.util.spec_from_file_location('review_surface_judge', ROOT/'scripts/review_surface.py')
JUDGE = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(JUDGE)


class ReviewSurfaceJudgeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self.tmp.name)
        self.git('init', '-q', '-b', 'main')
        self.git('config', 'user.email', 'judge@example.invalid')
        self.git('config', 'user.name', 'judge')
        self.git('config', 'commit.gpgsign', 'false')
        self.write('README', 'base\n')
        self.base = self.commit('base without a lock')

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, *args):
        result = subprocess.run(['git', '-C', str(self.repo), *args], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def write(self, path, text):
        target = self.repo/path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)

    def lock(self, constants):
        self.write(JUDGE.LOCK_PATH, json.dumps({'toolchain': 't', 'roots': ['r'], 'constants': constants}))

    def commit(self, message):
        self.git('add', '-A')
        self.git('commit', '-q', '-m', message)
        return self.git('rev-parse', 'HEAD')

    def test_bootstrap_when_the_base_has_no_lock(self):
        self.git('checkout', '-q', '-b', 'pr')
        self.lock({'A': 'def:1'})
        head = self.commit('introduce the lock')
        status, text = JUDGE.against('main', self.repo, head)
        self.assertEqual(status, 0)
        self.assertIn('bootstrap', text)

    def test_head_is_measured_from_the_merge_base(self):
        self.lock({'A': 'def:1'})
        self.commit('lock on main')
        self.git('checkout', '-q', '-b', 'pr')
        self.lock({'A': 'def:2'})
        self.write('formal/etna/scripts/gate.py', 'changed\n')
        head = self.commit('pull request change')
        self.git('checkout', '-q', 'main')
        self.lock({'A': 'def:1', 'B': 'def:9'})
        self.write('formal/etna/scripts/other.py', 'main moved\n')
        self.commit('main moves on')
        # The judge runs from a checkout that is neither side.
        self.git('checkout', '-q', '--detach', self.base)
        status, text = JUDGE.against('main', self.repo, head)
        self.assertEqual(status, 3)
        self.assertIn('changed `A`', text)
        self.assertNotIn('`B`', text)
        self.assertIn('formal/etna/scripts/gate.py', text)
        self.assertNotIn('other.py', text)

    def test_unchanged_surface_and_gates_pass(self):
        self.lock({'A': 'def:1'})
        self.commit('lock on main')
        self.git('checkout', '-q', '-b', 'pr')
        self.write('formal/etna/README.md', 'docs only\n')
        head = self.commit('docs only')
        status, _ = JUDGE.against('main', self.repo, head)
        self.assertEqual(status, 0)

    def test_formal_workflows_and_allowlist_are_gates(self):
        self.lock({'A': 'def:1'})
        self.commit('lock on main')
        self.git('checkout', '-q', '-b', 'pr')
        self.write('.github/workflows/formal--etna-full.yml', 'changed\n')
        self.write('formal/etna/manifests/shadowing-allowlist.json', '{}\n')
        # Evidence inputs: the theorem manifest, both coverage maps and a Lean regression fixture.
        for path in ('manifests/design.json', 'spec-coverage.json', 'rule-coverage.json', 'tests/CurrentGuards.lean'):
            self.write('formal/etna/'+path, 'weakened\n')
        head = self.commit('weaken a gate')
        status, text = JUDGE.against('main', self.repo, head)
        self.assertEqual(status, 3)
        self.assertIn('formal--etna-full.yml', text)
        self.assertIn('shadowing-allowlist.json', text)
        for path in ('manifests/design.json', 'spec-coverage.json', 'rule-coverage.json', 'tests/CurrentGuards.lean'):
            self.assertIn('formal/etna/'+path, text)


if __name__ == '__main__':
    unittest.main()
