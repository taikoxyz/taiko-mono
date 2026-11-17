// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { TestBridge2Base } from "./TestBridge2Base.sol";
import { Bridge } from "src/shared/bridge/Bridge.sol";
import { IBridge, IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

/// @dev A destination whose invocation can be switched between reverting and succeeding.
contract SwitchableTarget is IMessageInvocable {
    bool public failing = true;

    function onMessageInvocation(bytes calldata) external payable {
        require(!failing, "failing");
    }

    function setFailing(bool _failing) external {
        failing = _failing;
    }
}

/// @dev A recipient meant to be both `to` and `destOwner` of a message. Unarmed it rejects the
/// invocation; armed it calls back into the bridge with `payload`, records the outcome and then
/// accepts the Ether.
contract ReenteringRecipient is IMessageInvocable {
    bytes public payload;
    bool public reentered;
    bool public reentrySucceeded;
    bytes public reentryReturndata;

    function arm(bytes calldata _payload) external {
        payload = _payload;
    }

    function onMessageInvocation(bytes calldata) external payable {
        require(payload.length != 0, "unarmed");
        (reentrySucceeded, reentryReturndata) = msg.sender.call(payload);
        reentered = true;
    }
}

/// @dev Fail-and-recall exclusivity across two real bridges: the value of an Ethereum -> Taiko
/// message is either delivered on Taiko or refunded on Ethereum, never both.
/// @dev Both chains run `SignalService_ReadingRemoteStorage`, so a recall on Ethereum goes through
/// only if the Taiko bridge really sent the failure signal. The merkle proof and the checkpoint it
/// is verified against are not exercised. `Bridge2_recallThenRetry.t.sol` drives the failed-then-
/// recalled lifecycle without that link; this file adds it, and with it the cases that depend on
/// it: a message that was not failed on Taiko cannot be recalled.
contract TestBridge2_failRecallExclusivity is TestBridge2Base {
    uint256 private constant VALUE = 1 ether;
    uint256 private constant FUZZ_STEPS = 24;

    SignalService private tSignalService;
    Bridge private taikoBridge;
    SwitchableTarget private target;

    function setUpOnTaiko() internal override {
        tSignalService = deployLinkedSignalService(eSignalService, deployer);
        taikoBridge = deployBridge(
            address(
                new Bridge(address(resolver), address(tSignalService), address(0), address(0), true)
            )
        );
        vm.deal(address(taikoBridge), 10_000 ether);

        target = new SwitchableTarget();
    }

    // ---------------------------------------------------------------
    // Failed on Taiko and recalled on Ethereum: not deliverable anymore
    // ---------------------------------------------------------------

    /// @dev The reported scenario: fail the message on Taiko, recall it on Ethereum, then try to
    /// get it delivered on Taiko once its target works.
    function test_failMessage_ThenRecall_LeavesNoWayToDeliverOnTaiko() public {
        (IBridge.Message memory sent, bytes32 hash) = _send(address(target), Bob);
        uint256 taikoBalance = address(taikoBridge).balance;

        assertTrue(_process(sent, Bob) == IBridge.Status.RETRIABLE);

        vm.expectEmit();
        emit IBridge.MessageStatusChanged(hash, IBridge.Status.FAILED);
        _fail(sent, Bob);
        _assertStatuses(hash, IBridge.Status.NEW, IBridge.Status.FAILED);
        assertTrue(_isFailureSignalSent(hash));

        vm.expectEmit();
        emit IBridge.MessageStatusChanged(hash, IBridge.Status.RECALLED);
        _recall(sent);
        _assertStatuses(hash, IBridge.Status.RECALLED, IBridge.Status.FAILED);
        assertEq(Bob.balance, VALUE);

        target.setFailing(false);
        _assertSettledOnTaiko(sent, IBridge.Status.FAILED);
        assertEq(address(target).balance, 0);
        assertEq(address(taikoBridge).balance, taikoBalance);

        // The refund cannot be claimed twice either.
        _expectRecallRevert(sent, Bridge.B_INVALID_STATUS.selector);
        assertEq(Bob.balance, VALUE);
    }

    /// @dev Same, with the message failed by a last-attempt retry, and delivery attempted both in
    /// the window between the failure and the recall and after the recall.
    function test_retryMessage_LastAttemptThenRecall_LeavesNoWayToDeliverOnTaiko() public {
        (IBridge.Message memory sent, bytes32 hash) = _send(address(target), Bob);
        uint256 taikoBalance = address(taikoBridge).balance;

        assertTrue(_process(sent, Carol) == IBridge.Status.RETRIABLE);

        // Only the owner may give up on the message.
        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        _retry(sent, Carol, true);

        vm.expectEmit();
        emit IBridge.MessageStatusChanged(hash, IBridge.Status.FAILED);
        _retry(sent, Bob, true);
        _assertStatuses(hash, IBridge.Status.NEW, IBridge.Status.FAILED);
        assertTrue(_isFailureSignalSent(hash));

        // Race window: failed on Taiko, not yet recalled on Ethereum, and the target works again.
        target.setFailing(false);
        _assertSettledOnTaiko(sent, IBridge.Status.FAILED);

        _recall(sent);
        _assertStatuses(hash, IBridge.Status.RECALLED, IBridge.Status.FAILED);
        assertEq(Bob.balance, VALUE);

        _assertSettledOnTaiko(sent, IBridge.Status.FAILED);
        assertEq(address(target).balance, 0);
        assertEq(address(taikoBridge).balance, taikoBalance);
    }

    // ---------------------------------------------------------------
    // Not failed on Taiko: not recallable
    // ---------------------------------------------------------------

    function test_recallMessage_RevertWhen_MessageDeliveredByRetry() public {
        (IBridge.Message memory sent, bytes32 hash) = _send(address(target), Bob);
        uint256 ethereumBalance = address(eBridge).balance;

        assertTrue(_process(sent, Bob) == IBridge.Status.RETRIABLE);

        target.setFailing(false);
        _retry(sent, Carol, false);
        _assertStatuses(hash, IBridge.Status.NEW, IBridge.Status.DONE);
        assertEq(address(target).balance, VALUE);
        assertFalse(_isFailureSignalSent(hash));

        _expectRecallRevert(sent, Bridge.B_SIGNAL_NOT_RECEIVED.selector);

        // A delivered message cannot be failed afterwards to unlock the recall.
        _assertSettledOnTaiko(sent, IBridge.Status.DONE);
        _expectRecallRevert(sent, Bridge.B_SIGNAL_NOT_RECEIVED.selector);

        _assertStatuses(hash, IBridge.Status.NEW, IBridge.Status.DONE);
        assertEq(address(eBridge).balance, ethereumBalance);
        assertEq(Bob.balance, 0);
    }

    function test_recallMessage_RevertWhen_MessageDeliveredOnFirstAttempt() public {
        target.setFailing(false);
        (IBridge.Message memory sent, bytes32 hash) = _send(address(target), Bob);

        assertTrue(_process(sent, Carol) == IBridge.Status.DONE);
        assertEq(address(target).balance, VALUE);

        _expectRecallRevert(sent, Bridge.B_SIGNAL_NOT_RECEIVED.selector);
        _assertStatuses(hash, IBridge.Status.NEW, IBridge.Status.DONE);
        assertEq(Bob.balance, 0);
    }

    /// @dev Neither an unprocessed nor a retriable message is recallable: the owner can still get
    /// both delivered.
    function test_recallMessage_RevertWhen_MessageNewOrRetriableOnTaiko() public {
        (IBridge.Message memory sent, bytes32 hash) = _send(address(target), Bob);

        _expectRecallRevert(sent, Bridge.B_SIGNAL_NOT_RECEIVED.selector);
        _assertStatuses(hash, IBridge.Status.NEW, IBridge.Status.NEW);

        assertTrue(_process(sent, Bob) == IBridge.Status.RETRIABLE);
        _expectRecallRevert(sent, Bridge.B_SIGNAL_NOT_RECEIVED.selector);
        _assertStatuses(hash, IBridge.Status.NEW, IBridge.Status.RETRIABLE);
        assertEq(Bob.balance, 0);
    }

    // ---------------------------------------------------------------
    // Reentrancy: paid and failed in the same call
    // ---------------------------------------------------------------

    function test_retryMessage_RecipientCannotFailMessageWhileBeingPaid() public {
        _assertRecipientCannotReenter(false);
    }

    function test_retryMessage_RecipientCannotBurnLastAttemptWhileBeingPaid() public {
        _assertRecipientCannotReenter(true);
    }

    // ---------------------------------------------------------------
    // Arbitrary call orderings
    // ---------------------------------------------------------------

    /// @dev Drives one message through seed-chosen steps, each taken by the owner or a stranger,
    /// and checks after every step that its value is never both delivered and refunded.
    function testFuzz_recallMessage_NeverRefundsDeliveredValue(uint256 _seed) public {
        uint256 ethereumBalance = address(eBridge).balance;
        uint256 taikoBalance = address(taikoBridge).balance;
        (IBridge.Message memory sent, bytes32 hash) = _send(address(target), Bob);

        // Stays NEW until the message reaches DONE or FAILED on Taiko.
        IBridge.Status settled;

        for (uint256 i; i < FUZZ_STEPS; ++i) {
            uint256 rand = uint256(keccak256(abi.encode(_seed, i)));
            _step(sent, rand % 2 == 0 ? Bob : Carol, (rand >> 1) % 6);

            IBridge.Status taikoStatus = taikoBridge.messageStatus(hash);

            assertLe(
                taikoBalance - address(taikoBridge).balance,
                address(eBridge).balance - ethereumBalance,
                "Taiko released more than Ethereum still locks"
            );
            assertEq(
                _isFailureSignalSent(hash),
                taikoStatus == IBridge.Status.FAILED,
                "failure signal does not match FAILED status"
            );
            if (eBridge.messageStatus(hash) == IBridge.Status.RECALLED) {
                assertTrue(taikoStatus == IBridge.Status.FAILED, "recalled but not failed");
            }
            if (settled != IBridge.Status.NEW) {
                assertTrue(taikoStatus == settled, "settled status changed");
            } else if (taikoStatus == IBridge.Status.DONE || taikoStatus == IBridge.Status.FAILED) {
                settled = taikoStatus;
            }
        }
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Bob sends 1 ether from Ethereum to `_to` on Taiko, leaving him with no Ether. The
    /// message carries no fee but a gas limit, so strangers may process and retry it too.
    function _send(
        address _to,
        address _destOwner
    )
        private
        returns (IBridge.Message memory sent_, bytes32 hash_)
    {
        IBridge.Message memory message = _l1ToL2Message(Bob, VALUE);
        message.destOwner = _destOwner;
        message.to = _to;
        message.gasLimit = 1_000_000;
        message.data = abi.encodeCall(IMessageInvocable.onMessageInvocation, (""));

        vm.deal(Bob, VALUE);
        vm.prank(Bob);
        (hash_, sent_) = eBridge.sendMessage{ value: VALUE }(message);
    }

    function _process(
        IBridge.Message memory _sent,
        address _by
    )
        private
        onTaiko
        returns (IBridge.Status status_)
    {
        vm.prank(_by);
        (status_,) = taikoBridge.processMessage(_sent, FAKE_PROOF);
    }

    function _retry(
        IBridge.Message memory _sent,
        address _by,
        bool _isLastAttempt
    )
        private
        onTaiko
    {
        vm.prank(_by);
        taikoBridge.retryMessage(_sent, _isLastAttempt);
    }

    function _fail(IBridge.Message memory _sent, address _by) private onTaiko {
        vm.prank(_by);
        taikoBridge.failMessage(_sent);
    }

    /// @dev Anyone may trigger a recall; the refund goes to the source owner regardless.
    function _recall(IBridge.Message memory _sent) private {
        vm.prank(Carol);
        eBridge.recallMessage(_sent, FAKE_PROOF);
    }

    function _expectRecallRevert(IBridge.Message memory _sent, bytes4 _error) private {
        vm.expectRevert(_error);
        _recall(_sent);
    }

    /// @dev One fuzz step: `_actor` processes, retries, last-attempt retries or fails the message
    /// on Taiko, recalls it on Ethereum, or the target is toggled. Reverts are ignored; the
    /// invariants are checked by the caller.
    function _step(IBridge.Message memory _sent, address _actor, uint256 _action) private {
        if (_action == 5) {
            target.setFailing(!target.failing());
            return;
        }

        bytes memory data;
        if (_action == 0) data = abi.encodeCall(IBridge.processMessage, (_sent, FAKE_PROOF));
        else if (_action == 1) data = abi.encodeCall(IBridge.retryMessage, (_sent, false));
        else if (_action == 2) data = abi.encodeCall(IBridge.retryMessage, (_sent, true));
        else if (_action == 3) data = abi.encodeCall(IBridge.failMessage, (_sent));
        else data = abi.encodeCall(IBridge.recallMessage, (_sent, FAKE_PROOF));

        bool recalling = _action == 4;
        vm.chainId(recalling ? ethereumChainId : taikoChainId);
        vm.prank(_actor);
        (bool success,) = address(recalling ? eBridge : taikoBridge).call(data);
        success;
        vm.chainId(ethereumChainId);
    }

    /// @dev Runs the reentrancy scenario: while being paid by a retry, the recipient (also the
    /// owner) tries to fail the same message, directly or through a last-attempt retry, which
    /// would get the value refunded on Ethereum as well.
    function _assertRecipientCannotReenter(bool _viaLastAttemptRetry) private {
        ReenteringRecipient recipient = new ReenteringRecipient();
        (IBridge.Message memory sent, bytes32 hash) = _send(address(recipient), address(recipient));

        assertTrue(_process(sent, address(recipient)) == IBridge.Status.RETRIABLE);

        recipient.arm(
            _viaLastAttemptRetry
                ? abi.encodeCall(IBridge.retryMessage, (sent, true))
                : abi.encodeCall(IBridge.failMessage, (sent))
        );
        _retry(sent, address(recipient), false);

        assertTrue(recipient.reentered());
        assertFalse(recipient.reentrySucceeded());
        assertEq(
            recipient.reentryReturndata(),
            abi.encodeWithSelector(EssentialContract.REENTRANT_CALL.selector)
        );

        _assertStatuses(hash, IBridge.Status.NEW, IBridge.Status.DONE);
        assertEq(address(recipient).balance, VALUE);
        assertFalse(_isFailureSignalSent(hash));

        _expectRecallRevert(sent, Bridge.B_SIGNAL_NOT_RECEIVED.selector);
        assertEq(Bob.balance, 0);
    }

    /// @dev Whether the Taiko bridge sent the failure signal a recall has to prove.
    function _isFailureSignalSent(bytes32 _hash) private onTaiko returns (bool) {
        return tSignalService.isSignalSent(
            address(taikoBridge), taikoBridge.signalForFailedMessage(_hash)
        );
    }

    function _assertStatuses(
        bytes32 _hash,
        IBridge.Status _onEthereum,
        IBridge.Status _onTaiko
    )
        private
        view
    {
        assertEq(uint8(eBridge.messageStatus(_hash)), uint8(_onEthereum), "status on Ethereum");
        assertEq(uint8(taikoBridge.messageStatus(_hash)), uint8(_onTaiko), "status on Taiko");
    }

    /// @dev Asserts the message is settled as `_status` on Taiko: neither its owner nor a
    /// stranger can move it through any destination entry point, and the bridge pays nothing out.
    function _assertSettledOnTaiko(
        IBridge.Message memory _sent,
        IBridge.Status _status
    )
        private
        onTaiko
    {
        bytes32 hash = taikoBridge.hashMessage(_sent);
        uint256 balance = address(taikoBridge).balance;

        address[2] memory callers = [_sent.destOwner, Carol];
        for (uint256 i; i < callers.length; ++i) {
            vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
            vm.prank(callers[i]);
            taikoBridge.processMessage(_sent, FAKE_PROOF);

            vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
            vm.prank(callers[i]);
            taikoBridge.retryMessage(_sent, false);

            vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
            vm.prank(callers[i]);
            taikoBridge.retryMessage(_sent, true);
        }

        // A stranger does not get past the permission check of `failMessage`.
        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(_sent.destOwner);
        taikoBridge.failMessage(_sent);

        assertTrue(taikoBridge.messageStatus(hash) == _status);
        assertEq(address(taikoBridge).balance, balance);
    }
}
