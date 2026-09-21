#!/usr/bin/env python3
"""Fork resource regressions; synthetic budgets are not EVM gas certificates."""

import runpy
import importlib.util
import sys
import unittest
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
        self.assertEqual(S.L1_TRANSACTION_GAS_LIMIT, CAP)

    def test_forwarding_and_suffix_reserve_are_concurrent(self):
        required = M["l1_call_sequence_minimum_gas"]
        self.assertEqual(required((63,), 0), 64)
        self.assertEqual(required((63,), 2), 65)
        self.assertEqual(required((63, 63), 2), 128)
        self.assertEqual(M["settlement_validity_verifier_required_gas_v2"](
            2_000_000, 500_000), 2_510_006)
        self.assertEqual(S.settlement_validity_verifier_required_gas_v2(
            2_000_000, 500_000), 2_510_006)

    def test_declared_execution_is_not_a_compiled_certificate(self):
        # A necessary proof/preflight bound omits real prefix work.
        proof_bytes, reserve = 65_536, 500_000
        stipend = REQUIRED_AT_CAP - 21_000 - 16 * proof_bytes - reserve - 10_006
        M["validate_settlement_validity_resources_v2"](
            proof_bytes, stipend, reserve, 30_000_000)
        S.validate_settlement_validity_resources_v2(
            proof_bytes, stipend, reserve, 30_000_000)
        required = M["settlement_validity_verifier_required_gas_v2"](stipend, reserve)
        with self.assertRaises(AssertionError):
            M["validate_l1_transaction_gas"](
                M["l1_transaction_required_gas"](0, proof_bytes + 32, required + 1),
                30_000_000)
        with self.assertRaises(ValueError):
            S.validate_settlement_validity_resources_v2(
                proof_bytes, stipend + 1, reserve, 30_000_000)

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
        self.assertEqual(
            S.l1_call_sequence_minimum_gas((63, 63), 2),
            M["l1_call_sequence_minimum_gas"]((63, 63), 2),
        )


if __name__ == "__main__":
    if not __debug__:
        raise SystemExit("resource model refuses optimized Python")
    unittest.main()
