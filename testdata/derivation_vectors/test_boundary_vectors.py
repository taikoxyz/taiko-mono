"""Independent checks on the shared boundary fixture contract and its authored outcomes."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent


class BoundaryVectors(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.corpus = json.loads((ROOT / 'boundary_cases.json').read_text())
        cls.cases = {case['name']: case for case in cls.corpus['cases']}

    def test_unique_nonempty_cases_and_schema(self):
        self.assertEqual(self.corpus['schema_version'], 1)
        self.assertGreater(len(self.cases), 100)
        self.assertEqual(len(self.cases), len(self.corpus['cases']))
        for case in self.cases.values():
            self.assertEqual(sum(case['expected']['source_block_counts']), len(case['expected']['blocks']))
            self.assertEqual(len(case['expected']['headers']), len(case['expected']['blocks']))
            self.assertEqual(len(case['expected']['extracted_manifests_rlp_hex']), len(case['sources']))

    def test_coverage_manifest_tracks_every_named_boundary(self):
        coverage = json.loads((ROOT / 'boundary_coverage.json').read_text())['categories']
        self.assertEqual(set(coverage), {'extraction', 'header', 'version', 'size', 'offset', 'blob',
                                      'cardinality', 'rlp', 'timestamp', 'anchor', 'fork', 'gas',
                                      'inheritance', 'sequence'})
        listed = []
        for category, names in coverage.items():
            self.assertTrue(names)
            for name in names:
                self.assertEqual(self.cases[name]['category'], category)
            listed.extend(names)
        self.assertEqual(len(listed), len(set(listed)))
        self.assertEqual(set(listed), set(self.cases))

    def test_authored_acceptance_boundaries(self):
        for name, kept in {
            'timestamp_lower_minus_one': False, 'timestamp_lower_exact': True,
            'timestamp_upper_exact': True, 'timestamp_upper_plus_one': False,
            'anchor_lag_lower_minus_one': False, 'anchor_lag_lower_exact': True,
            'gas_lower_minus_one': False, 'gas_lower_exact': True,
            'gas_upper_exact': True, 'gas_upper_plus_one': False,
        }.items():
            block = self.cases[name]['expected']['blocks'][0]
            self.assertEqual(block['coinbase'] == '1111111111111111111111111111111111111111', kept, name)

    def test_cardinality_and_forced_isolation(self):
        for name, count in {'blocks_0': 1, 'blocks_1': 1, 'blocks_767': 767,
                            'blocks_768': 768, 'blocks_769': 1, 'forced_blocks_2': 1}.items():
            self.assertEqual(self.cases[name]['expected']['source_block_counts'], [count], name)
        for name, kept in {'forced_anchor_lag_exact': True, 'forced_anchor_lag_plus_one': False}.items():
            self.assertEqual(self.cases[name]['expected']['blocks'][0]['transactions_rlp_hex'] != 'c0', kept)
        case = self.cases['forced_then_empty_proposer']['expected']
        self.assertNotEqual(case['blocks'][0]['transactions_rlp_hex'], 'c0')
        self.assertEqual(case['blocks'][1]['transactions_rlp_hex'], 'c0')

    def test_fork_and_header_boundaries(self):
        for chain in ['mainnet', 'hoodi']:
            self.assertEqual(len(self.cases[chain + '_unzen_193_shasta_blocks']['expected']['blocks']), 193)
        self.assertEqual(self.cases['proposal_id_uint48_max']['expected']['headers'][0]['extra_data_hex'], '32ffffffffffff')
        self.assertEqual(self.cases['genesis_parent']['expected']['blocks'][0]['gas_limit'], 30000000)
        self.assertEqual(self.cases['non_genesis_parent_same_header_gas']['expected']['blocks'][0]['gas_limit'], 29000000)

    def test_client_only_fork_selection_pairs(self):
        data = json.loads((ROOT / 'fork_selection_cases.json').read_text())
        self.assertEqual(data['schema_version'], 1)
        cases = {case['name']: case for case in data['cases']}
        self.assertEqual(len(cases), 12)
        for chain, fork in [('mainnet', 1786021200), ('hoodi', 1781787600)]:
            before = cases[chain + '_before_193']
            at = cases[chain + '_at_193']
            after = cases[chain + '_after_193']
            self.assertEqual(before['proposal_timestamp'], fork - 1)
            self.assertEqual(at['proposal_timestamp'], fork)
            self.assertEqual(after['proposal_timestamp'], fork + 1)
            self.assertNotEqual(before['expected_manifest_rlp_hex'], at['expected_manifest_rlp_hex'])
            self.assertEqual(at['expected_manifest_rlp_hex'], after['expected_manifest_rlp_hex'])
            self.assertEqual(before['expected_manifest_rlp_hex'], cases[chain + '_at_769']['expected_manifest_rlp_hex'])


if __name__ == '__main__':
    unittest.main()
