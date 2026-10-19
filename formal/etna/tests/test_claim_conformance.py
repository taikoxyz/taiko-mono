"""Negative regressions for the actual L2FeeVault claim comparison/staging trust gates."""
import copy
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'scripts'))
sys.path.insert(0, str(ROOT/'tests'))
import claim_conformance as claim
import claim_mutant_specs
import landing_mutant_specs
import test_landing_conformance as fixture
landing = claim.landing_conformance


def fake_keccak(hex_bytes):
    """Deterministic stand-in for the cast oracle: distinct preimages give distinct words."""
    return '0x'+hashlib.sha256(bytes.fromhex(hex_bytes.removeprefix('0x'))).hexdigest()


class ClaimGateBase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.corpus = claim.load(ROOT/'corpus/claim.jsonl')
        cls.rows = {r['id']:r for r in cls.corpus}
        cls.observed = {r['id']:r for r in claim.load(ROOT/'reports/claim-solidity-observations.jsonl')}

    def triple(self, case):
        """One self-consistent corpus/actual/Lean triple under the fake oracle."""
        row = copy.deepcopy(self.rows[case])
        obs = copy.deepcopy(self.observed[case])
        batch = '0x'+claim.batch_preimage(row['receipt'])
        batch_id = fake_keccak(batch)
        obs['batchId'] = batch_id
        if obs['status'] == 'ok':
            obs['eventBatchId'] = batch_id
        lean = {k:obs[k] for k in claim.FIELDS} | {
            'expectedBatchPreimage':batch,
            'expectedCommitmentPreimage':'0x'+claim.commitment_preimage(batch_id, row['receipt'])}
        return row, obs, lean

    def check(self, cases, lean_cases=None, mutate=None):
        triples = [self.triple(c) for c in cases]
        corpus, observed = [t[0] for t in triples], [t[1] for t in triples]
        lean = [self.triple(c)[2] for c in (cases if lean_cases is None else lean_cases)]
        if mutate:
            mutate(corpus, observed, lean)
        claim.keccak.cache_clear()
        with patch.object(claim, 'run', return_value='\n'.join(json.dumps(v) for v in lean)), \
             patch.object(landing, 'keccak', side_effect=fake_keccak):
            try:
                return claim.compare(corpus, observed)
            finally:
                claim.keccak.cache_clear()

    def fields(self, case, mutate):
        return {f['field'] for f in self.check([case], mutate=mutate)['failures']}


