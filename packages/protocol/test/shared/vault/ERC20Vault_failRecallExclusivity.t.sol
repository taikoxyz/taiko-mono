// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { CommonTest } from "../CommonTest.sol";
import { FreeMintERC20Token } from "../helpers/FreeMintERC20Token.sol";
import { Bridge } from "src/shared/bridge/Bridge.sol";
import { IBridge } from "src/shared/bridge/IBridge.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { BridgedERC20 } from "src/shared/vault/BridgedERC20.sol";
import { ERC20Vault } from "src/shared/vault/ERC20Vault.sol";

/// @dev Fail-and-recall exclusivity for an ERC20 transfer through two real vaults and two real
/// bridges: tokens locked on Ethereum are either minted on Taiko or returned on Ethereum, never
/// both.
/// @dev The two signal services are linked (see `SignalService_ReadingRemoteStorage`), so a recall
/// goes through only if the Taiko bridge really sent the failure signal. The merkle proof and the
/// checkpoint it is verified against are not exercised.
contract TestERC20Vault_failRecallExclusivity is CommonTest {
    uint256 private constant AMOUNT = 10 ether;
    bytes private constant NO_PROOF = "";

    SignalService private eSignalService;
    Bridge private eBridge;
    ERC20Vault private eVault;
    FreeMintERC20Token private token;

    SignalService private tSignalService;
    Bridge private tBridge;
    ERC20Vault private tVault;

    function setUpOnEthereum() internal override {
        // A placeholder remote: `setUpOnTaiko` links this signal service to Taiko's.
        eSignalService = deploySignalServiceWithoutProof(address(this), randAddress(), deployer);
        eBridge = _deployBridge(eSignalService);
        eVault = deployERC20Vault();

        token = new FreeMintERC20Token("ERC20", "ERC20");
        token.mint(Alice);
    }

    function setUpOnTaiko() internal override {
        tSignalService = deployLinkedSignalService(eSignalService, deployer);
        tBridge = _deployBridge(tSignalService);
        tVault = deployERC20Vault();
        register("bridged_erc20", address(new BridgedERC20(address(tVault))));
    }

    /// @dev The reported scenario with tokens: the delivery fails on Taiko, the holder fails the
    /// message and is refunded on Ethereum, then tries to get it delivered once the vault works.
    function test_recallMessage_AfterFailure_LeavesNoWayToMintOnTaiko() public {
        uint256 balance = token.balanceOf(Alice);
        (IBridge.Message memory sent, bytes32 hash) = _sendAndFailDelivery();

        vm.chainId(taikoChainId);
        vm.prank(Alice);
        tBridge.failMessage(sent);
        assertTrue(_isFailureSignalSent(hash));
        vm.chainId(ethereumChainId);

        eBridge.recallMessage(sent, NO_PROOF);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.RECALLED);
        assertEq(token.balanceOf(Alice), balance);
        assertEq(token.balanceOf(address(eVault)), 0);

        _setTaikoVaultPaused(false);
        vm.chainId(taikoChainId);

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(Alice);
        tBridge.retryMessage(sent, false);

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(Alice);
        tBridge.retryMessage(sent, true);

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(Alice);
        tBridge.processMessage(sent, NO_PROOF);

        assertTrue(tBridge.messageStatus(hash) == IBridge.Status.FAILED);
        assertEq(tVault.canonicalToBridged(ethereumChainId, address(token)), address(0));
    }

    /// @dev The mirror: once a retry has minted the tokens on Taiko, the message can no longer be
    /// failed there, so the tokens locked on Ethereum cannot be recalled.
    function test_recallMessage_RevertWhen_TokensDeliveredByRetry() public {
        uint256 balance = token.balanceOf(Alice);
        (IBridge.Message memory sent, bytes32 hash) = _sendAndFailDelivery();

        _setTaikoVaultPaused(false);
        vm.chainId(taikoChainId);
        vm.prank(Alice);
        tBridge.retryMessage(sent, false);

        assertTrue(tBridge.messageStatus(hash) == IBridge.Status.DONE);
        address bridged = tVault.canonicalToBridged(ethereumChainId, address(token));
        assertEq(BridgedERC20(bridged).balanceOf(Alice), AMOUNT);
        assertFalse(_isFailureSignalSent(hash));

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(Alice);
        tBridge.failMessage(sent);

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(Alice);
        tBridge.retryMessage(sent, true);
        vm.chainId(ethereumChainId);

        vm.expectRevert(Bridge.B_SIGNAL_NOT_RECEIVED.selector);
        eBridge.recallMessage(sent, NO_PROOF);

        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.NEW);
        assertEq(token.balanceOf(Alice), balance - AMOUNT);
        assertEq(token.balanceOf(address(eVault)), AMOUNT);
    }

    function _deployBridge(SignalService _signalService) private returns (Bridge) {
        return deployBridge(
            address(
                new Bridge(address(resolver), address(_signalService), address(0), address(0), true)
            )
        );
    }

    /// @dev Alice sends `AMOUNT` tokens to herself on Taiko, where the vault is paused, so her
    /// delivery attempt fails and leaves the message RETRIABLE. Without a gas limit only she can
    /// process the message. Returns on Ethereum with the Taiko vault still paused.
    function _sendAndFailDelivery() private returns (IBridge.Message memory sent_, bytes32 hash_) {
        vm.startPrank(Alice);
        token.approve(address(eVault), AMOUNT);
        sent_ = eVault.sendToken(
            ERC20Vault.BridgeTransferOp({
                destChainId: taikoChainId,
                destOwner: Alice,
                to: Alice,
                fee: 0,
                token: address(token),
                gasLimit: 0,
                amount: AMOUNT
            })
        );
        vm.stopPrank();
        hash_ = eBridge.hashMessage(sent_);
        assertEq(token.balanceOf(address(eVault)), AMOUNT);

        _setTaikoVaultPaused(true);
        vm.chainId(taikoChainId);
        vm.prank(Alice);
        (IBridge.Status status,) = tBridge.processMessage(sent_, NO_PROOF);
        assertTrue(status == IBridge.Status.RETRIABLE);
        assertFalse(_isFailureSignalSent(hash_));
        vm.chainId(ethereumChainId);
    }

    function _setTaikoVaultPaused(bool _paused) private {
        vm.prank(deployer);
        if (_paused) tVault.pause();
        else tVault.unpause();
    }

    /// @dev Whether the Taiko bridge sent the failure signal a recall has to prove. Must be called
    /// on Taiko, since the signal's slot depends on the chain ID.
    function _isFailureSignalSent(bytes32 _hash) private view returns (bool) {
        return tSignalService.isSignalSent(address(tBridge), tBridge.signalForFailedMessage(_hash));
    }
}
