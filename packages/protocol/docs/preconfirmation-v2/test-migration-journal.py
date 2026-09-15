#!/usr/bin/env python3
"""F3 final-call ordering and rollback in the composed migration model."""

import copy
import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location(
    "migration_journal_fixtures", Path(__file__).with_name("test-settlement-window.py")
)
fixtures = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = fixtures
SPEC.loader.exec_module(fixtures)
m = fixtures.settlement


class MigrationJournalTests(unittest.TestCase):
    def ready_activation(self):
        fixture = fixtures.protocol_authority_fixture()
        _, mature, released = fixtures.ImmutableProtocolAuthorityV1Tests._execute_release(
            self, fixture, prepare_package=False
        )
        self.assertTrue(released)
        fixtures.ImmutableProtocolAuthorityV1Tests._prepare_release_package(self, fixture, mature)
        old_protocol, old_history = fixture[0][:2]
        router, witness, manager, timelock = fixture[1], fixture[2], fixture[4], fixture[5]
        decoded = m.decode_register_release_payload_v1(fixture[3])
        payload = b"".join((
            router.active_version.to_bytes(32, "big"),
            decoded.protocol_version.to_bytes(32, "big"),
            decoded.release_manifest_hash, decoded.target_registration_hash,
        ))
        operation_id = timelock.queue_protocol_change_v1(
            m.PUBLISH_MIGRATION_ARM, payload, caller=timelock.dao_proposer, clock=mature
        )
        operation = timelock.operations[operation_id]
        armed = m.Clock(mature.block_number + m.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS,
                        operation.execute_after)
        self.assertTrue(timelock.execute_protocol_change_v1(
            operation.nonce, m.PUBLISH_MIGRATION_ARM, payload,
            caller=fixtures.addr("journal-armer"), clock=armed,
        ))
        clock = m.Clock(max(old_history.last_canonical_l1_block + 1, armed.block_number + 1),
                        max(armed.timestamp + 1,
                            m.GENESIS_TIMESTAMP + old_history.core.tip_slot + 1))
        self.assertTrue(old_protocol.sync(clock))
        self.assertEqual(router.migration_gate.mode, "READY")
        target = witness.settlement
        candidate, rows = m.migration_activation_candidate(
            router, target, clock, decoded.release_manifest_hash, "journal",
            fixtures.addr("journal-beneficiary"),
        )
        authority = target.live_protocol._inbox_execution_authority
        attestation = m.issue_verified_migration_evm_trace_for_test(
            authority, router=router, settlement=target, clock=clock,
            target_manifest_hash=decoded.release_manifest_hash, candidate=candidate, rows=rows,
        )
        proof = authority.verify_migration_execution_output(
            router=router, settlement=target, clock=clock,
            target_manifest_hash=decoded.release_manifest_hash, candidate=candidate,
            evm_validity=attestation, rows=rows,
        )
        return fixture, target, clock, proof

    def projection(self, fixture, target):
        """The authority, custody, ingress and receipt state touched by cutover."""
        old_protocol, old_history = fixture[0][:2]
        router, manager = fixture[1], fixture[4]
        deployments = router._profile_deployments_by_version[target.protocol_version]
        adapter = next(value for value in deployments.values() if type(value) is m.BridgeAdapter)
        registry = router._bridge_domain_registry_authority
        # IngressBinding intentionally has identity equality. Preserve that
        # identity and its immutable values instead of deep-copying bindings.
        def binding(row):
            return (id(row), id(row.adapter), row.kind, row.address,
                    row.runtime_hash, row.configuration_hash)

        return copy.deepcopy((
            manager.lifecycle, manager.migration_lease, manager.migration_arms,
            old_history.mode, old_history.core, old_protocol.canonical,
            target.mode, target.current_sequence, target.core,
            target.live_protocol.seat_generation,
            router.active_version, router.migration_lifecycle,
            router._migration_callback_frame, router.migration_gate.__dict__,
            router.forced_queue._transaction_snapshot(),
            router.version_migration_activation_trace,
            tuple(router.registrations), router.used_target_addresses,
            router.activation_receipts, router.activation_receipt_rows_v1,
            router.seat_successor_rows_v1, router.activation_successor_index_v1,
            tuple(binding(row) for row in router._authorized_ingress),
            tuple((key, binding(row)) for key, row in router._authorized_ingress_by_address.items()),
            router._authorized_ingress_adapter_ids,
            tuple((key, id(value)) for key, value in deployments.items()),
            adapter.destination_domain_id, adapter.destination_sealed,
            adapter.source_bridge._transaction_snapshot(), registry.entries,
            manager.deployment_world.accounts,
            tuple(sorted((address, id(handle)) for address, handle
                         in manager.deployment_world.behavior_handles.items())),
        ))

    def activate(self, fixture, proof, clock):
        return fixture[1].activate_version_with_migration_v1(
            proof, caller=fixtures.addr("journal-activator"), clock=clock
        )

    def test_final_none_lease_read_follows_vmc1_and_both_idle_transitions(self):
        fixture, target, clock, proof = self.ready_activation()
        router, manager = fixture[1], fixture[4]
        consume = manager.consume_version_migration_lease_v1
        getter = manager.live_version_migration_lease_v1
        calls = []

        def recording_consume(*args, **kwargs):
            calls.append("VMC1_CALL")
            result = consume(*args, **kwargs)
            self.assertEqual(manager.lifecycle, "IDLE")
            calls.append("VMC1_RETURN")
            return result

        def recording_getter():
            if manager.migration_lease.state == 0:
                self.assertEqual(router.active_version, target.protocol_version)
                self.assertIs(router.migration_lifecycle, m.RouterMigrationLifecycle.IDLE)
                self.assertEqual(manager.lifecycle, "IDLE")
                calls.append("VML1_NONE_READ")
            else:
                calls.append("VML1_LIVE_READ")
            return getter()

        with patch.object(manager, "consume_version_migration_lease_v1", recording_consume), \
                patch.object(manager, "live_version_migration_lease_v1", recording_getter):
            self.assertIsNotNone(self.activate(fixture, proof, clock))
        self.assertEqual(calls[-3:], ["VMC1_CALL", "VMC1_RETURN", "VML1_NONE_READ"])
        self.assertEqual(router.version_migration_activation_trace, [
            "VERIFIED", "ACTIVATING", "MFRZ", "MCAN", "K0ING", "SACT",
            "BRC1", "BSEAL", "BIND", "QMIG", "MAPS", "REGISTERED",
            "PUBLISHED", "IDLE", "VMC1", "VML1_POST",
        ])
        self.assertEqual(len(getter()), 320)
        self.assertEqual(manager.migration_lease, m.VersionMigrationLeaseV1())

    def test_final_lease_read_faults_restore_complete_cutover_and_allow_retry(self):
        for fault in ("revert", "short", "trailing", "wrong_magic", "dirty_none", "stale_live", "wrong_type"):
            with self.subTest(fault=fault):
                fixture, target, clock, proof = self.ready_activation()
                router, manager = fixture[1], fixture[4]
                getter = manager.live_version_migration_lease_v1
                live = getter()
                expected_none = m.encode_live_version_migration_lease_return_v1(m.VersionMigrationLeaseV1())
                before = self.projection(fixture, target)
                late_reads = []

                def failing_getter():
                    if manager.migration_lease.state != 0:
                        return getter()
                    self.assertEqual(router.active_version, target.protocol_version)
                    self.assertEqual(manager.lifecycle, "IDLE")
                    late_reads.append(fault)
                    if fault == "revert":
                        raise RuntimeError("final static lease read reverted")
                    return {
                        "short": expected_none[:-1],
                        "trailing": expected_none + b"\x00",
                        "wrong_magic": b"FAIL" + expected_none[4:],
                        "dirty_none": expected_none[:95] + b"\x01" + expected_none[96:],
                        "stale_live": live,
                        "wrong_type": bytearray(expected_none),
                    }[fault]

                with patch.object(manager, "live_version_migration_lease_v1", failing_getter):
                    with self.assertRaises((ValueError, RuntimeError)):
                        self.activate(fixture, proof, clock)
                self.assertEqual(late_reads, [fault])
                self.assertEqual(self.projection(fixture, target), before)
                self.assertEqual(router.migration_gate.mode, "READY")
                self.assertEqual(target.mode, "PREACTIVE")
                self.assertIs(router.migration_lifecycle, m.RouterMigrationLifecycle.IDLE)
                self.assertEqual(manager.lifecycle, "IDLE")
                self.assertIsNotNone(self.activate(fixture, proof, clock))
                self.assertEqual(router.active_version, target.protocol_version)
                self.assertEqual(manager.migration_lease, m.VersionMigrationLeaseV1())


if __name__ == "__main__":
    unittest.main(verbosity=2)
