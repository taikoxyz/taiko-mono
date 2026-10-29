// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { EtnaStakingRegistryTestBase } from "./EtnaStakingRegistryTestBase.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";

/// @notice Test-only ABI for new selectors, so the original implementation fails behaviorally.
interface IEtnaRegistryAlignment {
    function topUp(uint256 _bondId, uint256 _amount) external;
    function activateTopUp(uint256 _bondId) external;
    function topUpOf(uint256 _bondId)
        external
        view
        returns (uint256 pendingTopUp_, uint48 readyAtL1_);
    function forfeit(
        uint256 _bondId,
        bytes32 _entryKey,
        bytes32 _incidentId,
        uint256 _validUntil
    )
        external;
    function forfeited(bytes32 _entryKey) external view returns (bool forfeited_);
    function forfeitBps() external view returns (uint256 forfeitBps_);
}

interface IEtnaInboxAlignment {
    function recover(
        uint48 _generation,
        uint256 _c,
        uint256 _nonce,
        uint256 _validUntil,
        IEtnaInbox.Exclusion[] calldata _exclusions,
        uint256[] calldata _fiToClear
    )
        external;
    function invalidateRecoveryNonce(uint256 _nonce) external;
    function recoveryNonce() external view returns (uint256 recoveryNonce_);
}

contract EtnaRegistrySpecAlignmentTest is EtnaStakingRegistryTestBase {
    function test_topUp_DelaysPrincipalWithoutChangingVotingStake() external {
        _register(Alice, 0xC0A);
        vm.roll(block.number + ACTIVATION_DELAY);
        _fund(Alice, 11 ether);
        bytes32 root = registry.entriesRoot();
        uint256 checkpoints = registry.checkpointCount();
        vm.prank(Alice);
        IEtnaRegistryAlignment(address(registry)).topUp(0, 11 ether);
        (uint256 pending, uint48 ready) = IEtnaRegistryAlignment(address(registry)).topUpOf(0);
        assertEq(pending, 11 ether, "pending principal");
        assertEq(ready, block.number + ACTIVATION_DELAY, "readiness");
        assertEq(registry.entryAt(0).effStake, MIN_STAKE, "no voting stake before activation");
        assertEq(registry.entriesRoot(), root, "no root change");
        assertEq(registry.checkpointCount(), checkpoints, "no checkpoint");
        vm.roll(ready);
        IEtnaRegistryAlignment(address(registry)).activateTopUp(0);
        assertEq(registry.entryAt(0).effStake, MIN_STAKE + 11 ether, "activated stake");
    }

    function test_forfeit_DeductsPrincipalAndForcesExit() external {
        _register(Alice, 0xC0A);
        mockInbox.setInitialized(true);
        bytes32 key = keccak256(abi.encode(registry.entryAt(0).ckPrefix, registry.entryAt(0).ckX));
        IEtnaRegistryAlignment(address(registry))
            .forfeit(0, key, keccak256("incident"), block.timestamp);
        assertEq(registry.entryAt(0).effStake, 900 ether, "ten percent deducted");
        assertEq(registry.entryAt(0).exitEffectiveL1, block.number, "immediate exit");
        assertEq(token.balanceOf(SLASH_SINK), 100 ether, "all penalty to sink");
        assertTrue(IEtnaRegistryAlignment(address(registry)).forfeited(key), "lifetime flag");
    }
}

contract EtnaInboxSpecAlignmentTest is EtnaInboxTestBase {
    function test_recover_RequiresNewSelectorAndConsumesNonce() external {
        IEtnaInboxAlignment target = IEtnaInboxAlignment(inboxProxy);
        target.recover(0, 0, 0, block.timestamp, new IEtnaInbox.Exclusion[](0), new uint256[](0));
        assertEq(target.recoveryNonce(), 1, "successful recovery consumes nonce");
        assertEq(
            uint256(uint48(uint256(vm.load(inboxProxy, bytes32(uint256(268)))))), 1, "generation"
        );
        target.invalidateRecoveryNonce(1);
        assertEq(target.recoveryNonce(), 2, "explicit invalidation");
    }
}
