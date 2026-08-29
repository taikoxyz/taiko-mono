#!/usr/bin/env python3
"""Adversarial tests for the bounded perpetual seat-market focused model."""

from __future__ import annotations

import copy
from dataclasses import replace
import importlib.util
import inspect
import itertools
from pathlib import Path
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

    def test_authority_and_clock_inputs_are_immutable(self):
        auth = authorization()
        clock = model.Clock(1, 2)
        with self.assertRaises((AttributeError, TypeError)):
            auth.target = "evil"
        with self.assertRaises((AttributeError, TypeError)):
            clock.timestamp = 3

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
            self.MUTATING_PUBLIC_EVENTS | {"assert_valid", "credit_id"},
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
