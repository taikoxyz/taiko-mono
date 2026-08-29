#!/usr/bin/env python3
"""Focused executable model for the bounded perpetual seat reverse auction.

This file intentionally models only the Task-2 surface: the shared four-cell
offer-book geometry, pending offer/tranche lifecycle, generation purge, exact
bond credits, and pull-payment rollback semantics.  Staging, installation,
premium accrual, release, and enforcement are added by later tasks.
"""

from __future__ import annotations

import copy
from dataclasses import dataclass, field
from enum import Enum
from functools import lru_cache
from pathlib import Path
import re
import runpy
from typing import Callable


UINT256_MAX = (1 << 256) - 1
UINT64_MAX = (1 << 64) - 1
PENDING_COUNT = 4
MAX_STAGE = 1
PROTOCOL_VERSION_BITS = 64
SEAT_GENERATION_BITS = 64
LOOKAHEAD = runpy.run_path(str(Path(__file__).with_name("lookahead-model.py")))
keccak256 = LOOKAHEAD["keccak256"]

_CANONICAL_ADDRESS = re.compile(r"0x[0-9a-f]{40}\Z")
D_AUTHORIZATION = b"TAIKO_SEAT_TARGET_AUTHORIZATION_V1"
D_TRANCHE = b"TAIKO_SEAT_TRANCHE_V1"
D_OFFER = b"TAIKO_SEAT_OFFER_V1"
D_CREDIT = b"TAIKO_SEAT_BOND_CREDIT_V1"


class TransitionRejected(Exception):
    """A state transition did not satisfy its exact preconditions."""


class ArithmeticFault(TransitionRejected):
    """Checked uint256 arithmetic failed."""


def _uint(value: int, name: str = "value") -> int:
    if type(value) is not int:
        raise ArithmeticFault(f"{name} is not a uint256")
    if value < 0 or value > UINT256_MAX:
        raise ArithmeticFault(f"{name} is outside uint256")
    return value


def checked_add(left: int, right: int) -> int:
    left = _uint(left, "left operand")
    right = _uint(right, "right operand")
    result = left + right
    if result > UINT256_MAX:
        raise ArithmeticFault("uint256 addition overflow")
    return result


def checked_sub(left: int, right: int) -> int:
    left = _uint(left, "left operand")
    right = _uint(right, "right operand")
    if right > left:
        raise ArithmeticFault("uint256 subtraction underflow")
    return left - right


def u8(value: int) -> bytes:
    value = _uint(value)
    if value >= 1 << 8:
        raise ArithmeticFault("value is outside uint8")
    return value.to_bytes(1, "big")


def u64(value: int) -> bytes:
    value = _uint(value)
    if value > UINT64_MAX:
        raise ArithmeticFault("value is outside uint64")
    return value.to_bytes(8, "big")


def u256(value: int) -> bytes:
    return _uint(value).to_bytes(32, "big")


def _bytes32(value: bytes, name: str) -> bytes:
    if type(value) is not bytes or len(value) != 32:
        raise TransitionRejected(f"{name} must be exact bytes32")
    return value


def _bytes4(value: bytes, name: str) -> bytes:
    if type(value) is not bytes or len(value) != 4:
        raise TransitionRejected(f"{name} must be exact bytes4")
    return value


def _canonical_address(value: str, name: str) -> str:
    if type(value) is not str or _CANONICAL_ADDRESS.fullmatch(value) is None:
        raise TransitionRejected(f"{name} is not a canonical address")
    if value == "0x" + "00" * 20:
        raise TransitionRejected(f"{name} must be nonzero")
    return value


def address20(value: str, name: str = "address") -> bytes:
    return bytes.fromhex(_canonical_address(value, name)[2:])


@lru_cache(maxsize=None)
def hash_fixed(domain: bytes, *fields: bytes) -> bytes:
    """Legacy Keccak over one ASCII domain and already-fixed-width fields."""

    if (
        type(domain) is not bytes
        or len(domain) == 0
        or any(byte < 0x20 or byte > 0x7E for byte in domain)
    ):
        raise TransitionRejected("hash domain must be nonempty ASCII bytes")
    for field_value in fields:
        if type(field_value) is not bytes:
            raise TransitionRejected("codec field must be exact bytes")
    return keccak256(domain + b"".join(fields))


class OfferLocation(Enum):
    NONE = 0
    PENDING = 1
    STAGED = 2


class TrancheUsage(Enum):
    OFFER = 1
    STAGED = 2
    INSTALLED = 3
    CLOSED_UNINSTALLED = 4


class BondDisposition(Enum):
    NONE = 0
    OWNER_CREDITED = 1
    PENALTY_CREDITED = 2


@dataclass(frozen=True)
class Clock:
    timestamp: int
    block_number: int


@dataclass
class BondTranche:
    tranche_id: bytes
    operator: str
    bond_amount: int
    creation_sequence: int
    authorization_id: bytes
    generation: int
    usage: TrancheUsage
    disposition: BondDisposition = BondDisposition.NONE
    current_offer_id: bytes | None = None
    installed_term_id: bytes | None = None
    pending_refund_at: int | None = None
    release_requested_at: int | None = None


@dataclass
class Offer:
    offer_id: bytes
    tranche_id: bytes
    operator: str
    payout: str
    ask_wei_per_second: int
    eligible_at_timestamp: int
    eligible_at_block: int
    quote_sequence: int
    target: str
    authorization_id: bytes
    generation: int
    location: OfferLocation = OfferLocation.PENDING

    @property
    def order_key(self) -> tuple[int, int, int, int, str]:
        return (
            self.ask_wei_per_second,
            self.eligible_at_timestamp,
            self.eligible_at_block,
            self.quote_sequence,
            self.operator,
        )


@dataclass
class Stage:
    stage_id: bytes
    offer_id: bytes


@dataclass
class ExactCredit:
    credit_id: bytes
    tranche_id: bytes
    beneficiary: str
    amount: int
    disposition: BondDisposition
    claimed: bool = False


@dataclass
class PremiumReserve:
    reserve_id: bytes
    reserved_wei: int


