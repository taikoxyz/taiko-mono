"""Review regressions using actual Git trees/renames and a cold Lean consumer."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
import ci_gate
import prepare_pair

class WorkflowReceiptTests(unittest.TestCase):
    def test_each_id_receipt_extracts_at_the_consumer_directory(self):
        workflow=(ROOT.parents[1]/'.github/workflows/etna--formal.yml').read_text()
        steps=re.split(r'(?m)^      - ',workflow)
        receipts=[step for step in steps if 'uses: actions/download-artifact@' in step]
        self.assertEqual(len(receipts),4)
        for step in receipts:
            with self.subTest(step=step):
                self.assertIn('artifact-ids:',step)
                self.assertIn('merge-multiple: true',step)

    def test_python_regressions_are_required_after_lean_bootstrap(self):
        workflow=(ROOT.parents[1]/'.github/workflows/etna--formal.yml').read_text()
        jobs=dict(re.findall(r'(?ms)^  ([a-z][a-z-]*):\n(.*?)(?=^  [a-z][a-z-]*:|\Z)',workflow))
        job=jobs['lean-proofs']
        self.assertIn('lean-proofs',ci_gate.REQUIRED)
        self.assertNotIn('continue-on-error:',job)
        steps=re.split(r'(?m)^      - ',job)
        suite=[step for step in steps if 'python3 -m unittest discover -s tests -v' in step]
        self.assertEqual(len(suite),1,'full Python suite must remain in the required Lean job')
        step=suite[0]
        self.assertLess(job.index('bootstrap_ci.sh lean'),job.index(step))
        self.assertLess(job.index('bootstrap_ci.sh cast'),job.index(step))
        bootstrap=(ROOT/'scripts/bootstrap_ci.sh').read_text()
        self.assertIn('if [[ "$mode" == protocol || "$mode" == cast ]]; then',bootstrap)
        self.assertIn('echo "$etna_tools/bin" >> "$GITHUB_PATH"',bootstrap)
        self.assertNotIn('if:',step)
        self.assertIn('shell: bash',step)
        self.assertIn('cd formal/etna',step)
        self.assertIn('set -o pipefail',step)
        self.assertIn('2>&1 | tee "$RUNNER_TEMP/etna-reports/python-regressions.log"',step)
        self.assertNotRegex(step,r'continue-on-error|\|\|\s*true|set \+e|pipefail.*true')
        self.assertIn('${{ runner.temp }}/etna-reports',job)
        self.assertIn('if: always()',job)

    def test_python_regression_failure_retains_log_and_fails_step(self):
        workflow=(ROOT.parents[1]/'.github/workflows/etna--formal.yml').read_text()
        job=workflow.split('  lean-proofs:\n',1)[1].split('  rust-refinement:\n',1)[0]
        step=next(step for step in re.split(r'(?m)^      - ',job)
                  if 'python3 -m unittest discover -s tests -v' in step)
        script=step.split('run: |\n',1)[1]
        script='\n'.join(line.removeprefix('          ') for line in script.splitlines())
        with tempfile.TemporaryDirectory(prefix='etna-regression-step-') as temporary:
            root=Path(temporary); binary=root/'bin'; binary.mkdir()
            fake=binary/'python3'
            fake.write_text('#!/bin/sh\necho regression-failure >&2\nexit 17\n')
            fake.chmod(0o755)
            env=os.environ|{'PATH':str(binary)+os.pathsep+os.environ['PATH'],'RUNNER_TEMP':str(root)}
            result=subprocess.run(['bash','--noprofile','--norc','-e','-o','pipefail','-c',script],
                                  cwd=ROOT.parents[1],env=env,text=True,capture_output=True)
            self.assertEqual(result.returncode,17,result.stdout+result.stderr)
            self.assertEqual((root/'etna-reports/python-regressions.log').read_text(),'regression-failure\n')

    def test_cold_consumers_build_etna_before_direct_lean_run(self):
        script=(ROOT/'scripts/bootstrap_ci.sh').read_text()
        lean_case=script.split('  lean|extract)',1)[1].split('    ;;',1)[0]
        self.assertRegex(lean_case,r'lake exe cache get[\s;]+lake build')
        # A fresh package has no Etna oleans, matching a new conformance runner.
        with tempfile.TemporaryDirectory(prefix='etna-cold-import-') as temporary:
            root=Path(temporary)
            (root/'lean-toolchain').write_bytes((ROOT/'lean-toolchain').read_bytes())
            (root/'lakefile.toml').write_text('name = "cold_etna"\ndefaultTargets = ["Etna"]\n[[lean_lib]]\nname = "Etna"\n')
            (root/'Etna').mkdir()
            (root/'Etna.lean').write_text('import Etna.Model\n')
            (root/'Etna/Model.lean').write_text('namespace Etna\ndef answer : Nat := 42\nend Etna\n')
            (root/'Check.lean').write_text('import Etna.Model\ndef main : IO Unit := IO.println Etna.answer\n')
            command=['lake','env','lean','--run','Check.lean']
            cold=subprocess.run(command,cwd=root,text=True,capture_output=True)
            self.assertNotEqual(cold.returncode,0)
            self.assertIn('unknown module prefix',cold.stdout+cold.stderr)
            subprocess.run(['lake','build'],cwd=root,check=True,capture_output=True)
            warm=subprocess.run(command,cwd=root,text=True,capture_output=True,check=True)
            self.assertEqual(warm.stdout.strip(),'42')

class GitFixture(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='etna-pair-policy-')
        self.root=Path(self.temp.name); self.repo=self.root/'event'; self.repo.mkdir()
        self.git('init','-q')
        self.git('config','user.name','Test'); self.git('config','user.email','test@example.invalid')
        self.write('packages/protocol/contracts/Inbox.sol','contract Inbox { uint old; }\n')
        self.write('packages/protocol/foundry.toml','[profile.layer1]\n')
        self.write('package.json','{}\n')
        self.write('pnpm-lock.yaml','lockfileVersion: 9\n')
        self.write('formal/etna/Etna/FI/Proofs.lean','-- theorem contract\n')
        self.client=self.commit('client baseline')
        self.git('checkout','-qb','protocol')
        self.write('packages/protocol/contracts/Inbox.sol','contract Inbox { uint etna; }\n')
        self.protocol_pin=self.commit('protocol feature')
        self.protocol=self.root/'protocol'
        subprocess.run(['git','clone','-q',str(self.repo),str(self.protocol)],check=True)
        self.git('checkout','-qb','followup',self.client)
        self.patches=[patch.object(prepare_pair,'REPO',self.repo),patch.object(prepare_pair,'CLIENT',self.client),
                      patch.object(prepare_pair,'PROTOCOL',self.protocol_pin)]
        for p in self.patches:p.start()

    def tearDown(self):
        for p in reversed(self.patches):p.stop()
        self.temp.cleanup()

    def git(self,*args):
        return subprocess.check_output(['git',*args],cwd=self.repo,text=True).strip()

    def write(self,name,data):
        path=self.repo/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(data)

    def commit(self,message):
        self.git('add','.');self.git('commit','-qm',message);return self.git('rev-parse','HEAD')

    def snapshot(self,event_name='pull_request',base_ref='feat/taiko-client-rs-abci',base_sha=None):
        event={'pull_request':{'base':{'ref':base_ref,'sha':base_sha or self.client}}} if event_name.startswith('pull_request') else {}
        eventfile=self.root/'event.json';eventfile.write_text(json.dumps(event))
        with patch.dict(os.environ,{'GITHUB_EVENT_NAME':event_name,'GITHUB_EVENT_PATH':str(eventfile),'GITHUB_ACTIONS':'true'}):
            return prepare_pair.snapshot(self.protocol,self.git('rev-parse','HEAD'))

class ProtocolOwnershipTests(GitFixture):
    def test_premerge_unchanged_is_accepted_but_protocol_edits_are_rejected(self):
        self.snapshot()
        for path,data in [('packages/protocol/contracts/Inbox.sol','changed runtime'),
                          ('packages/protocol/foundry.toml','different compiler'),
                          ('pnpm-lock.yaml','different dependencies'),('.npmrc','new resolution'),
                          ('remappings.txt','other/=other/'),('patches/dep.patch','new dependency patch')]:
            with self.subTest(path=path):
                self.git('reset','--hard',self.client)
                self.write(path,data);self.commit('unexpected event P change')
                with self.assertRaisesRegex(ValueError,'protocol ownership'):self.snapshot()

    def test_adopted_modes_do_not_ignore_old_or_divergent_protocol(self):
        for event in ['push','schedule','release','workflow_dispatch']:
            with self.subTest(event=event),self.assertRaisesRegex(ValueError,'protocol ownership'):
                self.snapshot(event)
        with self.assertRaisesRegex(ValueError,'protocol ownership'):
            self.snapshot(base_ref='main')

    def test_squash_equivalent_tree_accepted_but_changed_tree_mode_and_paths_fail(self):
        self.write('packages/protocol/contracts/Inbox.sol','contract Inbox { uint etna; }\n')
        self.write('formal/etna/followup.txt','independent squash contents')
        squash=self.commit('independent squash-equivalent tree')
        self.assertNotEqual(squash,self.protocol_pin)
        self.assertNotEqual(subprocess.run(['git','merge-base','--is-ancestor',self.protocol_pin,squash],cwd=self.repo).returncode,0)
        self.snapshot('push')
        self.snapshot(base_ref='main',base_sha=squash)
        # Adoption is also tree-based when a squash/re-root drops CLIENT ancestry.
        self.git('checkout','-q','--orphan','adopted-root')
        self.git('rm','-qr','--cached','.')
        squash=self.commit('adopted tree without either upstream commit as ancestor')
        self.assertNotEqual(subprocess.run(['git','merge-base','--is-ancestor',self.client,squash],cwd=self.repo).returncode,0)
        self.snapshot('push')
        for change in ['bytes','mode','new-file','delete','root-lock']:
            with self.subTest(change=change):
                self.git('reset','--hard',squash)
                path=self.repo/'packages/protocol/contracts/Inbox.sol'
                if change=='bytes':path.write_text('different')
                elif change=='mode':path.chmod(0o755)
                elif change=='delete':path.unlink()
                elif change=='root-lock':self.write('pnpm-lock.yaml','changed lock')
                else:self.write('packages/protocol/contracts/Extra.sol','unexpected')
                self.commit(change)
                with self.assertRaisesRegex(ValueError,'protocol ownership'):self.snapshot('push')

    def test_unknown_events_and_wrong_premerge_base_fail_closed(self):
        with self.assertRaises(ValueError):self.snapshot('unsupported_event')
        with self.assertRaises(ValueError):self.snapshot('local')
        with self.assertRaisesRegex(ValueError,'protocol ownership'):
            self.snapshot(base_ref='unrelated-branch')
        with self.assertRaisesRegex(ValueError,'protocol ownership'):
            self.snapshot(base_sha=self.protocol_pin)

class RenameTests(GitFixture):
    def test_actual_git_rename_keeps_old_proof_path_relevant_and_reviewed(self):
        (self.repo/'docs').mkdir()
        self.git('mv','formal/etna/Etna/FI/Proofs.lean','docs/moved-proof.lean')
        head=self.commit('move proof outside watched scope')
        event={'pull_request':{'base':{'sha':self.client},'head':{'sha':head}}}
        with patch.object(ci_gate,'run',side_effect=lambda args:self.git(*args[1:])):
            changed=ci_gate.changed(event)
        self.assertIn('formal/etna/Etna/FI/Proofs.lean',changed)
        self.assertTrue(ci_gate.relevant(changed))
        self.assertTrue(ci_gate.proof_change(changed))

if __name__=='__main__':unittest.main()
