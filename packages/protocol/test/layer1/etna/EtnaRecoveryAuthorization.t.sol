// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxLockHarness } from "./EtnaInboxLockHarness.sol";
import { EtnaLandTestBase } from "./EtnaLandTestBase.sol";
import { ReentrantERC20 } from "./ReentrantERC20.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";

/// @notice Test-only upgrade contract modelling the required settlement rollback storage effects.
/// @dev This harness deliberately exposes no production rollback API or verifier replacement.
contract EtnaSettlementRollbackHarness is EtnaInbox {
    constructor(Config memory _config) EtnaInbox(_config) { }

    function restoreTrustedCheckpoint(
        uint256 _height,
        bytes32 _hash,
        uint48 _head,
        uint256 _snapshot
    )
        external
        onlyOwner
        nonReentrant
    {
        uint256 currentNonce;
        assembly ("memory-safe") { currentNonce := sload(292) }
        uint256 nextNonce = currentNonce + 1;
        assembly ("memory-safe") {
            sstore(270, _height)
            sstore(271, _hash)
            sstore(281, or(and(sload(281), not(sub(shl(48, 1), 1))), _head))
            sstore(284, _snapshot)
            sstore(292, nextNonce)
        }
    }
}

/// @notice Test-only companion upgrade preserving lifetime namespaces and rechecking exits.
contract EtnaRegistryRollbackHarness is EtnaStakingRegistry {
    constructor(Config memory _config) EtnaStakingRegistry(_config) { }

    function recheckExitConfirmations(uint256 _restoredSnapshot) external onlyOwner {
        uint256 count = this.entryCount();
        for (uint256 i; i < count; ++i) {
            if (this.entryAt(i).exitEffectiveL1 <= _restoredSnapshot) continue;
            bytes32 slot = keccak256(
                abi.encode(
                    i, uint256(0x25e74f824855a18216fe2fa8b7d9dcc76ad83f6de1a344c666c3293e57124900)
                )
            );
            assembly ("memory-safe") { sstore(slot, 0) }
        }
    }
}