@dataclass
class MarketAccounting:
    bond_escrow: int = 0
    outstanding_owner_credits: int = 0
    outstanding_penalty_credits: int = 0
    free_premium: int = 0
    reserved_premium: int = 0
    outstanding_premium_claims: int = 0
    live_reserves: dict[bytes, PremiumReserve] = field(default_factory=dict)

    @property
    def accounted_balance(self) -> int:
        total = 0
        for amount in (
            self.bond_escrow,
            self.outstanding_owner_credits,
            self.outstanding_penalty_credits,
            self.free_premium,
            self.reserved_premium,
            self.outstanding_premium_claims,
        ):
            total = checked_add(total, amount)
        return total

    def assert_valid(self, actual_balance: int) -> None:
        actual_balance = _uint(actual_balance, "actual balance")
        for name in (
            "bond_escrow",
            "outstanding_owner_credits",
            "outstanding_penalty_credits",
            "free_premium",
            "reserved_premium",
            "outstanding_premium_claims",
        ):
            _uint(getattr(self, name), name)
        reserve_sum = 0
        for reserve_id, reserve in self.live_reserves.items():
            if not isinstance(reserve_id, bytes) or len(reserve_id) == 0:
                raise AssertionError("invalid reserve key")
            if reserve.reserve_id != reserve_id:
                raise AssertionError("reserve key mismatch")
            reserve_sum = checked_add(reserve_sum, reserve.reserved_wei)
        if self.reserved_premium != reserve_sum:
            raise AssertionError("reserved premium summary mismatch")
        if actual_balance < self.accounted_balance:
            raise AssertionError("actual balance is below accounted balance")


@dataclass(frozen=True)
class TargetAuthorization:
    target: str
    settlement_chain_id: int
    protocol_version: int
    runtime_hash: bytes
    configuration_hash: bytes
    expected_magic: bytes


@dataclass(frozen=True)
class ExactTargetView:
    target: str
    settlement_chain_id: int
    protocol_version: int
    runtime_hash: bytes
    configuration_hash: bytes
    magic: bytes
    phase: str
    generation: int


def authorization_identity(
    market_chain_id: int, market_address: str, auth: TargetAuthorization
) -> bytes:
    """Commit the exact authorized target identity into one fixed word."""

    if type(auth) is not TargetAuthorization:
        raise TransitionRejected("invalid target authorization")
    return hash_fixed(
        D_AUTHORIZATION,
        u256(market_chain_id),
        address20(market_address, "market address"),
        u256(auth.settlement_chain_id),
        u64(auth.protocol_version),
        address20(auth.target, "authorized target"),
        _bytes32(auth.runtime_hash, "runtime hash"),
        _bytes32(auth.configuration_hash, "configuration hash"),
        _bytes4(auth.expected_magic, "expected magic"),
    )


def tranche_identity(
    authorization_id: bytes,
    generation: int,
    operator: str,
    bond_amount: int,
    creation_sequence: int,
) -> bytes:
    """Encode one immutable bond-tranche identity without dynamic fields."""

    return hash_fixed(
        D_TRANCHE,
        _bytes32(authorization_id, "authorization ID"),
        u64(generation),
        address20(operator, "operator"),
        u256(bond_amount),
        u256(creation_sequence),
    )


def offer_identity(
    authorization_id: bytes,
    generation: int,
    tranche_id: bytes,
    payout: str,
    ask_wei_per_second: int,
    eligible_at_timestamp: int,
    eligible_at_block: int,
    quote_sequence: int,
) -> bytes:
    """Encode one quote identity with the complete immutable quote tuple."""

    return hash_fixed(
        D_OFFER,
        _bytes32(authorization_id, "authorization ID"),
        u64(generation),
        _bytes32(tranche_id, "tranche ID"),
        address20(payout, "payout"),
        u256(ask_wei_per_second),
        u256(eligible_at_timestamp),
        u256(eligible_at_block),
        u256(quote_sequence),
    )


def bond_credit_identity(
    market_chain_id: int,
    market_address: str,
    tranche_id: bytes,
    disposition: BondDisposition,
) -> bytes:
    """Encode the sole OWNER or PENALTY credit for one tranche."""

    if type(disposition) is not BondDisposition or disposition not in (
        BondDisposition.OWNER_CREDITED,
        BondDisposition.PENALTY_CREDITED,
    ):
        raise TransitionRejected("credit disposition must be terminal")
    return hash_fixed(
        D_CREDIT,
        u256(market_chain_id),
        address20(market_address, "market address"),
        _bytes32(tranche_id, "tranche ID"),
        u8(disposition.value),
    )


@dataclass
class TransitionResult:
    offer: Offer | None = None
    tranche: BondTranche | None = None
    displaced_offer_id: bytes | None = None
    credit_id: bytes | None = None
    purged_count: int = 0
    amount: int = 0


TransferCallback = Callable[[str, int, "SeatMarket"], None]


