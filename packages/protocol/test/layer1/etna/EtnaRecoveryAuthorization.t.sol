// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxLockHarness } from "./EtnaInboxLockHarness.sol";
import { EtnaLandTestBase } from "./EtnaLandTestBase.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

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
        _inbox().recover(_generation, _c, _nonce, _deadline, new uint256[](0), 0);
    }
}
