import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
import ci_gate
import check_provenance
import prepare_pair
from check_coverage import semantic_layout
from landing_mutant_specs import MUTANTS, expected_bytes, semantic_kill

from run_conformance import seeded_rows
import test_landing_conformance as fixture
landing=fixture.landing


class TriggerAndGateTests(unittest.TestCase):
    def test_six_required_simulations(self):
        # Draft uses precisely the same path predicate and strict result checks.
        cases=[('proof',['formal/etna/Etna/FI/Proofs.lean'],True),
               ('wrapper',['packages/taiko-client-rs/crates/abci/src/app/finalize.rs'],True),
               ('fixture-tool-workflow',['testdata/etna_vectors/input.json','formal/etna/tools.lock.json','.github/workflows/etna--formal.yml'],True),
               ('unrelated',['packages/bridge-ui/README.md'],False),
               ('draft',['formal/etna/Etna/Landing/Proofs.lean'],True)]
        for name,paths,needed in cases:
            with self.subTest(name=name):
                self.assertEqual(ci_gate.relevant(paths),needed)
                results={'changes':'success',**{k:'success' for k in ci_gate.REQUIRED}}
                self.assertEqual(ci_gate.aggregate(needed,results),'passed' if needed else 'not-applicable')
                for outcome in ['failure','skipped','cancelled','timed_out',None]:
                    results['conformance']=outcome
                    if needed:
                        with self.assertRaises(ValueError): ci_gate.aggregate(needed,results)
        pins={'upstream_client':prepare_pair.CLIENT,'paired_protocol':prepare_pair.PROTOCOL}
        for name in pins:
            with self.subTest(race=name),self.assertRaises(ValueError):
                prepare_pair.validate_heads(pins | {name:'a'*40})

    def test_failed_detection_cannot_skip_gate(self):
        with self.assertRaises(ValueError): ci_gate.aggregate(False,{'changes':'failure'})

    def test_proof_policy_and_statements_require_review(self):
        for path in ['formal/etna/manifests/fi.json','formal/etna/schemas/coverage-policy.json',
                     'formal/etna/scripts/check_coverage.py','formal/etna/Etna/FI/Proofs.lean',
                     'packages/taiko-client-rs/script/foundry_identity.py',
                     'packages/taiko-client-rs/script/gen_lander_artifacts.sh',
                     'packages/taiko-client-rs/script/check_lander_artifacts.sh']:
            self.assertTrue(ci_gate.proof_change([path]))

    def test_proof_review_requires_exact_head_explicit_writer_approval(self):
        event={'pull_request':{'number':123,'user':{'login':'author'}}}
        revision='a'*40
        review={'user':{'login':'reviewer'},'state':'APPROVED','commit_id':revision,
                'body':'Etna proof contract reviewed'}
        def check(row, permission='write'):
            with patch.object(ci_gate,'run',side_effect=[json.dumps([[row]]),json.dumps({'permission':permission})]):
                return ci_gate.proof_review(event,revision)
        self.assertEqual(check(review),'reviewer')
        for change in [{'commit_id':'b'*40},{'body':'updated hashes'}, {'state':'DISMISSED'},
                       {'user':{'login':'author'}}]:
            with self.assertRaises(ValueError): check(review|change)
        with self.assertRaises(ValueError): check(review,'read')

    def test_rerun_receipts_select_latest_existing_attempt_in_same_run(self):
        artifacts=[{'name':'etna-coverage-42-1','id':1,'expired':False},
                   {'name':'etna-coverage-42-2','id':2,'expired':False},
                   {'name':'etna-coverage-41-9','id':9,'expired':False}]
        self.assertEqual(ci_gate.select_artifact(artifacts,'coverage','42',3),2)
        self.assertEqual(ci_gate.select_artifact(artifacts,'coverage','42',1),1)
        with self.assertRaises(ValueError): ci_gate.select_artifact(artifacts,'conformance','42',3)

    def test_release_pending_wrong_sha_and_artifacts_fail(self):
        report={'verification_sha':'a'*40,'status':'passed','artifacts':{'runtime':'digest'},
                'protocol_ownership':{'mode':'adopted'},'release_obligations':{x:'pending' for x in ['GUEST-SOUNDNESS','TIME-RULE-REFINEMENT','SOLIDITY-BYTECODE-REFINEMENT']}}
        for revision,artifacts in [('a'*40,report['artifacts']),('b'*40,report['artifacts']),('a'*40,{})]:
            with self.assertRaises(ValueError): ci_gate.release_allowed(report,revision,artifacts)
        with self.assertRaisesRegex(ValueError,'remain pending'):
            ci_gate.release_allowed(report,'a'*40,report['artifacts'])
        completed=copy.deepcopy(report)
        completed['release_obligations']={key:'implementation-proved' for key in report['release_obligations']}
        completed['protocol_ownership']['mode']='premerge'
        with self.assertRaisesRegex(ValueError,'event protocol ownership'):
            ci_gate.release_allowed(completed,'a'*40,report['artifacts'])
        completed['protocol_ownership']['mode']='adopted'
        ci_gate.release_allowed(completed,'a'*40,report['artifacts'])

    def test_ownership_collision_is_never_overwritten(self):
        self.assertEqual(prepare_pair.merge_ownership({'shared':'x'},{'shared':'x','protocol':'y'}),{'shared':'x','protocol':'y'})
        with self.assertRaises(ValueError): prepare_pair.merge_ownership({'shared':'x'},{'shared':'y'})

    def test_complete_output_set_and_exact_bytes(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp); a=root/'a'; b=root/'b'; a.mkdir(); b.mkdir()
            for name in check_provenance.EXPECTED: (a/name).write_text(name); (b/name).write_text(name)
            check_provenance.compare(a,b)
            (a/'extra.lean').write_text('stale')
            with self.assertRaises(ValueError): check_provenance.compare(a,b)
            (a/'extra.lean').unlink(); (a/'provenance.json').write_text('different')
            with self.assertRaises(ValueError): check_provenance.compare(a,b)
            (a/'EtnaConsensusCore.lean').unlink()
            with self.assertRaises(ValueError): check_provenance.compare(a,b)

    def test_seeded_inputs_are_fresh_and_reproducible(self):
        for domain in ['fi','committee']:
            self.assertEqual(seeded_rows(domain,1),seeded_rows(domain,1))
            self.assertNotEqual(seeded_rows(domain,1),seeded_rows(domain,2))
            self.assertEqual(len(seeded_rows(domain,1)),256)


