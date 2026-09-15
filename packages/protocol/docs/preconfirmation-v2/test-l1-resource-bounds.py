#!/usr/bin/env python3
"""Fork resource regressions; synthetic budgets are not EVM gas certificates."""

import runpy
import importlib.util
import sys
import unittest
from dataclasses import replace
from pathlib import Path


M = runpy.run_path(str(Path(__file__).with_name("commitment-model.py")))
SETTLEMENT_SPEC = importlib.util.spec_from_file_location(
    "settlement_l1_resources", Path(__file__).with_name("settlement-window-model.py"))
S = importlib.util.module_from_spec(SETTLEMENT_SPEC)
sys.modules[SETTLEMENT_SPEC.name] = S
SETTLEMENT_SPEC.loader.exec_module(S)
CAP = 16_777_216
REQUIRED_AT_CAP = CAP * 100 // 130


class L1ResourceBoundsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profile = M["canonical_execution_profile_cross_model_fixture_v2"]()
        cls.settlement_profile = S.canonical_execution_profile_cross_model_fixture_v2()
        cls.authority = M["derive_register_release_authority_v2"](cls.profile, 0)
        cls.activation = cls.authority.migration_activation_profile

    def changed_profile(self, profile=None, **values):
        encoded = bytearray(self.profile if profile is None else profile)
        for index, value in values.items():
            index = int(index.removeprefix("word"))
            encoded[(index + 1) * 32:(index + 2) * 32] = M["u256"](value)
        return bytes(encoded)

    def decode_changed(self, **values):
        encoded = M["canonicalize_execution_profile_authority_graph_v2"](
            self.changed_profile(**values))
        return M["decode_execution_profile_v2"](encoded)

    def test_seventeen_million_stipend_rejects_full_profile(self):
        # The old decoder accepted this after all authority joins were rebuilt.
        with self.assertRaises(AssertionError):
            self.decode_changed(word279=17_000_000)
        with self.assertRaises(AssertionError):
            M["decode_execution_profile_v2"](
                self.changed_profile(word279=17_000_000),
                validate_authority_graph=False)

    def test_ordinary_exact_transaction_bound_and_one_over(self):
        proof_bytes, reserve = 65_536, 500_000
        stipend = REQUIRED_AT_CAP - 21_000 - 16 * proof_bytes - reserve - 10_006
        self.assertEqual(self.decode_changed(word279=stipend)[279], M["u256"](stipend))
        with self.assertRaises(AssertionError):
            self.decode_changed(word279=stipend + 1)

    def test_descriptor_getter_cannot_bypass_resources(self):
        words = list(M["decode_execution_profile_v2"](self.profile))
        words[279] = M["u256"](17_000_000)
        words[273] = M["keccak256"](
            M["SETTLEMENT_VALIDITY_VERIFIER_CONFIG_TYPEHASH"]
            + b"".join(words[274:281]))
        with self.assertRaises(AssertionError):
            M["settlement_validity_verifier_descriptor_hash_v2"](words)
        with self.assertRaises(AssertionError):
            M["encode_settlement_validity_verifier_descriptor_return_v2"](words)

    def test_floor_uses_tokens_and_is_not_added_to_execution(self):
        gas = M["l1_transaction_required_gas"]
        self.assertEqual(gas(1, 1, 0), 21_050)
        self.assertEqual(gas(1, 1, 100_000), 121_020)
        self.assertEqual(gas(0, 500_000, 100_000), 20_021_000)
        # Ordinary intrinsic + execution alone would incorrectly fit.
        M["validate_l1_transaction_gas"](8_121_000, 30_000_000)
        with self.assertRaises(AssertionError):
            M["validate_l1_transaction_gas"](gas(0, 500_000, 100_000), 30_000_000)

    def test_floor_heavy_exact_byte_bound_and_one_over(self):
        maximum_bytes = (REQUIRED_AT_CAP - 21_000) // 40
        gas = M["l1_transaction_required_gas"]
        M["validate_l1_transaction_gas"](gas(0, maximum_bytes, 0), 30_000_000)
        with self.assertRaises(AssertionError):
            M["validate_l1_transaction_gas"](gas(0, maximum_bytes + 1, 0), 30_000_000)

    def test_minimum_of_block_and_transaction_caps(self):
        validate = M["validate_l1_transaction_gas"]
        validate(REQUIRED_AT_CAP, 30_000_000)
        with self.assertRaises(AssertionError):
            validate(REQUIRED_AT_CAP + 1, 30_000_000)
        block_cap = 10_000_000
        validate(block_cap * 100 // 130, block_cap)
        with self.assertRaises(AssertionError):
            validate(block_cap * 100 // 130 + 1, block_cap)
        self.assertEqual(M["L1_TRANSACTION_GAS_LIMIT"], CAP)

    def test_forwarding_and_suffix_reserve_are_concurrent(self):
        required = M["l1_call_sequence_minimum_gas"]
        self.assertEqual(required((63,), 0), 64)
        self.assertEqual(required((63,), 2), 65)
        self.assertEqual(required((63, 63), 2), 128)
        self.assertEqual(M["settlement_validity_verifier_required_gas_v2"](
            2_000_000, 500_000), 2_510_006)

    def test_declared_execution_is_not_a_compiled_certificate(self):
        # A profile's necessary proof/preflight bound omits real prefix work.
        proof_bytes, reserve = 65_536, 500_000
        stipend = REQUIRED_AT_CAP - 21_000 - 16 * proof_bytes - reserve - 10_006
        M["validate_settlement_validity_resources_v2"](
            proof_bytes, stipend, reserve, 30_000_000)
        required = M["settlement_validity_verifier_required_gas_v2"](stipend, reserve)
        with self.assertRaises(AssertionError):
            M["validate_l1_transaction_gas"](
                M["l1_transaction_required_gas"](0, proof_bytes + 32, required + 1),
                30_000_000)

    def test_feasible_migration_profile_and_exact_bound(self):
        record = self.activation
        encoded = M["encode_migration_activation_profile_return"](record)
        self.assertEqual(M["decode_migration_activation_profile_return"](encoded), record)
        maximum_bytes = M["maximum_migration_activation_calldata_bytes"](131_072)
        self.assertEqual(maximum_bytes, 149_220)
        at_bound = REQUIRED_AT_CAP - 21_000 - 16 * maximum_bytes
        self.decode_changed(word148=at_bound)
        with self.assertRaises(AssertionError):
            self.decode_changed(word148=at_bound + 1)

    def test_twenty_million_activation_rejects_before_registration(self):
        with self.assertRaises(AssertionError):
            self.decode_changed(word148=20_000_000)
        invalid = replace(self.activation, worst_case_activation_adoption_gas=20_000_000)
        with self.assertRaises(AssertionError):
            M["migration_activation_profile_record_hash"](invalid)
        with self.assertRaises(AssertionError):
            M["encode_migration_activation_profile_return"](invalid)

    def test_raw_migration_getter_rejects_even_with_recomputed_hash(self):
        encoded = bytearray(M["encode_migration_activation_profile_return"](self.activation))
        encoded[14 * 32:15 * 32] = M["u256"](20_000_000)
        words = [bytes(encoded[i:i + 32]) for i in range(0, len(encoded), 32)]
        # Independent packed MPR2 hash of the malformed record's wire fields.
        preimage = (M["D_MIGRATION_ACTIVATION_PROFILE"] + words[1][-8:]
                    + words[2] + words[4][-20:] + b"".join(words[5:10])
                    + words[10][:4] + words[11][-4:]
                    + b"".join(word[-8:] for word in words[12:24]))
        encoded[3 * 32:4 * 32] = M["keccak256"](preimage)
        with self.assertRaises(AssertionError):
            M["decode_migration_activation_profile_return"](bytes(encoded))

    def test_compile_envelope_lower_bound_cannot_be_understated(self):
        with self.assertRaises(AssertionError):
            self.decode_changed(word148=1)
        # This reserve cannot cover even the three mandatory full MAPS reads.
        with self.assertRaises(AssertionError):
            M["migration_activation_profile_record_hash"](
                replace(self.activation, post_callback_reserve_gas=300_000))
        with self.assertRaises(AssertionError):
            M["migration_activation_profile_record_hash"](
                replace(self.activation, maximum_proof_bytes=131_073))

    def test_resource_arithmetic_rejects_overflow_and_nonintegers(self):
        gas = M["l1_transaction_required_gas"]
        for args in ((M["UINT64_MAX"], 1, 0), (0, M["UINT64_MAX"], 0),
                     (0, 0, M["UINT64_MAX"]), (-1, 0, 0), (True, 0, 0)):
            with self.subTest(args=args), self.assertRaises(AssertionError):
                gas(*args)
        with self.assertRaises(AssertionError):
            M["l1_gas_with_headroom"](M["UINT64_MAX"])
        with self.assertRaises(AssertionError):
            M["l1_call_sequence_minimum_gas"]((M["UINT64_MAX"],), 0)

    def test_registration_counts_all_six_postreads_and_retained_reserve(self):
        validate = M["validate_protocol_release_resources_v1"]
        validate(6_000_000, 1_000_000, 100_000, 2_000_000, 30_000_000)
        # Checking just Router+Market would miss the six separately called
        # views and approve this infeasible MAX_PROFILE configuration.
        with self.assertRaises(AssertionError):
            validate(7_000_000, 1_000_000, 500_000, 2_000_000, 30_000_000)
        config = M["fixture_protocol_authority"]()[2]
        with self.assertRaises(AssertionError):
            M["protocol_version_manager_configuration_hash"](
                replace(config, release_router_registration_gas=15_000_000))

    def test_source_bundle_deployment_rejects_old_fifteen_million_cap(self):
        validate = M["validate_source_bundle_factory_resources_v1"]
        validate(10_000_000, 2_000_000, 500_000, 30_000_000)
        with self.assertRaises(AssertionError):
            validate(15_000_000, 2_000_000, 500_000, 30_000_000)
        with self.assertRaises(AssertionError):
            validate(10_000_000, 2_000_000, 500_000, 10_000_000)
        with self.assertRaises(AssertionError):
            validate(10_000_000, 2_000_000, 2_000_000, 30_000_000)

    def test_both_profile_decoders_reject_impossible_resources(self):
        for values in ({"word279": 17_000_000}, {"word148": 20_000_000},
                       {"word145": (1 << 32) - 1}, {"word148": 1}):
            malformed = self.changed_profile(**values)
            settlement_malformed = self.changed_profile(self.settlement_profile, **values)
            for graph in (False, True):
                with self.subTest(values=values, graph=graph):
                    with self.assertRaises(AssertionError):
                        M["decode_execution_profile_v2"](
                            malformed, validate_authority_graph=graph)
                    with self.assertRaises(ValueError):
                        S._execution_profile_abi_words_v2(
                            settlement_malformed, validate_authority_graph=graph)
        self.assertEqual(S._execution_profile_abi_words_v2(self.settlement_profile)[145:158],
                         M["decode_execution_profile_v2"](self.profile)[145:158])

    def test_both_models_match_floor_headroom_and_exact_boundaries(self):
        for zero in (0, 17, 100_000):
            for nonzero in (0, 1_001, 500_000):
                for execution in (0, 100_000, 5_000_000):
                    expected = M["l1_transaction_required_gas"](zero, nonzero, execution)
                    self.assertEqual(S.l1_transaction_required_gas(zero, nonzero, execution), expected)
                    self.assertEqual(S.l1_gas_with_headroom(expected), M["l1_gas_with_headroom"](expected))
        S.validate_l1_transaction_gas(REQUIRED_AT_CAP, 30_000_000)
        with self.assertRaises(ValueError):
            S.validate_l1_transaction_gas(REQUIRED_AT_CAP + 1, 30_000_000)
        with self.assertRaises(ValueError):
            S.l1_transaction_required_gas(0, S.UINT64_MAX, 0)
        with self.assertRaises(ValueError):
            S.l1_gas_with_headroom(S.UINT64_MAX)

    def test_settlement_profile_object_and_record_cannot_bypass_bounds(self):
        profile = S.execution_profile_for_test(2)
        self.assertTrue(profile.structurally_valid())
        self.assertFalse(replace(profile, worst_case_activation_adoption_gas=20_000_000).structurally_valid())
        self.assertFalse(replace(profile, supported_l1_block_gas_limit=1_000_000).structurally_valid())
        with self.assertRaises(ValueError):
            S.settlement_validity_verifier_configuration_hash_v2(
                "test-key", verification_gas_limit=17_000_000)
        record = S.migration_activation_profile_for_execution_profile_v2(profile)
        gas_values = list(record.gas_values)
        gas_values[2] = 20_000_000
        for invalid in (replace(record, gas_values=tuple(gas_values)),
                        replace(record, maximum_proof_bytes=(1 << 32) - 1),
                        replace(record, verification_gas_limit=record.verification_gas_limit + 1)):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                S.migration_activation_profile_record_hash_v2(invalid)
            with self.assertRaises(ValueError):
                S.encode_migration_activation_profile_return_v2(invalid)

    def test_standalone_migration_verifiers_cannot_bypass_bounds(self):
        record = self.activation
        descriptor = M["MigrationVerifierDescriptor"](
            record.verifier, record.verifier_runtime_hash,
            record.verifier_configuration_hash, record.verifying_key_hash,
            record.proof_system_id, record.public_input_schema_hash,
            record.verifier_selector, record.maximum_proof_bytes,
            record.verification_gas_limit)
        M["migration_verifier_descriptor_hash"](descriptor)
        settlement_descriptor = S.execution_profile_for_test(2).migration_transition_verifier_descriptor
        self.assertTrue(settlement_descriptor.structurally_valid())
        for values in ({"maximum_proof_bytes": (1 << 32) - 1},
                       {"verification_gas_limit": 17_000_000},
                       {"verification_gas_limit": 13_000_000}):
            with self.subTest(values=values):
                with self.assertRaises(AssertionError):
                    M["_migration_verifier_configuration_hash"](replace(descriptor, **values))
                with self.assertRaises(ValueError):
                    S.migration_transition_verifier_configuration_hash(
                        "test-key", maximum_proof_bytes=values.get("maximum_proof_bytes", 131_072),
                        verification_gas_limit=values.get("verification_gas_limit", 1_000_000))
                invalid_descriptor = replace(settlement_descriptor, **values)
                self.assertFalse(invalid_descriptor.structurally_valid())
                with self.assertRaises(ValueError):
                    _ = invalid_descriptor.commitment

    def test_settlement_descriptor_getter_and_root_budgets_are_checked(self):
        words = list(S._execution_profile_abi_words_v2(self.settlement_profile))
        words[279] = M["u256"](17_000_000)
        words[273] = M["keccak256"](
            M["SETTLEMENT_VALIDITY_VERIFIER_CONFIG_TYPEHASH"] + b"".join(words[274:281]))
        raw_getter = b"SVD2" + bytes(28) + b"".join(words[271:281])
        with self.assertRaises(ValueError):
            S._profile_settlement_validity_verifier_descriptor_hash_v2(words)
        with self.assertRaises(ValueError):
            S._decode_settlement_validity_verifier_descriptor_return_v2(raw_getter)
        with self.assertRaises(ValueError):
            S.validate_protocol_release_resources_v1(15_000_000, 1_000_000, 100_000, 2_000_000, 30_000_000)
        with self.assertRaises(ValueError):
            S.validate_source_bundle_factory_resources_v1(15_000_000, 2_000_000, 500_000, 30_000_000)


if __name__ == "__main__":
    if not __debug__:
        raise SystemExit("resource model refuses optimized Python")
    unittest.main()
