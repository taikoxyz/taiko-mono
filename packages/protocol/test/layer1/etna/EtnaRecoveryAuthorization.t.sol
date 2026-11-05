// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxLockHarness } from "./EtnaInboxLockHarness.sol";
import { EtnaLandTestBase } from "./EtnaLandTestBase.sol";
import { ReentrantERC20 } from "./ReentrantERC20.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";

contract EtnaRecoveryAuthorizationTest is EtnaLandTestBase {
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
        emit IEtnaInbox.RecoveryNonceInvalidated(0, 1);
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
        exclusions[0] = IEtnaInbox.Exclusion(0, _entryKey(registry, 0));
        exclusions[1] = IEtnaInbox.Exclusion(1, bytes32(0));
        uint256[] memory blanks = new uint256[](1);
        blanks[0] = 0;
        bytes32 txHash = _inbox().getForcedInclusion(0).txHash;
        vm.expectRevert(IEtnaStakingRegistry.UnknownBond.selector);
        _inbox().recover(0, 0, 0, block.timestamp, exclusions, blanks, 0);
        assertEq(_inbox().recoveryNonce(), 0);
        assertEq(_inbox().recoveryGeneration(), 0);
        assertEq(registry.entryAt(0).exitEffectiveL1, type(uint48).max);
        assertEq(_inbox().getForcedInclusion(0).txHash, txHash);
        exclusions = new IEtnaInbox.Exclusion[](1);
        exclusions[0] = IEtnaInbox.Exclusion(0, _entryKey(registry, 0));
        _inbox().recover(0, 0, 0, block.timestamp, exclusions, blanks, 0);
        assertEq(_inbox().recoveryNonce(), 1);
        assertEq(registry.entryAt(0).effStake, MIN_STAKE, "exclusion is not a deduction");
    }

    function test_land_AndForfeitDoNotConsumeNonceOrInvalidateUnexpiredForfeiture() external {
        bytes32 key = _entryKey(registry, 0);
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
        exclusions[0] = IEtnaInbox.Exclusion(0, _entryKey(registry, 0));
        _inbox().recover(0, 0, 0, block.timestamp, exclusions, new uint256[](0), 0);
        (uint256 pendingAfter, uint48 readyAfter) = registry.topUpOf(0);
        assertEq(pendingAfter, pendingBefore, "recovery preserves pending principal");
        assertEq(readyAfter, readyBefore, "recovery preserves readiness");
        assertEq(registry.entryAt(0).effStake, MIN_STAKE, "no recovery deduction");
        vm.roll(readyAfter);
        vm.expectRevert(IEtnaStakingRegistry.ExitAlreadySet.selector);
        registry.activateTopUp(0);
        registry.forfeit(0, _entryKey(registry, 0), 0, block.timestamp);
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
            (0, 0, 0, block.timestamp, new IEtnaInbox.Exclusion[](0), new uint256[](0), 0)
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

    /// @dev Every Inbox entry point refuses to run while the registry holds its lock (the shared
    /// lock in the Etna README, beyond the entry points RECOV-8.3-19 lists): forced inclusion,
    /// the sweep and the schedule calls revert and change nothing.
    function test_entryPoints_RevertWhen_RegistryLocked() external {
        vm.deal(inboxProxy, 1 ether);
        vm.deal(Alice, 1 ether);
        IEtnaInbox.RulesSchedule memory schedule = _inbox().rulesSchedule();
        (uint48 head, uint48 tail) = _inbox().getForcedInclusionState();
        _mockRegistryLocked();

        vm.expectRevert(IEtnaInbox.RegistryLocked.selector);
        vm.prank(Alice);
        _inbox().saveForcedInclusion{ value: 1 ether }(hex"c0");
        vm.expectRevert(IEtnaInbox.RegistryLocked.selector);
        _inbox().sweepProtocolFees();
        vm.expectRevert(IEtnaInbox.RegistryLocked.selector);
        _inbox().scheduleRules(1, uint48(block.timestamp + 1 days));
        vm.expectRevert(IEtnaInbox.RegistryLocked.selector);
        _inbox().scheduleStop(uint48(block.timestamp + 1 days), 6);

        (uint48 headAfter, uint48 tailAfter) = _inbox().getForcedInclusionState();
        assertEq(headAfter, head, "queue head");
        assertEq(tailAfter, tail, "no forced inclusion");
        assertEq(inboxProxy.balance, 1 ether, "nothing swept");
        assertEq(Alice.balance, 1 ether, "nothing charged");
        assertEq(abi.encode(_inbox().rulesSchedule()), abi.encode(schedule), "no schedule");
    }

    function test_invalidateRecoveryNonce_RevertWhen_Uninitialized() external {
        _deployFreshInbox(false);
        EssentialContract(inboxProxy).upgradeTo(address(inboxImpl));
        vm.expectRevert(IEtnaInbox.NotInitialized.selector);
        _inbox().invalidateRecoveryNonce(0);
    }

    function _recover(
        uint48 _generation,
        uint256 _c,
        uint256 _nonce,
        uint256 _deadline
    )
        private
    {
        _inbox()
            .recover(
                _generation,
                _c,
                _nonce,
                _deadline,
                new IEtnaInbox.Exclusion[](0),
                new uint256[](0),
                0
            );
    }
}
