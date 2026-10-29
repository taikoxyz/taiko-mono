// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { EtnaStakingRegistryGasBase } from "./EtnaStakingRegistryGas.t.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";

/// @notice Cold-transaction budgets for the added capital-management operations.
abstract contract EtnaRegistryGovernanceGasBase is EtnaStakingRegistryGasBase {
    function setUp() public virtual override {
        super.setUp();
        _register(Alice, CK_A);
        _fund(Alice, 10_000 ether);
        mockInbox.setInitialized(true);
        vm.roll(block.number + ACTIVATION_DELAY);
    }
}

contract EtnaRegistryTopUpGasTest is EtnaRegistryGovernanceGasBase {
    function test_gas_TopUpWithoutCommitteeCheckpoint() external {
        EtnaStakingRegistry target = registry;
        vm.startPrank(Alice);
        vm.startSnapshotGas("top_up");
        target.topUp(0, 10_000 ether);
        _stopSnapshot("top_up");
        vm.stopPrank();
        assertEq(registry.entryAt(0).effStake, MIN_STAKE);
        assertEq(registry.checkpointCount(), 1);
    }
}

contract EtnaRegistryActivateTopUpGasTest is EtnaRegistryGovernanceGasBase {
    function setUp() public override {
        super.setUp();
        vm.prank(Alice);
        registry.topUp(0, 10_000 ether);
        vm.roll(block.number + ACTIVATION_DELAY);
    }

    function test_gas_ActivateTopUpWithCheckpoint() external {
        EtnaStakingRegistry target = registry;
        vm.startSnapshotGas("activate_top_up");
        target.activateTopUp(0);
        _stopSnapshot("activate_top_up");
        assertEq(registry.entryAt(0).effStake, 11_000 ether);
    }
}

contract EtnaRegistryForfeitGasTest is EtnaRegistryGovernanceGasBase {
    bytes32 private _key;

    function setUp() public override {
        super.setUp();
        vm.prank(Alice);
        registry.topUp(0, 10_000 ether);
        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(0);
        _key = keccak256(abi.encode(entry.ckPrefix, entry.ckX));
        vm.roll(block.number + 1);
    }

    function test_gas_ForfeitFromBothPrincipalSources() external {
        EtnaStakingRegistry target = registry;
        bytes32 key = _key;
        uint256 deadline = block.timestamp;
        vm.startSnapshotGas("forfeit_effective_and_pending");
        target.forfeit(0, key, bytes32(uint256(42)), deadline);
        _stopSnapshot("forfeit_effective_and_pending");
        assertEq(token.balanceOf(SLASH_SINK), 1100 ether);
        assertTrue(registry.forfeited(key));
    }
}

contract EtnaRecoveryNonceGasTest is EtnaInboxTestBase {
    function test_gas_InvalidateRecoveryNonce() external {
        EtnaInbox target = EtnaInbox(inboxProxy);
        vm.startSnapshotGas("invalidate_recovery_nonce");
        target.invalidateRecoveryNonce(0);
        uint256 gasUsed = vm.stopSnapshotGas();
        emit log_named_uint("invalidate_recovery_nonce", gasUsed);
        assertLt(gasUsed, 3_000_000);
        assertEq(target.recoveryNonce(), 1);
    }
}