class SeatMarket:
    """A small, strict state machine for Task-2 design validation."""

    def __setattr__(self, name: str, value: object) -> None:
        if name in {
            "_penalty_sink",
            "_sla_bond",
            "_immutable_maximum_ask",
        } and name in self.__dict__:
            raise AttributeError(f"{name[1:]} is immutable")
        object.__setattr__(self, name, value)

    def __init__(
        self,
        *,
        market_chain_id: int,
        market_address: str,
        sla_bond: int,
        immutable_maximum_ask: int,
        quote_maturity_seconds: int,
        quote_maturity_blocks: int,
        exit_delay_seconds: int,
        penalty_sink: str,
        authorization: TargetAuthorization,
        insertion_enabled: bool,
        cached_generation: int | None,
        starting_quote_sequence: int = 0,
        starting_creation_sequence: int = 0,
    ) -> None:
        self.market_chain_id = _uint(market_chain_id, "market chain id")
        self.market_address = _canonical_address(market_address, "market address")
        self._penalty_sink = _canonical_address(penalty_sink, "penalty sink")
        self._sla_bond = _uint(sla_bond, "SLA bond")
        if self._sla_bond == 0:
            raise TransitionRejected("SLA bond must be nonzero")
        self._immutable_maximum_ask = _uint(
            immutable_maximum_ask, "immutable maximum ask"
        )
        self.quote_maturity_seconds = _uint(
            quote_maturity_seconds, "quote maturity seconds"
        )
        self.quote_maturity_blocks = _uint(
            quote_maturity_blocks, "quote maturity blocks"
        )
        self.exit_delay_seconds = _uint(exit_delay_seconds, "exit delay seconds")
        self._validate_authorization_record(authorization)
        if type(insertion_enabled) is not bool:
            raise TransitionRejected("insertion-enabled flag must be boolean")
        initial_authorization_id = authorization_identity(
            self.market_chain_id, self.market_address, authorization
        )
        self.authorizations: dict[bytes, TargetAuthorization] = {
            initial_authorization_id: authorization
        }
        self.authorization_enabled: dict[bytes, bool] = {
            initial_authorization_id: insertion_enabled
        }
        self.current_authorization_id = initial_authorization_id
        self.cached_generation = (
            None
            if cached_generation is None
            else int.from_bytes(u64(cached_generation), "big")
        )
        self.quote_sequence = _uint(starting_quote_sequence, "starting quote sequence")
        self.creation_sequence = _uint(
            starting_creation_sequence, "starting creation sequence"
        )

        self.offers: dict[bytes, Offer] = {}
        self.tranches: dict[bytes, BondTranche] = {}
        self.credits: dict[bytes, ExactCredit] = {}
        self.pending_offer_ids: list[bytes] = []
        self.stage: Stage | None = None
        self.accounting = MarketAccounting()
        self.actual_balance = 0
        self.assert_valid()

    def __eq__(self, other: object) -> bool:
        return isinstance(other, SeatMarket) and self.__dict__ == other.__dict__

    @property
    def penalty_sink(self) -> str:
        return self._penalty_sink

    @property
    def sla_bond(self) -> int:
        return self._sla_bond

    @property
    def immutable_maximum_ask(self) -> int:
        return self._immutable_maximum_ask

    @property
    def authorization(self) -> TargetAuthorization:
        return self.authorizations[self.current_authorization_id]

    @property
    def insertion_enabled(self) -> bool:
        return self.authorization_enabled[self.current_authorization_id]

    def _set_authorization_enabled(self, authorization_id: bytes, enabled: bool) -> None:
        """Test-only primitive for the future release-manager authorization path."""

        snapshot = copy.deepcopy(self.__dict__)
        try:
            self.assert_valid()
            _bytes32(authorization_id, "authorization ID")
            if authorization_id not in self.authorizations:
                raise TransitionRejected("unknown authorization ID")
            if type(enabled) is not bool:
                raise TransitionRejected("enabled flag must be boolean")
            if not enabled:
                for offer in self.offers.values():
                    if (
                        offer.authorization_id == authorization_id
                        and offer.location in (
                            OfferLocation.PENDING,
                            OfferLocation.STAGED,
                        )
                    ):
                        raise TransitionRejected(
                            "live waiting records must be closed before disable"
                        )
            self.authorization_enabled[authorization_id] = enabled
            self.assert_valid()
        except BaseException:
            self.__dict__.clear()
            self.__dict__.update(snapshot)
            raise

    def _register_authorization(
        self,
        auth: TargetAuthorization,
        *,
        enabled: bool,
        make_current: bool,
    ) -> bytes:
        """Test-only append/point primitive; Task 2 exposes no public rotation."""

        snapshot = copy.deepcopy(self.__dict__)
        try:
            self.assert_valid()
            self._validate_authorization_record(auth)
            if type(enabled) is not bool or type(make_current) is not bool:
                raise TransitionRejected("authorization flags must be boolean")
            authorization_id = authorization_identity(
                self.market_chain_id, self.market_address, auth
            )
            if authorization_id in self.authorizations:
                raise TransitionRejected("authorization registry is append-only")
            if make_current and (self.pending_count != 0 or self.stage is not None):
                raise TransitionRejected("rotation requires no live waiting records")
            self.authorizations[authorization_id] = auth
            self.authorization_enabled[authorization_id] = enabled
            if make_current:
                self.current_authorization_id = authorization_id
                self.cached_generation = None
            self.assert_valid()
            return authorization_id
        except BaseException:
            self.__dict__.clear()
            self.__dict__.update(snapshot)
            raise

    @staticmethod
    def _validate_clock(clock: Clock) -> None:
        if type(clock) is not Clock:
            raise TransitionRejected("invalid clock")
        _uint(clock.timestamp, "clock timestamp")
        _uint(clock.block_number, "clock block number")

    @staticmethod
    def _validate_authorization_record(auth: TargetAuthorization) -> None:
        if type(auth) is not TargetAuthorization:
            raise TransitionRejected("invalid target authorization")
        _canonical_address(auth.target, "authorized target")
        _uint(auth.settlement_chain_id, "settlement chain id")
        u64(auth.protocol_version)
        for name, raw in (
            ("runtime hash", auth.runtime_hash),
            ("configuration hash", auth.configuration_hash),
        ):
            _bytes32(raw, name)
        _bytes4(auth.expected_magic, "expected magic")

    @property
    def pending_count(self) -> int:
        return len(self.pending_offer_ids)

    @property
    def staged_count(self) -> int:
        return 0 if self.stage is None else 1

    @property
    def pending_offers(self) -> list[Offer]:
        return [self.offers[offer_id] for offer_id in self.pending_offer_ids]

    @property
    def surplus(self) -> int:
        return checked_sub(self.actual_balance, self.accounting.accounted_balance)

    def _atomic(self, transition: Callable[[], TransitionResult]) -> TransitionResult:
        snapshot = copy.deepcopy(self.__dict__)
        try:
            try:
                self.assert_valid()
            except AssertionError as exc:
                raise TransitionRejected("invalid pre-transition state") from exc
            result = transition()
            self.assert_valid()
            return result
        except BaseException:
            self.__dict__.clear()
            self.__dict__.update(snapshot)
            raise

    def _require_current_authority(self, target: str, generation: int) -> None:
        if not self.insertion_enabled:
            raise TransitionRejected("offer insertion is disabled")
        if self.cached_generation is None:
            raise TransitionRejected("generation cache is uninitialized")
        _canonical_address(target, "target")
        if target != self.authorization.target:
            raise TransitionRejected("wrong installation target")
        generation_value = int.from_bytes(u64(generation), "big")
        if generation_value != self.cached_generation:
            raise TransitionRejected("stale generation")

    def _validate_exact_target_view(self, view: ExactTargetView) -> int:
        if type(view) is not ExactTargetView:
            raise TransitionRejected("malformed target view")
        _canonical_address(view.target, "view target")
        _uint(view.settlement_chain_id, "view settlement chain id")
        u64(view.protocol_version)
        _bytes32(view.runtime_hash, "view runtime hash")
        _bytes32(view.configuration_hash, "view configuration hash")
        _bytes4(view.magic, "view magic")
        if type(view.phase) is not str or view.phase != "ACTIVE":
            raise TransitionRejected("view phase is not exact ACTIVE")
        return int.from_bytes(u64(view.generation), "big")

    def _new_tranche_id(
        self,
        operator: str,
        sequence: int,
        authorization_id: bytes,
        generation: int,
    ) -> bytes:
        return tranche_identity(
            authorization_id,
            generation,
            operator,
            self.sla_bond,
            sequence,
        )

    def _new_offer_id(
        self,
        *,
        tranche_id: bytes,
        sequence: int,
        authorization_id: bytes,
        generation: int,
        payout: str,
        ask: int,
        eligible_at_timestamp: int,
        eligible_at_block: int,
    ) -> bytes:
        return offer_identity(
            authorization_id,
            generation,
            tranche_id,
            payout,
            ask,
            eligible_at_timestamp,
            eligible_at_block,
            sequence,
        )

    def credit_id(self, tranche_id: bytes, disposition: BondDisposition) -> bytes:
        return bond_credit_identity(
            self.market_chain_id,
            self.market_address,
            tranche_id,
            disposition,
        )

    def _fresh_quote_sequence(self) -> int:
        sequence = checked_add(self.quote_sequence, 1)
        self.quote_sequence = sequence
        return sequence

    def _fresh_creation_sequence(self) -> int:
        sequence = checked_add(self.creation_sequence, 1)
        self.creation_sequence = sequence
        return sequence

    def _sort_pending(self) -> None:
        self.pending_offer_ids.sort(key=lambda offer_id: self.offers[offer_id].order_key)

    def insert_offer(
        self,
        *,
        caller: str,
        payout: str,
        ask_wei_per_second: int,
        target: str,
        generation: int,
        clock: Clock,
        value: int,
    ) -> TransitionResult:
        def transition() -> TransitionResult:
            operator = _canonical_address(caller, "caller")
            payout_value = _canonical_address(payout, "payout")
            self._validate_clock(clock)
            self._require_current_authority(target, generation)
            ask = _uint(ask_wei_per_second, "ask")
            if ask > self.immutable_maximum_ask:
                raise TransitionRejected("ask exceeds immutable maximum")
            if _uint(value, "inserted value") != self.sla_bond:
                raise TransitionRejected("insertion must escrow exactly one SLA bond")

            creation_sequence = self._fresh_creation_sequence()
            quote_sequence = self._fresh_quote_sequence()
            authorization_id = self.current_authorization_id
            eligible_at_timestamp = checked_add(
                clock.timestamp, self.quote_maturity_seconds
            )
            eligible_at_block = checked_add(
                clock.block_number, self.quote_maturity_blocks
            )
            tranche_id = self._new_tranche_id(
                operator, creation_sequence, authorization_id, generation
            )
            offer_id = self._new_offer_id(
                tranche_id=tranche_id,
                sequence=quote_sequence,
                authorization_id=authorization_id,
                generation=generation,
                payout=payout_value,
                ask=ask,
                eligible_at_timestamp=eligible_at_timestamp,
                eligible_at_block=eligible_at_block,
            )
            if tranche_id in self.tranches or offer_id in self.offers:
                raise TransitionRejected("identity collision")
            offer = Offer(
                offer_id=offer_id,
                tranche_id=tranche_id,
                operator=operator,
                payout=payout_value,
                ask_wei_per_second=ask,
                eligible_at_timestamp=eligible_at_timestamp,
                eligible_at_block=eligible_at_block,
                quote_sequence=quote_sequence,
                target=target,
                authorization_id=authorization_id,
                generation=generation,
            )
            tranche = BondTranche(
                tranche_id=tranche_id,
                operator=operator,
                bond_amount=self.sla_bond,
                creation_sequence=creation_sequence,
                authorization_id=authorization_id,
                generation=generation,
                usage=TrancheUsage.OFFER,
                current_offer_id=offer_id,
            )

            capacity = PENDING_COUNT - self.staged_count
            displaced_offer_id = None
            credit_id = None
            if self.pending_count >= capacity:
                if capacity == 0:
                    raise TransitionRejected("no pending capacity")
                worst = self.pending_offers[-1]
                if not offer.order_key < worst.order_key:
                    raise TransitionRejected("fifth offer does not strictly beat worst")
                displaced_offer_id = worst.offer_id
                displaced_tranche_id = worst.tranche_id
                self.pending_offer_ids.remove(worst.offer_id)
                worst.location = OfferLocation.NONE
                displaced = self.tranches[displaced_tranche_id]
                displaced.usage = TrancheUsage.CLOSED_UNINSTALLED
                credit_id = self._terminalize_owner(displaced_tranche_id)

            self.offers[offer_id] = offer
            self.tranches[tranche_id] = tranche
            self.pending_offer_ids.append(offer_id)
            self._sort_pending()
            self.accounting.bond_escrow = checked_add(
                self.accounting.bond_escrow, self.sla_bond
            )
            self.actual_balance = checked_add(self.actual_balance, value)
            return TransitionResult(
                offer=offer,
                tranche=tranche,
                displaced_offer_id=displaced_offer_id,
                credit_id=credit_id,
            )

        return self._atomic(transition)

    def requote(
        self,
        *,
        caller: str,
        offer_id: bytes,
        payout: str,
        ask_wei_per_second: int,
        target: str,
        generation: int,
        clock: Clock,
    ) -> TransitionResult:
        def transition() -> TransitionResult:
            self._validate_clock(clock)
            self._require_current_authority(target, generation)
            old_offer = self.offers.get(offer_id)
            if old_offer is None:
                raise TransitionRejected("unknown or stale offer ID")
            tranche = self.tranches.get(old_offer.tranche_id)
            if tranche is None or tranche.current_offer_id != offer_id:
                raise TransitionRejected("offer/tranche binding mismatch")
            caller_value = _canonical_address(caller, "caller")
            if caller_value != tranche.operator or caller_value != old_offer.operator:
                raise TransitionRejected("only immutable operator may requote")
            if (
                old_offer.location is not OfferLocation.PENDING
                or tranche.usage is not TrancheUsage.OFFER
                or tranche.disposition is not BondDisposition.NONE
                or offer_id not in self.pending_offer_ids
                or tranche.pending_refund_at is not None
            ):
                raise TransitionRejected("requote requires a live pending offer")
            if old_offer.target != target or old_offer.generation != generation:
                raise TransitionRejected("stale offer authority")
            payout_value = _canonical_address(payout, "payout")
            ask = _uint(ask_wei_per_second, "ask")
            if ask > self.immutable_maximum_ask:
                raise TransitionRejected("ask exceeds immutable maximum")
            if ask > old_offer.ask_wei_per_second:
                raise TransitionRejected("ask increase is forbidden")
            if ask == old_offer.ask_wei_per_second and payout_value == old_offer.payout:
                raise TransitionRejected("requote is a no-op")

            quote_sequence = self._fresh_quote_sequence()
            eligible_at_timestamp = checked_add(
                clock.timestamp, self.quote_maturity_seconds
            )
            eligible_at_block = checked_add(
                clock.block_number, self.quote_maturity_blocks
            )
            new_offer_id = self._new_offer_id(
                tranche_id=tranche.tranche_id,
                sequence=quote_sequence,
                authorization_id=tranche.authorization_id,
                generation=tranche.generation,
                payout=payout_value,
                ask=ask,
                eligible_at_timestamp=eligible_at_timestamp,
                eligible_at_block=eligible_at_block,
            )
            if new_offer_id in self.offers:
                raise TransitionRejected("offer identity collision")
            new_offer = Offer(
                offer_id=new_offer_id,
                tranche_id=tranche.tranche_id,
                operator=tranche.operator,
                payout=payout_value,
                ask_wei_per_second=ask,
                eligible_at_timestamp=eligible_at_timestamp,
                eligible_at_block=eligible_at_block,
                quote_sequence=quote_sequence,
                target=target,
                authorization_id=tranche.authorization_id,
                generation=generation,
            )
            old_offer.location = OfferLocation.NONE
            self.pending_offer_ids.remove(offer_id)
            self.offers[new_offer_id] = new_offer
            self.pending_offer_ids.append(new_offer_id)
            tranche.current_offer_id = new_offer_id
            self._sort_pending()
            return TransitionResult(offer=new_offer, tranche=tranche)

        return self._atomic(transition)

    def request_pending_exit(
        self, caller: str, offer_id: bytes, clock: Clock
    ) -> TransitionResult:
        def transition() -> TransitionResult:
            self._validate_clock(clock)
            offer = self.offers.get(offer_id)
            if offer is None:
                raise TransitionRejected("unknown or stale offer ID")
            tranche = self.tranches.get(offer.tranche_id)
            if tranche is None or tranche.current_offer_id != offer_id:
                raise TransitionRejected("offer/tranche binding mismatch")
            caller_value = _canonical_address(caller, "caller")
            if caller_value != tranche.operator or caller_value != offer.operator:
                raise TransitionRejected("only immutable operator may exit")
            if (
                offer.location is not OfferLocation.PENDING
                or tranche.usage is not TrancheUsage.OFFER
                or tranche.disposition is not BondDisposition.NONE
                or offer_id not in self.pending_offer_ids
                or tranche.pending_refund_at is not None
            ):
                raise TransitionRejected("pending exit requires a live pending offer")
            offer.location = OfferLocation.NONE
            self.pending_offer_ids.remove(offer_id)
            tranche.usage = TrancheUsage.CLOSED_UNINSTALLED
            tranche.pending_refund_at = checked_add(
                clock.timestamp, self.exit_delay_seconds
            )
            return TransitionResult(offer=offer, tranche=tranche)

        return self._atomic(transition)

    def finalize_pending_exit(
        self, tranche_id: bytes, clock: Clock
    ) -> TransitionResult:
        def transition() -> TransitionResult:
            self._validate_clock(clock)
            tranche = self.tranches.get(tranche_id)
            if tranche is None:
                raise TransitionRejected("unknown tranche")
            offer = (
                self.offers.get(tranche.current_offer_id)
                if tranche.current_offer_id is not None
                else None
            )
            if (
                tranche.usage is not TrancheUsage.CLOSED_UNINSTALLED
                or tranche.disposition is not BondDisposition.NONE
                or tranche.pending_refund_at is None
                or offer is None
                or offer.location is not OfferLocation.NONE
            ):
                raise TransitionRejected("tranche is not awaiting pending refund")
            if clock.timestamp < tranche.pending_refund_at:
                raise TransitionRejected("pending refund is not mature")
            credit_id = self._terminalize_owner(tranche_id)
            return TransitionResult(
                offer=offer, tranche=tranche, credit_id=credit_id
            )

        return self._atomic(transition)

    def _terminalize_owner(self, tranche_id: bytes) -> bytes:
        return self._terminalize(tranche_id, BondDisposition.OWNER_CREDITED)

    def _terminalize_penalty(self, tranche_id: bytes) -> bytes:
        """Model-only primitive for Task-3 breach tests; not a public transition."""

        return self._terminalize(tranche_id, BondDisposition.PENALTY_CREDITED)

    def _terminalize(
        self, tranche_id: bytes, disposition: BondDisposition
    ) -> bytes:
        tranche = self.tranches.get(tranche_id)
        if tranche is None:
            raise TransitionRejected("unknown tranche")
        if tranche.disposition is not BondDisposition.NONE:
            raise TransitionRejected("bond already terminalized")
        if (
            disposition is BondDisposition.OWNER_CREDITED
            and tranche.usage is not TrancheUsage.CLOSED_UNINSTALLED
        ):
            raise TransitionRejected("owner credit requires a closed uninstalled tranche")
        if (
            disposition is BondDisposition.PENALTY_CREDITED
            and tranche.usage is not TrancheUsage.INSTALLED
        ):
            raise TransitionRejected("penalty credit requires an installed tranche")
        if disposition not in (
            BondDisposition.OWNER_CREDITED,
            BondDisposition.PENALTY_CREDITED,
        ):
            raise TransitionRejected("invalid terminal disposition")
        credit_id = self.credit_id(tranche_id, disposition)
        if credit_id in self.credits:
            raise TransitionRejected("deterministic credit already exists")
        beneficiary = (
            tranche.operator
            if disposition is BondDisposition.OWNER_CREDITED
            else self.penalty_sink
        )
        credit = ExactCredit(
            credit_id=credit_id,
            tranche_id=tranche_id,
            beneficiary=beneficiary,
            amount=tranche.bond_amount,
            disposition=disposition,
        )
        self.accounting.bond_escrow = checked_sub(
            self.accounting.bond_escrow, tranche.bond_amount
        )
        if disposition is BondDisposition.OWNER_CREDITED:
            self.accounting.outstanding_owner_credits = checked_add(
                self.accounting.outstanding_owner_credits, tranche.bond_amount
            )
        else:
            self.accounting.outstanding_penalty_credits = checked_add(
                self.accounting.outstanding_penalty_credits, tranche.bond_amount
            )
        tranche.disposition = disposition
        self.credits[credit_id] = credit
        return credit_id

    def sync_seat_generation(self, view: ExactTargetView) -> TransitionResult:
        def transition() -> TransitionResult:
            generation = self._validate_exact_target_view(view)
            auth = self.authorization
            exact = (
                view.target == auth.target
                and view.settlement_chain_id == auth.settlement_chain_id
                and view.protocol_version == auth.protocol_version
                and view.runtime_hash == auth.runtime_hash
                and view.configuration_hash == auth.configuration_hash
                and view.magic == auth.expected_magic
                and view.phase == "ACTIVE"
            )
            if not exact:
                raise TransitionRejected("target view does not match authorization")
            if self.cached_generation is not None and generation < self.cached_generation:
                raise TransitionRejected("generation cannot decrease")
            if generation == self.cached_generation:
                return TransitionResult(purged_count=0)

            purged = 0
            for offer_id in tuple(self.pending_offer_ids):
                offer = self.offers[offer_id]
                tranche = self.tranches[offer.tranche_id]
                if (
                    offer.location is not OfferLocation.PENDING
                    or tranche.usage is not TrancheUsage.OFFER
                    or tranche.disposition is not BondDisposition.NONE
                ):
                    raise TransitionRejected("corrupt pending cell")
                self.pending_offer_ids.remove(offer_id)
                offer.location = OfferLocation.NONE
                tranche.usage = TrancheUsage.CLOSED_UNINSTALLED
                self._terminalize_owner(tranche.tranche_id)
                purged = checked_add(purged, 1)
            # Cache commits last, after every bounded purge and credit succeeds.
            self.cached_generation = generation
            return TransitionResult(purged_count=purged)

        return self._atomic(transition)

    def claim_credit(
        self, credit_id: bytes, transfer: TransferCallback
    ) -> TransitionResult:
        def transition() -> TransitionResult:
            credit = self.credits.get(credit_id)
            if credit is None:
                raise TransitionRejected("unknown exact credit")
            if credit.claimed:
                raise TransitionRejected("exact credit already claimed")
            if credit.amount == 0:
                raise TransitionRejected("zero credit cannot be claimed")
            if not callable(transfer):
                raise TransitionRejected("transfer callback is not callable")

            # Effects precede interaction.  Any exception restores the complete
            # pre-call snapshot, including successful nested model transitions.
            credit.claimed = True
            if credit.disposition is BondDisposition.OWNER_CREDITED:
                self.accounting.outstanding_owner_credits = checked_sub(
                    self.accounting.outstanding_owner_credits, credit.amount
                )
            elif credit.disposition is BondDisposition.PENALTY_CREDITED:
                self.accounting.outstanding_penalty_credits = checked_sub(
                    self.accounting.outstanding_penalty_credits, credit.amount
                )
            else:
                raise TransitionRejected("credit has nonterminal disposition")
            self.actual_balance = checked_sub(self.actual_balance, credit.amount)
            transfer(credit.beneficiary, credit.amount, self)
            return TransitionResult(
                tranche=self.tranches[credit.tranche_id],
                credit_id=credit_id,
                amount=credit.amount,
            )

        return self._atomic(transition)

    def force_eth(self, amount: int) -> None:
        snapshot = copy.deepcopy(self.__dict__)
        try:
            try:
                self.assert_valid()
            except AssertionError as exc:
                raise TransitionRejected("invalid pre-transition state") from exc
            self.actual_balance = checked_add(self.actual_balance, amount)
            self.assert_valid()
        except BaseException:
            self.__dict__.clear()
            self.__dict__.update(snapshot)
            raise

    def assert_valid(self) -> None:
        try:
            self._assert_valid()
        except (TransitionRejected, KeyError, TypeError, ValueError) as exc:
            raise AssertionError(str(exc)) from exc

    def _assert_valid(self) -> None:
        _uint(self.market_chain_id, "market chain id")
        _canonical_address(self.market_address, "market address")
        _canonical_address(self.penalty_sink, "penalty sink")
        if self.sla_bond == 0:
            raise AssertionError("SLA bond must be nonzero")
        _uint(self.sla_bond, "SLA bond")
        _uint(self.quote_sequence, "quote sequence")
        _uint(self.creation_sequence, "creation sequence")
        _bytes32(self.current_authorization_id, "current authorization ID")
        if set(self.authorizations) != set(self.authorization_enabled):
            raise AssertionError("authorization registry/enabled keys differ")
        if self.current_authorization_id not in self.authorizations:
            raise AssertionError("current authorization is not registered")
        for authorization_id, auth in self.authorizations.items():
            _bytes32(authorization_id, "registered authorization ID")
            self._validate_authorization_record(auth)
            if (
                authorization_identity(
                    self.market_chain_id, self.market_address, auth
                )
                != authorization_id
            ):
                raise AssertionError("registered immutable authorization changed")
            if type(self.authorization_enabled[authorization_id]) is not bool:
                raise AssertionError("authorization enabled state is not boolean")
        if self.cached_generation is not None:
            u64(self.cached_generation)
        if self.staged_count > MAX_STAGE:
            raise AssertionError("more than one stage")
        if self.pending_count + self.staged_count > PENDING_COUNT:
            raise AssertionError("shared pending/staged capacity exceeded")
        if len(set(self.pending_offer_ids)) != self.pending_count:
            raise AssertionError("duplicate pending cell")
        pending_ids = set(self.pending_offer_ids)
        for offer_id in self.pending_offer_ids:
            _bytes32(offer_id, "pending offer ID")
            if offer_id not in self.offers:
                raise AssertionError("pending cell references unknown offer")
        if self.pending_offer_ids != sorted(
            self.pending_offer_ids, key=lambda offer_id: self.offers[offer_id].order_key
        ):
            raise AssertionError("pending book is not in complete deterministic order")
        staged_offer_id = None
        if self.stage is not None:
            _bytes32(self.stage.stage_id, "stage ID")
            _bytes32(self.stage.offer_id, "staged offer ID")
            staged_offer_id = self.stage.offer_id
            staged_offer = self.offers.get(self.stage.offer_id)
            if staged_offer is None or staged_offer.location is not OfferLocation.STAGED:
                raise AssertionError("stage does not bind a staged offer")
            staged_tranche = self.tranches.get(staged_offer.tranche_id)
            if (
                staged_tranche is None
                or staged_tranche.usage is not TrancheUsage.STAGED
                or staged_tranche.current_offer_id != staged_offer.offer_id
                or staged_tranche.disposition is not BondDisposition.NONE
            ):
                raise AssertionError("stage/tranche state mismatch")

        quote_sequences: set[int] = set()
        for offer_id, offer in self.offers.items():
            _bytes32(offer_id, "offer key")
            if offer.offer_id != offer_id:
                raise AssertionError("offer key mismatch")
            _bytes32(offer.tranche_id, "offer tranche ID")
            _bytes32(offer.authorization_id, "offer authorization ID")
            _canonical_address(offer.operator, "offer operator")
            _canonical_address(offer.payout, "offer payout")
            _canonical_address(offer.target, "offer target")
            _uint(offer.ask_wei_per_second, "offer ask")
            _uint(offer.eligible_at_timestamp, "offer eligible timestamp")
            _uint(offer.eligible_at_block, "offer eligible block")
            _uint(offer.quote_sequence, "offer quote sequence")
            u64(offer.generation)
            if offer.quote_sequence in quote_sequences:
                raise AssertionError("quote sequence was reused")
            quote_sequences.add(offer.quote_sequence)
            if offer.quote_sequence > self.quote_sequence:
                raise AssertionError("offer quote sequence exceeds counter")
            expected_offer_id = self._new_offer_id(
                tranche_id=offer.tranche_id,
                sequence=offer.quote_sequence,
                authorization_id=offer.authorization_id,
                generation=offer.generation,
                payout=offer.payout,
                ask=offer.ask_wei_per_second,
                eligible_at_timestamp=offer.eligible_at_timestamp,
                eligible_at_block=offer.eligible_at_block,
            )
            if expected_offer_id != offer_id:
                raise AssertionError("offer ID does not commit immutable fields")
            tranche = self.tranches.get(offer.tranche_id)
            if tranche is None:
                raise AssertionError("offer references unknown tranche")
            if offer.operator != tranche.operator:
                raise AssertionError("offer/tranche operator mismatch")
            auth = self.authorizations.get(offer.authorization_id)
            if auth is None:
                raise AssertionError("offer authorization is not registered")
            if (
                offer.authorization_id != tranche.authorization_id
                or offer.generation != tranche.generation
                or offer.target != auth.target
            ):
                raise AssertionError("offer/tranche authority mismatch")

            is_current = tranche.current_offer_id == offer_id
            in_pending = offer_id in pending_ids
            in_stage = staged_offer_id == offer_id
            if offer.location is OfferLocation.PENDING:
                if not is_current or not in_pending or in_stage:
                    raise AssertionError("orphan or multiply-located pending offer")
                if (
                    offer.authorization_id != self.current_authorization_id
                    or not self.authorization_enabled[offer.authorization_id]
                    or self.cached_generation is None
                    or offer.generation != self.cached_generation
                ):
                    raise AssertionError("stale or disabled authorization remains ranked")
            elif offer.location is OfferLocation.STAGED:
                if not is_current or in_pending or not in_stage:
                    raise AssertionError("orphan or multiply-located staged offer")
                if (
                    offer.authorization_id != self.current_authorization_id
                    or not self.authorization_enabled[offer.authorization_id]
                ):
                    raise AssertionError("stale or disabled authorization remains staged")
            elif offer.location is OfferLocation.NONE:
                if in_pending or in_stage:
                    raise AssertionError("NONE offer occupies waiting capacity")
            else:
                raise AssertionError("unknown offer location")
            if not is_current and offer.location is not OfferLocation.NONE:
                raise AssertionError("superseded offer remains live")

        escrow = 0
        owner_outstanding = 0
        penalty_outstanding = 0
        expected_credit_ids: set[bytes] = set()
        creation_sequences: set[int] = set()
        for tranche_id, tranche in self.tranches.items():
            _bytes32(tranche_id, "tranche key")
            if tranche.tranche_id != tranche_id:
                raise AssertionError("tranche key mismatch")
            _canonical_address(tranche.operator, "tranche operator")
            _uint(tranche.creation_sequence, "tranche creation sequence")
            u64(tranche.generation)
            _bytes32(tranche.authorization_id, "tranche authorization ID")
            if tranche.bond_amount != self.sla_bond:
                raise AssertionError("tranche bond differs from immutable SLA bond")
            if tranche.creation_sequence in creation_sequences:
                raise AssertionError("creation sequence was reused")
            creation_sequences.add(tranche.creation_sequence)
            if tranche.creation_sequence > self.creation_sequence:
                raise AssertionError("tranche creation sequence exceeds counter")
            if tranche.authorization_id not in self.authorizations:
                raise AssertionError("tranche authorization identity is unknown")
            expected_tranche_id = self._new_tranche_id(
                tranche.operator,
                tranche.creation_sequence,
                tranche.authorization_id,
                tranche.generation,
            )
            if expected_tranche_id != tranche_id:
                raise AssertionError("tranche ID does not commit immutable fields")
            if tranche.current_offer_id is None:
                raise AssertionError("tranche lost its current offer binding")
            _bytes32(tranche.current_offer_id, "current offer ID")
            current_offer = self.offers.get(tranche.current_offer_id)
            if current_offer is None or current_offer.tranche_id != tranche_id:
                raise AssertionError("current offer/tranche binding mismatch")
            if current_offer.operator != tranche.operator:
                raise AssertionError("current offer operator changed")

            if tranche.usage is TrancheUsage.OFFER:
                if current_offer.location is not OfferLocation.PENDING:
                    raise AssertionError("OFFER tranche is not pending")
                if tranche.pending_refund_at is not None:
                    raise AssertionError("live offer has a pending refund")
            elif tranche.usage is TrancheUsage.STAGED:
                if current_offer.location is not OfferLocation.STAGED:
                    raise AssertionError("STAGED tranche is not in the stage")
                if tranche.pending_refund_at is not None:
                    raise AssertionError("staged tranche has a pending refund")
            elif tranche.usage is TrancheUsage.CLOSED_UNINSTALLED:
                if current_offer.location is not OfferLocation.NONE:
                    raise AssertionError("closed tranche still occupies waiting capacity")
                if (
                    tranche.disposition is BondDisposition.NONE
                    and tranche.pending_refund_at is None
                ):
                    raise AssertionError("uncredited pending exit has no refund deadline")
            elif tranche.usage is TrancheUsage.INSTALLED:
                if current_offer.location is not OfferLocation.NONE:
                    raise AssertionError("installed tranche still occupies waiting capacity")
                _bytes32(tranche.installed_term_id, "installed term ID")
                if tranche.pending_refund_at is not None:
                    raise AssertionError("installed tranche uses pending refund path")
            else:
                raise AssertionError("unknown tranche usage")
            if (
                tranche.usage is not TrancheUsage.INSTALLED
                and tranche.installed_term_id is not None
            ):
                raise AssertionError("never-installed tranche has installed term ID")

            owner_id = self.credit_id(tranche_id, BondDisposition.OWNER_CREDITED)
            penalty_id = self.credit_id(tranche_id, BondDisposition.PENALTY_CREDITED)
            owner_credit = self.credits.get(owner_id)
            penalty_credit = self.credits.get(penalty_id)
            if tranche.disposition is BondDisposition.NONE:
                if owner_credit is not None or penalty_credit is not None:
                    raise AssertionError("unterminated tranche has terminal credit")
                escrow = checked_add(escrow, tranche.bond_amount)
            elif tranche.disposition is BondDisposition.OWNER_CREDITED:
                if tranche.usage not in (
                    TrancheUsage.CLOSED_UNINSTALLED,
                    TrancheUsage.INSTALLED,
                ):
                    raise AssertionError("owner credit is attached to live waiting tranche")
                if owner_credit is None or penalty_credit is not None:
                    raise AssertionError("owner terminalization is not exclusive")
                expected_credit_ids.add(owner_id)
                if not owner_credit.claimed:
                    owner_outstanding = checked_add(owner_outstanding, owner_credit.amount)
            elif tranche.disposition is BondDisposition.PENALTY_CREDITED:
                if tranche.usage is not TrancheUsage.INSTALLED:
                    raise AssertionError("penalty credit is attached to never-installed tranche")
                if penalty_credit is None or owner_credit is not None:
                    raise AssertionError("penalty terminalization is not exclusive")
                expected_credit_ids.add(penalty_id)
                if not penalty_credit.claimed:
                    penalty_outstanding = checked_add(
                        penalty_outstanding, penalty_credit.amount
                    )
            else:  # pragma: no cover - Enum prevents this absent hostile mutation
                raise AssertionError("unknown bond disposition")

        if set(self.credits) != expected_credit_ids:
            raise AssertionError("credit set is not exactly one per terminal tranche")
        for credit_id, credit in self.credits.items():
            _bytes32(credit_id, "credit key")
            if credit.credit_id != credit_id:
                raise AssertionError("credit key mismatch")
            tranche = self.tranches.get(credit.tranche_id)
            if tranche is None:
                raise AssertionError("credit references unknown tranche")
            if credit.disposition not in (
                BondDisposition.OWNER_CREDITED,
                BondDisposition.PENALTY_CREDITED,
            ):
                raise AssertionError("credit has nonterminal disposition")
            if self.credit_id(credit.tranche_id, credit.disposition) != credit_id:
                raise AssertionError("credit key is not its deterministic identity")
            expected_beneficiary = (
                tranche.operator
                if credit.disposition is BondDisposition.OWNER_CREDITED
                else self.penalty_sink
            )
            if (
                credit.amount != self.sla_bond
                or credit.beneficiary != expected_beneficiary
            ):
                raise AssertionError("exact credit changed immutable beneficiary or amount")
            if credit.disposition is not tranche.disposition:
                raise AssertionError("credit and tranche dispositions differ")
            if type(credit.claimed) is not bool:
                raise AssertionError("credit claimed flag is not boolean")
        if escrow != self.accounting.bond_escrow:
            raise AssertionError("bond escrow summary mismatch")
        if owner_outstanding != self.accounting.outstanding_owner_credits:
            raise AssertionError("owner-credit summary mismatch")
        if penalty_outstanding != self.accounting.outstanding_penalty_credits:
            raise AssertionError("penalty-credit summary mismatch")
        self.accounting.assert_valid(self.actual_balance)


if __name__ == "__main__":
    raise SystemExit("run test-seat-market.py")
