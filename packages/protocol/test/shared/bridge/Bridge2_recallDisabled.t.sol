// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestBridge2Base.sol";

/// @dev A destination whose invocation can be made to fail and later succeed, so a message can be
/// driven to RETRIABLE and then delivered.
contract FailingTarget is IMessageInvocable {
    bool public toFail;

    function onMessageInvocation(bytes calldata) external payable {
        if (toFail) revert("failed");
    }

    function setToFail(bool _fail) external {
        toFail = _fail;
    }
}

/// @dev End-to-end cover for the disabled recall path across both chains: no message can reach
/// `Status.FAILED` on its destination chain, so none can reach `Status.RECALLED` on its source
/// chain, and a message whose delivery fails stays RETRIABLE until a retry succeeds. One message
/// that is already FAILED is planted directly, to cover the messages left in that status before
/// recalls were disabled.
contract TestBridge2_recallDisabled is TestBridge2Base {
    using stdStorage for StdStorage;

    // Contracts on Taiko. The base registers a plain address as "bridge" there, so a real
    // destination bridge is deployed here and takes over that registration.
    SignalService internal tSignalService;
    Bridge internal taikoBridge;

    function setUp() public override {
        super.setUp();

        vm.chainId(taikoChainId);
        vm.startPrank(deployer);

        tSignalService = deploySignalServiceWithoutProof(
            address(this), address(uint160(uint256(keccak256("REMOTE_SIGNAL_SERVICE_T")))), deployer
        );
        taikoBridge = deployBridge(
            address(new Bridge(address(resolver), address(tSignalService), address(0), address(0)))
        );
        vm.deal(address(taikoBridge), 10_000 ether);

        vm.stopPrank();
        vm.chainId(ethereumChainId);
    }

    function test_RECALL_ENABLED_isFalse() public view {
        assertFalse(eBridge.RECALL_ENABLED());
        assertFalse(taikoBridge.RECALL_ENABLED());
    }

    function test_recallMessage_RevertWhen_recallsDisabled() public dealEther(Bob) {
        uint256 bobBalanceBefore = Bob.balance;

        IBridge.Message memory sent = _sendOneEther(Zachary, "");

        uint256 bridgeBalance = address(eBridge).balance;
        assertEq(Bob.balance, bobBalanceBefore - 1 ether);

        vm.expectRevert(Bridge.B_RECALL_DISABLED.selector);
        eBridge.recallMessage(sent, FAKE_PROOF);

        // Nothing moved: the message is still NEW and the Ether Bob locked is still in the bridge.
        assertTrue(eBridge.messageStatus(eBridge.hashMessage(sent)) == IBridge.Status.NEW);
        assertEq(Bob.balance, bobBalanceBefore - 1 ether);
        assertEq(address(eBridge).balance, bridgeBalance);
    }

    /// @dev The pre-upgrade stranded case `RECALL_ENABLED`'s documentation describes: a message
    /// that was already FAILED on its destination chain when recalls were switched off. Nothing
    /// can move it any more - it is neither RETRIABLE nor NEW on Taiko, and its recall on
    /// Ethereum is refused outright - so it stays put until recalls are re-enabled.
    function test_recallMessage_RevertWhen_messageAlreadyFailedBeforeDisable()
        public
        dealEther(Bob)
    {
        IBridge.Message memory sent = _sendOneEther(Zachary, "");
        bytes32 hash = eBridge.hashMessage(sent);

        vm.chainId(taikoChainId);

        // Put the message into the state a pre-upgrade `failMessage` would have left behind. No
        // entry point can reach `Status.FAILED` any more, so the status is written directly.
        stdstore.target(address(taikoBridge)).sig("messageStatus(bytes32)").with_key(hash)
            .checked_write(uint256(IBridge.Status.FAILED));
        assertTrue(taikoBridge.messageStatus(hash) == IBridge.Status.FAILED);

        // Retrying is out, with or without a last attempt: `retryMessage` only accepts RETRIABLE.
        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(Bob);
        taikoBridge.retryMessage(sent, false);

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(Bob);
        taikoBridge.retryMessage(sent, true);

        // Delivering it afresh is out too: `processMessage` only accepts NEW.
        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(Bob);
        taikoBridge.processMessage(sent, FAKE_PROOF);

        // Re-failing it, which would re-send the failure signal, hits the disabled guard first.
        vm.expectRevert(Bridge.B_RECALL_DISABLED.selector);
        vm.prank(Bob);
        taikoBridge.failMessage(sent);

        assertTrue(taikoBridge.messageStatus(hash) == IBridge.Status.FAILED);

        // On the source chain the message is still NEW and really was sent, so the only thing
        // standing between it and a refund is the disabled guard. The Ether stays in the bridge.
        vm.chainId(ethereumChainId);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.NEW);
        uint256 bridgeBalance = address(eBridge).balance;

        vm.expectRevert(Bridge.B_RECALL_DISABLED.selector);
        eBridge.recallMessage(sent, FAKE_PROOF);

        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.NEW);
        assertEq(address(eBridge).balance, bridgeBalance);
    }

    /// @dev The full lifecycle of a message whose delivery fails: it can neither be failed on
    /// Taiko nor recalled on Ethereum, and stays RETRIABLE until the target is fixed.
    function test_retryMessage_failedDeliveryStaysRetriableUntilRetrySucceeds()
        public
        dealEther(Bob)
    {
        FailingTarget target = new FailingTarget();
        target.setToFail(true);

        IBridge.Message memory sent = _sendOneEther(
            address(target), abi.encodeCall(IMessageInvocable.onMessageInvocation, (""))
        );
        bytes32 hash = eBridge.hashMessage(sent);

        vm.chainId(taikoChainId);

        // The invocation reverts, so the delivery leaves the message retriable.
        vm.prank(Bob);
        (IBridge.Status status, IBridge.StatusReason reason) =
            taikoBridge.processMessage(sent, FAKE_PROOF);
        assertTrue(status == IBridge.Status.RETRIABLE);
        assertTrue(reason == IBridge.StatusReason.INVOCATION_FAILED);
        assertEq(address(target).balance, 0);

        // Its destOwner cannot mark it FAILED...
        vm.expectRevert(Bridge.B_RECALL_DISABLED.selector);
        vm.prank(Bob);
        taikoBridge.failMessage(sent);

        assertTrue(taikoBridge.messageStatus(hash) == IBridge.Status.RETRIABLE);
        assertFalse(
            tSignalService.isSignalSent(
                address(taikoBridge), taikoBridge.signalForFailedMessage(hash)
            )
        );

        // ...and neither can a failing last attempt, which reverts as a whole rather than
        // recording the failure.
        vm.expectRevert(Bridge.B_RECALL_DISABLED.selector);
        vm.prank(Bob);
        taikoBridge.retryMessage(sent, true);

        assertTrue(taikoBridge.messageStatus(hash) == IBridge.Status.RETRIABLE);
        assertFalse(
            tSignalService.isSignalSent(
                address(taikoBridge), taikoBridge.signalForFailedMessage(hash)
            )
        );

        // Once the target works, the still-retriable message is delivered.
        target.setToFail(false);
        vm.prank(Bob);
        taikoBridge.retryMessage(sent, false);

        assertTrue(taikoBridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(address(target).balance, 1 ether);

        // Back on the source chain, the message can never be recalled, so the Ether it locked is
        // released exactly once - by the delivery above.
        vm.chainId(ethereumChainId);
        vm.expectRevert(Bridge.B_RECALL_DISABLED.selector);
        eBridge.recallMessage(sent, FAKE_PROOF);

        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.NEW);
    }

    function test_retryMessage_lastAttemptSucceeds_marksDone() public dealEther(Bob) {
        FailingTarget target = new FailingTarget();
        target.setToFail(true);

        IBridge.Message memory sent = _sendOneEther(
            address(target), abi.encodeCall(IMessageInvocable.onMessageInvocation, (""))
        );
        bytes32 hash = eBridge.hashMessage(sent);

        vm.chainId(taikoChainId);

        vm.prank(Bob);
        taikoBridge.processMessage(sent, FAKE_PROOF);
        assertTrue(taikoBridge.messageStatus(hash) == IBridge.Status.RETRIABLE);

        // A last attempt that succeeds never reaches the disabled branch.
        target.setToFail(false);
        vm.prank(Bob);
        taikoBridge.retryMessage(sent, true);

        assertTrue(taikoBridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(address(target).balance, 1 ether);

        vm.chainId(ethereumChainId);
    }

    /// @dev The guard precedes the status check, so even a message that was never delivered
    /// cannot be failed.
    function test_failMessage_RevertWhen_recallsDisabled_evenForNew() public {
        IBridge.Message memory message;
        message.srcChainId = taikoChainId;
        message.destChainId = ethereumChainId;
        message.srcOwner = Bob;
        message.destOwner = Bob;
        message.to = Zachary;
        message.gasLimit = 1_000_000;

        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.NEW);

        vm.expectRevert(Bridge.B_RECALL_DISABLED.selector);
        vm.prank(Bob);
        eBridge.failMessage(message);

        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.NEW);
    }

    /// @dev Bob sends 1 ether from Ethereum to Taiko, owning the message on both ends. The gas
    /// limit is zero, so only Bob can process it on Taiko.
    function _sendOneEther(
        address _to,
        bytes memory _data
    )
        private
        returns (IBridge.Message memory sent_)
    {
        IBridge.Message memory message;
        message.srcChainId = ethereumChainId;
        message.destChainId = taikoChainId;
        message.srcOwner = Bob;
        message.destOwner = Bob;
        message.to = _to;
        message.value = 1 ether;
        message.fee = 0;
        message.gasLimit = 0;
        message.data = _data;

        vm.prank(Bob);
        (, sent_) = eBridge.sendMessage{ value: 1 ether }(message);
    }
}
