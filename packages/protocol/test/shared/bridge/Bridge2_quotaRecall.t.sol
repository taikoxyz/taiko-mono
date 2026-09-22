// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestBridge2Base.sol";

/// @dev A recipient that rejects every Ether transfer, so a delivery to it on the destination
/// chain fails and leaves the message RETRIABLE there.
contract RejectingReceiver {
    receive() external payable {
        revert("rejected");
    }
}

/// @dev Exercises `recallMessage`'s quota accounting against the real `QuotaManager` behind the
/// real bridge proxy rather than a counting stub, so the refill curve, the unlimited default and
/// the owner-armed cap are the production ones.
/// @dev Both chains run `SignalService_WithoutProofVerification`, so the failure proof that
/// releases a recall is not authenticated here. What these tests exercise is the destination-side
/// failure and the source-side quota accounting, never proof validity.
contract TestBridge2_quotaRecall is TestBridge2Base {
    uint256 internal constant ETH_QUOTA = 250 ether;
    uint256 internal constant RECALL_CAP = 500 ether;
    address internal constant ETHER = address(0);

    QuotaManager internal qm;
    address internal recallKey;

    // Contracts on Taiko. Unlike the base fixture, this is a real bridge so a message can actually
    // be delivered, fail and be marked FAILED there.
    SignalService internal tSignalService;
    Bridge internal taikoBridge;

    function setUpOnEthereum() internal override {
        super.setUpOnEthereum();

        // The quota manager only accepts its configured bridge, and the bridge's quota manager is
        // immutable, so the two are wired together by upgrading the already-deployed proxy.
        qm = deployQuotaManager(address(eBridge), address(0));
        eBridge.upgradeTo(
            address(new Bridge(address(resolver), address(eSignalService), address(qm), address(0)))
        );
        assertEq(address(eBridge.quotaManager()), address(qm));

        qm.updateQuota(ETHER, uint104(ETH_QUOTA));
        recallKey = eBridge.ETHER_RECALL_QUOTA_KEY();
    }

    function setUpOnTaiko() internal override {
        tSignalService = deploySignalServiceWithoutProof(
            address(this), address(uint160(uint256(keccak256("REMOTE_SIGNAL_SERVICE_T")))), deployer
        );
        taikoBridge = deployBridge(
            address(new Bridge(address(resolver), address(tSignalService), address(0), address(0)))
        );
        vm.deal(address(taikoBridge), 10_000 ether);
    }

    /// @dev Sends `_value` Ether owned by `_owner` on Ethereum and returns the message as sent.
    function _send(address _owner, uint256 _value) internal returns (IBridge.Message memory) {
        vm.prank(_owner);
        (, IBridge.Message memory m) =
            eBridge.sendMessage{ value: _value }(_l1ToL2Message(_owner, _value));
        return m;
    }

    /// @dev Runs one complete send-then-recall cycle, which returns `_value` to `_owner`.
    function _sendAndRecall(address _owner, uint256 _value) internal {
        IBridge.Message memory m = _send(_owner, _value);
        eBridge.recallMessage(m, FAKE_PROOF);
        assertTrue(eBridge.messageStatus(eBridge.hashMessage(m)) == IBridge.Status.RECALLED);
    }

    /// @dev Settles an L2 -> L1 withdrawal of `_value` to `_to`, relayed by Carol.
    function _withdraw(address _to, uint256 _value) internal {
        vm.prank(Carol);
        eBridge.processMessage(_l2ToL1Message(_to, _value), FAKE_PROOF);
    }

    // The recall key is unconfigured out of the box, which the quota manager reads as unlimited:
    // the split costs operators nothing until they choose to arm it.
    function test_quota_recall_key_is_unlimited_by_default() public view {
        assertEq(qm.availableQuota(recallKey, 0), qm.UNLIMITED_QUOTA());
        assertTrue(recallKey != ETHER);
    }

    // The griefing vector this change closes: repeated send-recall cycles are free to their sender
    // and used to drain the shared Ether withdrawal quota. They now leave it fully intact, so real
    // withdrawals keep working -- and, symmetrically, a spent withdrawal quota never blocks a
    // recall.
    function test_quota_recall_cycle_leaves_withdrawal_quota_untouched() public {
        vm.deal(Bob, ETH_QUOTA);

        for (uint256 i; i < 3; ++i) {
            _sendAndRecall(Bob, ETH_QUOTA);
            assertEq(Bob.balance, ETH_QUOTA);
            assertEq(qm.availableQuota(ETHER, 0), ETH_QUOTA);
        }

        // Another user's recall is unaffected by Bob's cycles too.
        vm.deal(Alice, 10 ether);
        _sendAndRecall(Alice, 10 ether);
        assertEq(Alice.balance, 10 ether);
        assertEq(qm.availableQuota(ETHER, 0), ETH_QUOTA);

        // The full withdrawal quota is still there for a real withdrawal ...
        vm.expectEmit();
        emit QuotaManager.QuotaConsumed(ETHER, ETH_QUOTA, 0);
        _withdraw(David, ETH_QUOTA);
        assertEq(David.balance, ETH_QUOTA);
        assertEq(qm.availableQuota(ETHER, 0), 0);

        // ... which is what exhausts it, not the recalls.
        vm.prank(Carol);
        vm.expectRevert(QuotaManager.QM_OUT_OF_QUOTA.selector);
        eBridge.processMessage(_l2ToL1Message(Emma, 1 ether), FAKE_PROOF);

        // And an exhausted withdrawal quota does not block a recall.
        _sendAndRecall(Bob, 1 ether);
        assertEq(Bob.balance, ETH_QUOTA);

        vm.warp(block.timestamp + 24 hours);
        assertEq(qm.availableQuota(ETHER, 0), ETH_QUOTA);
    }

    // A recall larger than the whole withdrawal quota clears in one call while the recall key is
    // unarmed. Under the old accounting it could never be refunded, because the quota manager caps
    // a key's refill at its configured quota.
    function test_quota_recall_above_withdrawal_quota_succeeds_when_unarmed() public {
        uint256 value = 2 * ETH_QUOTA;
        vm.deal(Bob, value);

        _sendAndRecall(Bob, value);

        assertEq(Bob.balance, value);
        assertEq(qm.availableQuota(ETHER, 0), ETH_QUOTA);
    }

    // The same property over the real lifecycle: the message is delivered on Taiko, fails there,
    // is marked FAILED, and only then recalled on Ethereum.
    function test_quota_recall_after_destination_failure_leaves_withdrawal_quota_untouched()
        public
    {
        RejectingReceiver receiver = new RejectingReceiver();
        vm.deal(Bob, ETH_QUOTA);

        IBridge.Message memory message = _l1ToL2Message(Bob, ETH_QUOTA);
        message.to = address(receiver);

        vm.prank(Bob);
        (, IBridge.Message memory sent) = eBridge.sendMessage{ value: ETH_QUOTA }(message);
        bytes32 hash = eBridge.hashMessage(sent);
        assertEq(Bob.balance, 0);

        // On Taiko the delivery reverts in the receiver, so the message becomes RETRIABLE ...
        vm.chainId(taikoChainId);
        vm.prank(Bob);
        (IBridge.Status status, IBridge.StatusReason reason) =
            taikoBridge.processMessage(sent, FAKE_PROOF);
        assertTrue(status == IBridge.Status.RETRIABLE);
        assertTrue(reason == IBridge.StatusReason.INVOCATION_FAILED);
        assertEq(address(receiver).balance, 0);

        // ... and its owner gives up on it, which sends the failure signal a recall proves.
        vm.prank(Bob);
        taikoBridge.failMessage(sent);
        assertTrue(taikoBridge.messageStatus(hash) == IBridge.Status.FAILED);
        assertTrue(
            tSignalService.isSignalSent(
                address(taikoBridge), taikoBridge.signalForFailedMessage(hash)
            )
        );

        // Back on Ethereum the recall refunds Bob without touching the withdrawal quota.
        vm.chainId(ethereumChainId);
        eBridge.recallMessage(sent, FAKE_PROOF);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.RECALLED);
        assertEq(Bob.balance, ETH_QUOTA);
        assertEq(qm.availableQuota(ETHER, 0), ETH_QUOTA);
        assertEq(qm.availableQuota(recallKey, 0), qm.UNLIMITED_QUOTA());
    }

    // Arming the recall key gives recalls their own ceiling: it throttles them exactly like the
    // withdrawal quota throttles withdrawals, and the two buckets stay independent.
    function test_quota_armed_recall_key_bounds_recalls_without_touching_withdrawals() public {
        vm.prank(deployer);
        qm.updateQuota(recallKey, uint104(RECALL_CAP));

        vm.deal(Bob, ETH_QUOTA);
        _sendAndRecall(Bob, ETH_QUOTA);
        _sendAndRecall(Bob, ETH_QUOTA);

        assertEq(qm.availableQuota(recallKey, 0), 0);
        assertEq(qm.availableQuota(ETHER, 0), ETH_QUOTA);

        // The next recall has to wait for the recall key to refill.
        IBridge.Message memory pending = _send(Bob, 1 ether);
        vm.expectRevert(QuotaManager.QM_OUT_OF_QUOTA.selector);
        eBridge.recallMessage(pending, FAKE_PROOF);
        bytes32 hash = eBridge.hashMessage(pending);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.NEW);

        // Withdrawals are untouched by the exhausted recall key.
        _withdraw(David, ETH_QUOTA);
        assertEq(David.balance, ETH_QUOTA);
        assertEq(qm.availableQuota(ETHER, 0), 0);

        vm.warp(block.timestamp + 24 hours);
        assertEq(qm.availableQuota(recallKey, 0), RECALL_CAP);

        eBridge.recallMessage(pending, FAKE_PROOF);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.RECALLED);
        assertEq(Bob.balance, ETH_QUOTA);
    }

    // The caveat documented on ETHER_RECALL_QUOTA_KEY: the quota manager caps a key's refill at its
    // configured quota, so while the key is armed a recall above the cap never clears on its own.
    // Only the owner raising the cap unblocks it, so the cap must exceed any plausible deposit.
    function test_quota_armed_recall_above_cap_RevertWhen_not_raised() public {
        vm.prank(deployer);
        qm.updateQuota(recallKey, uint104(RECALL_CAP));

        uint256 value = RECALL_CAP + 1 ether;
        vm.deal(Bob, value);
        IBridge.Message memory stuck = _send(Bob, value);

        vm.expectRevert(QuotaManager.QM_OUT_OF_QUOTA.selector);
        eBridge.recallMessage(stuck, FAKE_PROOF);

        // Waiting does not help: the refill is capped at the configured quota.
        vm.warp(block.timestamp + 365 days);
        vm.expectRevert(QuotaManager.QM_OUT_OF_QUOTA.selector);
        eBridge.recallMessage(stuck, FAKE_PROOF);
        assertEq(Bob.balance, 0);

        // Raising the cap is the only way out, and it needs no upgrade.
        vm.prank(deployer);
        qm.updateQuota(recallKey, uint104(2 * RECALL_CAP));

        eBridge.recallMessage(stuck, FAKE_PROOF);
        assertTrue(eBridge.messageStatus(eBridge.hashMessage(stuck)) == IBridge.Status.RECALLED);
        assertEq(Bob.balance, value);
    }

    // Splitting the quota key did not loosen any of the other gates a recall must clear.
    function test_recallMessage_RevertWhen_MessageAlteredUnsentUnprovenOrReplayed() public {
        vm.deal(Bob, 1 ether);
        IBridge.Message memory sent = _send(Bob, 1 ether);

        // A message whose fields were altered hashes differently, so it was never sent.
        sent.value = 2 ether;
        vm.expectRevert(Bridge.B_MESSAGE_NOT_SENT.selector);
        eBridge.recallMessage(sent, FAKE_PROOF);
        sent.value = 1 ether;

        // Neither was a message that this bridge never emitted at all.
        vm.expectRevert(Bridge.B_MESSAGE_NOT_SENT.selector);
        eBridge.recallMessage(_l1ToL2Message(Alice, 1 ether), FAKE_PROOF);

        // Without the destination chain's failure proof the recall is refused.
        vm.mockCallRevert(
            address(eSignalService),
            abi.encodeWithSelector(ISignalService.proveSignalReceived.selector),
            ""
        );
        vm.expectRevert(Bridge.B_SIGNAL_NOT_RECEIVED.selector);
        eBridge.recallMessage(sent, FAKE_PROOF);
        vm.clearMockedCalls();

        eBridge.recallMessage(sent, FAKE_PROOF);
        assertEq(Bob.balance, 1 ether);

        // A recalled message cannot be recalled a second time.
        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        eBridge.recallMessage(sent, FAKE_PROOF);
    }
}
