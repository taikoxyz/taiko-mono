#!/usr/bin/env python3
"""Adversarial tests for the bounded perpetual seat-market focused model."""

from __future__ import annotations

import copy
from dataclasses import replace
import importlib.util
import inspect
import itertools
from pathlib import Path
import random
import sys
import unittest


ROOT = Path(__file__).resolve().parent
MODEL_PATH = ROOT / "seat-market-model.py"


def load_module():
    spec = importlib.util.spec_from_file_location("seat_market_model", MODEL_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("unable to load seat-market-model.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


model = load_module()


def addr(label):
    if isinstance(label, int):
        if label <= 0 or label >= 1 << 160:
            raise ValueError("address integer is out of range")
        return "0x" + label.to_bytes(20, "big").hex()
    if isinstance(label, str) and label.startswith("0x"):
        return label
    raw = label.encode("ascii")
    if not raw or len(raw) > 20:
        raise ValueError("test address label must contain 1..20 ASCII bytes")
    return "0x" + raw.ljust(20, b"\x00").hex()


def immutable_authorization(target="settlement-v1", **overrides):
    values = dict(
        target=addr(target),
        settlement_chain_id=1,
        protocol_version=25,
        runtime_hash=b"r" * 32,
        configuration_hash=b"c" * 32,
        expected_magic=b"SEAT",
    )
    values.update(overrides)
    return model.TargetAuthorization(**values)


def make_codec_market(**overrides):
    values = dict(
        market_chain_id=1,
        market_address=addr("market"),
        sla_bond=1_000,
        immutable_maximum_ask=100,
        quote_maturity_seconds=10,
        quote_maturity_blocks=3,
        exit_delay_seconds=20,
        penalty_sink=addr("penalty-sink"),
        authorization=immutable_authorization(),
        insertion_enabled=True,
        cached_generation=7,
    )
    values.update(overrides)
    return model.SeatMarket(**values)


class AuthorizationArchitectureAndCodecTests(unittest.TestCase):
    def test_domains_widths_and_legacy_keccak_direct_construction_are_frozen(self):
        self.assertEqual(
            model.D_AUTHORIZATION, b"TAIKO_SEAT_TARGET_AUTHORIZATION_V1"
        )
        self.assertEqual(model.D_TRANCHE, b"TAIKO_SEAT_TRANCHE_V1")
        self.assertEqual(model.D_OFFER, b"TAIKO_SEAT_OFFER_V1")
        self.assertEqual(model.D_CREDIT, b"TAIKO_SEAT_BOND_CREDIT_V1")
        self.assertEqual(model.PROTOCOL_VERSION_BITS, 64)
        self.assertEqual(model.SEAT_GENERATION_BITS, 64)

        auth = immutable_authorization()
        expected = model.keccak256(
            model.D_AUTHORIZATION
            + model.u256(1)
            + model.address20(addr("market"))
            + model.u256(auth.settlement_chain_id)
            + model.u64(auth.protocol_version)
            + model.address20(auth.target)
            + auth.runtime_hash
            + auth.configuration_hash
            + auth.expected_magic
        )
        self.assertEqual(
            model.authorization_identity(1, addr("market"), auth), expected
        )

    def test_tranche_offer_and_credit_ids_equal_one_direct_fixed_width_encoding(self):
        market = make_codec_market()
        row = market.insert_offer(
            caller=addr("alice"), payout=addr("alice-payout"),
            ask_wei_per_second=9, target=addr("settlement-v1"), generation=7,
            clock=model.Clock(100, 50), value=1_000,
        )
        auth_id = market.current_authorization_id
        expected_tranche = model.keccak256(
            model.D_TRANCHE
            + auth_id
            + model.u64(7)
            + model.address20(addr("alice"))
            + model.u256(1_000)
            + model.u256(row.tranche.creation_sequence)
        )
        expected_offer = model.keccak256(
            model.D_OFFER
            + auth_id
            + model.u64(7)
            + expected_tranche
            + model.address20(addr("alice-payout"))
            + model.u256(9)
            + model.u256(110)
            + model.u256(53)
            + model.u256(row.offer.quote_sequence)
        )
        self.assertEqual(row.tranche.tranche_id, expected_tranche)
        self.assertEqual(row.offer.offer_id, expected_offer)
        self.assertEqual(
            model.tranche_identity(
                auth_id,
                7,
                addr("alice"),
                1_000,
                row.tranche.creation_sequence,
            ),
            expected_tranche,
        )
        self.assertEqual(
            model.offer_identity(
                auth_id,
                7,
                expected_tranche,
                addr("alice-payout"),
                9,
                110,
                53,
                row.offer.quote_sequence,
            ),
            expected_offer,
        )
        expected_credit = model.keccak256(
            model.D_CREDIT
            + model.u256(1)
            + model.address20(addr("market"))
            + expected_tranche
            + model.u8(model.BondDisposition.OWNER_CREDITED.value)
        )
        self.assertEqual(
            market.credit_id(
                expected_tranche, model.BondDisposition.OWNER_CREDITED
            ),
            expected_credit,
        )
        self.assertEqual(
            model.bond_credit_identity(
                1,
                addr("market"),
                expected_tranche,
                model.BondDisposition.OWNER_CREDITED,
            ),
            expected_credit,
        )

    def test_disable_and_current_rotation_preserve_historical_authority(self):
        market = make_codec_market()
        owner = market.insert_offer(
            caller=addr("alice"), payout=addr("alice-payout"),
            ask_wei_per_second=10, target=addr("settlement-v1"), generation=7,
            clock=model.Clock(100, 50), value=1_000,
        )
        market.request_pending_exit(
            addr("alice"), owner.offer.offer_id, model.Clock(100, 50)
        )
        owner_credit = market.finalize_pending_exit(
            owner.tranche.tranche_id, model.Clock(120, 50)
        ).credit_id

        installed = market.insert_offer(
            caller=addr("bob"), payout=addr("bob-payout"),
            ask_wei_per_second=11, target=addr("settlement-v1"), generation=7,
            clock=model.Clock(100, 50), value=1_000,
        )
        market.pending_offer_ids.clear()
        installed.offer.location = model.OfferLocation.NONE
        installed.tranche.usage = model.TrancheUsage.INSTALLED
        installed.tranche.installed_term_id = b"i" * 32
        market.assert_valid()

        old_id = market.current_authorization_id
        market._set_authorization_enabled(old_id, False)
        self.assertEqual(market.current_authorization_id, old_id)
        self.assertEqual(
            model.authorization_identity(1, addr("market"), immutable_authorization()),
            old_id,
        )
        market.assert_valid()
        before = copy.deepcopy(market)
        with self.assertRaises(model.TransitionRejected):
            market.insert_offer(
                caller=addr("carol"), payout=addr("carol-payout"),
                ask_wei_per_second=1, target=addr("settlement-v1"), generation=7,
                clock=model.Clock(200, 100), value=1_000,
            )
        self.assertEqual(market, before)

        new_auth = immutable_authorization(
            target="settlement-v2", protocol_version=26,
            runtime_hash=b"x" * 32, configuration_hash=b"y" * 32,
        )
        new_id = market._register_authorization(
            new_auth, enabled=True, make_current=True
        )
        self.assertNotEqual(new_id, old_id)
        market.assert_valid()
        self.assertEqual(
            market.tranches[owner.tranche.tranche_id].authorization_id, old_id
        )
        self.assertEqual(
            market.tranches[installed.tranche.tranche_id].authorization_id, old_id
        )
        self.assertEqual(
            market.tranches[installed.tranche.tranche_id].usage,
            model.TrancheUsage.INSTALLED,
        )
        paid = []
        market.claim_credit(
            owner_credit,
            lambda beneficiary, amount, _market: paid.append((beneficiary, amount)),
        )
        self.assertEqual(paid, [(addr("alice"), 1_000)])
        market.assert_valid()
        before = copy.deepcopy(market)
        with self.assertRaises(model.TransitionRejected):
            market.requote(
                caller=addr("alice"), offer_id=owner.offer.offer_id,
                payout=addr("new"), ask_wei_per_second=9,
                target=addr("settlement-v1"), generation=7,
                clock=model.Clock(200, 100),
            )
        self.assertEqual(market, before)
        self.assertEqual(market.current_authorization_id, new_id)
        before = copy.deepcopy(market)
        with self.assertRaises(model.TransitionRejected):
            market.insert_offer(
                caller=addr("carol"), payout=addr("carol-payout"),
                ask_wei_per_second=1, target=addr("settlement-v1"), generation=7,
                clock=model.Clock(200, 100), value=1_000,
            )
        self.assertEqual(market, before)

    def test_registry_control_primitives_reject_atomically_and_live_rows_gate_state(self):
        live = make_codec_market()
        row = live.insert_offer(
            caller=addr("alice"), payout=addr("alice-payout"),
            ask_wei_per_second=9, target=addr("settlement-v1"), generation=7,
            clock=model.Clock(100, 50), value=1_000,
        )
        current = live.current_authorization_id
        before = copy.deepcopy(live)
        with self.assertRaises(model.TransitionRejected):
            live._set_authorization_enabled(current, False)
        self.assertEqual(live, before)
        with self.assertRaises(model.TransitionRejected):
            live._set_authorization_enabled(b"u" * 32, True)
        self.assertEqual(live, before)

        new_auth = immutable_authorization(
            target="settlement-v2", protocol_version=26,
            runtime_hash=b"x" * 32, configuration_hash=b"y" * 32,
        )
        with self.assertRaises(model.TransitionRejected):
            live._register_authorization(new_auth, enabled=True, make_current=True)
        self.assertEqual(live, before)

        registered = live._register_authorization(
            new_auth, enabled=True, make_current=False
        )
        live.assert_valid()
        before_duplicate = copy.deepcopy(live)
        with self.assertRaises(model.TransitionRejected):
            live._register_authorization(new_auth, enabled=True, make_current=False)
        self.assertEqual(live, before_duplicate)

        disabled_live = copy.deepcopy(live)
        disabled_live.authorization_enabled[current] = False
        with self.assertRaises(AssertionError):
            disabled_live.assert_valid()
        stale_current = copy.deepcopy(live)
        stale_current.current_authorization_id = registered
        with self.assertRaises(AssertionError):
            stale_current.assert_valid()
        orphaned_authority = copy.deepcopy(live)
        del orphaned_authority.authorizations[row.offer.authorization_id]
        del orphaned_authority.authorization_enabled[row.offer.authorization_id]
        with self.assertRaises(AssertionError):
            orphaned_authority.assert_valid()

    def test_every_codec_field_substitution_and_exact_width_is_observable(self):
        auth = immutable_authorization()
        authorization_id = model.authorization_identity(1, addr("market"), auth)
        authorization_substitutions = (
            model.authorization_identity(2, addr("market"), auth),
            model.authorization_identity(1, addr("other-market"), auth),
            model.authorization_identity(
                1, addr("market"), replace(auth, settlement_chain_id=2)
            ),
            model.authorization_identity(
                1, addr("market"), replace(auth, protocol_version=26)
            ),
            model.authorization_identity(
                1, addr("market"), replace(auth, target=addr("settlement-v2"))
            ),
            model.authorization_identity(
                1, addr("market"), replace(auth, runtime_hash=b"x" * 32)
            ),
            model.authorization_identity(
                1, addr("market"), replace(auth, configuration_hash=b"y" * 32)
            ),
            model.authorization_identity(
                1, addr("market"), replace(auth, expected_magic=b"NEXT")
            ),
        )
        for substituted in authorization_substitutions:
            self.assertNotEqual(substituted, authorization_id)

        base_market = make_codec_market()
        base = base_market.insert_offer(
            caller=addr("alice"), payout=addr("alice-payout"),
            ask_wei_per_second=9, target=auth.target, generation=7,
            clock=model.Clock(100, 50), value=1_000,
        )
        operator = make_codec_market().insert_offer(
            caller=addr("bob"), payout=addr("alice-payout"),
            ask_wei_per_second=9, target=auth.target, generation=7,
            clock=model.Clock(100, 50), value=1_000,
        )
        generation = make_codec_market(cached_generation=8).insert_offer(
            caller=addr("alice"), payout=addr("alice-payout"),
            ask_wei_per_second=9, target=auth.target, generation=8,
            clock=model.Clock(100, 50), value=1_000,
        )
        creation_sequence = make_codec_market(
            starting_creation_sequence=1
        ).insert_offer(
            caller=addr("alice"), payout=addr("alice-payout"),
            ask_wei_per_second=9, target=auth.target, generation=7,
            clock=model.Clock(100, 50), value=1_000,
        )
        payout = make_codec_market().insert_offer(
            caller=addr("alice"), payout=addr("other-payout"),
            ask_wei_per_second=9, target=auth.target, generation=7,
            clock=model.Clock(100, 50), value=1_000,
        )
        quote_sequence = make_codec_market(starting_quote_sequence=1).insert_offer(
            caller=addr("alice"), payout=addr("alice-payout"),
            ask_wei_per_second=9, target=auth.target, generation=7,
            clock=model.Clock(100, 50), value=1_000,
        )
        for tranche_substitution in (operator, generation, creation_sequence):
            self.assertNotEqual(
                tranche_substitution.tranche.tranche_id, base.tranche.tranche_id
            )
        for offer_substitution in (
            operator, generation, creation_sequence, payout, quote_sequence
        ):
            self.assertNotEqual(offer_substitution.offer.offer_id, base.offer.offer_id)

        owner_credit = base_market.credit_id(
            base.tranche.tranche_id, model.BondDisposition.OWNER_CREDITED
        )
        self.assertNotEqual(
            owner_credit,
            base_market.credit_id(
                base.tranche.tranche_id, model.BondDisposition.PENALTY_CREDITED
            ),
        )
        self.assertNotEqual(
            owner_credit,
            make_codec_market(market_chain_id=2).credit_id(
                base.tranche.tranche_id, model.BondDisposition.OWNER_CREDITED
            ),
        )
        self.assertNotEqual(
            owner_credit,
            make_codec_market(market_address=addr("other-market")).credit_id(
                base.tranche.tranche_id, model.BondDisposition.OWNER_CREDITED
            ),
        )

        self.assertEqual(model.u8(255), b"\xff")
        self.assertEqual(model.u64(model.UINT64_MAX), b"\xff" * 8)
        self.assertEqual(model.u256(model.UINT256_MAX), b"\xff" * 32)
        for codec, invalid in (
            (model.u8, 256),
            (model.u64, model.UINT64_MAX + 1),
            (model.u256, model.UINT256_MAX + 1),
        ):
            with self.assertRaises(model.ArithmeticFault):
                codec(invalid)
            for wrong_type in (True, 1.0, bytearray(b"\x01")):
                with self.assertRaises(model.ArithmeticFault):
                    codec(wrong_type)
        for invalid_address in (
            "0x" + "00" * 20,
            "0x" + "AA" * 20,
            "0x01",
            bytearray(b"\x01" * 20),
        ):
            with self.assertRaises(model.TransitionRejected):
                model.address20(invalid_address)
        for invalid_auth in (
            replace(auth, protocol_version=model.UINT64_MAX + 1),
            replace(auth, settlement_chain_id=model.UINT256_MAX + 1),
        ):
            with self.assertRaises((model.ArithmeticFault, model.TransitionRejected)):
                model.authorization_identity(1, addr("market"), invalid_auth)


def authorization(target="settlement-v1"):
    return model.TargetAuthorization(
        target=addr(target),
        settlement_chain_id=1,
        protocol_version=25,
        runtime_hash=b"r" * 32,
        configuration_hash=b"c" * 32,
        expected_magic=b"SEAT",
    )


def target_view(generation, target="settlement-v1", phase="ACTIVE"):
    auth = authorization(target)
    return model.ExactTargetView(
        target=auth.target,
        settlement_chain_id=auth.settlement_chain_id,
        protocol_version=auth.protocol_version,
        runtime_hash=auth.runtime_hash,
        configuration_hash=auth.configuration_hash,
        magic=auth.expected_magic,
        phase=phase,
        generation=generation,
    )


def make_market(**overrides):
    values = dict(
        market_chain_id=1,
        market_address=addr("market"),
        sla_bond=1_000,
        immutable_maximum_ask=100,
        quote_maturity_seconds=10,
        quote_maturity_blocks=3,
        exit_delay_seconds=20,
        penalty_sink=addr("penalty-sink"),
        authorization=authorization(),
        insertion_enabled=True,
        cached_generation=7,
    )
    values.update(overrides)
    return model.SeatMarket(**values)


def insert(
    market,
    operator,
    ask,
    *,
    payout=None,
    clock=None,
    target="settlement-v1",
    generation=7,
):
    return market.insert_offer(
        caller=addr(operator),
        payout=addr(payout or f"payout-{operator}"),
        ask_wei_per_second=ask,
        target=addr(target),
        generation=generation,
        clock=clock or model.Clock(100, 50),
        value=market.sla_bond,
    )


class EnumAndRecordTests(unittest.TestCase):
    def test_public_discriminants_are_pinned(self):
        self.assertEqual(model.OfferLocation.NONE.value, 0)
        self.assertEqual(model.OfferLocation.PENDING.value, 1)
        self.assertEqual(model.OfferLocation.STAGED.value, 2)
        self.assertEqual(model.TrancheUsage.OFFER.value, 1)
        self.assertEqual(model.TrancheUsage.STAGED.value, 2)
        self.assertEqual(model.TrancheUsage.INSTALLED.value, 3)
        self.assertEqual(model.TrancheUsage.CLOSED_UNINSTALLED.value, 4)
        self.assertEqual(model.BondDisposition.NONE.value, 0)
        self.assertEqual(model.BondDisposition.OWNER_CREDITED.value, 1)
        self.assertEqual(model.BondDisposition.PENALTY_CREDITED.value, 2)
        self.assertEqual(model.ReserveLifecycle.ABSENT.value, 0)
        self.assertEqual(model.ReserveLifecycle.UNSTARTED.value, 1)
        self.assertEqual(model.ReserveLifecycle.OPEN.value, 2)
        self.assertEqual(model.ReserveLifecycle.CLOSED_TAIL.value, 3)

    def test_authority_and_clock_inputs_are_immutable(self):
        auth = authorization()
        clock = model.Clock(1, 2)
        with self.assertRaises((AttributeError, TypeError)):
            auth.target = "evil"
        with self.assertRaises((AttributeError, TypeError)):
            clock.timestamp = 3
        snapshot = lineup()
        with self.assertRaises((AttributeError, TypeError)):
            snapshot.generation = 8

    def test_ethereum_legacy_keccak_empty_vector(self):
        self.assertEqual(
            model.keccak256(b"").hex(),
            "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470",
        )


class AtomicAssertions(unittest.TestCase):
    def assert_rejects_unchanged(self, market, call, exception=None):
        before = copy.deepcopy(market)
        with self.assertRaises(exception or model.TransitionRejected):
            call()
        self.assertEqual(market, before)


class OfferBookTests(AtomicAssertions):
    def test_four_cells_and_complete_five_key_order(self):
        market = make_market()
        # Keys differ at each successive field.  Deliberately insert in reverse order.
        clocks = {
            "ask": model.Clock(101, 50),
            "time": model.Clock(101, 50),
            "block": model.Clock(100, 51),
            "sequence": model.Clock(100, 50),
        }
        rows = [
            ("operator-z", 11, clocks["ask"]),
            ("operator-y", 10, clocks["time"]),
            ("operator-x", 10, clocks["block"]),
            ("operator-w", 10, clocks["sequence"]),
        ]
        for operator, ask, clock in rows:
            insert(market, operator, ask, clock=clock)
        self.assertEqual(market.pending_count, 4)
        self.assertEqual(market.staged_count, 0)
        keys = [offer.order_key for offer in market.pending_offers]
        self.assertEqual(keys, sorted(keys))
        self.assertEqual(
            [offer.operator for offer in market.pending_offers],
            [
                addr("operator-w"),
                addr("operator-x"),
                addr("operator-y"),
                addr("operator-z"),
            ],
        )
        self.assertLessEqual(market.pending_count + market.staged_count, 4)

        # Operator is the fifth and final tie breaker.  A direct record vector
        # isolates it without manufacturing a non-monotone market counter.
        common = dict(
            tranche_id=b"t", payout=addr("p"), ask_wei_per_second=9,
            eligible_at_timestamp=20, eligible_at_block=20, quote_sequence=42,
            target=addr("settlement-v1"),
            authorization_id=model.authorization_identity(
                1, addr("market"), authorization()
            ),
            generation=7,
        )
        tied = [
            model.Offer(offer_id=b"b", operator=addr("operator-b"), **common),
            model.Offer(offer_id=b"a", operator=addr("operator-a"), **common),
        ]
        self.assertEqual(
            [offer.operator for offer in sorted(tied, key=lambda offer: offer.order_key)],
            [addr("operator-a"), addr("operator-b")],
        )

    def test_quote_sequence_precedes_operator_in_independent_conflict_vector(self):
        common = dict(
            tranche_id=b"t", payout=addr("p"), ask_wei_per_second=9,
            eligible_at_timestamp=20, eligible_at_block=20,
            target=addr("settlement-v1"),
            authorization_id=model.authorization_identity(
                1, addr("market"), authorization()
            ),
            generation=7,
        )
        lower_sequence_higher_operator = model.Offer(
            offer_id=b"first", operator=addr("operator-z"), quote_sequence=41, **common
        )
        higher_sequence_lower_operator = model.Offer(
            offer_id=b"second", operator=addr("operator-a"), quote_sequence=42, **common
        )
        ordered = sorted(
            (higher_sequence_lower_operator, lower_sequence_higher_operator),
            key=lambda offer: offer.order_key,
        )
        self.assertEqual(
            [offer.offer_id for offer in ordered], [b"first", b"second"]
        )

    def test_full_book_rejects_equal_or_worse_fifth_without_retaining_value(self):
        market = make_market()
        for index, ask in enumerate((10, 20, 30, 40)):
            insert(market, f"op-{index}", ask)
        self.assert_rejects_unchanged(market, lambda: insert(market, "worse", 40))
        self.assert_rejects_unchanged(market, lambda: insert(market, "much-worse", 41))
        self.assertEqual(market.actual_balance, 4 * market.sla_bond)

    def test_strictly_better_fifth_displaces_worst_to_exact_owner_credit(self):
        market = make_market()
        inserted = [insert(market, f"op-{index}", ask) for index, ask in enumerate((10, 20, 30, 40))]
        worst = inserted[-1]
        accepted = insert(market, "better", 5)
        self.assertEqual(market.pending_count, 4)
        self.assertNotIn(worst.offer.offer_id, market.pending_offer_ids)
        old_offer = market.offers[worst.offer.offer_id]
        old_tranche = market.tranches[worst.tranche.tranche_id]
        self.assertEqual(old_offer.location, model.OfferLocation.NONE)
        self.assertEqual(old_tranche.usage, model.TrancheUsage.CLOSED_UNINSTALLED)
        self.assertEqual(old_tranche.disposition, model.BondDisposition.OWNER_CREDITED)
        displaced_credit_id = market.credit_id(
            worst.tranche.tranche_id, model.BondDisposition.OWNER_CREDITED
        )
        credit = market.credits[displaced_credit_id]
        self.assertEqual(
            (credit.beneficiary, credit.amount, credit.claimed),
            (addr("op-3"), 1_000, False),
        )
        self.assertEqual(accepted.displaced_offer_id, worst.offer.offer_id)
        self.assertEqual(market.accounting.bond_escrow, 4_000)
        self.assertEqual(market.accounting.outstanding_owner_credits, 1_000)
        self.assertEqual(market.actual_balance, 5_000)
        market.assert_valid()

    def test_insertion_derives_operator_and_rejects_bad_authority_or_value_atomically(self):
        market = make_market()
        accepted = insert(market, "alice", 10)
        self.assertEqual(accepted.offer.operator, addr("alice"))
        cases = (
            lambda: market.insert_offer(
                caller=addr("bob"), payout=addr("p"), ask_wei_per_second=1,
                target=addr("evil"), generation=7, clock=model.Clock(1, 1), value=1_000
            ),
            lambda: market.insert_offer(
                caller=addr("bob"), payout=addr("p"), ask_wei_per_second=1,
                target=addr("settlement-v1"), generation=6, clock=model.Clock(1, 1), value=1_000
            ),
            lambda: market.insert_offer(
                caller=addr("bob"), payout=addr("p"), ask_wei_per_second=1,
                target=addr("settlement-v1"), generation=7, clock=model.Clock(1, 1), value=999
            ),
        )
        for case in cases:
            self.assert_rejects_unchanged(market, case)

    def test_uninitialized_or_disabled_authority_rejects_insertion(self):
        uninitialized = make_market(cached_generation=None)
        self.assert_rejects_unchanged(uninitialized, lambda: insert(uninitialized, "alice", 1))
        disabled = make_market(insertion_enabled=False)
        self.assert_rejects_unchanged(disabled, lambda: insert(disabled, "alice", 1))

    def test_insert_ask_and_payout_boundaries(self):
        for ask in (99, 100):
            market = make_market()
            insert(market, "alice", ask)
        market = make_market()
        self.assert_rejects_unchanged(market, lambda: insert(market, "alice", 101))
        self.assert_rejects_unchanged(
            market,
            lambda: market.insert_offer(
                caller=addr("alice"), payout="", ask_wei_per_second=10,
                target=addr("settlement-v1"), generation=7,
                clock=model.Clock(1, 1), value=1_000,
            ),
        )

    def test_shared_pending_and_staged_capacity_is_always_enforced(self):
        market = make_market()
        for index in range(4):
            insert(market, f"op-{index}", index)
        # Task 3 owns the public stage transition.  Inject only its exact state
        # shape here so Task 2 can prove the shared-capacity predicate now.
        staged_offer_id = market.pending_offer_ids.pop(0)
        staged_offer = market.offers[staged_offer_id]
        staged_offer.location = model.OfferLocation.STAGED
        market.tranches[staged_offer.tranche_id].usage = model.TrancheUsage.STAGED
        market.stage = model.Stage(b"s" * 32, staged_offer_id)
        market.assert_valid()
        self.assertEqual((market.pending_count, market.staged_count), (3, 1))
        insert(market, "replacement", 1)
        self.assertEqual((market.pending_count, market.staged_count), (3, 1))
        self.assertLessEqual(market.pending_count + market.staged_count, 4)
        self.assert_rejects_unchanged(market, lambda: insert(market, "worse", 100))

    def test_generation_sync_purges_pending_to_owner_credits_and_writes_cache_last(self):
        market = make_market()
        rows = [insert(market, f"op-{index}", index) for index in range(4)]
        result = market.sync_seat_generation(target_view(8))
        self.assertEqual(result.purged_count, 4)
        self.assertEqual(market.cached_generation, 8)
        self.assertEqual(market.pending_count, 0)
        for row in rows:
            tranche = market.tranches[row.tranche.tranche_id]
            self.assertEqual(tranche.disposition, model.BondDisposition.OWNER_CREDITED)
        self.assertEqual(market.accounting.bond_escrow, 0)
        self.assertEqual(market.accounting.outstanding_owner_credits, 4_000)
        market.assert_valid()

    def test_generation_sync_faults_and_lower_generation_roll_back(self):
        market = make_market()
        insert(market, "alice", 1)
        bad_views = [
            target_view(6),
            target_view(8, target="evil"),
            target_view(8, phase="ARMED"),
        ]
        good = target_view(8)
        bad_views.extend([
            model.ExactTargetView(**{**good.__dict__, "magic": b"FAIL"}),
            model.ExactTargetView(**{**good.__dict__, "runtime_hash": b"x" * 32}),
            model.ExactTargetView(**{**good.__dict__, "configuration_hash": b"x" * 32}),
            model.ExactTargetView(**{**good.__dict__, "protocol_version": 24}),
            model.ExactTargetView(**{**good.__dict__, "settlement_chain_id": 2}),
        ])
        for view in bad_views:
            self.assert_rejects_unchanged(market, lambda view=view: market.sync_seat_generation(view))
        same = market.sync_seat_generation(target_view(7))
        self.assertEqual(same.purged_count, 0)

    def test_exact_target_view_rejects_every_wrong_runtime_type_and_width(self):
        market = make_market()
        insert(market, "alice", 1)
        good = target_view(7)
        invalid = (
            replace(good, target=b"settlement-v1"),
            replace(good, target=bytearray(b"settlement-v1")),
            replace(good, target="Settlement-v1"),
            replace(good, settlement_chain_id=True),
            replace(good, settlement_chain_id=1.0),
            replace(good, settlement_chain_id=model.UINT256_MAX + 1),
            replace(good, protocol_version=True),
            replace(good, protocol_version=25.0),
            replace(good, protocol_version=model.UINT64_MAX + 1),
            replace(good, protocol_version=model.UINT256_MAX + 1),
            replace(good, generation=True),
            replace(good, generation=7.0),
            replace(good, generation=-1),
            replace(good, generation=model.UINT64_MAX + 1),
            replace(good, generation=model.UINT256_MAX + 1),
            replace(good, runtime_hash=bytearray(b"r" * 32)),
            replace(good, runtime_hash=b"r" * 31),
            replace(good, configuration_hash=bytearray(b"c" * 32)),
            replace(good, configuration_hash=b"c" * 33),
            replace(good, magic=bytearray(b"SEAT")),
            replace(good, magic=b"SEA"),
            replace(good, phase=b"ACTIVE"),
            replace(good, phase=bytearray(b"ACTIVE")),
        )
        for view in invalid:
            self.assert_rejects_unchanged(
                market, lambda view=view: market.sync_seat_generation(view)
            )

    def test_ids_bind_full_authorization_identity_and_generation(self):
        base_auth = authorization()
        variants = (
            replace(base_auth, target=addr("settlement-v2")),
            replace(base_auth, protocol_version=26),
            replace(base_auth, runtime_hash=b"x" * 32),
            replace(base_auth, configuration_hash=b"y" * 32),
        )
        base = insert(make_market(), "alice", 1)
        tranche_ids = {base.tranche.tranche_id}
        offer_ids = {base.offer.offer_id}
        for auth in variants:
            row = insert(
                make_market(authorization=auth),
                "alice",
                1,
                target=auth.target,
            )
            tranche_ids.add(row.tranche.tranche_id)
            offer_ids.add(row.offer.offer_id)
        generation_row = insert(
            make_market(cached_generation=8), "alice", 1, generation=8
        )
        tranche_ids.add(generation_row.tranche.tranche_id)
        offer_ids.add(generation_row.offer.offer_id)
        expected_count = 1 + len(variants) + 1
        self.assertEqual(len(tranche_ids), expected_count)
        self.assertEqual(len(offer_ids), expected_count)

    def test_orphan_waiting_offers_and_capacity_attack_are_rejected(self):
        pending_ghost = make_market()
        row = insert(pending_ghost, "alice", 1)
        pending_ghost.pending_offer_ids.remove(row.offer.offer_id)
        with self.assertRaises(AssertionError):
            pending_ghost.assert_valid()

        staged_ghost = make_market()
        staged = insert(staged_ghost, "alice", 1)
        staged_ghost.pending_offer_ids.clear()
        staged.offer.location = model.OfferLocation.STAGED
        staged.tranche.usage = model.TrancheUsage.STAGED
        with self.assertRaises(AssertionError):
            staged_ghost.assert_valid()

        none_in_pending = make_market()
        none_row = insert(none_in_pending, "alice", 1)
        none_row.offer.location = model.OfferLocation.NONE
        with self.assertRaises(AssertionError):
            none_in_pending.assert_valid()

        wrong_current = make_market()
        current_row = insert(wrong_current, "alice", 1)
        current_row.tranche.current_offer_id = b"x" * 32
        with self.assertRaises(AssertionError):
            wrong_current.assert_valid()

        capacity_attack = make_market()
        rows = [insert(capacity_attack, f"op-{i}", i) for i in range(4)]
        capacity_attack.pending_offer_ids.remove(rows[0].offer.offer_id)
        self.assert_rejects_unchanged(
            capacity_attack, lambda: insert(capacity_attack, "fifth", 0)
        )

    def test_coordinated_operator_bond_and_binding_mutations_fail_closed(self):
        market = make_market()
        row = insert(market, "alice", 1)
        row.offer.operator = addr("mallory")
        row.tranche.operator = addr("mallory")
        with self.assertRaises(AssertionError):
            market.assert_valid()

        bond_attack = make_market()
        bond_row = insert(bond_attack, "alice", 1)
        bond_row.tranche.bond_amount = 999
        bond_attack.accounting.bond_escrow = 999
        with self.assertRaises(AssertionError):
            bond_attack.assert_valid()

    def test_all_permutations_leave_best_four_by_structural_key(self):
        offers = tuple((f"op-{ask}", ask) for ask in (11, 7, 30, 2, 19))
        for ordering in itertools.permutations(offers):
            market = make_market()
            for operator, ask in ordering:
                try:
                    insert(market, operator, ask)
                except model.TransitionRejected:
                    pass
                self.assertLessEqual(market.pending_count + market.staged_count, 4)
                market.assert_valid()
            self.assertEqual([offer.ask_wei_per_second for offer in market.pending_offers], [2, 7, 11, 19])


class RequoteTests(AtomicAssertions):
    def test_requote_is_pending_only_preserves_tranche_and_resets_maturity(self):
        market = make_market()
        first = insert(market, "alice", 50, clock=model.Clock(100, 50))
        result = market.requote(
            caller=addr("alice"),
            offer_id=first.offer.offer_id,
            payout=addr("alice-new"),
            ask_wei_per_second=40,
            target=addr("settlement-v1"),
            generation=7,
            clock=model.Clock(200, 70),
        )
        self.assertEqual(result.tranche.tranche_id, first.tranche.tranche_id)
        self.assertEqual(result.tranche.bond_amount, first.tranche.bond_amount)
        self.assertEqual(result.offer.eligible_at_timestamp, 210)
        self.assertEqual(result.offer.eligible_at_block, 73)
        self.assertGreater(result.offer.quote_sequence, first.offer.quote_sequence)
        self.assertNotEqual(result.offer.offer_id, first.offer.offer_id)
        self.assertEqual(market.offers[first.offer.offer_id].location, model.OfferLocation.NONE)
        self.assertEqual(market.accounting.bond_escrow, 1_000)
        self.assertEqual(market.actual_balance, 1_000)
        self.assert_rejects_unchanged(
            market,
            lambda: market.request_pending_exit(
                addr("alice"), first.offer.offer_id, model.Clock(220, 80)
            ),
        )
        self.assert_rejects_unchanged(
            market,
            lambda: market.requote(
                caller=addr("alice"), offer_id=first.offer.offer_id,
                payout=addr("stale"), ask_wei_per_second=39,
                target=addr("settlement-v1"), generation=7,
                clock=model.Clock(220, 80),
            ),
        )

    def test_same_ask_changed_payout_is_allowed(self):
        market = make_market()
        first = insert(market, "alice", 50)
        result = market.requote(
            caller=addr("alice"), offer_id=first.offer.offer_id,
            payout=addr("new-payout"), ask_wei_per_second=50,
            target=addr("settlement-v1"), generation=7,
            clock=model.Clock(200, 100),
        )
        self.assertEqual(result.offer.payout, addr("new-payout"))

    def test_wrong_caller_noop_upward_zero_payout_max_and_stale_bindings_reject_unchanged(self):
        market = make_market()
        first = insert(market, "alice", 50, payout="alice-payout")
        common = dict(
            caller=addr("alice"), offer_id=first.offer.offer_id,
            payout=addr("new"), ask_wei_per_second=40,
            target=addr("settlement-v1"), generation=7,
            clock=model.Clock(200, 100),
        )
        cases = []
        for changes in (
            {"caller": addr("mallory")},
            {"payout": addr("alice-payout"), "ask_wei_per_second": 50},
            {"ask_wei_per_second": 51},
            {"payout": ""},
            {"ask_wei_per_second": 101},
            {"offer_id": b"stale"},
            {"target": addr("evil")},
            {"generation": 6},
        ):
            args = {**common, **changes}
            cases.append(lambda args=args: market.requote(**args))
        for case in cases:
            self.assert_rejects_unchanged(market, case)

    def test_requote_maximum_ask_boundaries(self):
        for ask in (99, 100):
            market = make_market()
            first = insert(market, "alice", 100, payout="old")
            market.requote(
                caller=addr("alice"), offer_id=first.offer.offer_id,
                payout=addr("new"), ask_wei_per_second=ask,
                target=addr("settlement-v1"), generation=7,
                clock=model.Clock(200, 100),
            )
        market = make_market()
        first = insert(market, "alice", 100)
        self.assert_rejects_unchanged(
            market,
            lambda: market.requote(
                caller=addr("alice"), offer_id=first.offer.offer_id,
                payout=addr("new"), ask_wei_per_second=101,
                target=addr("settlement-v1"), generation=7,
                clock=model.Clock(200, 100),
            ),
        )

    def test_quote_sequence_uses_full_uint256_and_never_wraps(self):
        market = make_market(starting_quote_sequence=model.UINT256_MAX - 2)
        first = insert(market, "alice", 50)
        self.assertEqual(first.offer.quote_sequence, model.UINT256_MAX - 1)
        second = market.requote(
            caller=addr("alice"), offer_id=first.offer.offer_id,
            payout=addr("new"), ask_wei_per_second=49,
            target=addr("settlement-v1"), generation=7,
            clock=model.Clock(200, 100),
        )
        self.assertEqual(second.offer.quote_sequence, model.UINT256_MAX)
        self.assertEqual(len(second.offer.offer_id), 32)
        self.assert_rejects_unchanged(
            market,
            lambda: market.requote(
                caller=addr("alice"), offer_id=second.offer.offer_id,
                payout=addr("newer"), ask_wei_per_second=48,
                target=addr("settlement-v1"), generation=7,
                clock=model.Clock(300, 200),
            ),
        )

    def test_terminal_tranche_never_reenters_offer(self):
        market = make_market()
        row = insert(market, "alice", 50)
        market.request_pending_exit(
            addr("alice"), row.offer.offer_id, model.Clock(100, 50)
        )
        self.assert_rejects_unchanged(
            market,
            lambda: market.requote(
                caller=addr("alice"), offer_id=row.offer.offer_id,
                payout=addr("new"), ask_wei_per_second=40,
                target=addr("settlement-v1"), generation=7,
                clock=model.Clock(200, 100),
            ),
        )


class PendingExitTests(AtomicAssertions):
    def test_exit_frees_capacity_but_keeps_bond_until_equality(self):
        market = make_market()
        rows = [insert(market, f"op-{i}", i) for i in range(4)]
        row = rows[0]
        result = market.request_pending_exit(
            addr("op-0"), row.offer.offer_id, model.Clock(100, 50)
        )
        tranche = market.tranches[row.tranche.tranche_id]
        self.assertEqual(market.pending_count, 3)
        self.assertEqual(tranche.usage, model.TrancheUsage.CLOSED_UNINSTALLED)
        self.assertEqual(tranche.pending_refund_at, 120)
        self.assertEqual(tranche.disposition, model.BondDisposition.NONE)
        self.assertEqual(market.accounting.bond_escrow, 4_000)
        insert(market, "new", 9)
        self.assertEqual(market.pending_count, 4)
        self.assertIsNone(result.credit_id)
        self.assert_rejects_unchanged(
            market,
            lambda: market.finalize_pending_exit(row.tranche.tranche_id, model.Clock(119, 99)),
        )
        finalized = market.finalize_pending_exit(row.tranche.tranche_id, model.Clock(120, 99))
        credit = market.credits[finalized.credit_id]
        self.assertEqual(
            (credit.beneficiary, credit.amount), (addr("op-0"), 1_000)
        )
        self.assertEqual(market.accounting.bond_escrow, 4_000)
        self.assertEqual(market.accounting.outstanding_owner_credits, 1_000)
        market.assert_valid()

    def test_after_refund_boundary_is_also_valid(self):
        market = make_market()
        row = insert(market, "alice", 1)
        market.request_pending_exit(
            addr("alice"), row.offer.offer_id, model.Clock(100, 50)
        )
        market.finalize_pending_exit(row.tranche.tranche_id, model.Clock(121, 51))

    def test_wrong_caller_stale_offer_and_repeated_terminalization_reject_without_mutation(self):
        market = make_market()
        row = insert(market, "alice", 1)
        self.assert_rejects_unchanged(
            market,
            lambda: market.request_pending_exit(
                addr("mallory"), row.offer.offer_id, model.Clock(100, 50)
            ),
        )
        self.assert_rejects_unchanged(
            market,
            lambda: market.request_pending_exit(
                addr("alice"), b"stale", model.Clock(100, 50)
            ),
        )
        market.request_pending_exit(
            addr("alice"), row.offer.offer_id, model.Clock(100, 50)
        )
        finalized = market.finalize_pending_exit(row.tranche.tranche_id, model.Clock(120, 50))
        self.assert_rejects_unchanged(
            market,
            lambda: market.finalize_pending_exit(row.tranche.tranche_id, model.Clock(121, 51)),
        )
        self.assert_rejects_unchanged(
            market,
            lambda: market._terminalize_owner(row.tranche.tranche_id),
        )
        self.assertIn(finalized.credit_id, market.credits)


class AccountingAndClaimTests(AtomicAssertions):
    def displaced_credit(self, market, operator="owner"):
        row = insert(market, operator, 50)
        market.request_pending_exit(
            addr(operator), row.offer.offer_id, model.Clock(100, 1)
        )
        result = market.finalize_pending_exit(row.tranche.tranche_id, model.Clock(120, 1))
        return result.credit_id

    def test_exact_credit_claim_uses_stored_beneficiary_and_is_replay_safe(self):
        market = make_market()
        credit_id = self.displaced_credit(market)
        transfers = []

        def transfer(beneficiary, amount, _market):
            transfers.append((beneficiary, amount))

        result = market.claim_credit(credit_id, transfer)
        self.assertEqual(result.credit_id, credit_id)
        self.assertEqual(transfers, [(addr("owner"), 1_000)])
        self.assertTrue(market.credits[credit_id].claimed)
        self.assertEqual(market.accounting.outstanding_owner_credits, 0)
        self.assertEqual(market.actual_balance, 0)
        self.assert_rejects_unchanged(market, lambda: market.claim_credit(credit_id, transfer))

    def test_zero_credit_is_unreachable_and_beneficiary_substitution_rejects(self):
        market = make_market()
        credit_id = self.displaced_credit(market)
        market.credits[credit_id].amount = 0
        market.accounting.outstanding_owner_credits = 0
        with self.assertRaisesRegex(
            AssertionError, "exact credit changed immutable beneficiary or amount"
        ):
            market.assert_valid()
        self.assert_rejects_unchanged(
            market, lambda: market.claim_credit(credit_id, lambda *_: None)
        )
        clean = make_market()
        real = self.displaced_credit(clean)
        with self.assertRaises(TypeError):
            clean.claim_credit(real, lambda *_: None, beneficiary="mallory")
        self.assertFalse(clean.credits[real].claimed)

    def test_callback_observes_effects_and_same_credit_reentry_cannot_double_claim(self):
        market = make_market()
        first = self.displaced_credit(market, "first")
        second = self.displaced_credit(market, "second")
        observations = []

        def callback(beneficiary, amount, callback_market):
            observations.append((
                beneficiary,
                amount,
                callback_market.credits[first].claimed,
                callback_market.accounting.outstanding_owner_credits,
                callback_market.actual_balance,
            ))
            with self.assertRaises(model.TransitionRejected):
                callback_market.claim_credit(first, callback)
            callback_market.claim_credit(second, lambda *_: None)

        market.claim_credit(first, callback)
        self.assertEqual(
            observations, [(addr("first"), 1_000, True, 1_000, 1_000)]
        )
        self.assertTrue(market.credits[first].claimed)
        self.assertTrue(market.credits[second].claimed)
        self.assertEqual(market.accounting.outstanding_owner_credits, 0)
        self.assertEqual(market.actual_balance, 0)

    def test_reverting_callback_restores_outer_and_nested_claims_atomically(self):
        market = make_market()
        first = self.displaced_credit(market, "first")
        second = self.displaced_credit(market, "second")
        before = copy.deepcopy(market)

        def callback(_beneficiary, _amount, callback_market):
            callback_market.claim_credit(second, lambda *_: None)
            raise RuntimeError("recipient reverted")

        with self.assertRaisesRegex(RuntimeError, "recipient reverted"):
            market.claim_credit(first, callback)
        self.assertEqual(market, before)
        self.assertFalse(market.credits[first].claimed)
        self.assertFalse(market.credits[second].claimed)

    def test_forced_eth_is_unattributed_surplus(self):
        market = make_market()
        self.displaced_credit(market)
        accounted = market.accounting.accounted_balance
        market.force_eth(777)
        self.assertEqual(market.accounting.accounted_balance, accounted)
        self.assertEqual(market.surplus, 777)
        market.assert_valid()

    def test_credit_identity_is_bound_to_market_chain_address_tranche_and_kind(self):
        tranche = b"t" * 32
        base = make_market()
        owner = base.credit_id(tranche, model.BondDisposition.OWNER_CREDITED)
        variants = {
            make_market(market_chain_id=2).credit_id(
                tranche, model.BondDisposition.OWNER_CREDITED
            ),
            make_market(market_address=addr("other-market")).credit_id(
                tranche, model.BondDisposition.OWNER_CREDITED
            ),
            base.credit_id(b"u" * 32, model.BondDisposition.OWNER_CREDITED),
            base.credit_id(tranche, model.BondDisposition.PENALTY_CREDITED),
        }
        self.assertEqual(len(owner), 32)
        self.assertNotIn(owner, variants)
        self.assertEqual(len(variants), 4)

    def test_penalty_sink_is_immutable_canonical_and_exclusive(self):
        for invalid in ("", "Penalty Sink", "UPPER"):
            with self.assertRaises(model.TransitionRejected):
                make_market(penalty_sink=invalid)
        market = make_market(penalty_sink=addr("penalty-sink"))
        self.assertEqual(market.penalty_sink, addr("penalty-sink"))
        with self.assertRaises((AttributeError, TypeError)):
            market.penalty_sink = "mallory"

        row = insert(market, "alice", 1)
        market.pending_offer_ids.remove(row.offer.offer_id)
        row.offer.location = model.OfferLocation.NONE
        row.tranche.usage = model.TrancheUsage.INSTALLED
        row.tranche.installed_term_id = b"i" * 32
        market.assert_valid()
        penalty_id = market._terminalize_penalty(row.tranche.tranche_id)
        market.assert_valid()
        credit = market.credits[penalty_id]
        self.assertEqual(credit.beneficiary, addr("penalty-sink"))
        self.assertEqual(credit.disposition, model.BondDisposition.PENALTY_CREDITED)
        before = copy.deepcopy(market)
        with self.assertRaises(model.TransitionRejected):
            market._terminalize_penalty(row.tranche.tranche_id)
        self.assertEqual(market, before)
        with self.assertRaises(model.TransitionRejected):
            market._terminalize_owner(row.tranche.tranche_id)

        paid = []
        market.claim_credit(
            penalty_id,
            lambda beneficiary, amount, _market: paid.append((beneficiary, amount)),
        )
        self.assertEqual(paid, [(addr("penalty-sink"), 1_000)])
        self.assert_rejects_unchanged(
            market, lambda: market.claim_credit(penalty_id, lambda *_: None)
        )

    def test_arbitrary_extra_credits_and_coordinated_mallory_surplus_attack_fail(self):
        for claimed in (False, True):
            market = make_market(penalty_sink=addr("penalty-sink"))
            row = insert(market, "alice", 1)
            market.force_eth(1_000)
            junk = (b"j" if claimed else b"u") * 32
            market.credits[junk] = model.ExactCredit(
                credit_id=junk,
                tranche_id=row.tranche.tranche_id,
                beneficiary=addr("alice"),
                amount=1_000,
                disposition=model.BondDisposition.NONE,
                claimed=claimed,
            )
            with self.assertRaises(AssertionError):
                market.assert_valid()

        coordinated = make_market(penalty_sink=addr("penalty-sink"))
        victim = insert(coordinated, "alice", 1)
        coordinated.force_eth(1_000)
        victim.offer.operator = addr("mallory")
        victim.tranche.operator = addr("mallory")
        victim.offer.location = model.OfferLocation.NONE
        coordinated.pending_offer_ids.clear()
        victim.tranche.usage = model.TrancheUsage.CLOSED_UNINSTALLED
        victim.tranche.disposition = model.BondDisposition.OWNER_CREDITED
        owner_id = coordinated.credit_id(
            victim.tranche.tranche_id, model.BondDisposition.OWNER_CREDITED
        )
        coordinated.credits[owner_id] = model.ExactCredit(
            credit_id=owner_id,
            tranche_id=victim.tranche.tranche_id,
            beneficiary=addr("mallory"),
            amount=1_000,
            disposition=model.BondDisposition.OWNER_CREDITED,
        )
        coordinated.accounting.bond_escrow = 0
        coordinated.accounting.outstanding_owner_credits = 1_000
        with self.assertRaises(AssertionError):
            coordinated.assert_valid()

    def test_accounting_covers_reserves_claims_and_rejects_short_balance(self):
        accounting = model.MarketAccounting(
            bond_escrow=10,
            outstanding_owner_credits=20,
            outstanding_penalty_credits=30,
            free_premium=40,
            reserved_premium=50,
            outstanding_premium_claims=60,
            live_reserves={b"r": model.PremiumReserve(b"r", 50)},
        )
        self.assertEqual(accounting.accounted_balance, 210)
        accounting.assert_valid(210)
        with self.assertRaises(AssertionError):
            accounting.assert_valid(209)
        accounting.live_reserves[b"r"].reserved_wei = 49
        with self.assertRaises(AssertionError):
            accounting.assert_valid(210)


class EdgeMatrixTests(AtomicAssertions):
    MUTATING_PUBLIC_EVENTS = {
        "insert_offer",
        "requote",
        "request_pending_exit",
        "finalize_pending_exit",
        "sync_seat_generation",
        "claim_credit",
        "force_eth",
    }
    TASK3_MUTATING_PUBLIC_EVENTS = {
        "sponsor_premium",
        "stage_best",
        "expire_stage",
        "invalidate_stage",
        "cancel_stage_for_migration",
        "install_stage",
        "accrue_premium",
        "close_reserve",
        "reconcile_tail",
        "request_release",
        "finalize_release",
        "enforce_breach",
        "claim_premium_credit",
    }

    def staged_fixture(self):
        market = make_market()
        row = insert(market, "alice", 50)
        market.pending_offer_ids.clear()
        row.offer.location = model.OfferLocation.STAGED
        row.tranche.usage = model.TrancheUsage.STAGED
        market.stage = model.Stage(b"s" * 32, row.offer.offer_id)
        market.assert_valid()
        return market, row

    def closed_fixture(self, credited=False):
        market = make_market()
        row = insert(market, "alice", 50)
        market.request_pending_exit(
            addr("alice"), row.offer.offer_id, model.Clock(100, 50)
        )
        if credited:
            result = market.finalize_pending_exit(
                row.tranche.tranche_id, model.Clock(120, 50)
            )
            return market, row, result.credit_id
        market.assert_valid()
        return market, row, None

    def installed_fixture(self, penalized=False):
        market = make_market(penalty_sink=addr("penalty-sink"))
        row = insert(market, "alice", 50)
        market.pending_offer_ids.clear()
        row.offer.location = model.OfferLocation.NONE
        row.tranche.usage = model.TrancheUsage.INSTALLED
        row.tranche.installed_term_id = b"i" * 32
        market.assert_valid()
        credit_id = None
        if penalized:
            credit_id = market._terminalize_penalty(row.tranche.tranche_id)
            market.assert_valid()
        return market, row, credit_id

    def test_public_mutation_surface_is_exhaustively_named(self):
        public_functions = {
            name
            for name, value in inspect.getmembers(model.SeatMarket, inspect.isfunction)
            if not name.startswith("_")
        }
        self.assertEqual(
            public_functions,
            self.MUTATING_PUBLIC_EVENTS
            | self.TASK3_MUTATING_PUBLIC_EVENTS
            | {"assert_valid", "credit_id", "is_duty_history_safe"},
        )

    def test_complete_public_event_success_matrix_uses_only_valid_fixtures(self):
        covered = set()

        accepted_market = make_market()
        accepted_market.assert_valid()
        accepted = insert(accepted_market, "alice", 10)
        covered.add("insert_offer")
        self.assertEqual(accepted_market.pending_count, 1)
        self.assertEqual(accepted_market.accounting.bond_escrow, 1_000)
        accepted_market.assert_valid()

        displaced_market = make_market()
        for index, ask in enumerate((10, 20, 30, 40)):
            insert(displaced_market, f"op-{index}", ask)
        displaced_market.assert_valid()
        displaced = insert(displaced_market, "best", 1)
        self.assertIsNotNone(displaced.displaced_offer_id)
        self.assertEqual(displaced_market.pending_count, 4)
        self.assertEqual(displaced_market.accounting.outstanding_owner_credits, 1_000)
        displaced_market.assert_valid()

        requote_market = make_market()
        quote = insert(requote_market, "alice", 20)
        requote_market.assert_valid()
        requoted = requote_market.requote(
            caller=addr("alice"), offer_id=quote.offer.offer_id,
            payout=addr("new"), ask_wei_per_second=19,
            target=addr("settlement-v1"), generation=7,
            clock=model.Clock(200, 100),
        )
        covered.add("requote")
        self.assertEqual(requoted.offer.ask_wei_per_second, 19)
        self.assertEqual(requote_market.accounting.bond_escrow, 1_000)
        requote_market.assert_valid()

        exit_market = make_market()
        exiting = insert(exit_market, "alice", 20)
        exit_market.assert_valid()
        exit_market.request_pending_exit(
            addr("alice"), exiting.offer.offer_id, model.Clock(100, 50)
        )
        covered.add("request_pending_exit")
        self.assertEqual(exit_market.pending_count, 0)
        self.assertEqual(exit_market.accounting.bond_escrow, 1_000)
        exit_market.assert_valid()
        finalized = exit_market.finalize_pending_exit(
            exiting.tranche.tranche_id, model.Clock(120, 50)
        )
        covered.add("finalize_pending_exit")
        self.assertEqual(exit_market.accounting.bond_escrow, 0)
        self.assertEqual(exit_market.accounting.outstanding_owner_credits, 1_000)
        exit_market.assert_valid()

        equal_sync_market = make_market()
        insert(equal_sync_market, "alice", 10)
        equal_sync_market.assert_valid()
        equal_before = copy.deepcopy(equal_sync_market)
        equal = equal_sync_market.sync_seat_generation(target_view(7))
        covered.add("sync_seat_generation")
        self.assertEqual(equal.purged_count, 0)
        self.assertEqual(equal_sync_market, equal_before)

        purge_market = make_market()
        insert(purge_market, "alice", 10)
        purge_market.assert_valid()
        purged = purge_market.sync_seat_generation(target_view(8))
        self.assertEqual(purged.purged_count, 1)
        self.assertEqual(purge_market.cached_generation, 8)
        self.assertEqual(purge_market.accounting.outstanding_owner_credits, 1_000)
        purge_market.assert_valid()

        claim_market, _claim_row, owner_credit = self.closed_fixture(credited=True)
        claim_market.assert_valid()
        claim_market.claim_credit(owner_credit, lambda *_: None)
        covered.add("claim_credit")
        self.assertEqual(claim_market.accounting.outstanding_owner_credits, 0)
        claim_market.assert_valid()

        penalty_market, _penalty_row, penalty_credit = self.installed_fixture(
            penalized=True
        )
        penalty_market.assert_valid()
        penalty_market.claim_credit(penalty_credit, lambda *_: None)
        self.assertEqual(penalty_market.accounting.outstanding_penalty_credits, 0)
        penalty_market.assert_valid()

        forced_market = make_market()
        forced_market.assert_valid()
        forced_market.force_eth(7)
        covered.add("force_eth")
        self.assertEqual(forced_market.surplus, 7)
        forced_market.assert_valid()

        self.assertEqual(covered, self.MUTATING_PUBLIC_EVENTS)
        self.assertIsNotNone(finalized.credit_id)

    def test_pending_only_event_matrix_rejects_other_valid_reachable_states(self):
        fixtures = [
            self.staged_fixture(),
            self.closed_fixture(credited=False)[:2],
            self.closed_fixture(credited=True)[:2],
            self.installed_fixture(penalized=False)[:2],
            self.installed_fixture(penalized=True)[:2],
        ]
        for market, row in fixtures:
            market.assert_valid()
            self.assert_rejects_unchanged(
                market,
                lambda market=market, row=row: market.requote(
                    caller=addr("alice"), offer_id=row.offer.offer_id,
                    payout=addr("new"), ask_wei_per_second=40,
                    target=addr("settlement-v1"), generation=7,
                    clock=model.Clock(200, 100),
                ),
            )
            self.assert_rejects_unchanged(
                market,
                lambda market=market, row=row: market.request_pending_exit(
                    addr("alice"), row.offer.offer_id, model.Clock(200, 100)
                ),
            )

        finalize_reject_fixtures = [
            (make_market(), None),
            self.staged_fixture(),
            self.closed_fixture(credited=True)[:2],
            self.installed_fixture(penalized=False)[:2],
            self.installed_fixture(penalized=True)[:2],
        ]
        empty_market, _ = finalize_reject_fixtures[0]
        empty_market.assert_valid()
        self.assert_rejects_unchanged(
            empty_market,
            lambda: empty_market.finalize_pending_exit(
                b"x" * 32, model.Clock(200, 100)
            ),
        )
        for market, row in finalize_reject_fixtures[1:]:
            market.assert_valid()
            self.assert_rejects_unchanged(
                market,
                lambda market=market, row=row: market.finalize_pending_exit(
                    row.tranche.tranche_id, model.Clock(200, 100)
                ),
            )

    def test_every_public_event_has_a_valid_fixture_atomic_rejection_row(self):
        full = make_market()
        for index, ask in enumerate((10, 20, 30, 40)):
            insert(full, f"op-{index}", ask)

        staged, staged_row = self.staged_fixture()

        closed, closed_row, _ = self.closed_fixture(credited=False)

        pending_finalize = make_market()
        pending_row = insert(pending_finalize, "alice", 10)

        stale_sync = make_market()
        insert(stale_sync, "alice", 10)

        claimed, _claimed_row, claimed_credit = self.closed_fixture(credited=True)
        claimed.claim_credit(claimed_credit, lambda *_: None)

        forced = make_market()

        rows = {
            "insert_offer": (
                full,
                lambda: insert(full, "worse", 100),
            ),
            "requote": (
                staged,
                lambda: staged.requote(
                    caller=addr("alice"), offer_id=staged_row.offer.offer_id,
                    payout=addr("new"), ask_wei_per_second=40,
                    target=addr("settlement-v1"), generation=7,
                    clock=model.Clock(200, 100),
                ),
            ),
            "request_pending_exit": (
                closed,
                lambda: closed.request_pending_exit(
                    addr("alice"), closed_row.offer.offer_id, model.Clock(200, 100)
                ),
            ),
            "finalize_pending_exit": (
                pending_finalize,
                lambda: pending_finalize.finalize_pending_exit(
                    pending_row.tranche.tranche_id, model.Clock(200, 100)
                ),
            ),
            "sync_seat_generation": (
                stale_sync,
                lambda: stale_sync.sync_seat_generation(target_view(6)),
            ),
            "claim_credit": (
                claimed,
                lambda: claimed.claim_credit(claimed_credit, lambda *_: None),
            ),
            "force_eth": (
                forced,
                lambda: forced.force_eth(-1),
            ),
        }
        self.assertEqual(set(rows), self.MUTATING_PUBLIC_EVENTS)
        for event, (market, call) in rows.items():
            with self.subTest(event=event):
                market.assert_valid()
                before = copy.deepcopy(market)
                with self.assertRaises(model.TransitionRejected):
                    call()
                self.assertEqual(market, before)

    def test_unreachable_task2_enum_combinations_fail_invariant_without_public_call(self):
        reachable = {
            (model.OfferLocation.PENDING, model.TrancheUsage.OFFER, model.BondDisposition.NONE),
            (model.OfferLocation.STAGED, model.TrancheUsage.STAGED, model.BondDisposition.NONE),
            (model.OfferLocation.NONE, model.TrancheUsage.CLOSED_UNINSTALLED, model.BondDisposition.NONE),
            (model.OfferLocation.NONE, model.TrancheUsage.CLOSED_UNINSTALLED, model.BondDisposition.OWNER_CREDITED),
        }
        all_edges = set(itertools.product(
            model.OfferLocation, model.TrancheUsage, model.BondDisposition
        ))
        for location, usage, disposition in all_edges - reachable:
            market = make_market()
            row = insert(market, "alice", 50)
            market.pending_offer_ids.clear()
            market.stage = None
            row.offer.location = location
            row.tranche.usage = usage
            row.tranche.disposition = disposition
            row.tranche.pending_refund_at = (
                120 if usage is model.TrancheUsage.CLOSED_UNINSTALLED else None
            )
            if location is model.OfferLocation.PENDING:
                market.pending_offer_ids.append(row.offer.offer_id)
            elif location is model.OfferLocation.STAGED:
                market.stage = model.Stage(b"s" * 32, row.offer.offer_id)
            with self.assertRaises(AssertionError):
                market.assert_valid()

    def test_terminal_closed_tranche_cannot_bind_a_new_quote(self):
        market = make_market()
        row = insert(market, "alice", 10)
        market.request_pending_exit(
            addr("alice"), row.offer.offer_id, model.Clock(10, 10)
        )
        market.finalize_pending_exit(row.tranche.tranche_id, model.Clock(30, 30))
        for event in ("requote", "request_exit"):
            if event == "requote":
                call = lambda: market.requote(
                    caller=addr("alice"), offer_id=row.offer.offer_id,
                    payout=addr("new"), ask_wei_per_second=9,
                    target=addr("settlement-v1"), generation=7,
                    clock=model.Clock(40, 40),
                )
            else:
                call = lambda: market.request_pending_exit(
                    addr("alice"), row.offer.offer_id, model.Clock(40, 40)
                )
            self.assert_rejects_unchanged(market, call)


class ArithmeticAndInputTests(AtomicAssertions):
    def test_checked_arithmetic_boundaries(self):
        self.assertEqual(model.checked_add(model.UINT256_MAX - 1, 1), model.UINT256_MAX)
        with self.assertRaises(model.ArithmeticFault):
            model.checked_add(model.UINT256_MAX, 1)
        self.assertEqual(model.checked_sub(1, 1), 0)
        with self.assertRaises(model.ArithmeticFault):
            model.checked_sub(0, 1)
        for invalid in (-1, model.UINT256_MAX + 1, True, "1"):
            with self.assertRaises((model.ArithmeticFault, TypeError)):
                model.checked_add(invalid, 0)

    def test_constructor_and_clock_reject_out_of_range_values(self):
        for changes in (
            {"sla_bond": 0},
            {"immutable_maximum_ask": model.UINT256_MAX + 1},
            {"quote_maturity_seconds": -1},
        ):
            with self.assertRaises((model.ArithmeticFault, model.TransitionRejected)):
                make_market(**changes)
        market = make_market()
        self.assert_rejects_unchanged(
            market,
            lambda: insert(market, "alice", 1, clock=model.Clock(-1, 1)),
        )

    def test_creation_sequence_reaches_uint256_max_then_fails_without_wrap(self):
        market = make_market(starting_creation_sequence=model.UINT256_MAX - 2)
        first = insert(market, "alice", 1)
        second = insert(market, "bob", 2)
        self.assertEqual(first.tranche.creation_sequence, model.UINT256_MAX - 1)
        self.assertEqual(second.tranche.creation_sequence, model.UINT256_MAX)
        self.assert_rejects_unchanged(market, lambda: insert(market, "carol", 3))

    def test_saturated_sequence_state_is_representable_but_cannot_allocate(self):
        quote_saturated = make_market(starting_quote_sequence=model.UINT256_MAX)
        quote_saturated.assert_valid()
        self.assert_rejects_unchanged(
            quote_saturated, lambda: insert(quote_saturated, "alice", 1)
        )
        creation_saturated = make_market(
            starting_creation_sequence=model.UINT256_MAX
        )
        creation_saturated.assert_valid()
        self.assert_rejects_unchanged(
            creation_saturated, lambda: insert(creation_saturated, "alice", 1)
        )


def lineup(*terms, generation=7, commitment=b"L" * 32):
    auth = authorization()
    return model.LineupSnapshot(
        target=auth.target,
        authorization_id=model.authorization_identity(1, addr("market"), auth),
        generation=generation,
        commitment=commitment,
        terms=tuple(terms),
    )


def lineup_term(
    label="primary",
    ask=50,
    minimum_tenure_until=100,
    service_eligible_until=1_000,
    healthy=True,
):
    return model.LineupTerm(
        term_id=(label.encode("ascii")[:1] or b"t") * 32,
        tranche_id=(label.encode("ascii")[-1:] or b"r") * 32,
        offer_id=b"o" * 32,
        operator=addr(f"op-{label}"),
        payout=addr(f"pay-{label}"),
        ask_wei_per_second=ask,
        minimum_tenure_until=minimum_tenure_until,
        service_eligible_until=service_eligible_until,
        healthy=healthy,
    )


def stage_and_install(market, operator="alice", ask=5, term_id=b"T" * 32):
    market.sponsor_premium(ask * market.seat_runway_seconds)
    row = insert(market, operator, ask)
    result = market.stage_best(lineup(), model.Clock(110, 53))
    if result.code is not model.ResultCode.STAGED:
        raise AssertionError("test fixture did not stage")
    market.install_stage(installation_view(market, result.stage, term_id))
    return row, term_id


def installation_view(market, stage, term_id, applied_at=None):
    return model.InstallationView(
        target=market.authorization.target,
        authorization_id=market.current_authorization_id,
        generation=market.cached_generation,
        stage_id=stage.stage_id,
        term_id=term_id,
        offer_id=stage.offer_id,
        lineup_commitment=stage.lineup_commitment,
        applied_at=stage.handover_at if applied_at is None else applied_at,
    )


def service_view(
    row,
    term_id,
    *,
    start=120,
    funded_until=220,
    cap=170,
    closed=False,
    refundable=False,
    disposition_at=None,
    last_liability_at=None,
    duty_id=b"D" * 32,
    duty_disposition="NONE",
    breached=False,
    breach_recorded_at=None,
    roster_occupied=False,
    history_retained=True,
):
    auth = authorization()
    return model.ServiceView(
        target=auth.target,
        authorization_id=row.tranche.authorization_id,
        settlement_chain_id=auth.settlement_chain_id,
        protocol_version=auth.protocol_version,
        runtime_hash=auth.runtime_hash,
        configuration_hash=auth.configuration_hash,
        magic=auth.expected_magic,
        generation=7,
        term_id=term_id,
        tranche_id=row.tranche.tranche_id,
        offer_id=row.offer.offer_id,
        operator=row.tranche.operator,
        payout=row.offer.payout,
        ask_wei_per_second=row.offer.ask_wei_per_second,
        responsibility_start=start,
        premium_funded_until=funded_until,
        settlement_cap=cap,
        closed=closed,
        refundable=refundable,
        disposition_at=disposition_at,
        last_liability_at=last_liability_at,
        duty_id=duty_id,
        duty_disposition=duty_disposition,
        breached=breached,
        breach_recorded_at=breach_recorded_at,
        roster_occupied=roster_occupied,
        history_retained=history_retained,
    )


class Task3StagingTests(AtomicAssertions):
    def test_pretenure_standby_uses_its_own_short_deadline_not_primary_tenure(self):
        for service_eligible_until, expected in (
            (124, model.ResultCode.NO_FEASIBLE_OFFER),
            (125, model.ResultCode.STAGED),
            (126, model.ResultCode.STAGED),
        ):
            market = make_market()
            market.sponsor_premium(1_100)
            insert(market, f"sb-{service_eligible_until}", 11)
            primary = lineup_term(
                ask=10,
                minimum_tenure_until=1_000,
                service_eligible_until=service_eligible_until,
            )
            result = market.stage_best(lineup(primary), model.Clock(110, 53))
            self.assertEqual(result.code, expected)
            if expected is model.ResultCode.STAGED:
                self.assertEqual(result.stage.handover_at, 115)
                self.assertEqual(result.stage.expires_at, 120)

    def test_shared_capacity_trace_stage_insert_displace_and_exact_restore(self):
        market = make_market()
        market.sponsor_premium(10_000)
        rows = [insert(market, name, ask) for name, ask in zip("ABCD", (1, 2, 3, 4))]
        staged = market.stage_best(lineup(), model.Clock(110, 53))
        self.assertEqual((market.pending_count, market.staged_count), (3, 1))
        self.assertEqual(staged.offer.offer_id, rows[0].offer.offer_id)
        fifth = insert(market, "E", 3)
        self.assertEqual((market.pending_count, market.staged_count), (3, 1))
        self.assertEqual(fifth.displaced_offer_id, rows[3].offer.offer_id)
        market.expire_stage(staged.stage.stage_id, model.Clock(staged.stage.expires_at, 53))
        self.assertEqual((market.pending_count, market.staged_count), (4, 0))
        self.assertIn(rows[0].offer.offer_id, market.pending_offer_ids)
        self.assertEqual(market.accounting.reserved_premium, 0)
        market.assert_valid()

    def test_maturity_empty_roster_standby_and_replacement_boundaries(self):
        for clock, expected in (
            (model.Clock(109, 53), model.ResultCode.NO_FEASIBLE_OFFER),
            (model.Clock(110, 52), model.ResultCode.NO_FEASIBLE_OFFER),
            (model.Clock(110, 53), model.ResultCode.STAGED),
            (model.Clock(111, 54), model.ResultCode.STAGED),
        ):
            market = make_market()
            market.sponsor_premium(10_000)
            insert(market, "alice", 9)
            self.assertEqual(market.stage_best(lineup(), clock).code, expected)

        primary = lineup_term(ask=10, minimum_tenure_until=200)
        replacement = make_market()
        replacement.sponsor_premium(900)
        insert(replacement, "alice", 9)
        result = replacement.stage_best(lineup(primary), model.Clock(110, 53))
        self.assertEqual(result.stage.selected_rank, 0)
        self.assertEqual(result.stage.outgoing_primary_term_id, primary.term_id)
        self.assertEqual(result.stage.handover_at, 200)

        standby = make_market()
        standby.sponsor_premium(1_100)
        insert(standby, "bob", 11)
        result = standby.stage_best(lineup(primary), model.Clock(110, 53))
        self.assertEqual(result.stage.selected_rank, 1)
        self.assertIsNone(result.stage.outgoing_primary_term_id)
        self.assertEqual(result.stage.handover_at, 115)

    def test_structural_infeasibility_is_skipped_but_first_feasible_underfunded_stops(self):
        # The best quote is structurally poisoned only by being immature; the
        # later mature quote must still stage.
        market = make_market()
        market.sponsor_premium(1_000)
        insert(market, "immature", 1, clock=model.Clock(105, 50))
        mature = insert(market, "mature", 2, clock=model.Clock(100, 50))
        result = market.stage_best(lineup(), model.Clock(110, 53))
        self.assertEqual(result.offer.offer_id, mature.offer.offer_id)

        underfunded = make_market()
        insert(underfunded, "best", 2)
        insert(underfunded, "later", 3)
        underfunded.sponsor_premium(199)
        before = copy.deepcopy(underfunded)
        result = underfunded.stage_best(lineup(), model.Clock(110, 53))
        self.assertEqual(result.code, model.ResultCode.UNDERFUNDED)
        self.assertEqual(result.offer.ask_wei_per_second, 2)
        self.assertEqual(underfunded, before)
        underfunded.sponsor_premium(1)
        self.assertEqual(
            underfunded.stage_best(lineup(), model.Clock(110, 53)).code,
            model.ResultCode.STAGED,
        )

    def test_live_primary_headroom_and_gross_reserve_do_not_use_outgoing_release(self):
        primary = lineup_term(
            ask=10, minimum_tenure_until=200, service_eligible_until=209
        )
        market = make_market()
        market.sponsor_premium(10_000)
        insert(market, "alice", 9)
        before = copy.deepcopy(market)
        self.assertEqual(
            market.stage_best(lineup(primary), model.Clock(110, 53)).code,
            model.ResultCode.NO_FEASIBLE_OFFER,
        )
        self.assertEqual(market, before)

        # A large incumbent reserve exists, but only current freePremium counts.
        incumbent = make_market()
        old, old_term = stage_and_install(incumbent, "old", 50, b"O" * 32)
        challenger = insert(incumbent, "new", 9)
        active = model.LineupTerm(
            term_id=old_term,
            tranche_id=old.tranche.tranche_id,
            offer_id=old.offer.offer_id,
            operator=old.tranche.operator,
            payout=old.offer.payout,
            ask_wei_per_second=50,
            minimum_tenure_until=100,
            service_eligible_until=1_000,
        )
        self.assertEqual(incumbent.accounting.free_premium, 0)
        result = incumbent.stage_best(lineup(active), model.Clock(110, 53))
        self.assertEqual(result.code, model.ResultCode.UNDERFUNDED)
        self.assertEqual(result.offer.offer_id, challenger.offer.offer_id)

    def test_monotone_sponsorship_and_rank_is_not_caller_controlled(self):
        for funding in range(0, 1_001, 37):
            market = make_market()
            insert(market, "a", 3)
            insert(market, "b", 5)
            market.sponsor_premium(funding)
            result = market.stage_best(lineup(), model.Clock(110, 53))
            if funding < 300:
                self.assertEqual(result.code, model.ResultCode.UNDERFUNDED)
            else:
                self.assertEqual(result.code, model.ResultCode.STAGED)
                self.assertEqual(result.offer.ask_wei_per_second, 3)
        with self.assertRaises(TypeError):
            make_market().stage_best(lineup(), model.Clock(110, 53), rank=3)

    def test_every_declared_stage_fault_rolls_back_byte_identically(self):
        stage_faults = (
            "after_candidate_selection",
            "after_reserve_debit",
            "after_offer_location_change",
            "after_tranche_usage_change",
        )
        for fault in stage_faults:
            market = make_market()
            market.sponsor_premium(1_000)
            insert(market, fault[-8:], 5)
            market.fault_point = fault
            self.assert_rejects_unchanged(
                market,
                lambda market=market: market.stage_best(
                    lineup(), model.Clock(110, 53)
                ),
                RuntimeError,
            )
        for fault in ("after_reserve_rekey", "after_stage_clear"):
            market = make_market()
            market.sponsor_premium(1_000)
            insert(market, fault[-8:], 5)
            staged = market.stage_best(lineup(), model.Clock(110, 53))
            market.fault_point = fault
            self.assert_rejects_unchanged(
                market,
                lambda market=market, staged=staged: market.install_stage(
                    installation_view(market, staged.stage, b"T" * 32)
                ),
                RuntimeError,
            )
        market = make_market()
        market.sponsor_premium(1_000)
        insert(market, "credit", 5)
        staged = market.stage_best(lineup(), model.Clock(110, 53))
        market.fault_point = "after_credit_creation"
        self.assert_rejects_unchanged(
            market,
            lambda: market.cancel_stage_for_migration(
                staged.stage.stage_id,
                staged.stage.lineup_commitment,
                model.Clock(120, 53),
            ),
            RuntimeError,
        )

    def test_expiry_invalidation_migration_and_install_match_section_4_4(self):
        # Ordinary expiry and authenticated lineup invalidation restore the
        # exact staged offer without terminalizing its bond.
        for event in ("expire", "invalidate"):
            market = make_market()
            market.sponsor_premium(500)
            row = insert(market, event, 5)
            staged = market.stage_best(lineup(), model.Clock(110, 53))
            if event == "expire":
                self.assert_rejects_unchanged(
                    market,
                    lambda: market.expire_stage(
                        staged.stage.stage_id,
                        model.Clock(staged.stage.expires_at - 1, 53),
                    ),
                )
                market.expire_stage(
                    staged.stage.stage_id,
                    model.Clock(staged.stage.expires_at, 53),
                )
            else:
                self.assert_rejects_unchanged(
                    market,
                    lambda: market.invalidate_stage(
                        staged.stage.stage_id, b"X" * 32
                    ),
                )
                market.invalidate_stage(
                    staged.stage.stage_id, staged.stage.lineup_commitment
                )
            tranche = market.tranches[row.tranche.tranche_id]
            self.assertEqual(tranche.usage, model.TrancheUsage.OFFER)
            self.assertEqual(tranche.disposition, model.BondDisposition.NONE)
            self.assertEqual(
                market.offers[row.offer.offer_id].location,
                model.OfferLocation.PENDING,
            )

        migration = make_market()
        migration.sponsor_premium(500)
        row = insert(migration, "migration", 5)
        staged = migration.stage_best(lineup(), model.Clock(110, 53))
        result = migration.cancel_stage_for_migration(
            staged.stage.stage_id,
            staged.stage.lineup_commitment,
            model.Clock(120, 53),
        )
        self.assertEqual(
            migration.tranches[row.tranche.tranche_id].usage,
            model.TrancheUsage.CLOSED_UNINSTALLED,
        )
        self.assertEqual(
            migration.tranches[row.tranche.tranche_id].disposition,
            model.BondDisposition.OWNER_CREDITED,
        )
        self.assertEqual(
            migration.credits[result.credit_id].beneficiary, row.tranche.operator
        )

        installed = make_market()
        installed.sponsor_premium(500)
        row = insert(installed, "installed", 5)
        staged = installed.stage_best(lineup(), model.Clock(110, 53))
        installed.install_stage(
            installation_view(installed, staged.stage, b"I" * 32)
        )
        tranche = installed.tranches[row.tranche.tranche_id]
        self.assertEqual(tranche.usage, model.TrancheUsage.INSTALLED)
        self.assertEqual(tranche.disposition, model.BondDisposition.NONE)
        self.assertEqual(
            installed.accounting.live_reserves[b"I" * 32].owner_id, b"I" * 32
        )

    def test_higher_generation_sync_preserves_stage_but_stale_install_fails_closed(self):
        market = make_market()
        market.sponsor_premium(500)
        row = insert(market, "old-stage", 5)
        staged = market.stage_best(lineup(), model.Clock(110, 53))
        stage_before = copy.deepcopy(market.stage)
        market.sync_seat_generation(target_view(8))
        self.assertEqual(market.stage, stage_before)
        self.assertEqual(market.cached_generation, 8)
        stale_install = installation_view(market, staged.stage, b"I" * 32)
        stale_install = replace(stale_install, generation=7)
        self.assert_rejects_unchanged(
            market, lambda: market.install_stage(stale_install)
        )
        # Only the authenticated migration tombstone path owns the old stage.
        result = market.cancel_stage_for_migration(
            staged.stage.stage_id,
            staged.stage.lineup_commitment,
            model.Clock(120, 53),
        )
        self.assertEqual(
            market.tranches[row.tranche.tranche_id].disposition,
            model.BondDisposition.OWNER_CREDITED,
        )
        self.assertIsNotNone(result.credit_id)

    def test_posttenure_timestamp_skip_and_equal_sync_keep_funded_stage_installable(self):
        primary = lineup_term(
            ask=10,
            minimum_tenure_until=200,
            service_eligible_until=400,
        )
        for applied_at, succeeds in ((199, False), (200, True), (205, True), (206, False)):
            market = make_market()
            market.sponsor_premium(900)
            insert(market, f"pt-{applied_at}", 9)
            staged = market.stage_best(
                lineup(primary), model.Clock(110, 53)
            )
            self.assertEqual(staged.stage.handover_at, 200)
            self.assertEqual(staged.stage.expires_at, 205)
            before_sync = copy.deepcopy(market)
            self.assertEqual(
                market.sync_seat_generation(target_view(7)).purged_count, 0
            )
            self.assertEqual(market, before_sync)
            install = installation_view(
                market, staged.stage, b"P" * 32, applied_at=applied_at
            )
            if succeeds:
                market.install_stage(install)
                self.assertEqual(market.staged_count, 0)
            else:
                self.assert_rejects_unchanged(
                    market, lambda: market.install_stage(install)
                )


class Task3PremiumTests(AtomicAssertions):
    def installed(self, ask=5):
        market = make_market(
            seat_runway_seconds=100, premium_claim_delay_seconds=10
        )
        row, term_id = stage_and_install(market, ask=ask)
        return market, row, term_id

    def test_lazy_promotion_and_accrual_delay_cap_funding_and_repeat(self):
        market, row, term = self.installed()
        view = service_view(row, term)
        reserve = market.accounting.live_reserves[term]
        self.assertEqual(reserve.lifecycle, model.ReserveLifecycle.UNSTARTED)
        self.assertEqual(market.accrue_premium(view, model.Clock(129, 1)).amount, 0)
        self.assertEqual(reserve.lifecycle, model.ReserveLifecycle.OPEN)
        self.assertEqual(market.accrue_premium(view, model.Clock(130, 1)).amount, 0)
        one = market.accrue_premium(view, model.Clock(131, 1))
        self.assertEqual(one.amount, 5)
        self.assertEqual(
            market.premium_credits[one.premium_credit_id].beneficiary,
            row.offer.payout,
        )
        capped = market.accrue_premium(view, model.Clock(1_000, 1))
        self.assertEqual(capped.amount, 5 * 49)
        self.assertEqual(market.accrue_premium(view, model.Clock(1_001, 1)).amount, 0)
        funding_cap = service_view(row, term, cap=300)
        # Settlement cap is higher, but immutable fundedUntil remains 220.
        self.assertEqual(
            market.accrue_premium(funding_cap, model.Clock(1_002, 1)).amount,
            5 * 50,
        )
        market.assert_valid()

    def test_unstarted_sentinel_cannot_hide_started_service_and_checked_mul_rolls_back(self):
        market, row, term = self.installed(ask=5)
        reserve = market.accounting.live_reserves[term]
        reserve.lifecycle = model.ReserveLifecycle.UNSTARTED
        reserve.last_accrued_at = None
        reserve.premium_funded_until = None
        earned = market.accrue_premium(
            service_view(row, term), model.Clock(140, 1)
        )
        self.assertEqual(earned.amount, 50)

        overflow = make_market(
            immutable_maximum_ask=model.UINT256_MAX,
            seat_runway_seconds=2,
        )
        overflow.sponsor_premium(1)
        insert(overflow, "overflow", model.UINT256_MAX)
        self.assert_rejects_unchanged(
            overflow,
            lambda: overflow.stage_best(lineup(), model.Clock(110, 53)),
            model.ArithmeticFault,
        )

    def test_every_exact_target_identity_field_fails_closed(self):
        market, row, term = self.installed(ask=5)
        view = service_view(row, term)
        substitutions = (
            {"target": addr("other-target")},
            {"authorization_id": b"a" * 32},
            {"settlement_chain_id": 2},
            {"protocol_version": 26},
            {"runtime_hash": b"x" * 32},
            {"configuration_hash": b"y" * 32},
            {"magic": b"NOPE"},
            {"generation": 8},
            {"term_id": b"x" * 32},
            {"tranche_id": b"y" * 32},
            {"offer_id": b"z" * 32},
            {"operator": addr("other-operator")},
            {"payout": addr("other-payout")},
            {"ask_wei_per_second": 6},
        )
        for changes in substitutions:
            bad = replace(view, **changes)
            self.assert_rejects_unchanged(
                market,
                lambda bad=bad: market.accrue_premium(
                    bad, model.Clock(140, 1)
                ),
            )

    def test_healthy_partition_tail_equality_and_forced_eth_surplus(self):
        market, row, term = self.installed(ask=5)
        market.force_eth(777)
        before_surplus = market.surplus
        view = service_view(row, term, closed=True)
        close = market.close_reserve(view, model.Clock(160, 1))
        self.assertEqual(close.amount, 5 * 30)
        reserve = market.accounting.live_reserves[term]
        self.assertEqual(reserve.lifecycle, model.ReserveLifecycle.CLOSED_TAIL)
        self.assertEqual(reserve.reserved_wei, 5 * 20)
        self.assertEqual(market.accounting.free_premium, 5 * 50)
        self.assertEqual(market.surplus, before_surplus)
        self.assert_rejects_unchanged(
            market,
            lambda: market.reconcile_tail(term, model.Clock(179, 1)),
        )
        tail = market.reconcile_tail(term, model.Clock(180, 1))
        self.assertEqual(tail.amount, 5 * 20)
        self.assertNotIn(term, market.accounting.live_reserves)
        self.assert_rejects_unchanged(
            market,
            lambda: market.close_reserve(view, model.Clock(181, 1)),
        )
        market.assert_valid()

    def test_async_close_before_equal_after_and_unstarted_zero_ask(self):
        for now, succeeds in ((179, False), (180, True), (181, True)):
            market, row, term = self.installed(ask=5)
            view = service_view(row, term, closed=True)
            if succeeds:
                result = market.close_reserve(
                    view, model.Clock(now, 1), atomic_healthy=False
                )
                self.assertEqual(result.amount, 5 * 50)
                self.assertNotIn(term, market.accounting.live_reserves)
            else:
                self.assert_rejects_unchanged(
                    market,
                    lambda: market.close_reserve(
                        view, model.Clock(now, 1), atomic_healthy=False
                    ),
                )

        zero, row, term = self.installed(ask=0)
        self.assertNotIn(term, zero.accounting.live_reserves)
        result = zero.close_reserve(
            service_view(row, term, closed=True), model.Clock(0, 0)
        )
        self.assertEqual(result.amount, 0)

    def test_random_partition_identity_checked_for_500_inputs(self):
        rng = random.Random(0x5EA7)
        for _ in range(500):
            ask = rng.randrange(0, 10**12)
            a = rng.randrange(0, 10**9)
            c = rng.randrange(a, 10**9 + 1)
            f = rng.randrange(c, 10**9 + 1)
            now = rng.randrange(0, 10**9)
            delay = rng.randrange(0, 10**6)
            m = max(a, min(c, max(0, now - delay)))
            matured = model.checked_mul(ask, model.checked_sub(m, a))
            tail = model.checked_mul(ask, model.checked_sub(c, m))
            unearned = model.checked_mul(ask, model.checked_sub(f, c))
            total = model.checked_mul(ask, model.checked_sub(f, a))
            self.assertEqual(model.checked_add(model.checked_add(matured, tail), unearned), total)

    def test_premium_claim_guard_effects_and_full_rollback(self):
        market, row, term = self.installed(ask=5)
        credit = market.accrue_premium(
            service_view(row, term), model.Clock(140, 1)
        ).premium_credit_id
        second = market.accrue_premium(
            service_view(row, term), model.Clock(150, 1)
        ).premium_credit_id
        observations = []

        def guarded(beneficiary, amount, callback_market):
            observations.append((beneficiary, amount, callback_market.premium_credits[credit].claimed))
            with self.assertRaises(model.TransitionRejected):
                callback_market.claim_premium_credit(second, lambda *_: None)
            bond_id = callback_market.credit_id(
                row.tranche.tranche_id, model.BondDisposition.OWNER_CREDITED
            )
            with self.assertRaises(model.TransitionRejected):
                callback_market.claim_credit(bond_id, lambda *_: None)

        market.claim_premium_credit(credit, guarded)
        self.assertEqual(observations, [(row.offer.payout, 50, True)])
        self.assertFalse(market.premium_credits[second].claimed)

        before = copy.deepcopy(market)
        with self.assertRaisesRegex(RuntimeError, "payout reverted"):
            market.claim_premium_credit(
                second,
                lambda *_: (_ for _ in ()).throw(RuntimeError("payout reverted")),
            )
        self.assertEqual(market, before)


class Task3ReleaseAndHistoryTests(AtomicAssertions):
    def installed(self, ask=0):
        market = make_market(
            seat_runway_seconds=100,
            premium_claim_delay_seconds=10,
            release_challenge_seconds=20,
            reorg_stability_seconds=30,
            evidence_delay_seconds=40,
        )
        row, term = stage_and_install(market, ask=ask)
        return market, row, term

    def refundable_view(self, row, term, **overrides):
        values = dict(
            closed=True,
            refundable=True,
            disposition_at=110,
            last_liability_at=50,
            duty_disposition="SATISFIED",
            roster_occupied=False,
        )
        values.update(overrides)
        return service_view(row, term, **values)

    def test_release_request_is_permissionless_one_shot_and_three_max_boundaries(self):
        market, row, term = self.installed()
        view = self.refundable_view(row, term)
        first = market.request_release(row.tranche.tranche_id, view, model.Clock(100, 1))
        again = market.request_release(row.tranche.tranche_id, view, model.Clock(130, 2))
        self.assertEqual(first.deadline, 100)
        self.assertEqual(again.deadline, 100)
        # max(100+20, 110+30, 50+40+30) == 140
        self.assert_rejects_unchanged(
            market,
            lambda: market.finalize_release(
                row.tranche.tranche_id, view, model.Clock(139, 3)
            ),
        )
        result = market.finalize_release(
            row.tranche.tranche_id, view, model.Clock(140, 3)
        )
        credit = market.credits[result.credit_id]
        self.assertEqual(credit.beneficiary, row.tranche.operator)
        self.assertEqual(
            market.tranches[row.tranche.tranche_id].disposition,
            model.BondDisposition.OWNER_CREDITED,
        )
        self.assert_rejects_unchanged(
            market,
            lambda: market.enforce_breach(
                row.tranche.tranche_id,
                self.refundable_view(
                    row,
                    term,
                    refundable=False,
                    breached=True,
                    breach_recorded_at=100,
                    duty_disposition="BREACHED",
                ),
                model.Clock(200, 3),
            ),
        )

    def test_each_release_max_component_and_zero_sentinels(self):
        cases = (
            # request challenge dominates
            (100, 0, 0, 120),
            # disposition stability dominates
            (0, 100, 0, 130),
            # evidence safety dominates
            (0, 0, 100, 170),
        )
        for requested, disposition, liability, boundary in cases:
            market, row, term = self.installed()
            view = self.refundable_view(
                row,
                term,
                disposition_at=disposition,
                last_liability_at=liability,
            )
            market.request_release(
                row.tranche.tranche_id, view, model.Clock(requested, 1)
            )
            self.assert_rejects_unchanged(
                market,
                lambda market=market, row=row, view=view, boundary=boundary: market.finalize_release(
                    row.tranche.tranche_id, view, model.Clock(boundary - 1, 1)
                ),
            )
            market.finalize_release(
                row.tranche.tranche_id, view, model.Clock(boundary, 1)
            )

    def test_breach_overrides_request_and_waits_for_receipt_and_reserve(self):
        market, row, term = self.installed(ask=5)
        refundable = self.refundable_view(row, term)
        market.request_release(row.tranche.tranche_id, refundable, model.Clock(100, 1))
        breach = self.refundable_view(
            row,
            term,
            refundable=False,
            disposition_at=130,
            breached=True,
            breach_recorded_at=130,
            duty_disposition="BREACHED",
        )
        # receipt stable 160; reserve maturity 180, so the reserve dominates.
        self.assert_rejects_unchanged(
            market,
            lambda: market.enforce_breach(
                row.tranche.tranche_id, breach, model.Clock(179, 1)
            ),
        )
        result = market.enforce_breach(
            row.tranche.tranche_id, breach, model.Clock(180, 1)
        )
        self.assertEqual(
            market.credits[result.credit_id].beneficiary, market.penalty_sink
        )
        self.assertEqual(
            market.tranches[row.tranche.tranche_id].disposition,
            model.BondDisposition.PENALTY_CREDITED,
        )
        self.assertNotIn(term, market.accounting.live_reserves)

        receipt_market, receipt_row, receipt_term = self.installed()
        receipt_view = self.refundable_view(
            receipt_row,
            receipt_term,
            refundable=False,
            disposition_at=200,
            breached=True,
            breach_recorded_at=200,
            duty_disposition="BREACHED",
        )
        self.assert_rejects_unchanged(
            receipt_market,
            lambda: receipt_market.enforce_breach(
                receipt_row.tranche.tranche_id,
                receipt_view,
                model.Clock(229, 1),
            ),
        )
        receipt_market.enforce_breach(
            receipt_row.tranche.tranche_id,
            receipt_view,
            model.Clock(230, 1),
        )

    def test_reserve_absent_is_required_and_timing_overflow_is_atomic(self):
        market, row, term = self.installed(ask=5)
        view = self.refundable_view(row, term)
        market.request_release(row.tranche.tranche_id, view, model.Clock(100, 1))
        self.assert_rejects_unchanged(
            market,
            lambda: market.finalize_release(
                row.tranche.tranche_id, view, model.Clock(179, 1)
            ),
        )
        market.finalize_release(
            row.tranche.tranche_id, view, model.Clock(180, 1)
        )
        self.assertNotIn(term, market.accounting.live_reserves)

        overflow, row, term = self.installed()
        bad = self.refundable_view(row, term, disposition_at=model.UINT256_MAX)
        overflow.request_release(row.tranche.tranche_id, bad, model.Clock(0, 1))
        self.assert_rejects_unchanged(
            overflow,
            lambda: overflow.finalize_release(
                row.tranche.tranche_id, bad, model.Clock(model.UINT256_MAX, 1)
            ),
            model.ArithmeticFault,
        )

    def test_unresolved_or_breached_duty_cannot_create_owner_credit(self):
        for disposition, breached in (("OPEN", False), ("BREACHED", True)):
            market, row, term = self.installed()
            view = self.refundable_view(
                row,
                term,
                duty_disposition=disposition,
                breached=breached,
                breach_recorded_at=100 if breached else None,
            )
            self.assert_rejects_unchanged(
                market,
                lambda market=market, row=row, view=view: market.request_release(
                    row.tranche.tranche_id, view, model.Clock(100, 1)
                ),
            )

    def test_installed_release_never_uses_missing_liability_zero_branch(self):
        market, row, term = self.installed()
        missing = self.refundable_view(row, term, last_liability_at=None)
        self.assert_rejects_unchanged(
            market,
            lambda: market.request_release(
                row.tranche.tranche_id, missing, model.Clock(100, 1)
            ),
        )

        valid = self.refundable_view(row, term, last_liability_at=50)
        market.request_release(row.tranche.tranche_id, valid, model.Clock(100, 1))
        market.finalize_release(
            row.tranche.tranche_id, valid, model.Clock(140, 1)
        )
        self.assertFalse(
            market.is_duty_history_safe(
                valid.duty_id,
                term,
                row.tranche.tranche_id,
                missing,
                model.Clock(10_000, 1),
            )
        )

    def test_penalty_history_waits_for_independent_evidence_horizon(self):
        market, row, term = self.installed()
        breach = self.refundable_view(
            row,
            term,
            refundable=False,
            disposition_at=150,
            last_liability_at=149,
            breached=True,
            breach_recorded_at=150,
            duty_disposition="BREACHED",
        )
        market.enforce_breach(
            row.tranche.tranche_id, breach, model.Clock(180, 1)
        )
        self.assertFalse(
            market.is_duty_history_safe(
                breach.duty_id,
                term,
                row.tranche.tranche_id,
                breach,
                model.Clock(218, 1),
            )
        )
        self.assertTrue(
            market.is_duty_history_safe(
                breach.duty_id,
                term,
                row.tranche.tranche_id,
                breach,
                model.Clock(219, 1),
            )
        )

    def test_duty_timestamp_combinations_fail_closed(self):
        market, row, term = self.installed()
        base = self.refundable_view(row, term, last_liability_at=50)
        inconsistent = (
            replace(base, duty_disposition="NO_DUTY"),
            replace(base, duty_disposition="SATISFIED", disposition_at=None),
            replace(base, duty_disposition="EXCUSED", disposition_at=None),
            replace(
                base,
                duty_disposition="BREACHED",
                breached=True,
                breach_recorded_at=None,
            ),
        )
        for view in inconsistent:
            self.assert_rejects_unchanged(
                market,
                lambda view=view: market.request_release(
                    row.tranche.tranche_id, view, model.Clock(100, 1)
                ),
            )

    def test_task3_freeze_matrix_is_a_model_constant(self):
        self.assertTrue(hasattr(model, "TASK3_EVENT_FREEZE"))

    def test_history_safety_is_monotone_and_claim_independent(self):
        market, row, term = self.installed()
        view = self.refundable_view(row, term)
        duty = view.duty_id
        self.assertFalse(
            market.is_duty_history_safe(
                duty, term, row.tranche.tranche_id, view, model.Clock(139, 1)
            )
        )
        market.request_release(row.tranche.tranche_id, view, model.Clock(100, 1))
        result = market.finalize_release(
            row.tranche.tranche_id, view, model.Clock(140, 1)
        )
        for now in (140, 141, 10_000):
            self.assertTrue(
                market.is_duty_history_safe(
                    duty, term, row.tranche.tranche_id, view, model.Clock(now, 1)
                )
            )
        self.assertFalse(market.credits[result.credit_id].claimed)
        wrong = market.is_duty_history_safe(
            b"X" * 32, term, row.tranche.tranche_id, view, model.Clock(10_000, 1)
        )
        self.assertFalse(wrong)
        # An unrelated live stage must not make an already-safe binding unsafe.
        insert(market, "unrelated", 1, clock=model.Clock(200, 100))
        market.sponsor_premium(100)
        market.stage_best(lineup(), model.Clock(210, 103))
        self.assertTrue(
            market.is_duty_history_safe(
                duty,
                term,
                row.tranche.tranche_id,
                view,
                model.Clock(10_001, 1),
            )
        )
        # Terminal history cannot enter any waiting or installed path again.
        self.assert_rejects_unchanged(
            market,
            lambda: market.request_pending_exit(
                row.tranche.operator, row.offer.offer_id, model.Clock(200, 1)
            ),
        )

    def test_never_installed_cannot_release_or_breach_and_installed_never_reenters(self):
        market = make_market()
        row = insert(market, "pending", 5)
        fake = service_view(row, b"T" * 32, closed=True, refundable=True)
        for call in (
            lambda: market.request_release(row.tranche.tranche_id, fake, model.Clock(1, 1)),
            lambda: market.enforce_breach(row.tranche.tranche_id, fake, model.Clock(1, 1)),
        ):
            self.assert_rejects_unchanged(market, call)

    def test_task3_events_reject_every_wrong_reachable_lifecycle_class(self):
        pending = make_market()
        pending_row = insert(pending, "p-matrix", 5)
        fake_term = b"F" * 32
        fake_view = service_view(
            pending_row,
            fake_term,
            closed=True,
            refundable=True,
            duty_disposition="SATISFIED",
        )
        pending_calls = (
            lambda: pending.expire_stage(b"S" * 32, model.Clock(1_000, 1)),
            lambda: pending.invalidate_stage(b"S" * 32, b"L" * 32),
            lambda: pending.cancel_stage_for_migration(
                b"S" * 32, b"L" * 32, model.Clock(1_000, 1)
            ),
            lambda: pending.install_stage(
                model.InstallationView(
                    target=pending.authorization.target,
                    authorization_id=pending.current_authorization_id,
                    generation=7,
                    stage_id=b"S" * 32,
                    term_id=fake_term,
                    offer_id=pending_row.offer.offer_id,
                    lineup_commitment=b"L" * 32,
                    applied_at=0,
                )
            ),
            lambda: pending.accrue_premium(fake_view, model.Clock(1_000, 1)),
            lambda: pending.close_reserve(fake_view, model.Clock(1_000, 1)),
            lambda: pending.request_release(
                pending_row.tranche.tranche_id,
                fake_view,
                model.Clock(1_000, 1),
            ),
            lambda: pending.finalize_release(
                pending_row.tranche.tranche_id,
                fake_view,
                model.Clock(1_000, 1),
            ),
            lambda: pending.enforce_breach(
                pending_row.tranche.tranche_id,
                fake_view,
                model.Clock(1_000, 1),
            ),
            lambda: pending.reconcile_tail(fake_term, model.Clock(1_000, 1)),
            lambda: pending.claim_premium_credit(b"C" * 32, lambda *_: None),
        )
        for call in pending_calls:
            self.assert_rejects_unchanged(pending, call)

        staged = make_market()
        staged.sponsor_premium(500)
        insert(staged, "s-matrix", 5)
        staged.stage_best(lineup(), model.Clock(110, 53))
        self.assert_rejects_unchanged(
            staged,
            lambda: staged.stage_best(lineup(), model.Clock(111, 54)),
        )

        installed, installed_row, installed_term = self.installed()
        for call in (
            lambda: installed.expire_stage(b"S" * 32, model.Clock(1_000, 1)),
            lambda: installed.invalidate_stage(b"S" * 32, b"L" * 32),
            lambda: installed.cancel_stage_for_migration(
                b"S" * 32, b"L" * 32, model.Clock(1_000, 1)
            ),
            lambda: installed.install_stage(
                model.InstallationView(
                    target=installed.authorization.target,
                    authorization_id=installed.current_authorization_id,
                    generation=7,
                    stage_id=b"S" * 32,
                    term_id=b"N" * 32,
                    offer_id=installed_row.offer.offer_id,
                    lineup_commitment=b"L" * 32,
                    applied_at=0,
                )
            ),
            lambda: installed.request_pending_exit(
                installed_row.tranche.operator,
                installed_row.offer.offer_id,
                model.Clock(1_000, 1),
            ),
        ):
            self.assert_rejects_unchanged(installed, call)

        closed = make_market()
        closed_row = insert(closed, "c-matrix", 5)
        closed.request_pending_exit(
            closed_row.tranche.operator,
            closed_row.offer.offer_id,
            model.Clock(100, 50),
        )
        closed_view = service_view(
            closed_row,
            b"X" * 32,
            closed=True,
            refundable=True,
            duty_disposition="SATISFIED",
        )
        for call in (
            lambda: closed.request_release(
                closed_row.tranche.tranche_id,
                closed_view,
                model.Clock(1_000, 1),
            ),
            lambda: closed.enforce_breach(
                closed_row.tranche.tranche_id,
                closed_view,
                model.Clock(1_000, 1),
            ),
        ):
            self.assert_rejects_unchanged(closed, call)


class Task3FrozenMatrixTests(AtomicAssertions):
    ROWS = (
        "pending",
        "staged",
        "closed-none",
        "closed-owner",
        "installed-none",
        "installed-owner",
        "installed-penalty",
    )
    TASK3_EVENT_COVERAGE = {
        "sponsor_premium": "GLOBAL_ACCOUNTING",
        "stage_best": "SECTION_4_4",
        "expire_stage": "SECTION_4_4",
        "invalidate_stage": "SECTION_4_4",
        "cancel_stage_for_migration": "SECTION_4_4",
        "install_stage": "SECTION_4_4",
        "accrue_premium": "INSTALLED_NONE",
        "close_reserve": "INSTALLED_NONE",
        "reconcile_tail": "INSTALLED_NONE",
        "request_release": "SECTION_4_4",
        "finalize_release": "SECTION_4_4",
        "enforce_breach": "SECTION_4_4",
        "claim_premium_credit": "EXACT_CREDIT",
    }

    @staticmethod
    def lifecycle(market, row):
        offer = market.offers[row.offer.offer_id]
        tranche = market.tranches[row.tranche.tranche_id]
        return offer.location, tranche.usage, tranche.disposition

    def fixture(self, kind):
        market = make_market(
            seat_runway_seconds=100,
            premium_claim_delay_seconds=10,
            release_challenge_seconds=20,
            reorg_stability_seconds=30,
            evidence_delay_seconds=40,
        )
        stage = None
        term = b"M" * 32
        view = None
        if kind == "pending":
            market.sponsor_premium(500)
            row = insert(market, "mx-pending", 5)
        elif kind == "staged":
            market.sponsor_premium(500)
            row = insert(market, "mx-staged", 5)
            stage = market.stage_best(lineup(), model.Clock(110, 53)).stage
        elif kind in ("closed-none", "closed-owner"):
            row = insert(market, f"mx-{kind[-5:]}", 5)
            market.request_pending_exit(
                row.tranche.operator, row.offer.offer_id, model.Clock(100, 50)
            )
            if kind == "closed-owner":
                market.finalize_pending_exit(
                    row.tranche.tranche_id, model.Clock(120, 50)
                )
        else:
            row, term = stage_and_install(market, "mx-installed", 0, term)
            view = service_view(
                row,
                term,
                closed=True,
                refundable=True,
                disposition_at=10,
                last_liability_at=0,
                duty_disposition="SATISFIED",
            )
            if kind == "installed-owner":
                market.request_release(
                    row.tranche.tranche_id, view, model.Clock(0, 1)
                )
                market.finalize_release(
                    row.tranche.tranche_id, view, model.Clock(70, 1)
                )
            elif kind == "installed-penalty":
                view = replace(
                    view,
                    refundable=False,
                    disposition_at=10,
                    breached=True,
                    breach_recorded_at=10,
                    duty_disposition="BREACHED",
                )
                market.enforce_breach(
                    row.tranche.tranche_id, view, model.Clock(40, 1)
                )
        market.assert_valid()
        return dict(market=market, row=row, stage=stage, term=term, view=view)

    def invoke(self, event, fixture):
        market = fixture["market"]
        row = fixture["row"]
        stage = fixture["stage"]
        term = fixture["term"]
        view = fixture["view"]
        if event == "stage_best":
            return market.stage_best(lineup(), model.Clock(110, 53))
        if event == "expire_stage":
            return market.expire_stage(
                stage.stage_id if stage else b"S" * 32,
                model.Clock(stage.expires_at if stage else 1_000, 53),
            )
        if event == "invalidate_stage":
            return market.invalidate_stage(
                stage.stage_id if stage else b"S" * 32,
                stage.lineup_commitment if stage else b"L" * 32,
            )
        if event == "cancel_stage_for_migration":
            return market.cancel_stage_for_migration(
                stage.stage_id if stage else b"S" * 32,
                stage.lineup_commitment if stage else b"L" * 32,
                model.Clock(1_000, 53),
            )
        if event == "install_stage":
            install = (
                installation_view(market, stage, term)
                if stage
                else model.InstallationView(
                    target=market.authorization.target,
                    authorization_id=market.current_authorization_id,
                    generation=market.cached_generation,
                    stage_id=b"S" * 32,
                    term_id=term,
                    offer_id=row.offer.offer_id,
                    lineup_commitment=b"L" * 32,
                    applied_at=0,
                )
            )
            return market.install_stage(install)
        exact = view or service_view(
            row,
            term,
            closed=True,
            refundable=True,
            disposition_at=10,
            last_liability_at=0,
            duty_disposition="SATISFIED",
        )
        if event == "request_release":
            return market.request_release(
                row.tranche.tranche_id, exact, model.Clock(0, 1)
            )
        if event == "finalize_release":
            return market.finalize_release(
                row.tranche.tranche_id, exact, model.Clock(1_000, 1)
            )
        if event == "enforce_breach":
            breach = replace(
                exact,
                refundable=False,
                disposition_at=10,
                breached=True,
                breach_recorded_at=10,
                duty_disposition="BREACHED",
            )
            return market.enforce_breach(
                row.tranche.tranche_id, breach, model.Clock(1_000, 1)
            )
        raise AssertionError(f"unhandled matrix event {event}")

    def test_introspection_requires_a_row_for_every_task3_public_event(self):
        self.assertEqual(
            set(self.TASK3_EVENT_COVERAGE), EdgeMatrixTests.TASK3_MUTATING_PUBLIC_EVENTS
        )
        section_events = {
            event
            for event, category in self.TASK3_EVENT_COVERAGE.items()
            if category == "SECTION_4_4"
        }
        self.assertEqual(section_events, set(model.TASK3_EVENT_FREEZE))

    def test_every_section_4_4_success_edge_matches_the_frozen_table(self):
        for event, (expected_before, expected_after) in model.TASK3_EVENT_FREEZE.items():
            fixture = self.fixture(
                "pending" if event == "stage_best" else
                "staged" if event in {
                    "expire_stage",
                    "invalidate_stage",
                    "cancel_stage_for_migration",
                    "install_stage",
                } else
                "installed-none"
            )
            market, row = fixture["market"], fixture["row"]
            if event == "finalize_release":
                market.request_release(
                    row.tranche.tranche_id, fixture["view"], model.Clock(0, 1)
                )
            before = self.lifecycle(market, row)
            self.assertEqual(before, expected_before, event)
            self.invoke(event, fixture)
            self.assertEqual(self.lifecycle(market, row), expected_after, event)
            market.assert_valid()

    def test_every_nonnormative_reachable_row_rejects_or_returns_no_edge_unchanged(self):
        for event, (allowed_source, _target) in model.TASK3_EVENT_FREEZE.items():
            for kind in self.ROWS:
                fixture = self.fixture(kind)
                market, row = fixture["market"], fixture["row"]
                if self.lifecycle(market, row) == allowed_source:
                    continue
                before = copy.deepcopy(market)
                try:
                    result = self.invoke(event, fixture)
                except model.TransitionRejected:
                    pass
                else:
                    self.assertEqual(
                        result.code,
                        model.ResultCode.NO_FEASIBLE_OFFER,
                        (event, kind),
                    )
                self.assertEqual(market, before, (event, kind))


class Task3StatefulTests(unittest.TestCase):
    def test_stateful_gate_is_not_four_fixed_modulo_templates(self):
        source = inspect.getsource(
            Task3StatefulTests.test_1000_deterministic_pseudorandom_full_lifecycle_sequences
        )
        self.assertNotIn("branch = sequence % 4", source)

    def assert_reference_oracle(self, market, shadow_surplus=0):
        """Independent sums and direct identities, without assert_valid()."""

        self.assertLessEqual(
            len(market.pending_offer_ids) + (market.stage is not None), 4
        )
        self.assertEqual(len(market.pending_offer_ids), len(set(market.pending_offer_ids)))
        self.assertEqual(
            market.pending_offer_ids,
            sorted(
                market.pending_offer_ids,
                key=lambda offer_id: market.offers[offer_id].order_key,
            ),
        )
        bond_escrow = sum(
            tranche.bond_amount
            for tranche in market.tranches.values()
            if tranche.disposition is model.BondDisposition.NONE
        )
        owner_outstanding = sum(
            credit.amount
            for credit in market.credits.values()
            if credit.disposition is model.BondDisposition.OWNER_CREDITED
            and not credit.claimed
        )
        penalty_outstanding = sum(
            credit.amount
            for credit in market.credits.values()
            if credit.disposition is model.BondDisposition.PENALTY_CREDITED
            and not credit.claimed
        )
        premium_outstanding = sum(
            credit.amount
            for credit in market.premium_credits.values()
            if not credit.claimed
        )
        reserved = sum(
            reserve.reserved_wei
            for reserve in market.accounting.live_reserves.values()
        )
        self.assertEqual(market.accounting.bond_escrow, bond_escrow)
        self.assertEqual(market.accounting.outstanding_owner_credits, owner_outstanding)
        self.assertEqual(market.accounting.outstanding_penalty_credits, penalty_outstanding)
        self.assertEqual(market.accounting.outstanding_premium_claims, premium_outstanding)
        self.assertEqual(market.accounting.reserved_premium, reserved)
        independent_accounted = sum((
            bond_escrow,
            owner_outstanding,
            penalty_outstanding,
            market.accounting.free_premium,
            reserved,
            premium_outstanding,
        ))
        self.assertEqual(
            market.actual_balance,
            independent_accounted + shadow_surplus,
        )

        for tranche in market.tranches.values():
            owner_id = model.keccak256(
                b"TAIKO_SEAT_BOND_CREDIT_V1"
                + model.u256(market.market_chain_id)
                + model.address20(market.market_address)
                + tranche.tranche_id
                + model.u8(model.BondDisposition.OWNER_CREDITED.value)
            )
            penalty_id = model.keccak256(
                b"TAIKO_SEAT_BOND_CREDIT_V1"
                + model.u256(market.market_chain_id)
                + model.address20(market.market_address)
                + tranche.tranche_id
                + model.u8(model.BondDisposition.PENALTY_CREDITED.value)
            )
            present = {credit_id for credit_id in (owner_id, penalty_id) if credit_id in market.credits}
            if tranche.disposition is model.BondDisposition.NONE:
                self.assertEqual(present, set())
            elif tranche.disposition is model.BondDisposition.OWNER_CREDITED:
                self.assertEqual(present, {owner_id})
            else:
                self.assertEqual(present, {penalty_id})
            current_offer = market.offers[tranche.current_offer_id]
            self.assertEqual(current_offer.tranche_id, tranche.tranche_id)
            if tranche.disposition is not model.BondDisposition.NONE:
                self.assertEqual(current_offer.location, model.OfferLocation.NONE)
                self.assertNotIn(current_offer.offer_id, market.pending_offer_ids)
                if market.stage is not None:
                    self.assertNotEqual(market.stage.offer_id, current_offer.offer_id)
            if tranche.usage is model.TrancheUsage.INSTALLED:
                self.assertIsNotNone(tranche.installed_term_id)
            else:
                self.assertIsNone(tranche.installed_term_id)

        installed_terms = [
            tranche.installed_term_id
            for tranche in market.tranches.values()
            if tranche.installed_term_id is not None
        ]
        self.assertEqual(len(installed_terms), len(set(installed_terms)))

        for credit_id, credit in market.premium_credits.items():
            direct = model.keccak256(
                b"TAIKO_SEAT_PREMIUM_CREDIT_V1"
                + model.u256(market.market_chain_id)
                + model.address20(market.market_address)
                + credit.reserve_id
                + model.address20(credit.beneficiary)
                + model.u256(credit.amount)
                + model.u256(credit.sequence)
            )
            self.assertEqual(credit_id, direct)

    def assert_atomic_rejection(self, market, call, shadow_surplus=0):
        before = copy.deepcopy(market)
        with self.assertRaises(model.TransitionRejected):
            call()
        self.assertEqual(market, before)
        self.assert_reference_oracle(market, shadow_surplus)

    def test_1000_deterministic_pseudorandom_full_lifecycle_sequences(self):
        names = (
            "sponsor_premium", "force_eth", "insert", "requote", "stage",
            "expire", "invalidate", "migration_cancel", "pending_exit",
            "pending_finalize", "generation_sync", "install", "accrue",
            "healthy_close", "async_close", "tail_reconcile",
            "request_release", "finalize_release", "enforce_breach",
            "claim_owner", "claim_penalty", "claim_premium",
            "owner_history_unclaimed_premium", "penalty_history",
            "atomic_rejection",
        )
        counts = {name: 0 for name in names}
        traces: set[tuple[str, ...]] = set()
        pair_counts = {name: 0 for name in (
            "release_then_breach", "accrue_then_close",
            "close_then_tail", "terminalize_then_claim",
            "stage_then_invalidate", "stage_then_migration_cancel",
            "stage_then_install",
        )}

        for sequence in range(1_000):
            rng = random.Random(0x51A7E000 + sequence)
            trace: list[str] = []
            shadow_surplus = 0
            ask = rng.randrange(1, 6)
            market = make_market(
                seat_runway_seconds=100,
                premium_claim_delay_seconds=10,
                release_challenge_seconds=20,
                reorg_stability_seconds=30,
                evidence_delay_seconds=40,
            )

            def record(name, call):
                result = call()
                counts[name] += 1
                trace.append(name)
                self.assert_reference_oracle(market, shadow_surplus)
                return result

            def reject(name, call):
                self.assert_atomic_rejection(market, call, shadow_surplus)
                counts["atomic_rejection"] += 1
                trace.append(f"reject:{name}")

            def force():
                nonlocal shadow_surplus
                amount = rng.randrange(1, 8)
                market.force_eth(amount)
                shadow_surplus += amount
                counts["force_eth"] += 1
                trace.append("force_eth")
                self.assert_reference_oracle(market, shadow_surplus)

            record(
                "sponsor_premium", lambda: market.sponsor_premium((ask + 1) * 100)
            )
            row = record("insert", lambda: insert(market, f"q{sequence}", ask + 1))

            # Seeded per-step prefix.  It deliberately mixes valid no-op syncs,
            # requotes, forced surplus, and invalid lifecycle calls.
            for step in range(rng.randrange(2, 6)):
                action = rng.choice((
                    "force", "sync", "requote", "bad_tail",
                    "bad_install", "bad_release", "bad_claim",
                ))
                if action == "force":
                    force()
                elif action == "sync":
                    before = copy.deepcopy(market)
                    result = record(
                        "generation_sync",
                        lambda: market.sync_seat_generation(target_view(7)),
                    )
                    self.assertEqual(result.purged_count, 0)
                    self.assertEqual(market, before)
                elif action == "requote":
                    result = record(
                        "requote",
                        lambda step=step: market.requote(
                            caller=row.tranche.operator,
                            offer_id=row.offer.offer_id,
                            payout=addr(f"p{sequence}x{step}"),
                            ask_wei_per_second=ask,
                            target=addr("settlement-v1"),
                            generation=7,
                            clock=model.Clock(100, 50),
                        ),
                    )
                    row = model.TransitionResult(
                        offer=result.offer, tranche=result.tranche
                    )
                elif action == "bad_tail":
                    reject(
                        action,
                        lambda: market.reconcile_tail(
                            b"X" * 32, model.Clock(1_000, 1)
                        ),
                    )
                elif action == "bad_install":
                    reject(
                        action,
                        lambda: market.install_stage(
                            model.InstallationView(
                                target=market.authorization.target,
                                authorization_id=market.current_authorization_id,
                                generation=7,
                                stage_id=b"S" * 32,
                                term_id=b"T" * 32,
                                offer_id=row.offer.offer_id,
                                lineup_commitment=b"L" * 32,
                                applied_at=0,
                            )
                        ),
                    )
                elif action == "bad_release":
                    fake = service_view(
                        row,
                        b"F" * 32,
                        closed=True,
                        refundable=True,
                        disposition_at=10,
                        last_liability_at=0,
                        duty_disposition="SATISFIED",
                    )
                    reject(
                        action,
                        lambda fake=fake: market.request_release(
                            row.tranche.tranche_id,
                            fake,
                            model.Clock(100, 1),
                        ),
                    )
                else:
                    reject(
                        action,
                        lambda: market.claim_premium_credit(
                            b"C" * 32, lambda *_: None
                        ),
                    )

            staged = record(
                "stage",
                lambda: market.stage_best(lineup(), model.Clock(110, 53)),
            )
            self.assertEqual(staged.code, model.ResultCode.STAGED)

            for _ in range(rng.randrange(1, 4)):
                action = rng.choice((
                    "force", "sync", "bad_requote", "bad_exit",
                    "bad_second_stage", "bad_claim",
                ))
                if action == "force":
                    force()
                elif action == "sync":
                    before = copy.deepcopy(market)
                    record(
                        "generation_sync",
                        lambda: market.sync_seat_generation(target_view(7)),
                    )
                    self.assertEqual(market, before)
                elif action == "bad_requote":
                    reject(
                        action,
                        lambda: market.requote(
                            caller=row.tranche.operator,
                            offer_id=row.offer.offer_id,
                            payout=addr("bad-stage-rq"),
                            ask_wei_per_second=ask,
                            target=addr("settlement-v1"),
                            generation=7,
                            clock=model.Clock(120, 56),
                        ),
                    )
                elif action == "bad_exit":
                    reject(
                        action,
                        lambda: market.request_pending_exit(
                            row.tranche.operator,
                            row.offer.offer_id,
                            model.Clock(120, 56),
                        ),
                    )
                elif action == "bad_second_stage":
                    reject(
                        action,
                        lambda: market.stage_best(
                            lineup(), model.Clock(120, 56)
                        ),
                    )
                else:
                    reject(
                        action,
                        lambda: market.claim_premium_credit(
                            b"C" * 32, lambda *_: None
                        ),
                    )

            resolution = rng.choice(("expire", "invalidate", "cancel", "install"))
            terminal_credit = None
            if resolution == "expire":
                reject(
                    "early_expire",
                    lambda: market.expire_stage(
                        staged.stage.stage_id,
                        model.Clock(staged.stage.expires_at - 1, 56),
                    ),
                )
                record(
                    "expire",
                    lambda: market.expire_stage(
                        staged.stage.stage_id,
                        model.Clock(staged.stage.expires_at, 56),
                    ),
                )
            elif resolution == "invalidate":
                record(
                    "invalidate",
                    lambda: market.invalidate_stage(
                        staged.stage.stage_id,
                        staged.stage.lineup_commitment,
                    ),
                )
            elif resolution == "cancel":
                canceled = record(
                    "migration_cancel",
                    lambda: market.cancel_stage_for_migration(
                        staged.stage.stage_id,
                        staged.stage.lineup_commitment,
                        model.Clock(120, 56),
                    ),
                )
                terminal_credit = canceled.credit_id

            if resolution in ("expire", "invalidate"):
                for step in range(rng.randrange(0, 3)):
                    if rng.choice((True, False)):
                        force()
                    else:
                        before = copy.deepcopy(market)
                        record(
                            "generation_sync",
                            lambda: market.sync_seat_generation(target_view(7)),
                        )
                        self.assertEqual(market, before)
                staged = record(
                    "stage",
                    lambda: market.stage_best(lineup(), model.Clock(130, 59)),
                )
                if rng.choice((True, False)):
                    canceled = record(
                        "migration_cancel",
                        lambda: market.cancel_stage_for_migration(
                            staged.stage.stage_id,
                            staged.stage.lineup_commitment,
                            model.Clock(140, 59),
                        ),
                    )
                    terminal_credit = canceled.credit_id
                    resolution = "cancel"
                else:
                    resolution = "install"

            if resolution == "install":
                term = (sequence + 1).to_bytes(32, "big")
                record(
                    "install",
                    lambda: market.install_stage(
                        installation_view(market, staged.stage, term)
                    ),
                )
                open_view = service_view(row, term, cap=170)
                closed_owner = service_view(
                    row,
                    term,
                    cap=170,
                    closed=True,
                    refundable=True,
                    disposition_at=150,
                    last_liability_at=100,
                    duty_disposition="SATISFIED",
                )
                for step in range(rng.randrange(1, 4)):
                    action = rng.choice((
                        "accrue", "force", "bad_close",
                        "bad_release", "bad_claim", "sponsor",
                    ))
                    if action == "accrue":
                        record(
                            "accrue",
                            lambda: market.accrue_premium(
                                open_view,
                                model.Clock(rng.choice((131, 135, 140, 145)), 1),
                            ),
                        )
                    elif action == "force":
                        force()
                    elif action == "bad_close":
                        reject(
                            action,
                            lambda: market.close_reserve(
                                open_view, model.Clock(160, 1)
                            ),
                        )
                    elif action == "bad_release":
                        missing = replace(
                            closed_owner, last_liability_at=None
                        )
                        reject(
                            action,
                            lambda missing=missing: market.request_release(
                                row.tranche.tranche_id,
                                missing,
                                model.Clock(140, 1),
                            ),
                        )
                    elif action == "bad_claim":
                        reject(
                            action,
                            lambda: market.claim_premium_credit(
                                b"C" * 32, lambda *_: None
                            ),
                        )
                    else:
                        record(
                            "sponsor_premium",
                            lambda: market.sponsor_premium(rng.randrange(1, 8)),
                        )

                record(
                    "accrue",
                    lambda: market.accrue_premium(
                        open_view, model.Clock(150, 1)
                    ),
                )
                terminal = rng.choice(("healthy_owner", "async_owner", "penalty"))
                if terminal == "healthy_owner":
                    requested_before = rng.choice((True, False))
                    if requested_before:
                        record(
                            "request_release",
                            lambda: market.request_release(
                                row.tranche.tranche_id,
                                closed_owner,
                                model.Clock(150, 1),
                            ),
                        )
                    record(
                        "healthy_close",
                        lambda: market.close_reserve(
                            closed_owner, model.Clock(160, 1)
                        ),
                    )
                    reject(
                        "early_tail",
                        lambda: market.reconcile_tail(
                            term, model.Clock(179, 1)
                        ),
                    )
                    record(
                        "tail_reconcile",
                        lambda: market.reconcile_tail(
                            term, model.Clock(180, 1)
                        ),
                    )
                    if not requested_before:
                        record(
                            "request_release",
                            lambda: market.request_release(
                                row.tranche.tranche_id,
                                closed_owner,
                                model.Clock(180, 1),
                            ),
                        )
                    owner_at = 180 if requested_before else 200
                    reject(
                        "early_finalize",
                        lambda: market.finalize_release(
                            row.tranche.tranche_id,
                            closed_owner,
                            model.Clock(owner_at - 1, 1),
                        ),
                    )
                    owner = record(
                        "finalize_release",
                        lambda: market.finalize_release(
                            row.tranche.tranche_id,
                            closed_owner,
                            model.Clock(owner_at, 1),
                        ),
                    )
                    terminal_credit = owner.credit_id
                    self.assertTrue(
                        market.is_duty_history_safe(
                            closed_owner.duty_id,
                            term,
                            row.tranche.tranche_id,
                            closed_owner,
                            model.Clock(owner_at, 1),
                        )
                    )
                    counts["owner_history_unclaimed_premium"] += 1
                    trace.append("owner_history_unclaimed_premium")
                elif terminal == "async_owner":
                    record(
                        "request_release",
                        lambda: market.request_release(
                            row.tranche.tranche_id,
                            closed_owner,
                            model.Clock(160, 1),
                        ),
                    )
                    reject(
                        "early_async_close",
                        lambda: market.close_reserve(
                            closed_owner,
                            model.Clock(179, 1),
                            atomic_healthy=False,
                        ),
                    )
                    record(
                        "async_close",
                        lambda: market.close_reserve(
                            closed_owner,
                            model.Clock(180, 1),
                            atomic_healthy=False,
                        ),
                    )
                    owner = record(
                        "finalize_release",
                        lambda: market.finalize_release(
                            row.tranche.tranche_id,
                            closed_owner,
                            model.Clock(180, 1),
                        ),
                    )
                    terminal_credit = owner.credit_id
                else:
                    record(
                        "request_release",
                        lambda: market.request_release(
                            row.tranche.tranche_id,
                            closed_owner,
                            model.Clock(140, 1),
                        ),
                    )
                    breach = replace(
                        closed_owner,
                        refundable=False,
                        disposition_at=150,
                        breached=True,
                        breach_recorded_at=150,
                        duty_disposition="BREACHED",
                    )
                    reject(
                        "early_breach",
                        lambda: market.enforce_breach(
                            row.tranche.tranche_id,
                            breach,
                            model.Clock(179, 1),
                        ),
                    )
                    penalty = record(
                        "enforce_breach",
                        lambda: market.enforce_breach(
                            row.tranche.tranche_id,
                            breach,
                            model.Clock(180, 1),
                        ),
                    )
                    terminal_credit = penalty.credit_id
                    self.assertTrue(
                        market.is_duty_history_safe(
                            breach.duty_id,
                            term,
                            row.tranche.tranche_id,
                            breach,
                            model.Clock(180, 1),
                        )
                    )
                    counts["penalty_history"] += 1
                    trace.append("penalty_history")

            claim_actions = []
            if terminal_credit is not None:
                disposition = market.credits[terminal_credit].disposition
                claim_name = (
                    "claim_penalty"
                    if disposition is model.BondDisposition.PENALTY_CREDITED
                    else "claim_owner"
                )
                claim_actions.append((
                    claim_name,
                    terminal_credit,
                    lambda credit_id=terminal_credit: market.claim_credit(
                        credit_id, lambda *_: None
                    ),
                ))
            for premium_credit_id, credit in tuple(market.premium_credits.items()):
                if not credit.claimed:
                    claim_actions.append((
                        "claim_premium",
                        premium_credit_id,
                        lambda credit_id=premium_credit_id: market.claim_premium_credit(
                            credit_id, lambda *_: None
                        ),
                    ))
            rng.shuffle(claim_actions)
            for claim_name, _credit_id, call in claim_actions:
                record(claim_name, call)

            # Random Task-2 suffixes keep exit and higher-generation purge in
            # the same varied traces without disturbing installed history.
            if market.cached_generation == 7 and rng.random() < 0.45:
                extra = record(
                    "insert",
                    lambda: insert(
                        market,
                        f"e{sequence}",
                        rng.randrange(0, 6),
                        clock=model.Clock(220, 100),
                    ),
                )
                record(
                    "pending_exit",
                    lambda: market.request_pending_exit(
                        extra.tranche.operator,
                        extra.offer.offer_id,
                        model.Clock(220, 100),
                    ),
                )
                reject(
                    "early_pending_finalize",
                    lambda: market.finalize_pending_exit(
                        extra.tranche.tranche_id, model.Clock(239, 100)
                    ),
                )
                refund = record(
                    "pending_finalize",
                    lambda: market.finalize_pending_exit(
                        extra.tranche.tranche_id, model.Clock(240, 100)
                    ),
                )
                record(
                    "claim_owner",
                    lambda: market.claim_credit(refund.credit_id, lambda *_: None),
                )
            if market.cached_generation == 7 and rng.random() < 0.45:
                old = record(
                    "insert",
                    lambda: insert(
                        market,
                        f"g{sequence}",
                        rng.randrange(0, 6),
                        clock=model.Clock(250, 120),
                    ),
                )
                purged = record(
                    "generation_sync",
                    lambda: market.sync_seat_generation(target_view(8)),
                )
                self.assertEqual(purged.purged_count, 1)
                purge_credit = market.credit_id(
                    old.tranche.tranche_id,
                    model.BondDisposition.OWNER_CREDITED,
                )
                record(
                    "claim_owner",
                    lambda: market.claim_credit(purge_credit, lambda *_: None),
                )

            self.assert_reference_oracle(market, shadow_surplus)
            market.assert_valid()
            traces.add(tuple(trace))
            ordered_pairs = {
                "release_then_breach": ("request_release", "enforce_breach"),
                "accrue_then_close": ("accrue", None),
                "close_then_tail": ("healthy_close", "tail_reconcile"),
                "terminalize_then_claim": (None, None),
                "stage_then_invalidate": ("stage", "invalidate"),
                "stage_then_migration_cancel": ("stage", "migration_cancel"),
                "stage_then_install": ("stage", "install"),
            }
            for name, (left, right) in ordered_pairs.items():
                if name == "accrue_then_close":
                    closes = ("healthy_close", "async_close", "enforce_breach")
                    matched = "accrue" in trace and any(
                        trace.index("accrue") < trace.index(close)
                        for close in closes if close in trace
                    )
                elif name == "terminalize_then_claim":
                    terminals = (
                        "migration_cancel", "pending_finalize",
                        "finalize_release", "enforce_breach", "generation_sync",
                    )
                    claims = ("claim_owner", "claim_penalty", "claim_premium")
                    matched = any(
                        terminal in trace and claim in trace
                        and trace.index(terminal) < trace.index(claim)
                        for terminal in terminals for claim in claims
                    )
                else:
                    matched = (
                        left in trace and right in trace
                        and trace.index(left) < trace.index(right)
                    )
                if matched:
                    pair_counts[name] += 1

        self.assertEqual(sequence + 1, 1_000)
        self.assertGreater(len(traces), 900)
        minimum_counts = {
            "sponsor_premium": 1_000,
            "force_eth": 300,
            "insert": 1_000,
            "requote": 100,
            "stage": 1_000,
            "expire": 150,
            "invalidate": 150,
            "migration_cancel": 200,
            "pending_exit": 300,
            "pending_finalize": 300,
            "generation_sync": 300,
            "install": 300,
            "accrue": 300,
            "healthy_close": 80,
            "async_close": 80,
            "tail_reconcile": 80,
            "request_release": 250,
            "finalize_release": 150,
            "enforce_breach": 80,
            "claim_owner": 400,
            "claim_penalty": 80,
            "claim_premium": 300,
            "owner_history_unclaimed_premium": 80,
            "penalty_history": 80,
            "atomic_rejection": 1_000,
        }
        self.assertEqual(set(counts), set(minimum_counts))
        for name, minimum in minimum_counts.items():
            self.assertGreaterEqual(counts[name], minimum, (name, counts))
        for name, count in pair_counts.items():
            self.assertGreaterEqual(count, 80, (name, pair_counts))
        self.assertGreater(sum(counts.values()), 10_000)
        global STATEFUL_COVERAGE
        STATEFUL_COVERAGE = {
            "unique_traces": len(traces),
            "action_counts": dict(counts),
            "pair_counts": dict(pair_counts),
            "total_actions": sum(counts.values()),
        }


if __name__ == "__main__":
    unittest.main(verbosity=2)
