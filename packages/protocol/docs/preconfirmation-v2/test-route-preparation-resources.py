#!/usr/bin/env python3
"""BRD1 split-transaction regressions; budgets are not EVM gas certificates."""

from contextlib import contextmanager
import copy
from dataclasses import replace
import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import patch


FIXTURE_PATH = Path(__file__).with_name("test-settlement-window.py")
SPEC = importlib.util.spec_from_file_location(
    "settlement_route_resource_fixtures", FIXTURE_PATH
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("unable to load settlement route fixtures")
fixtures = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = fixtures
SPEC.loader.exec_module(fixtures)
settlement = fixtures.settlement
resources = fixtures.commitment


@contextmanager
def forbid_factory_deployment():
    """Fail if preparation or activation replays either public transaction."""
    with patch.object(
        settlement.ImmutableV2BridgeFactory,
        "deploy_source_bundle_exact_v1",
        side_effect=AssertionError("unexpected SBD1 deployment transaction"),
    ) as bundle, patch.object(
        settlement.ImmutableV2BridgeFactory,
        "deploy_bridge_adapter_exact_v1",
        side_effect=AssertionError("unexpected SAD1 deployment transaction"),
    ) as adapter:
        yield
        bundle.assert_not_called()
        adapter.assert_not_called()


class RoutePreparationResourcesTests(unittest.TestCase):
    def registered_fixture(self):
        fixture = fixtures.genesis_protocol_authority_fixture()
        _operation, mature, success = (
            fixtures.ImmutableProtocolAuthorityV1Tests._execute_release(
                self, fixture, prepare_package=False
            )
        )
        self.assertTrue(success)
        self.assert_unstaged(fixture)
        return fixture, mature

    def bridge_authorization(self, fixture):
        return next(
            row for row in fixture[2].ingress_authorizations
            if row.kind is settlement.ForceKind.BRIDGE_CREDIT
        )

    def version(self, fixture):
        return settlement.decode_register_release_payload_v1(
            fixture[3]
        ).protocol_version

    def prepare(self, fixture, clock, *, gas=12_000_000):
        return fixture[1].prepare_bridge_route_package_v1(
            settlement.encode_prepare_bridge_route_package_calldata_v1(
                self.version(fixture)
            ),
            caller=fixtures.addr("resource-preparer"), value=0,
            gas=gas, clock=clock,
        )

    def assert_unstaged(self, fixture):
        self.assertFalse(any(
            row.protocol_version == self.version(fixture)
            for row in fixture[1]._bridge_domain_registry_authority.entries.values()
        ))

    def clear_simulator_caches(self, fixture):
        router = fixture[1]
        for factory in router._source_bridge_factories_by_address.values():
            for name in (
                "_deployments", "_bundles", "_adapter_deployments", "_adapters"
            ):
                getattr(factory, name).clear()
        router._source_bridge_factories_by_address.clear()
        router._source_bundles_by_descriptor_id.clear()
        router._profile_deployments_by_version.clear()
        router._source_descriptor_id_by_version.clear()
        router._used_source_component_addresses.clear()
        fixture[4].deployment_world.behavior_handles.clear()

    def test_missing_and_partial_predeployments_reject_without_creation(self):
        # Registration alone does not create the bundle. Removing one account
        # after predeployment also leaves stale handles that must not authorize it.
        for missing in (
            "all", "bundle_deployer", "source_bridge", "bridge_credit_registry",
            "native_quota_manager", "source_terminal_verifier", "adapter",
        ):
            with self.subTest(missing=missing):
                fixture, clock = self.registered_fixture()
                world = fixture[4].deployment_world
                if missing != "all":
                    fixtures.predeploy_release_source_for_test(fixture)
                    authorization = self.bridge_authorization(fixture)
                    address = (
                        authorization.adapter_address if missing == "adapter"
                        else getattr(authorization.source_descriptor, missing)
                    )
                    world.accounts.pop(settlement._model_address20(address))
                accounts_before = copy.deepcopy(world.accounts)
                with forbid_factory_deployment(), self.assertRaises(ValueError):
                    self.prepare(fixture, clock)
                self.assertEqual(world.accounts, accounts_before)
                self.assert_unstaged(fixture)
                self.assertIs(
                    fixture[1].migration_lifecycle,
                    settlement.RouterMigrationLifecycle.IDLE,
                )

    def test_wrong_code_or_configuration_rejects_despite_cached_handles(self):
        for component in ("source_bridge", "bridge_credit_registry", "adapter"):
            for field in ("runtime_hash", "configuration_hash"):
                with self.subTest(component=component, field=field):
                    fixture, clock = self.registered_fixture()
                    fixtures.predeploy_release_source_for_test(fixture)
                    authorization = self.bridge_authorization(fixture)
                    address = settlement._model_address20(
                        authorization.adapter_address if component == "adapter"
                        else getattr(authorization.source_descriptor, component)
                    )
                    world = fixture[4].deployment_world
                    self.assertIn(address, world.behavior_handles)
                    world.accounts[address] = replace(
                        world.accounts[address], **{field: bytes.fromhex("a5" * 32)}
                    )
                    accounts_before = copy.deepcopy(world.accounts)
                    with forbid_factory_deployment(), self.assertRaises(ValueError):
                        self.prepare(fixture, clock)
                    self.assertEqual(world.accounts, accounts_before)
                    self.assert_unstaged(fixture)

    def test_independent_deployments_survive_failure_after_staging(self):
        fixture, clock = self.registered_fixture()
        world = fixture[4].deployment_world
        accounts_before_deployment = set(world.accounts)
        fixtures.predeploy_release_source_for_test(fixture)
        deployed_addresses = set(world.accounts) - accounts_before_deployment
        self.assertEqual(len(deployed_addresses), 5)
        self.assert_unstaged(fixture)
        router = fixture[1]
        registry = router._bridge_domain_registry_authority
        accounts_before = copy.deepcopy(world.accounts)
        registry_before = registry._transaction_snapshot()
        router.prepare_bridge_route_return_override = b"invalid BRD1 return"
        with forbid_factory_deployment(), self.assertRaises(ValueError):
            self.prepare(fixture, clock)
        self.assertEqual(world.accounts, accounts_before)
        self.assertTrue(deployed_addresses <= set(world.accounts))
        self.assertEqual(registry._transaction_snapshot(), registry_before)
        router.prepare_bridge_route_return_override = None
        with forbid_factory_deployment():
            prepared = self.prepare(fixture, clock)
        self.assertEqual(prepared[:32], b"BRD1" + bytes(28))

    def test_retry_preserves_original_review_clock(self):
        fixture, clock = self.registered_fixture()
        fixtures.predeploy_release_source_for_test(fixture)
        first = self.prepare(fixture, clock)
        registry = fixture[1]._bridge_domain_registry_authority
        registry_before = registry._transaction_snapshot()
        later = settlement.Clock(
            clock.block_number + settlement.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS + 7,
            clock.timestamp + 86_400,
        )
        with forbid_factory_deployment():
            retried = self.prepare(fixture, later)
        self.assertEqual(retried, first)
        self.assertEqual(registry._transaction_snapshot(), registry_before)
        self.assertEqual(
            int.from_bytes(retried[96:128], "big"),
            clock.block_number + settlement.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS,
        )

    def test_cold_restart_authenticates_and_preserves_accounts_and_balances(self):
        fixture, clock = self.registered_fixture()
        fixtures.predeploy_release_source_for_test(fixture)
        authorization = self.bridge_authorization(fixture)
        descriptor = authorization.source_descriptor
        world = fixture[4].deployment_world
        for index, address in enumerate((
            descriptor.bundle_deployer, descriptor.source_bridge,
            descriptor.bridge_credit_registry, descriptor.native_quota_manager,
            authorization.adapter_address,
        ), 1):
            raw_address = settlement._model_address20(address)
            world.accounts[raw_address] = replace(
                world.accounts[raw_address], balance=index * 123
            )
        accounts_before = copy.deepcopy(world.accounts)
        self.clear_simulator_caches(fixture)
        with forbid_factory_deployment():
            result = self.prepare(fixture, clock)
        self.assertEqual((len(result), result[:32]), (128, b"BRD1" + bytes(28)))
        self.assertEqual(world.accounts, accounts_before)
        for address, expected_type in (
            (descriptor.source_bridge, settlement.SourceBridgeV2),
            (descriptor.bridge_credit_registry, settlement.BridgeCreditRegistryV2),
            (descriptor.native_quota_manager, settlement.FrozenNativeQuotaManagerV2),
            (descriptor.source_terminal_verifier, settlement.TerminalSignalVerifier),
            (authorization.adapter_address, settlement.BridgeAdapter),
        ):
            self.assertIsInstance(
                world.behavior_handles[settlement._model_address20(address)],
                expected_type,
            )
        self.assertEqual(
            world.behavior_handles[
                settlement._model_address20(descriptor.source_bridge)
            ].balance,
            accounts_before[settlement._model_address20(descriptor.source_bridge)].balance,
        )

    def test_activation_snapshot_reconstructs_without_deployment(self):
        for missing in (False, True):
            with self.subTest(missing_source_account=missing):
                fixture, clock = self.registered_fixture()
                fixtures.predeploy_release_source_for_test(fixture)
                self.prepare(fixture, clock)
                self.clear_simulator_caches(fixture)
                world = fixture[4].deployment_world
                if missing:
                    world.accounts.pop(settlement._model_address20(
                        self.bridge_authorization(fixture).source_descriptor.source_bridge
                    ))
                accounts_before = copy.deepcopy(world.accounts)
                with forbid_factory_deployment():
                    if missing:
                        with self.assertRaises(ValueError):
                            fixture[1]._source_install_snapshot_for_registration_v1(fixture[2])
                    else:
                        snapshot = fixture[1]._source_install_snapshot_for_registration_v1(
                            fixture[2]
                        )
                        self.assertIsInstance(snapshot, tuple)
                self.assertEqual(world.accounts, accounts_before)

    def test_old_twenty_five_million_prepare_envelope_rejects(self):
        fixture, clock = self.registered_fixture()
        fixtures.predeploy_release_source_for_test(fixture)
        accounts_before = copy.deepcopy(fixture[4].deployment_world.accounts)
        with forbid_factory_deployment(), self.assertRaises(ValueError):
            self.prepare(fixture, clock, gas=25_000_000)
        self.assertEqual(fixture[4].deployment_world.accounts, accounts_before)
        self.assert_unstaged(fixture)
        with forbid_factory_deployment():
            self.assertEqual(self.prepare(fixture, clock)[:4], b"BRD1")

    def test_split_budgets_fit_generic_transaction_and_forwarding_bounds(self):
        budgets = (
            (settlement.SOURCE_BUNDLE_FACTORY_BUNDLE_DEPLOYMENT_GAS, 10_000_000, 1_668),
            (settlement.SOURCE_BUNDLE_FACTORY_ADAPTER_DEPLOYMENT_GAS, 2_000_000, 260),
            (settlement.PREPARE_BRIDGE_ROUTE_PACKAGE_GAS, 12_000_000, 36),
            (settlement.STAGE_BRIDGE_ROUTE_PACKAGE_GAS, 10_000_000, 36),
        )
        for actual, expected, calldata_bytes in budgets:
            with self.subTest(budget=expected, calldata_bytes=calldata_bytes):
                self.assertEqual(actual, expected)
                resources.validate_l1_transaction_gas(
                    resources.l1_transaction_required_gas(0, calldata_bytes, actual),
                    30_000_000,
                )
        stage_with_reserve = resources.l1_call_sequence_minimum_gas(
            (settlement.STAGE_BRIDGE_ROUTE_PACKAGE_GAS,), 500_000
        )
        self.assertLess(stage_with_reserve, settlement.PREPARE_BRIDGE_ROUTE_PACKAGE_GAS)
        with self.assertRaises(AssertionError):
            resources.validate_l1_transaction_gas(
                resources.l1_transaction_required_gas(0, 36, 25_000_000),
                30_000_000,
            )


if __name__ == "__main__":
    if not __debug__:
        raise SystemExit("resource model refuses optimized Python")
    unittest.main()