class LayoutAndMutantTests(unittest.TestCase):
    def test_only_ast_ids_are_ignored(self):
        baseline={'storage':[{'astId':1,'contract':'Inbox','label':'queue','slot':'4','offset':0,'type':'t_struct(Queue)123_storage'}],
                  'types':{'t_struct(Queue)123_storage':{'encoding':'inplace','label':'struct Queue','numberOfBytes':'64',
                  'members':[{'astId':2,'label':'items','slot':'0','offset':0,'type':'t_array(t_uint256)50_storage'}]}}}
        changed=json.loads(json.dumps(baseline).replace('123_storage','987_storage'))
        changed['storage'][0]['astId']=99
        self.assertEqual(semantic_layout(baseline),semantic_layout(changed))
        for key,value in [('slot','5'),('offset',1),('label','changed'),('contract','Other')]:
            bad=copy.deepcopy(changed); bad['storage'][0][key]=value
            self.assertNotEqual(semantic_layout(baseline),semantic_layout(bad))
        bad=json.loads(json.dumps(changed).replace(')50_storage',')49_storage'))
        self.assertNotEqual(semantic_layout(baseline),semantic_layout(bad))
        for field,value in [('encoding','mapping'),('numberOfBytes','32')]:
            bad=copy.deepcopy(changed); bad['types']['t_struct(Queue)987_storage'][field]=value
            self.assertNotEqual(semantic_layout(baseline),semantic_layout(bad))

    def test_actual_foundry_assertion_summary_required(self):
        for name,spec in MUTANTS.items():
            good=spec[4]+' test_land_LeanCorpus()\nSuite result: FAILED. 0 passed; 1 failed; 0 skipped;'
            self.assertTrue(semantic_kill(name,1,good))
            for code,log in [(0,good),(-9,good),(1,'Compiler run failed'),(1,'No tests found'),
                             (1,'Suite result: FAILED'),(1,good+' MemoryOOG')]:
                self.assertFalse(semantic_kill(name,code,log))

    def test_unknown_mutant_and_wrong_baseline_rejected(self):
        with self.assertRaises(ValueError): expected_bytes('unknown',b'anything')
        for name,spec in MUTANTS.items():
            with self.assertRaises(ValueError): expected_bytes(name,spec[1].encode())


class ExpectedMutantAuthenticationTests(unittest.TestCase):
    git=fixture.PinnedInputTests.git
    # Reuse a tiny real Git repository, not a mocked pinned_inputs implementation.
    def setUp(self):
        fixture.PinnedInputTests.setUp(self)
        self.name='recipient-omission'; spec=MUTANTS[self.name]
        self.target=self.protocol/spec[0]; self.target.parent.mkdir(parents=True)
        self.target.write_text(spec[1]+'\n')
        self.git('add','.'); self.git('-c','user.name=Test','-c','user.email=test@example.invalid','commit','-qm','target')
        self.patch.stop(); self.pin=self.git('rev-parse','HEAD').strip()
        self.patch=patch.object(landing,'PIN',self.pin); self.patch.start()
        self.original=self.target.read_bytes(); self.mutated=self.original.replace(spec[1].encode(),spec[2].encode())
        self.specpatch=patch.dict(MUTANTS,{self.name:(spec[0],spec[1],spec[2],hashlib.sha256(self.mutated).hexdigest(),spec[4],spec[5])})
        self.specpatch.start()

    def tearDown(self):
        self.specpatch.stop(); fixture.PinnedInputTests.tearDown(self)

    def test_exact_exception_preserves_all_other_authentication(self):
        self.target.write_bytes(self.mutated)
        landing.pinned_inputs(self.protocol,self.name)
        with landing.staged(self.protocol,[],self.name): pass
        for mutation in ['extra-target','other-source','index']:
            with self.subTest(mutation=mutation):
                self.target.write_bytes(self.mutated)
                other=self.protocol/'contracts/Inbox.sol'; original=other.read_bytes()
                if mutation=='extra-target': self.target.write_bytes(self.mutated+b' ')
                elif mutation=='other-source': other.write_bytes(original+b' ')
                else: self.git('add',str(self.target))
                with self.assertRaises(ValueError): landing.pinned_inputs(self.protocol,self.name)
                self.git('reset','-q','HEAD'); other.write_bytes(original)
        with self.assertRaises(ValueError): landing.pinned_inputs(self.protocol,'unknown')

    def test_canonical_auth_still_rejects_mutant(self):
        self.target.write_bytes(self.mutated)
        with self.assertRaises(ValueError): landing.pinned_inputs(self.protocol)
        with self.assertRaises(ValueError): landing.pinned_inputs(self.protocol,'fee-interval')

if __name__=='__main__': unittest.main()