contract EtnaRecoveryAuthorizationTest is EtnaLandTestBase {
    event RecoveryNonceInvalidated(uint256 oldNonce, uint256 newNonce);

    function test_recover_DeadlineIsInclusiveAndNonceConsumesExactlyOnce() external {
        vm.warp(1000);
        _recover(0, 0, 0, 1000);
        assertEq(_inbox().recoveryNonce(), 1);
        assertEq(uint256(vm.load(inboxProxy, bytes32(uint256(292)))), 1);
        assertEq(_inbox().recoveryGeneration(), 1);
        vm.expectRevert(IEtnaInbox.RecoveryNonceMismatch.selector);
        _recover(1, 0, 0, 1000);
        _recover(1, 0, 1, 1000);
        assertEq(_inbox().recoveryNonce(), 2);
    }

    function test_recover_RevertWhen_ExpiredDoesNotConsumeNonceAndFreshRetrySucceeds() external {
        vm.warp(1000);
        vm.expectRevert(IEtnaInbox.AuthorizationExpired.selector);
        _recover(0, 0, 0, 999);
        assertEq(_inbox().recoveryNonce(), 0);
        assertEq(_inbox().recoveryGeneration(), 0);
        _recover(0, 0, 0, 1000);
        assertEq(_inbox().recoveryNonce(), 1);
    }

    function test_recover_RevertWhen_StaleNonceDespiteCurrentGenerationAndCheckpoint() external {
        _inbox().invalidateRecoveryNonce(0);
        vm.expectRevert(IEtnaInbox.RecoveryNonceMismatch.selector);
        _recover(0, 0, 0, block.timestamp);
        assertEq(_inbox().recoveryGeneration(), 0);
        _recover(0, 0, 1, block.timestamp);
        assertEq(_inbox().recoveryNonce(), 2);
    }

    function test_invalidateRecoveryNonce_OnlyOwnerAndCurrentNonceNoOtherStateChange() external {
        bytes32 checkpoint = vm.load(inboxProxy, bytes32(uint256(271)));
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(Bob);
        _inbox().invalidateRecoveryNonce(0);
        vm.expectRevert(IEtnaInbox.RecoveryNonceMismatch.selector);
        _inbox().invalidateRecoveryNonce(1);
        vm.expectEmit();
        emit RecoveryNonceInvalidated(0, 1);
        _inbox().invalidateRecoveryNonce(0);
        assertEq(_inbox().recoveryNonce(), 1);
        assertEq(_inbox().recoveryGeneration(), 0);
        assertEq(vm.load(inboxProxy, bytes32(uint256(271))), checkpoint);
        assertEq(_inbox().lastCheckpoint().height, 0);
        assertEq(_inbox().origins(1).startHeight, 0);
        assertEq(_inbox().origins(1).l1BlockNumber, 0);
    }

    function test_recoveryAuthorization_RevertWhen_NonceIncrementOverflowsWithoutEffects()
        external
    {
        vm.store(inboxProxy, bytes32(uint256(292)), bytes32(type(uint256).max));
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        _inbox().invalidateRecoveryNonce(type(uint256).max);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        _recover(0, 0, type(uint256).max, block.timestamp);
        assertEq(_inbox().recoveryNonce(), type(uint256).max);
        assertEq(_inbox().recoveryGeneration(), 0);
        assertEq(_inbox().origins(1).l1BlockNumber, 0);
        assertEq(registry.entryAt(0).exitEffectiveL1, type(uint48).max);
    }

    function test_recover_FailedRegistryExclusionAndRetryPreserveNonceAtomicity() external {
        IEtnaInbox.Exclusion[] memory exclusions = new IEtnaInbox.Exclusion[](2);
        exclusions[0] = IEtnaInbox.Exclusion(0, _entryKey(0));
        exclusions[1] = IEtnaInbox.Exclusion(1, bytes32(0));
        uint256[] memory blanks = new uint256[](1);
        blanks[0] = 0;
        bytes32 txHash = _inbox().getForcedInclusion(0).txHash;
        vm.expectRevert(IEtnaStakingRegistry.UnknownBond.selector);
        _inbox().recover(0, 0, 0, block.timestamp, exclusions, blanks);
        assertEq(_inbox().recoveryNonce(), 0);
        assertEq(_inbox().recoveryGeneration(), 0);
        assertEq(registry.entryAt(0).exitEffectiveL1, type(uint48).max);
        assertEq(_inbox().getForcedInclusion(0).txHash, txHash);
        exclusions = new IEtnaInbox.Exclusion[](1);
        exclusions[0] = IEtnaInbox.Exclusion(0, _entryKey(0));
        _inbox().recover(0, 0, 0, block.timestamp, exclusions, blanks);
        assertEq(_inbox().recoveryNonce(), 1);
        assertEq(registry.entryAt(0).effStake, MIN_STAKE, "exclusion is not a deduction");
    }

    function test_land_AndForfeitDoNotConsumeNonceOrInvalidateUnexpiredForfeiture() external {
        bytes32 key = _entryKey(0);
        _land(0, 6);
        assertEq(_inbox().recoveryNonce(), 0);
        _recover(0, 6, 0, block.timestamp);
        assertEq(_inbox().recoveryNonce(), 1);
        registry.forfeit(0, key, keccak256("incident authorized earlier"), block.timestamp);
        assertEq(_inbox().recoveryNonce(), 1);
        assertTrue(registry.forfeited(key));
        _recover(1, 6, 1, block.timestamp);
        assertTrue(registry.forfeited(key), "recovery does not clear lifetime flag");
    }

    function test_recover_ExclusionPreservesPendingPrincipalAndDisablesActivation() external {
        taikoToken.mint(Alice, 7 ether);
        vm.prank(Alice);
        taikoToken.approve(address(registry), type(uint256).max);
        vm.prank(Alice);
        registry.topUp(0, 7 ether);
        (uint256 pendingBefore, uint48 readyBefore) = registry.topUpOf(0);
        IEtnaInbox.Exclusion[] memory exclusions = new IEtnaInbox.Exclusion[](1);
        exclusions[0] = IEtnaInbox.Exclusion(0, _entryKey(0));
        _inbox().recover(0, 0, 0, block.timestamp, exclusions, new uint256[](0));
        (uint256 pendingAfter, uint48 readyAfter) = registry.topUpOf(0);
        assertEq(pendingAfter, pendingBefore, "recovery preserves pending principal");
        assertEq(readyAfter, readyBefore, "recovery preserves readiness");
        assertEq(registry.entryAt(0).effStake, MIN_STAKE, "no recovery deduction");
        vm.roll(readyAfter);
        vm.expectRevert(IEtnaStakingRegistry.ExitAlreadySet.selector);
        registry.activateTopUp(0);
        registry.forfeit(0, _entryKey(0), 0, block.timestamp);
        assertEq(registry.entryAt(0).effStake, 899.3 ether);
        (pendingAfter,) = registry.topUpOf(0);
        assertEq(pendingAfter, 7 ether);
        assertEq(_inbox().recoveryNonce(), 1, "independent forfeiture leaves nonce");
    }

    function test_invalidateRecoveryNonce_RevertWhen_SharedInboxLockHeld() external {
        _inbox().upgradeTo(address(new EtnaInboxLockHarness(_defaultConfig())));
        _inbox().transferOwnership(inboxProxy);
        vm.prank(inboxProxy);
        _inbox().acceptOwnership();
        (bool ok, bytes memory ret) = EtnaInboxLockHarness(inboxProxy)
            .lockedCall(inboxProxy, abi.encodeCall(IEtnaInbox.invalidateRecoveryNonce, (0)));
        assertFalse(ok);
        assertEq(ret, abi.encodeWithSelector(EssentialContract.REENTRANT_CALL.selector));
        assertEq(_inbox().recoveryNonce(), 0);
    }

    function test_rollback_PreservesCurrentNonceAndLifetimeFlagAndPreventsOldCheckpointReplay()
        external
    {
        bytes32 key = _entryKey(0);
        registry.forfeit(0, key, 0, block.timestamp);
        _land(0, 6);
        _inbox().invalidateRecoveryNonce(0);
        _inbox().invalidateRecoveryNonce(1);
        _inbox().upgradeTo(address(new EtnaSettlementRollbackHarness(_defaultConfig())));
        registry.upgradeTo(
            address(
                new EtnaRegistryRollbackHarness(_registryConfig(address(taikoToken), inboxProxy))
            )
        );
        EtnaSettlementRollbackHarness(inboxProxy)
            .restoreTrustedCheckpoint(0, bytes32(uint256(100)), 0, 1);
        EtnaRegistryRollbackHarness(address(registry)).recheckExitConfirmations(1);
        assertEq(_inbox().lastCheckpoint().height, 0);
        assertEq(_inbox().recoveryNonce(), 3, "increments current nonce, never restores old one");
        assertEq(_inbox().recoveryGeneration(), 0, "rollback does not change generation");
        assertTrue(registry.forfeited(key), "rollback preserves lifetime flag");
        vm.expectRevert(IEtnaInbox.RecoveryNonceMismatch.selector);
        _recover(0, 0, 0, block.timestamp);
        _recover(0, 0, 3, block.timestamp);
        assertEq(_inbox().recoveryNonce(), 4);
    }

    function test_rollback_RechecksConfirmationAgainstSnapshotIncludingSameBlockConfirmations()
        external
    {
        _registerValidator(registry, Bob, 0xB0B);
        vm.prank(Alice);
        registry.requestExit(0); // exit 31
        vm.prank(Bob);
        registry.requestExit(1); // exit 41
        vm.roll(50);
        _setReference(49, keccak256("reference49"));
        IEtnaInbox.LandInput memory input = _input(0, 6);
        input.activeCommitteeSnapshot = 45;
        vm.blobhashes(blobHashes);
        _inbox().land(input, _leaves(0, 6), PROOF);
        registry.confirmExit(0);
        registry.confirmExit(1);
        assertEq(registry.exitConfirmedAtL1(0), 50);
        assertEq(registry.exitConfirmedAtL1(1), 50);
        _inbox().upgradeTo(address(new EtnaSettlementRollbackHarness(_defaultConfig())));
        registry.upgradeTo(
            address(
                new EtnaRegistryRollbackHarness(_registryConfig(address(taikoToken), inboxProxy))
            )
        );
        EtnaSettlementRollbackHarness(inboxProxy)
            .restoreTrustedCheckpoint(0, bytes32(uint256(100)), 0, 31);
        EtnaRegistryRollbackHarness(address(registry)).recheckExitConfirmations(31);
        assertEq(registry.exitConfirmedAtL1(0), 50, "still covered, clock preserved");
        assertEq(
            registry.exitConfirmedAtL1(1), 0, "uncovered confirmation cleared despite same block"
        );
        vm.roll(80);
        vm.expectRevert(IEtnaStakingRegistry.ExitNotConfirmed.selector);
        vm.prank(Bob);
        registry.withdraw(1, Bob);
        vm.prank(Alice);
        registry.withdraw(0, Alice);
    }

    function test_registryTokenCallback_CannotRecoverInvalidateOrLandDuringTopUp() external {
        ReentrantERC20 reentrant = new ReentrantERC20();
        taikoToken = TestERC20(address(reentrant));
        _deployFreshInbox(true);
        vm.roll(block.number + ACTIVATION_DELAY);
        taikoToken.mint(Alice, 7 ether);
        vm.prank(Alice);
        taikoToken.approve(address(registry), type(uint256).max);
        _inbox().transferOwnership(address(reentrant));
        vm.prank(address(reentrant));
        _inbox().acceptOwnership();
        bytes[] memory attacks = new bytes[](3);
        attacks[0] = abi.encodeCall(
            IEtnaInbox.recover,
            (0, 0, 0, block.timestamp, new IEtnaInbox.Exclusion[](0), new uint256[](0))
        );
        attacks[1] = abi.encodeCall(IEtnaInbox.invalidateRecoveryNonce, (0));
        attacks[2] = abi.encodeCall(IEtnaInbox.land, (_input(0, 6), new bytes32[](0), PROOF));
        for (uint256 i; i < attacks.length; ++i) {
            reentrant.armReentry(inboxProxy, attacks[i]);
            vm.expectRevert(IEtnaInbox.RegistryLocked.selector);
            vm.prank(Alice);
            registry.topUp(0, 7 ether);
            (uint256 pending, uint48 ready) = registry.topUpOf(0);
            assertEq(pending, 0);
            assertEq(ready, 0);
            assertEq(_inbox().recoveryNonce(), 0);
            assertEq(_inbox().recoveryGeneration(), 0);
            assertEq(_inbox().lastCheckpoint().height, 0);
            assertEq(reentrant.balanceOf(Alice), 7 ether);
        }
    }

    function test_recoveryAuthorization_RevertWhen_UninitializedForBothEntryPoints() external {
        _deployFreshInbox(false);
        EssentialContract(inboxProxy).upgradeTo(address(inboxImpl));
        vm.expectRevert(IEtnaInbox.NotInitialized.selector);
        _inbox().invalidateRecoveryNonce(0);
        vm.expectRevert(IEtnaInbox.NotInitialized.selector);
        _recover(0, 0, 0, block.timestamp);
    }

    function _recover(uint48 _generation, uint256 _c, uint256 _nonce, uint256 _deadline) private {
        _inbox()
            .recover(
                _generation, _c, _nonce, _deadline, new IEtnaInbox.Exclusion[](0), new uint256[](0)
            );
    }

    function _entryKey(uint256 _id) private view returns (bytes32) {
        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(_id);
        return keccak256(abi.encode(entry.ckPrefix, entry.ckX));
    }
}
