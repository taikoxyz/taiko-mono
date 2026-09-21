#!/usr/bin/env python3
"""F1 regressions for forced transaction admission and total classification.

The facts are explicit abstract decoder/state witnesses, not EVM or signature
verification. Real client/circuit vectors remain a production release gate.
"""

import importlib.util
from dataclasses import replace
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location(
    "settlement_forced_validity", ROOT / "settlement-window-model.py"
)
m = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = m
SPEC.loader.exec_module(m)


class ForcedAdmissionRegressionTests(unittest.TestCase):
    def admitted(self, row, fork=None):
        return m.valid_forced_ingress_static(
            row, clock=m.clock(1100, 1100), deposit=row.prepaid,
            fork=m.ForcedTxFork.FUSAKA if fork is None else fork,
        )

    def test_zero_gas_is_rejected_instead_of_hidden_by_accounting_max(self):
        row = m.message(1100, "low-gas", gas=0)
        self.assertEqual(row.accounted_gas, 21000)
        self.assertFalse(m.valid_forced_ingress_static(
            row, clock=m.clock(1100, 1100), deposit=row.prepaid
        ))

    def test_disposition_codes_are_circuit_internal_and_five_is_unassigned(self):
        self.assertEqual(
            [int(code) for code in m.ForcedDisposition], [0, 1, 2, 3, 4, 6]
        )
        self.assertEqual(m.ForcedDisposition.INVALID_NO_TX, 6)
        self.assertEqual([kind.value for kind in m.ForceKind], [0])

    def test_type_matrix_and_static_byte_errors(self):
        row = m.message(1100, "types")
        for kind in (0, 1, 2):
            with self.subTest(kind=kind):
                self.assertTrue(self.admitted(replace(
                    row, transaction=replace(row.transaction, tx_type=kind)
                )))
        invalid = (
            replace(row, gas_limit=20999),
            replace(row, signature_ok=False),
            replace(row, chain_id_ok=False),
            replace(row, nonce=m.UINT64_MAX),
            replace(row, nonce=-1),
            replace(row, nonce=True),
            replace(row, valid_until="not-an-integer"),
            replace(row, signature_ok=1),
            *(replace(row, transaction=replace(row.transaction, tx_type=kind))
              for kind in (3, 4, 127, 255)),
            replace(row, transaction=replace(row.transaction, chain_protected=False)),
            replace(row, transaction=replace(row.transaction, canonical_encoding=False)),
            replace(row, transaction=replace(row.transaction, destination=b"short")),
            replace(row, transaction=replace(row.transaction, max_priority_fee=row.max_fee+1)),
            replace(row, transaction=replace(row.transaction, value=m.SEAT_UINT256_MAX)),
            replace(row, transaction=replace(row.transaction, access_list=((b"x", ()),))),
        )
        for item in invalid:
            with self.subTest(item=item):
                self.assertFalse(self.admitted(item))
        self.assertFalse(self.admitted(row, m.ForcedTxFork.BERLIN))
        self.assertTrue(self.admitted(row, m.ForcedTxFork.LONDON))

    def test_access_list_intrinsic_counts_duplicates(self):
        row = m.message(1100, "access-list", gas=33400)
        entry = (b"a" * 20, (b"k" * 32, b"k" * 32))
        tx = replace(row.transaction, tx_type=1, access_list=(entry, entry))
        intrinsic, floor = m.forced_transaction_gas(tx, m.ForcedTxFork.FUSAKA)
        self.assertEqual((intrinsic, floor), (33400, 21000))
        row = replace(row, transaction=tx, intrinsic_gas=intrinsic)
        self.assertTrue(self.admitted(row))
        self.assertFalse(self.admitted(replace(row, gas_limit=intrinsic - 1)))

    def test_floor_activation_and_initcode_size_gas_boundaries(self):
        row = m.message(1100, "calldata", gas=22000)
        tx = replace(row.transaction, data=b"a" * 25)
        row = replace(row, transaction=tx, intrinsic_gas=21400)
        self.assertEqual(m.forced_transaction_gas(tx, m.ForcedTxFork.PRAGUE),
                         (21400, 22000))
        self.assertTrue(self.admitted(row))
        self.assertFalse(self.admitted(replace(row, gas_limit=21999)))
        self.assertTrue(self.admitted(replace(row, gas_limit=21400, accounted_gas=21400),
                                      m.ForcedTxFork.SHANGHAI))
        for size in (49152, 49153):
            tx = replace(row.transaction, destination=None, data=bytes(size))
            intrinsic, floor = m.forced_transaction_gas(tx, m.ForcedTxFork.FUSAKA)
            gas = max(intrinsic, floor)
            creation = replace(row, transaction=tx, gas_limit=gas,
                               accounted_gas=gas, intrinsic_gas=intrinsic)
            self.assertEqual(self.admitted(creation), size == 49152)
        tx = replace(row.transaction, destination=None, data=bytes(33))
        self.assertEqual(m.forced_transaction_gas(tx, m.ForcedTxFork.SHANGHAI)[0],
                         53000 + 132 + 4)

    def test_static_rejection_retains_no_queue_value(self):
        p = m.protocol()
        now = m.clock(1100, 1100)
        before = (p.forced_queue.count, p.forced_queue.root,
                  p.forced_queue.escrow_balance, p.forced_queue.last_due_at)
        row = m.message(1100, "zero-gas-payable", gas=0)
        with self.assertRaises(ValueError):
            p.forced_queue.enqueue(now, row, caller=row.sender, deposit=row.prepaid)
        self.assertEqual(before, (p.forced_queue.count, p.forced_queue.root,
                                 p.forced_queue.escrow_balance,
                                 p.forced_queue.last_due_at))

    def test_queue_rejects_enqueue_before_activation_binds_a_settlement(self):
        queue = m.QueueContinuity(
            "unbound-forced-queue", m.model_force_root([]), 0, 0, 0, 0,
            settlement_address="model-settlement",
        )
        row = m.message(1100, "early")
        with self.assertRaises(ValueError):
            queue.enqueue(m.clock(1100, 1100), row, caller=row.sender, deposit=row.prepaid)
        self.assertEqual(queue.count, 0)

    def test_transaction_facts_do_not_change_frozen_descriptor(self):
        row = m.message(1100, "durable-fields")
        other = replace(row, transaction=replace(row.transaction, data=b"x"))
        self.assertEqual(m.durable_queue_leaf_fields(row), m.durable_queue_leaf_fields(other))
        self.assertEqual(m.durable_queue_leaf_hash(row), m.durable_queue_leaf_hash(other))


