// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestBridge2Base.sol";

/// @dev A destination whose invocation can be switched between failing and succeeding.
contract FailingTarget is IMessageInvocable {
    bool public toFail;

    function onMessageInvocation(bytes calldata) external payable {
        if (toFail) revert("failed");
    }

    function setToFail(bool _fail) external {
        toFail = _fail;
    }
}

/// @dev The disabled fail-and-recall path across two real bridges. `TestBridge2Base` deploys
/// enabled bridges by default; this file deploys both of its bridges with the flag off.
contract TestBridge2_recallDisabled is TestBridge2Base {
    using stdStorage for StdStorage;

    // A real destination bridge replaces the base's placeholder "bridge" registration.
    SignalService internal tSignalService;
    Bridge internal taikoBridge;

    /// @dev Production configuration: fail-and-recall off.
    function getEnableFailAndRecall() internal pure override returns (bool) {
        return false;
    }

    function setUp() public override {
        super.setUp();

        vm.chainId(taikoChainId);
        vm.startPrank(deployer);

        tSignalService = deploySignalServiceWithoutProof(
            address(this), address(uint160(uint256(keccak256("REMOTE_SIGNAL_SERVICE_T")))), deployer
        );
        taikoBridge = deployBridge(
            address(
                new Bridge(
                    address(resolver), address(tSignalService), address(0), address(0), false
                )
            )
        );
        vm.deal(address(taikoBridge), 10_000 ether);

        vm.stopPrank();
        vm.chainId(ethereumChainId);
    }

    function test_enableFailAndRecall_isFalse() public view {
        assertFalse(eBridge.enableFailAndRecall());
        assertFalse(taikoBridge.enableFailAndRecall());
    }

    function test_recallMessage_RevertWhen_recallsDisabled() public dealEther(Bob) {
        uint256 bobBalanceBefore = Bob.balance;

        IBridge.Message memory sent = _sendOneEther(Zachary, "");

        uint256 bridgeBalance = address(eBridge).balance;
        assertEq(Bob.balance, bobBalanceBefore - 1 ether);

        vm.expectRevert(Bridge.B_FAIL_AND_RECALL_DISABLED.selector);
        eBridge.recallMessage(sent, FAKE_PROOF);

        // Nothing moved: still NEW, Ether still in the bridge.
        assertTrue(eBridge.messageStatus(eBridge.hashMessage(sent)) == IBridge.Status.NEW);
        assertEq(Bob.balance, bobBalanceBefore - 1 ether);
        assertEq(address(eBridge).balance, bridgeBalance);
    }

    /// @dev A message already FAILED before the switch can be neither retried nor recalled.
    function test_recallMessage_RevertWhen_messageAlreadyFailedBeforeDisable()
        public
        dealEther(Bob)
    {
        IBridge.Message memory sent = _sendOneEther(Zachary, "");
        bytes32 hash = eBridge.hashMessage(sent);

        vm.chainId(taikoChainId);

        // The state a pre-switch `failMessage` left behind; no entry point can write it now.
        stdstore.target(address(taikoBridge)).sig("messageStatus(bytes32)").with_key(hash)
            .checked_write(uint256(IBridge.Status.FAILED));
        assertTrue(taikoBridge.messageStatus(hash) == IBridge.Status.FAILED);

        // Retrying needs RETRIABLE.
        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(Bob);
        taikoBridge.retryMessage(sent, false);

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(Bob);
        taikoBridge.retryMessage(sent, true);

        // Delivering needs NEW.
        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(Bob);
        taikoBridge.processMessage(sent, FAKE_PROOF);

        // Re-failing hits the guard first.
        vm.expectRevert(Bridge.B_FAIL_AND_RECALL_DISABLED.selector);
        vm.prank(Bob);
        taikoBridge.failMessage(sent);

        assertTrue(taikoBridge.messageStatus(hash) == IBridge.Status.FAILED);

        // On the source chain only the guard blocks the refund; the Ether stays in the bridge.
        vm.chainId(ethereumChainId);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.NEW);
        uint256 bridgeBalance = address(eBridge).balance;

        vm.expectRevert(Bridge.B_FAIL_AND_RECALL_DISABLED.selector);
        eBridge.recallMessage(sent, FAKE_PROOF);

        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.NEW);
        assertEq(address(eBridge).balance, bridgeBalance);
    }

    /// @dev A failed delivery stays RETRIABLE: it can be neither failed nor recalled.
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

        // The invocation reverts: RETRIABLE.
        vm.prank(Bob);
        (IBridge.Status status, IBridge.StatusReason reason) =
            taikoBridge.processMessage(sent, FAKE_PROOF);
        assertTrue(status == IBridge.Status.RETRIABLE);
        assertTrue(reason == IBridge.StatusReason.INVOCATION_FAILED);
        assertEq(address(target).balance, 0);

        // Cannot be marked FAILED...
        vm.expectRevert(Bridge.B_FAIL_AND_RECALL_DISABLED.selector);
        vm.prank(Bob);
        taikoBridge.failMessage(sent);

        assertTrue(taikoBridge.messageStatus(hash) == IBridge.Status.RETRIABLE);
        assertFalse(
            tSignalService.isSignalSent(
                address(taikoBridge), taikoBridge.signalForFailedMessage(hash)
            )
        );

        // ...and a failing last attempt reverts like any failing retry.
        vm.expectRevert(Bridge.B_RETRY_FAILED.selector);
        vm.prank(Bob);
        taikoBridge.retryMessage(sent, false);

        vm.expectRevert(Bridge.B_RETRY_FAILED.selector);
        vm.prank(Bob);
        taikoBridge.retryMessage(sent, true);

        assertTrue(taikoBridge.messageStatus(hash) == IBridge.Status.RETRIABLE);
        assertFalse(
            tSignalService.isSignalSent(
                address(taikoBridge), taikoBridge.signalForFailedMessage(hash)
            )
        );

        // A working target lets the retry deliver.
        target.setToFail(false);
        vm.prank(Bob);
        taikoBridge.retryMessage(sent, false);

        assertTrue(taikoBridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(address(target).balance, 1 ether);

        // The source-chain recall stays blocked.
        vm.chainId(ethereumChainId);
        vm.expectRevert(Bridge.B_FAIL_AND_RECALL_DISABLED.selector);
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

        // A succeeding last attempt still marks DONE.
        target.setToFail(false);
        vm.prank(Bob);
        taikoBridge.retryMessage(sent, true);

        assertTrue(taikoBridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(address(target).balance, 1 ether);

        vm.chainId(ethereumChainId);
    }

    /// @dev The guard precedes the status check.
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

        vm.expectRevert(Bridge.B_FAIL_AND_RECALL_DISABLED.selector);
        vm.prank(Bob);
        eBridge.failMessage(message);

        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.NEW);
    }

    /// @dev Sends 1 ether from Bob to Taiko with gas limit 0, so only Bob can process it.
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
