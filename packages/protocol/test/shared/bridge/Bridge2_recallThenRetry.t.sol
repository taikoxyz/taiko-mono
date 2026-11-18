// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestBridge2Base.sol";

/// @dev A recipient whose invocation can be switched between failing and succeeding.
contract RecallRetryTarget is IMessageInvocable {
    bool public toFail = true;

    function onMessageInvocation(bytes calldata) external payable {
        if (toFail) revert("failed");
    }

    function setToFail(bool _toFail) external {
        toFail = _toFail;
    }
}

/// @dev Regression coverage for the reported "failed on the destination, recalled on the source,
/// then retried on the destination" double release.
///
/// A genuine source recall requires the destination bridge to have marked the message FAILED and
/// to have sent its failure signal. FAILED is terminal on the destination, so neither
/// `retryMessage` nor `processMessage` can release the value after the recall. These tests drive
/// the full two-bridge lifecycle, including both ways a destination message becomes FAILED, and
/// pin that the destination cannot pay out after the source has refunded.
///
/// Boundary: both chains run `SignalService_WithoutProofVerification`, so the recall's proof is
/// not authenticated here. The destination-side state transition and failure signal are real, and
/// the recall is checked to ask for exactly that signal; a forged failure proof for a message that
/// is still deliverable is the separate, known proof-trust risk that the deployed bridges address
/// by setting `recallEnabled = false`.
contract TestBridge2_recallThenRetry is TestBridge2Base {
    SignalService internal tSignalService;
    Bridge internal taikoBridge;

    function setUpOnTaiko() internal override {
        tSignalService = deploySignalServiceWithoutProof(
            address(this), address(uint160(uint256(keccak256("REMOTE_SIGNAL_SERVICE_T")))), deployer
        );
        taikoBridge = deployBridge(
            address(
                new Bridge(address(resolver), address(tSignalService), address(0), address(0), true)
            )
        );
        vm.deal(address(taikoBridge), 10_000 ether);
    }

    /// @dev The destination owner marks the failed delivery FAILED, which sends the failure
    /// signal, and the source recalls. A later retry would succeed if the status guard were
    /// missing, so the reverts below are what prevent the double release.
    function test_recallThenRetry_RevertsWhenOwnerMarksFailed() public {
        (
            IBridge.Message memory sent,
            bytes32 hash,
            RecallRetryTarget target,
            uint256 bridgeBalance
        ) = _failAndRecall(false);

        _assertDestinationIsTerminal(sent, hash, address(target), bridgeBalance);
    }

    /// @dev Same lifecycle, but the destination reaches FAILED through a failing last-attempt
    /// retry instead of `failMessage`.
    function test_recallThenRetry_RevertsWhenLastAttemptFails() public {
        (
            IBridge.Message memory sent,
            bytes32 hash,
            RecallRetryTarget target,
            uint256 bridgeBalance
        ) = _failAndRecall(true);

        _assertDestinationIsTerminal(sent, hash, address(target), bridgeBalance);
    }

    function _failAndRecall(bool _failWithLastAttempt)
        internal
        returns (
            IBridge.Message memory sent_,
            bytes32 hash_,
            RecallRetryTarget target_,
            uint256 bridgeBalance_
        )
    {
        target_ = new RecallRetryTarget();
        sent_ = _sendOneEtherTo(address(target_));
        hash_ = eBridge.hashMessage(sent_);

        assertEq(Bob.balance, 0);
        assertEq(address(eBridge).balance, 10_000 ether + 1 ether);

        // The destination delivery fails and parks the message as RETRIABLE.
        vm.chainId(taikoChainId);
        vm.prank(Bob);
        (IBridge.Status status, IBridge.StatusReason reason) =
            taikoBridge.processMessage(sent_, FAKE_PROOF);
        assertTrue(status == IBridge.Status.RETRIABLE);
        assertTrue(reason == IBridge.StatusReason.INVOCATION_FAILED);
        assertEq(address(target_).balance, 0);
        assertFalse(
            tSignalService.isSignalSent(
                address(taikoBridge), taikoBridge.signalForFailedMessage(hash_)
            )
        );

        // Both ways of entering FAILED also send the failure signal a recall must present.
        vm.prank(Bob);
        if (_failWithLastAttempt) {
            taikoBridge.retryMessage(sent_, true);
        } else {
            taikoBridge.failMessage(sent_);
        }

        assertTrue(taikoBridge.messageStatus(hash_) == IBridge.Status.FAILED);
        assertTrue(
            tSignalService.isSignalSent(
                address(taikoBridge), taikoBridge.signalForFailedMessage(hash_)
            )
        );

        // Make the recipient accept, so a retry would succeed if the status guard were absent.
        target_.setToFail(false);
        bridgeBalance_ = address(taikoBridge).balance;

        // The source recall refunds the value exactly once. It asks this chain's signal service
        // for exactly the failure signal the destination bridge sent; only the proof bytes are
        // unauthenticated in this fixture.
        vm.chainId(ethereumChainId);
        vm.expectCall(
            address(eSignalService),
            abi.encodeCall(
                ISignalService.proveSignalReceived,
                (
                    taikoChainId,
                    address(taikoBridge),
                    taikoBridge.signalForFailedMessage(hash_),
                    FAKE_PROOF
                )
            )
        );
        eBridge.recallMessage(sent_, FAKE_PROOF);
        assertTrue(eBridge.messageStatus(hash_) == IBridge.Status.RECALLED);
        assertEq(Bob.balance, 1 ether);
        assertEq(address(eBridge).balance, 10_000 ether);

        vm.chainId(taikoChainId);
    }

    function _assertDestinationIsTerminal(
        IBridge.Message memory _sent,
        bytes32 _hash,
        address _target,
        uint256 _bridgeBalance
    )
        internal
    {
        // FAILED is terminal: retrying, retrying as the last attempt, and re-processing all
        // revert before releasing anything.
        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(Bob);
        taikoBridge.retryMessage(_sent, false);

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(Bob);
        taikoBridge.retryMessage(_sent, true);

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(Bob);
        taikoBridge.processMessage(_sent, FAKE_PROOF);

        assertTrue(taikoBridge.messageStatus(_hash) == IBridge.Status.FAILED);
        assertEq(_target.balance, 0);
        assertEq(address(taikoBridge).balance, _bridgeBalance);

        // The source recall is also single-use.
        vm.chainId(ethereumChainId);
        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        eBridge.recallMessage(_sent, FAKE_PROOF);
        assertTrue(eBridge.messageStatus(_hash) == IBridge.Status.RECALLED);
        assertEq(Bob.balance, 1 ether);

        // The destination still holds the value, so the refund was not paid out twice.
        vm.chainId(taikoChainId);
        assertEq(_target.balance, 0);
        assertEq(address(taikoBridge).balance, _bridgeBalance);
    }

    function _sendOneEtherTo(address _to) internal returns (IBridge.Message memory sent_) {
        vm.deal(Bob, 1 ether);

        IBridge.Message memory message;
        message.srcOwner = Bob;
        message.destOwner = Bob;
        message.srcChainId = ethereumChainId;
        message.destChainId = taikoChainId;
        message.value = 1 ether;
        message.to = _to;
        message.data = abi.encodeCall(IMessageInvocable.onMessageInvocation, (""));
        message.gasLimit = 1_000_000;

        vm.prank(Bob);
        (, sent_) = eBridge.sendMessage{ value: 1 ether }(message);
    }
}