class ForcedClassificationTests(unittest.TestCase):
    def setUp(self):
        self.row = m.message(1100, "classify")
        self.witness = m.ForcedTxExecutionWitness(0, self.row.payload_hash,
            self.row.transaction,
            authentication=m.ForcedRawAuthentication(self.row.sender, self.row.l2_chain_id))

    def classify(self, row=None, witness=None, **changes):
        context = dict(timestamp=m.GENESIS_TIMESTAMP+1200,
                       fork=m.ForcedTxFork.FUSAKA, chain_id=167000,
                       base_fee=100, raw_available=True,
                       witness=self.witness if witness is None else witness)
        context.update(changes)
        return m.classify_forced_transaction(self.row if row is None else row, **context)

    def test_admission_only_flags_cannot_change_execution_classification(self):
        for changes in ({"signature_ok": False}, {"chain_id_ok": False},
                        {"outer_authorized": False}, {"payload_available": False}):
            changed = replace(self.row, **changes)
            self.assertEqual(m.durable_queue_leaf_hash(changed),
                             m.durable_queue_leaf_hash(self.row))
            self.assertEqual(self.classify(changed), self.classify())

    def test_execution_authentication_is_derived_from_the_raw_witness(self):
        for authentication in (
            m.ForcedRawAuthentication(None, self.row.l2_chain_id),
            m.ForcedRawAuthentication("different-signer", self.row.l2_chain_id),
            m.ForcedRawAuthentication(self.row.sender, 1),
        ):
            self.assertEqual(self.classify(witness=replace(
                self.witness, authentication=authentication)), 6)
        with self.assertRaises(ValueError):
            self.classify(witness=replace(self.witness, authentication=None))

    def test_exact_precedence_and_expiry_equality(self):
        bad = replace(self.witness, sender=m.ForcedSenderState(nonce=1, balance=0, code=b"x"))
        row = replace(self.row, max_fee=1)
        self.assertEqual(self.classify(row, bad), m.ForcedDisposition.NONCE_NO_TX)
        bad = replace(bad, sender=replace(bad.sender, nonce=0))
        self.assertEqual(self.classify(row, bad), m.ForcedDisposition.FUNDS_NO_TX)
        bad = replace(bad, sender=replace(bad.sender, balance=m.SEAT_UINT256_MAX))
        self.assertEqual(self.classify(row, bad), m.ForcedDisposition.FEE_NO_TX)
        self.assertEqual(self.classify(witness=bad), m.ForcedDisposition.INVALID_NO_TX)
        self.assertEqual(self.classify(), m.ForcedDisposition.INCLUDED_TX)
        expired = replace(row, valid_until=m.GENESIS_TIMESTAMP+1199)
        self.assertEqual(self.classify(expired, bad, raw_available=False),
                         m.ForcedDisposition.EXPIRED_NO_TX)
        with self.assertRaises(ValueError):
            self.classify(replace(expired, valid_until=m.GENESIS_TIMESTAMP+1200),
                          bad, raw_available=False)

    def test_missing_bytes_or_state_never_becomes_invalid_discard(self):
        for field in ({"raw_available": False}, {"witness": None}):
            context = dict(timestamp=m.GENESIS_TIMESTAMP+1200, fork=m.ForcedTxFork.FUSAKA,
                           chain_id=167000, base_fee=100, witness=self.witness,
                           raw_available=True)
            context.update(field)
            with self.assertRaises(ValueError):
                m.classify_forced_transaction(self.row, **context)

    def test_sender_code_delegation_is_exact_and_fork_dependent(self):
        for code in (b"", b"x", b"\xef\x01\x00"+b"a"*20,
                     b"\xef\x01\x00"+bytes(20), b"\xef\x01\x00"+b"a"*19,
                     b"\xef\x01\x00"+b"a"*21, b"\xef\x01\x01"+b"a"*20):
            witness = replace(self.witness, sender=m.ForcedSenderState(code=code))
            for fork in (m.ForcedTxFork.SHANGHAI, m.ForcedTxFork.PRAGUE):
                with self.subTest(code=code, fork=fork):
                    allowed = not code or (fork == m.ForcedTxFork.PRAGUE
                              and len(code) == 23 and code[:3] == b"\xef\x01\x00")
                    self.assertEqual(self.classify(witness=witness, fork=fork),
                                     4 if allowed else 6)

    def test_fork_rule_changes_produce_explicit_no_tx(self):
        row = replace(self.row, gas_limit=21400, accounted_gas=21400)
        tx = replace(row.transaction, data=b"a"*25)
        witness = replace(self.witness, transaction=tx)
        self.assertEqual(self.classify(row, witness, fork=m.ForcedTxFork.SHANGHAI), 4)
        self.assertEqual(self.classify(row, witness, fork=m.ForcedTxFork.PRAGUE), 6)
        self.assertEqual(self.classify(fork=m.ForcedTxFork.BERLIN), 6)
        self.assertEqual(self.classify(chain_id=1), 6)
        creation_tx = replace(self.row.transaction, destination=None, data=bytes(49153))
        before, _ = m.forced_transaction_gas(creation_tx, m.ForcedTxFork.LONDON)
        creation = replace(self.row, gas_limit=before+10000,
                           accounted_gas=before+10000, intrinsic_gas=before,
                           transaction=creation_tx)
        self.assertTrue(m.valid_forced_ingress_static(
            creation, clock=m.clock(1100, 1100), deposit=creation.prepaid,
            fork=m.ForcedTxFork.LONDON,
        ))
        creation_witness = replace(self.witness, transaction=creation_tx)
        self.assertEqual(self.classify(creation, creation_witness, fork=m.ForcedTxFork.LONDON), 4)
        self.assertEqual(self.classify(creation, creation_witness, fork=m.ForcedTxFork.SHANGHAI), 6)
        last = replace(self.row, nonce=m.UINT64_MAX)
        last_witness = replace(self.witness, sender=m.ForcedSenderState(nonce=m.UINT64_MAX))
        self.assertEqual(self.classify(last, last_witness), 6)
        self.assertEqual(self.classify(replace(last, nonce=m.UINT64_MAX-1),
                        replace(last_witness, sender=m.ForcedSenderState(nonce=m.UINT64_MAX-1))), 4)

    def test_success_revert_and_exceptional_halt_are_all_included(self):
        for outcome in m.ForcedEvmOutcome:
            self.assertEqual(self.classify(witness=replace(self.witness, outcome=outcome)), 4)

    def test_every_invalid_head_is_consumed_and_valid_follower_progresses(self):
        invalid_cases = (
            (self.row, replace(self.witness, sender=m.ForcedSenderState(code=b"x"))),
            (replace(self.row, gas_limit=0), self.witness),
            (self.row, replace(self.witness, transaction=replace(self.row.transaction, tx_type=4))),
            (self.row, replace(self.witness, transaction=replace(self.row.transaction, canonical_encoding=False))),
            (self.row, replace(self.witness, transaction=replace(self.row.transaction, max_priority_fee=self.row.max_fee+1))),
            (replace(self.row, gas_limit=21400),
             replace(self.witness, transaction=replace(self.row.transaction, data=b"a"*25))),
            (replace(self.row, gas_limit=500000),
             replace(self.witness, transaction=replace(self.row.transaction, destination=None, data=bytes(49153)))),
            (replace(self.row, nonce=m.UINT64_MAX),
             replace(self.witness, sender=m.ForcedSenderState(nonce=m.UINT64_MAX))),
        )
        for head, witness in invalid_cases:
            with self.subTest(head=head, witness=witness):
                following = replace(m.message(1100, "following"), sender="other", refund_address="other")
                p = m.protocol(messages=[head, following])
                m.open_recovery(p)
                now = m.recovery_submit_clock(p)
                witnesses = (witness, m.ForcedTxExecutionWitness(
                    1, following.payload_hash, following.transaction,
                    authentication=m.ForcedRawAuthentication(following.sender, following.l2_chain_id)))
                proof = m.candidate(p, now, tier=m.Tier.ESCAPE_UNSIGNED,
                                    signed=False, slot=p.recovery.escape_slot,
                                    discretionary=False, recovery_fields_zero=False,
                                    forced_tx_witnesses=witnesses)
                rows = m.forced_block_rows(p.messages, proof.tip, proof.available_payload_hashes)
                self.assertEqual([row[1] for row in rows], [6, 4])
                self.assertEqual(rows[0][2:4], (m.UINT32_MAX, ""))
                # No system transactions precede the forced prefix.
                self.assertEqual(rows[1][2:4], (0, following.payload_hash))
                self.assertEqual(p.submit(proof, now), "COMMITTED")
                self.assertEqual(p.core.message_cursor, 2)

    def test_synthetic_helpers_increment_nonce_and_expiry_needs_no_witness(self):
        rows = [self.row, replace(m.message(1100, "next-nonce"), nonce=1)]
        p = m.protocol(messages=rows)
        m.open_recovery(p)
        now = m.recovery_submit_clock(p)
        proof = m.escape_candidate(p, now)
        self.assertEqual([w.sender.nonce for w in proof.tip.forced_tx_witnesses], [0, 1])
        self.assertEqual([r[1] for r in m.forced_block_rows(rows, proof.tip, proof.available_payload_hashes)],
                         [4, 4])
        expired = replace(self.row, valid_until=m.GENESIS_TIMESTAMP+1200)
        p = m.protocol(messages=[expired])
        m.open_recovery(p)
        now = m.recovery_submit_clock(p)
        proof = m.candidate(p, now, tier=m.Tier.ESCAPE_UNSIGNED,
                            signed=False, slot=p.recovery.escape_slot,
                            discretionary=False, recovery_fields_zero=False,
                            available_payload_hashes=frozenset())
        self.assertEqual(proof.tip.forced_tx_witnesses, ())
        self.assertEqual(m.forced_block_rows(p.messages, proof.tip, frozenset())[0][1], 0)
        self.assertEqual(p.submit(proof, now), "COMMITTED")


if __name__ == "__main__":
    unittest.main()