class ComparisonGateTests(ClaimGateBase):
    def test_complete_clean_output_is_accepted(self):
        cases = ['valid','replay','root-zero','reentrant-cross','zero-amount-rejecting','underfunded']
        result = self.check(cases)
        self.assertEqual((result['cases'], result['failures']), (len(cases), []))

    def test_committed_observations_cover_every_corpus_row(self):
        self.assertEqual(set(self.observed), set(self.rows))
        self.assertEqual(len(self.rows), 41)

    def test_empty_partial_duplicate_extra_lean_output_is_rejected(self):
        for lean in [[], ['valid'], ['valid','valid','replay'], ['valid','replay','root-zero']]:
            with self.subTest(lean=lean), self.assertRaisesRegex(ValueError, 'Lean'):
                self.check(['valid','replay'], lean)

    def test_missing_duplicate_extra_actual_ids_are_rejected(self):
        for changed in [[], ['valid','valid'], ['valid','replay']]:
            def mutate(c, o, l, changed=changed):
                o[:] = [self.triple(i)[1] for i in changed]
            with self.subTest(changed=changed), self.assertRaisesRegex(ValueError, 'Solidity'):
                self.check(['valid'], mutate=mutate)

    def test_empty_and_duplicate_corpus_are_rejected(self):
        with self.assertRaisesRegex(ValueError, 'corpus'):
            self.check([], [])
        with self.assertRaisesRegex(ValueError, 'corpus'):
            self.check(['valid','valid'])

    def test_every_compared_field_mismatch_is_reported(self):
        for field in claim.FIELDS[2:]:
            def mutate(c, o, l, field=field):
                value = o[0][field]
                o[0][field] = (not value if isinstance(value, bool) else value+1 if isinstance(value, int)
                               else '0x'+'77'*(len(value)//2-1) if value.startswith('0x') else value+'-changed')
            with self.subTest(field=field):
                self.assertIn(field, self.fields('reentrant-cross', mutate))

    def test_missing_actual_field_is_reported(self):
        self.assertIn('nestedResult', self.fields('valid', lambda c, o, l: o[0].pop('nestedResult')))

    def test_lean_preimages_must_match_the_independent_encoding(self):
        def batch(c, o, l):
            p = l[0]['expectedBatchPreimage']
            l[0]['expectedBatchPreimage'] = p[:2+5*64]+claim.word(1)+p[2+6*64:]
        def commitment(c, o, l):
            p = l[0]['expectedCommitmentPreimage']
            l[0]['expectedCommitmentPreimage'] = p[:2+3*64]+claim.word(1)+p[2+4*64:]
        def missing(c, o, l):
            l[0].pop('expectedCommitmentPreimage')
        self.assertIn('batchPreimage', self.fields('valid', batch))
        self.assertIn('commitmentPreimage', self.fields('zero-amount', commitment))
        self.assertIn('commitmentPreimage', self.fields('valid', missing))

    def test_lean_and_actual_batch_ids_must_be_the_independent_digest(self):
        def same_wrong(c, o, l):
            o[0]['batchId'] = l[0]['batchId'] = '0x'+'11'*32
        self.assertIn('independentBatchId', self.fields('replay', same_wrong))

    def test_oracle_covers_ledger_prior_and_reentry_receipts(self):
        with patch.object(landing, 'keccak', side_effect=fake_keccak):
            claim.keccak.cache_clear()
            try:
                # One batch and one commitment preimage per distinct receipt; amount and
                # recipient are outside the batch id, so such forgeries share its preimage.
                self.assertEqual(len(claim.oracle(self.rows['valid'])), 2)
                self.assertEqual(len(claim.oracle(self.rows['forged-amount'])), 3)
                self.assertEqual(len(claim.oracle(self.rows['replay-other-commitment'])), 3)
                self.assertEqual(len(claim.oracle(self.rows['forged-generation'])), 4)
                self.assertEqual(len(claim.oracle(self.rows['reentrant-cross'])), 4)
            finally:
                claim.keccak.cache_clear()

    def test_corpus_covers_each_required_outcome(self):
        errors = {r['error'] for r in self.observed.values()}
        self.assertEqual(errors, {'none','reentrant','invalid-receipt','empty-account-proof','already-claimed',
                                  'invalid-anchor-root','proof','transfer'})
        self.assertEqual({r['nestedResult'] for r in self.observed.values()}, {'none','reentrant'})


class SchemaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows = {r['id']:r for r in claim.load(ROOT/'corpus/claim.jsonl')}

    def reject(self, case, mutate, message):
        row = copy.deepcopy(self.rows[case])
        mutate(row)
        with self.assertRaisesRegex(ValueError, message):
            claim.validate([row])

    def test_committed_corpus_is_valid(self):
        claim.validate(list(self.rows.values()))

    def test_missing_extra_and_nested_schema_keys_are_rejected(self):
        self.reject('valid', lambda r: r.pop('root'), 'row schema')
        self.reject('valid', lambda r: r.update(expected='none'), 'row schema')
        self.reject('valid', lambda r: r['vault'].pop('entered'), 'vault schema')
        self.reject('valid', lambda r: r['receipt'].update(extra=1), 'receipt schema')
        self.reject('valid', lambda r: r['ledger'].pop('mappingSlot'), 'ledger schema')
        self.reject('replay', lambda r: r['prior'].pop('anchorTimestamp'), 'prior schema')

    def test_out_of_range_and_malformed_values_are_rejected(self):
        self.reject('valid', lambda r: r['receipt'].update(lastHeight=2**64), 'uint64')
        self.reject('valid', lambda r: r['receipt'].update(baseFeeAmount=str(2**256)), 'uint256')
        self.reject('valid', lambda r: r['receipt'].update(baseFeeAmount=3), 'uint256')
        self.reject('valid', lambda r: r['vault'].update(inbox='0x1111'), 'hex')
        self.reject('valid', lambda r: r['vault'].update(l1ChainId='0'), 'nonzero')

    def test_unknown_modes_and_reentry_pairing_are_rejected(self):
        for key in ['accountProof','storageProof','root','recipient']:
            self.reject('valid', lambda r, key=key: r.update({key:'other-mode'}), 'mode')
        self.reject('valid', lambda r: r.update(recipient='reentrant'), 'reentry')
        self.reject('reentrant-cross', lambda r: r.update(recipient='eoa'), 'reentry')

    def test_ring_slot_collisions_and_zero_timestamps_are_rejected(self):
        self.reject('replay', lambda r: r['prior'].update(anchorTimestamp=100+8191), 'ring slot')
        self.reject('reentrant-cross', lambda r: r['reentry'].update(anchorTimestamp=100), 'ring slot')
        self.reject('valid', lambda r: r.update(anchorTimestamp=0), 'timestamp zero')
        # The identical same-receipt re-entry may reuse the observed claim's root.
        claim.validate([self.rows['reentrant-same']])

    def test_caller_and_locked_prior_constraints(self):
        self.reject('valid', lambda r: r.update(caller=r['receipt']['l2RewardRecipient']), 'caller')
        self.reject('replay', lambda r: r['vault'].update(entered=True), 'unlocked')


class ClaimStagingTests(unittest.TestCase):
    git = fixture.PinnedInputTests.git

    def setUp(self):
        # The fixture pins its own module instance; the claim driver imports the shared one.
        fixture.PinnedInputTests.setUp(self)
        self.pinpatch = patch.object(landing, 'PIN', self.pin); self.pinpatch.start()

    def tearDown(self):
        self.pinpatch.stop(); fixture.PinnedInputTests.tearDown(self)

    def test_only_owned_adapter_paths_can_be_staged(self):
        for files in [{}, {'contracts/Inbox.sol':b'x'}, {'test/layer2/core/Other.t.sol':b'x'}]:
            with self.subTest(files=files), self.assertRaisesRegex(ValueError, 'owned adapter'):
                with landing.staged_files(self.protocol, files):
                    pass

    def test_claim_harness_and_corpus_are_staged_and_restored(self):
        seen = {}
        original = subprocess.run
        def forge(cmd, *args, **kwargs):
            # Git authentication still runs for real; only the Foundry invocation is replaced.
            if cmd[0] != 'forge':
                return original(cmd, *args, **kwargs)
            env = kwargs['env']
            seen['corpus'] = json.loads(Path(env['ETNA_CLAIM_CORPUS']).read_text())
            seen['harness'] = (Path(kwargs['cwd'])/claim.HARNESS).read_bytes()
            seen['cmd'], seen['profile'] = cmd, env['FOUNDRY_PROFILE']
            line = 'CLAIM_OBSERVATION '+json.dumps({'id':'x'})
            return subprocess.CompletedProcess(cmd, 0, line+'\n', '')
        output = self.repo/'observations.jsonl'
        with patch.object(subprocess, 'run', side_effect=forge):
            code, _, rows = claim.solidity(self.protocol, [{'id':'x'}], output)
        self.assertEqual((code, rows, seen['corpus'], seen['profile']), (0, [{'id':'x'}], [{'id':'x'}], 'layer2'))
        self.assertEqual(seen['harness'], (ROOT/'adapters/solidity/L2FeeVaultLeanConformance.t.sol').read_bytes())
        self.assertIn('--no-cache', seen['cmd'])
        for relative in [claim.HARNESS, claim.STAGED_CORPUS]:
            self.assertFalse((self.protocol/relative).exists())
        self.assertTrue(output.with_suffix('.log').exists())

    def test_dirty_pin_is_rejected_before_claim_staging(self):
        (self.protocol/'contracts/Inbox.sol').write_text('contract Changed {}\n')
        with self.assertRaisesRegex(ValueError, 'pinned'):
            claim.solidity(self.protocol, [], self.repo/'observations.jsonl')
        self.assertFalse((self.protocol/claim.HARNESS).exists())


class ClaimMutantTests(unittest.TestCase):
    def test_names_are_disjoint_from_landing_mutants(self):
        self.assertFalse(set(claim_mutant_specs.MUTANTS) & set(landing_mutant_specs.MUTANTS))
        self.assertGreaterEqual(len(claim_mutant_specs.MUTANTS), 2)

    def test_unknown_mutant_and_wrong_baseline_rejected(self):
        with self.assertRaises(ValueError): claim_mutant_specs.expected_bytes('unknown', b'anything')
        for name, spec in claim_mutant_specs.MUTANTS.items():
            with self.assertRaises(ValueError): claim_mutant_specs.expected_bytes(name, spec[1].encode())

    def test_assert_kill_requires_the_named_foundry_assertion(self):
        for name, spec in claim_mutant_specs.MUTANTS.items():
            if spec[4] != 'assert':
                continue
            good = spec[5]+'] test_claim_LeanCorpus()\nSuite result: FAILED. 0 passed; 1 failed; 0 skipped;'
            self.assertTrue(claim_mutant_specs.semantic_kill(name, 1, good))
            for code, log in [(0, good), (-9, good), (1, 'Compiler run failed'), (1, 'No tests found'),
                              (1, 'Suite result: FAILED'), (1, good+' MemoryOOG')]:
                self.assertFalse(claim_mutant_specs.semantic_kill(name, code, log))

    def test_lean_kill_requires_a_green_harness_and_the_exact_case_field(self):
        for name, spec in claim_mutant_specs.MUTANTS.items():
            if spec[4] != 'lean':
                continue
            case, field = spec[5].split(':')
            log = 'Suite result: ok. 1 passed; 0 failed; 0 skipped;'
            hit = [{'id':case, 'field':field, 'lean':'a', 'solidity':'b'}]
            self.assertTrue(claim_mutant_specs.semantic_kill(name, 0, log, hit))
            for code, text, failures in [(1, log, hit), (0, log, []), (0, log, None),
                                         (0, log, [{'id':case, 'field':'other'}]),
                                         (0, 'Compiler run failed '+log, hit)]:
                self.assertFalse(claim_mutant_specs.semantic_kill(name, code, text, failures))

    def test_lean_kill_cases_exist_in_the_corpus(self):
        ids = {r['id'] for r in claim.load(ROOT/'corpus/claim.jsonl')}
        fields = set(claim.FIELDS)
        for spec in claim_mutant_specs.MUTANTS.values():
            if spec[4] == 'lean':
                case, field = spec[5].split(':')
                self.assertIn(case, ids); self.assertIn(field, fields)


class ExpectedClaimMutantAuthenticationTests(unittest.TestCase):
    git = fixture.PinnedInputTests.git

    def setUp(self):
        fixture.PinnedInputTests.setUp(self)
        self.name = 'claim-flag-dropped'; spec = claim_mutant_specs.MUTANTS[self.name]
        self.target = self.protocol/spec[0]; self.target.parent.mkdir(parents=True)
        self.target.write_text('contract Vault {\n'+spec[1]+'}\n')
        self.git('add','.'); self.git('-c','user.name=Test','-c','user.email=test@example.invalid','commit','-qm','vault')
        self.patch.stop(); self.pin = self.git('rev-parse','HEAD').strip()
        self.patch = patch.object(landing, 'PIN', self.pin); self.patch.start()
        self.mutated = self.target.read_bytes().replace(spec[1].encode(), spec[2].encode())
        self.specpatch = patch.dict(claim_mutant_specs.MUTANTS, {self.name:
            spec[:3]+(hashlib.sha256(self.mutated).hexdigest(),)+spec[4:]})
        self.specpatch.start()

    def tearDown(self):
        self.specpatch.stop(); fixture.PinnedInputTests.tearDown(self)

    def test_exact_claim_mutant_is_authenticated_and_nothing_else(self):
        self.target.write_bytes(self.mutated)
        landing.pinned_inputs(self.protocol, self.name)
        with self.assertRaises(ValueError): landing.pinned_inputs(self.protocol)
        with self.assertRaises(ValueError): landing.pinned_inputs(self.protocol, 'recipient-omission')
        self.target.write_bytes(self.mutated+b' ')
        with self.assertRaises(ValueError): landing.pinned_inputs(self.protocol, self.name)


@unittest.skipUnless(shutil.which('lake') and shutil.which('cast'), 'requires the pinned Lean toolchain and cast')
class RealLeanReplayTests(unittest.TestCase):
    def test_committed_actual_observations_agree_with_the_real_lean_checker(self):
        corpus = claim.load(ROOT/'corpus/claim.jsonl')
        observed = claim.load(ROOT/'reports/claim-solidity-observations.jsonl')
        result = claim.compare(corpus, observed)
        self.assertEqual((result['cases'], result['failures']), (41, []))


if __name__ == '__main__':
    unittest.main()
