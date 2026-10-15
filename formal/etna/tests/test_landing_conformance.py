"""Negative regressions for the actual Landing comparison/staging trust gates."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('landing_conformance', ROOT/'scripts/landing_conformance.py')
landing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(landing)


class ComparisonGateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows = {r['id']:r for r in landing.load(ROOT/'corpus/landing.jsonl')}
        cls.observed = {r['id']:r for r in landing.load(ROOT/'reports/landing-solidity-observations.jsonl')}

    def check(self, ids, lean_ids, mutate=None):
        corpus = [copy.deepcopy(self.rows[i]) for i in ids]
        observed = [copy.deepcopy(self.observed[i]) for i in ids]
        lean = [{k:self.observed[i][k] for k in landing.FIELDS} for i in lean_ids]
        if mutate:
            mutate(corpus, observed, lean)
        with patch.object(landing, 'run', return_value='\n'.join(json.dumps(v) for v in lean)), \
             patch.object(landing, 'keccak', return_value='0x'+'00'*32):
            return landing.compare(corpus, observed)

    def test_complete_clean_output_is_accepted(self):
        self.assertEqual(self.check(['inactive','no-progress'], ['inactive','no-progress'])['failures'], [])

    def test_empty_successful_lean_output_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Lean'):
            self.check(['inactive'], [])

    def test_partial_successful_lean_output_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Lean'):
            self.check(['inactive','no-progress'], ['inactive'])

    def test_duplicate_successful_lean_output_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Lean'):
            self.check(['inactive'], ['inactive','inactive'])

    def test_extra_lean_id_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Lean'):
            self.check(['inactive'], ['inactive','no-progress'])

    def test_empty_corpus_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'corpus'):
            self.check([], [])

    def test_duplicate_corpus_ids_are_rejected(self):
        with self.assertRaisesRegex(ValueError, 'corpus'):
            self.check(['inactive','inactive'], ['inactive','inactive'])

    def test_actual_missing_duplicate_extra_ids_are_rejected(self):
        for changed in [[], ['inactive','inactive'], ['inactive','no-progress']]:
            with self.subTest(changed=changed), self.assertRaisesRegex(ValueError, 'Solidity'):
                self.check(['inactive'], ['inactive'], lambda c,o,l: o.__setitem__(slice(None),
                    [copy.deepcopy(self.observed[i]) for i in changed]))

    def test_unexpected_actual_preimage_cannot_be_ignored(self):
        def mutate(c, o, l):
            o[0].update({k:self.observed['normal'][k]
                         for k in ['actualPreimage','actualDigest','statementWords']})
        result = self.check(['inactive'], ['inactive'], mutate)
        self.assertTrue(any(f['field']=='preimage-presence' for f in result['failures']), result)

    def test_missing_actual_preimage_is_explicitly_rejected(self):
        def mutate(c, o, l):
            l[0]['expectedPreimage'] = self.observed['normal']['actualPreimage']
        result = self.check(['inactive'], ['inactive'], mutate)
        self.assertTrue(any(f['field']=='preimage-presence' for f in result['failures']), result)

    def test_both_sides_cannot_omit_a_reached_preimage(self):
        def mutate(c, o, l):
            for key in ['actualPreimage','actualDigest','statementWords']:
                o[0].pop(key)
        result = self.check(['normal'], ['normal'], mutate)
        self.assertTrue(any(f['field']=='preimage-presence' for f in result['failures']), result)

    def test_incomplete_preimage_group_is_rejected(self):
        def mutate(c, o, l):
            o[0]['actualDigest'] = self.observed['normal']['actualDigest']
        result = self.check(['inactive'], ['inactive'], mutate)
        self.assertTrue(any(f['field']=='preimage-presence' for f in result['failures']), result)


class PinnedInputTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='landing-pinned-inputs-')
        self.repo = Path(self.tmp.name)
        self.protocol = self.repo/'packages/protocol'
        for relative, text in {
            'contracts/Inbox.sol':'contract Inbox {}\n',
            'test/layer1/etna/Base.sol':'contract Base {}\n',
            'script/Deploy.sol':'contract Deploy {}\n',
            'foundry.toml':'[profile.layer1]\nsrc="contracts"\n',
            'CLAUDE.md':'pinned protocol instructions\n',
            '.gitignore':'out/\ncache/\nnode_modules/\n*.ignored.sol\n.env\n',
        }.items():
            p = self.protocol/relative
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(text)
        (self.protocol/'AGENTS.md').symlink_to('CLAUDE.md')
        (self.repo/'package.json').write_text('{}\n')
        (self.repo/'pnpm-lock.yaml').write_text('lockfileVersion: 9\n')
        self.git('init','-q')
        self.git('add','.')
        self.git('-c','user.name=Test','-c','user.email=test@example.invalid','commit','-qm','pin')
        self.pin = self.git('rev-parse','HEAD').strip()
        self.patch = patch.object(landing, 'PIN', self.pin)
        self.patch.start()

    def tearDown(self):
        self.patch.stop()
        self.tmp.cleanup()

    def git(self, *args):
        return subprocess.check_output(['git',*args],cwd=self.repo,text=True)

    def stage(self):
        with landing.staged(self.protocol, []):
            self.assertTrue((self.protocol/'test/layer1/etna/EtnaInboxLeanConformance.t.sol').exists())

    def test_clean_pin_with_ignored_caches_is_accepted_and_owned_files_restored(self):
        for relative in ['out/Generated.sol','cache/old.json','node_modules/library/index.sol']:
            p=self.protocol/relative
            p.parent.mkdir(parents=True,exist_ok=True)
            p.write_text('cache or installed dependency\n')
        target=self.protocol/'test/layer1/etna/EtnaInboxLeanConformance.t.sol'
        target.write_text('preexisting owned staging bytes\n')
        self.stage()
        self.assertEqual(target.read_text(),'preexisting owned staging bytes\n')
        self.assertFalse((self.protocol/'test/layer1/etna/landing-corpus.json').exists())

    def test_dirty_tracked_production_is_rejected_before_staging(self):
        (self.protocol/'contracts/Inbox.sol').write_text('contract Changed {}\n')
        with self.assertRaisesRegex(ValueError,'pinned'):
            self.stage()
        self.assertFalse((self.protocol/'test/layer1/etna/EtnaInboxLeanConformance.t.sol').exists())

    def test_dirty_index_even_with_original_worktree_is_rejected(self):
        p=self.protocol/'contracts/Inbox.sol'
        p.write_text('contract Staged {}\n')
        self.git('add',str(p.relative_to(self.repo)))
        p.write_text('contract Inbox {}\n')
        with self.assertRaisesRegex(ValueError,'pinned'):
            self.stage()

    def test_dirty_foundry_config_is_rejected(self):
        (self.protocol/'foundry.toml').write_text('[profile.layer1]\nvia_ir=true\n')
        with self.assertRaisesRegex(ValueError,'pinned'):
            self.stage()

    def test_dirty_test_helper_and_root_lockfile_are_rejected(self):
        for path in [self.protocol/'test/layer1/etna/Base.sol', self.repo/'pnpm-lock.yaml']:
            original=path.read_bytes()
            with self.subTest(path=path):
                path.write_text('changed\n')
                with self.assertRaisesRegex(ValueError,'pinned'):
                    self.stage()
                path.write_bytes(original)

    def test_unexpected_sources_and_config_are_rejected_including_ignored(self):
        for relative in ['contracts/Extra.sol','test/layer1/etna/Extra.sol',
                         'contracts/Extra.ignored.sol','remappings.txt','.env']:
            path=self.protocol/relative
            with self.subTest(relative=relative):
                path.write_text('unexpected compilation input\n')
                with self.assertRaisesRegex(ValueError,'unexpected'):
                    self.stage()
                self.assertTrue(path.exists(), 'preflight must never delete user files')
                path.unlink()

    def test_compiler_environment_override_is_rejected(self):
        with patch.dict('os.environ', {'FOUNDRY_CONFIG':'/tmp/other-foundry.toml'}):
            with self.assertRaisesRegex(ValueError,'unexpected compilation environment'):
                self.stage()

    def test_tracked_file_symlink_replacement_is_rejected(self):
        path=self.protocol/'contracts/Inbox.sol'
        original=path.read_bytes()
        external=self.repo/'External.sol'
        external.write_bytes(original)
        path.unlink()
        path.symlink_to(external)
        with self.assertRaisesRegex(ValueError,'pinned'):
            self.stage()

    def test_pinned_alias_link_text_change_is_rejected(self):
        path=self.protocol/'AGENTS.md'
        path.unlink()
        path.symlink_to('contracts/Inbox.sol')
        with self.assertRaisesRegex(ValueError,'pinned'):
            self.stage()

    def test_pinned_alias_target_change_is_rejected(self):
        (self.protocol/'CLAUDE.md').write_text('changed target\n')
        with self.assertRaisesRegex(ValueError,'pinned'):
            self.stage()

    def test_owned_staging_symlink_is_rejected_without_touching_target(self):
        external=self.repo/'user-file.sol'
        external.write_text('user-owned bytes\n')
        target=self.protocol/'test/layer1/etna/EtnaInboxLeanConformance.t.sol'
        target.symlink_to(external)
        with self.assertRaisesRegex(ValueError,'unexpected owned staging symlink'):
            self.stage()
        self.assertEqual(external.read_text(),'user-owned bytes\n')

    def test_other_package_overlay_does_not_change_protocol_pin(self):
        path=self.repo/'packages/taiko-client-rs/Cargo.toml'
        path.parent.mkdir(parents=True)
        path.write_text('[package]\nname="overlay"\n')
        self.stage()


if __name__=='__main__':
    unittest.main()
