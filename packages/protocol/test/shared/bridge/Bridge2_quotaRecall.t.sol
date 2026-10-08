// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestBridge2Base.sol";

/// @dev A message recipient that rejects every Ether transfer, so a delivery to it fails.
contract RejectingReceiver {
    receive() external payable {
        revert("rejected");
    }
}

/// @dev Exercises the reported griefing scenario against the real QuotaManager, configured like
/// mainnet (250 Ether per 24 hours). A send-fail-recall cycle costs the attacker nothing, so it
/// must leave the quota untouched: other users' recalls keep working and L2 -> L1 withdrawals
/// still find the full quota, which keeps bounding those withdrawals and refills over the period.
/// @dev Boundary: both chains run `SignalService_WithoutProofVerification`, so the failure proof a
/// recall presents is never authenticated. The destination-side failure (RETRIABLE, then FAILED
/// with its failure signal) and the source-side accounting are exercised; the merkle proof that
/// links the two chains in production is not.
contract TestBridge2_quotaRecall is TestBridge2Base {
    uint256 private constant ETH_QUOTA = 250 ether;
    address private constant ETHER = address(0);

    QuotaManager private qm;

    // A real bridge on the destination chain, so a message can actually fail there.
    SignalService private tSignalService;
    Bridge private taikoBridge;

    function setUpOnEthereum() internal virtual override {
        // The base deploys the signal service and a bridge with no quota manager. The bridge and
        // the quota manager reference each other through immutables, so wire them up the way
        // mainnet did: bind the quota manager to the existing bridge proxy, then upgrade the proxy
        // to an implementation that carries the quota manager.
        super.setUpOnEthereum();
        qm = deployQuotaManager(address(eBridge), address(0));
        eBridge.upgradeTo(
            address(
                new Bridge(
                    address(resolver), address(eSignalService), address(qm), address(0), true
                )
            )
        );
        assertEq(address(eBridge.quotaManager()), address(qm));
        qm.updateQuota(ETHER, uint104(ETH_QUOTA));
    }

    function setUpOnTaiko() internal virtual override {
        tSignalService = deploySignalServiceWithoutProof(
            address(this), address(uint160(uint256(keccak256("REMOTE_SIGNAL_SERVICE_T")))), deployer
        );
        // No quota manager and no pauser, like the live L2 bridge.
        taikoBridge = deployBridge(
            address(
                new Bridge(address(resolver), address(tSignalService), address(0), address(0), true)
            )
        );
        vm.deal(address(taikoBridge), 10_000 ether);
    }

    function test_quota_recall_cycle_leaves_quota_untouched() public {
        assertEq(qm.availableQuota(ETHER, 0), ETH_QUOTA);

        // Attacker (Bob): lock the whole quota's worth on L1, let it fail on L2, recall it on L1,
        // repeat. Every cycle costs nothing and must consume nothing.
        vm.deal(Bob, ETH_QUOTA);
        for (uint256 i; i < 3; ++i) {
            vm.prank(Bob);
            (, IBridge.Message memory attack) =
                eBridge.sendMessage{ value: ETH_QUOTA }(_l1ToL2Message(Bob, ETH_QUOTA));
            eBridge.recallMessage(attack, FAKE_PROOF);
            assertTrue(
                eBridge.messageStatus(eBridge.hashMessage(attack)) == IBridge.Status.RECALLED
            );
            assertEq(Bob.balance, ETH_QUOTA);
            assertEq(qm.availableQuota(ETHER, 0), ETH_QUOTA);
        }

        // Victim (Alice) can still recall her own locked Ether.
        vm.deal(Alice, 10 ether);
        vm.prank(Alice);
        (, IBridge.Message memory victim) =
            eBridge.sendMessage{ value: 10 ether }(_l1ToL2Message(Alice, 10 ether));
        eBridge.recallMessage(victim, FAKE_PROOF);
        assertEq(Alice.balance, 10 ether);
        assertEq(qm.availableQuota(ETHER, 0), ETH_QUOTA);

        // A real withdrawal (an L2 -> L1 delivery) still finds the full quota and is debited...
        vm.expectEmit();
        emit QuotaManager.QuotaConsumed(ETHER, ETH_QUOTA, 0);
        vm.prank(Carol);
        eBridge.processMessage(_l2ToL1Message(David, ETH_QUOTA), FAKE_PROOF);
        assertEq(David.balance, ETH_QUOTA);
        assertEq(qm.availableQuota(ETHER, 0), 0);

        // ...and the quota keeps bounding withdrawals...
        vm.prank(Carol);
        vm.expectRevert(QuotaManager.QM_OUT_OF_QUOTA.selector);
        eBridge.processMessage(_l2ToL1Message(Emma, 1 ether), FAKE_PROOF);

        // ...while recalls still go through with the quota exhausted.
        vm.prank(Bob);
        (, IBridge.Message memory late) =
            eBridge.sendMessage{ value: 1 ether }(_l1ToL2Message(Bob, 1 ether));
        eBridge.recallMessage(late, FAKE_PROOF);
        assertEq(Bob.balance, ETH_QUOTA);
        assertEq(qm.availableQuota(ETHER, 0), 0);

        // The quota refills over its period, for withdrawals only.
        vm.warp(block.timestamp + 24 hours);
        assertEq(qm.availableQuota(ETHER, 0), ETH_QUOTA);
    }

    // The full cycle from the report, with the message really failing on the destination: the
    // owner processes it into a rejecting recipient (RETRIABLE), marks it FAILED, and recalls it on
    // the source chain, where the quota is left untouched.
    function test_quota_recall_after_destination_failure_leaves_quota_untouched() public {
        RejectingReceiver receiver = new RejectingReceiver();

        // L1: the attacker locks the whole quota's worth, addressed to a recipient that rejects it.
        vm.deal(Bob, ETH_QUOTA);
        IBridge.Message memory message = _l1ToL2Message(Bob, ETH_QUOTA);
        message.to = address(receiver);
        vm.prank(Bob);
        (, IBridge.Message memory sent) = eBridge.sendMessage{ value: ETH_QUOTA }(message);
        assertEq(Bob.balance, 0);

        // L2: without a gas limit only the owner can process the message. The invocation is
        // rejected, so the message parks as RETRIABLE, and the owner marks it FAILED, which sends
        // the failure signal a recall must present.
        vm.chainId(taikoChainId);
        vm.prank(Bob);
        (IBridge.Status status, IBridge.StatusReason reason) =
            taikoBridge.processMessage(sent, FAKE_PROOF);
        assertTrue(status == IBridge.Status.RETRIABLE);
        assertTrue(reason == IBridge.StatusReason.INVOCATION_FAILED);
        assertEq(address(receiver).balance, 0);

        vm.prank(Bob);
        taikoBridge.failMessage(sent);
        bytes32 hash = taikoBridge.hashMessage(sent);
        assertTrue(taikoBridge.messageStatus(hash) == IBridge.Status.FAILED);
        assertTrue(
            tSignalService.isSignalSent(
                address(taikoBridge), taikoBridge.signalForFailedMessage(hash)
            )
        );
        vm.chainId(ethereumChainId);

        // L1: the recall asks this chain's signal service for exactly the failure signal the
        // destination bridge sent, on the destination chain; only the proof bytes go unverified.
        vm.expectCall(
            address(eSignalService),
            abi.encodeCall(
                ISignalService.proveSignalReceived,
                (
                    taikoChainId,
                    address(taikoBridge),
                    taikoBridge.signalForFailedMessage(hash),
                    FAKE_PROOF
                )
            )
        );

        // The recall returns the Ether and consumes no quota.
        eBridge.recallMessage(sent, FAKE_PROOF);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.RECALLED);
        assertEq(Bob.balance, ETH_QUOTA);
        assertEq(qm.availableQuota(ETHER, 0), ETH_QUOTA);
    }

    // A recall larger than the whole quota, which the quota manager could never have served in a
    // single call, goes through: the cap only applies to withdrawals.
    function test_quota_recall_above_the_quota_succeeds() public {
        uint256 amount = 2 * ETH_QUOTA;
        vm.deal(Bob, amount);
        vm.prank(Bob);
        (, IBridge.Message memory sent) =
            eBridge.sendMessage{ value: amount }(_l1ToL2Message(Bob, amount));

        eBridge.recallMessage(sent, FAKE_PROOF);
        assertEq(Bob.balance, amount);
        assertEq(qm.availableQuota(ETHER, 0), ETH_QUOTA);
    }

    // The exemption changes nothing about what a recall must prove: an altered or never-sent
    // message, a missing failure proof and a replay are all still rejected.
    function test_recallMessage_RevertWhen_MessageAlteredUnsentUnprovenOrReplayed() public {
        vm.deal(Bob, 1 ether);
        vm.prank(Bob);
        (, IBridge.Message memory sent) =
            eBridge.sendMessage{ value: 1 ether }(_l1ToL2Message(Bob, 1 ether));

        // Altered: a different value hashes to a message this bridge never sent. Mutated in place
        // and restored, since a memory struct assignment would alias rather than copy.
        sent.value = 2 ether;
        vm.expectRevert(Bridge.B_MESSAGE_NOT_SENT.selector);
        eBridge.recallMessage(sent, FAKE_PROOF);
        sent.value = 1 ether;

        // Never sent: a message that skipped sendMessage.
        vm.expectRevert(Bridge.B_MESSAGE_NOT_SENT.selector);
        eBridge.recallMessage(_l1ToL2Message(Alice, 1 ether), FAKE_PROOF);

        // Unproven: the destination chain has not reported the failure.
        vm.mockCallRevert(
            address(eSignalService),
            abi.encodeWithSelector(ISignalService.proveSignalReceived.selector),
            ""
        );
        vm.expectRevert(Bridge.B_SIGNAL_NOT_RECEIVED.selector);
        eBridge.recallMessage(sent, FAKE_PROOF);
        vm.clearMockedCalls();

        // Proven: the recall goes through exactly once.
        eBridge.recallMessage(sent, FAKE_PROOF);
        assertEq(Bob.balance, 1 ether);
        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        eBridge.recallMessage(sent, FAKE_PROOF);
        assertEq(qm.availableQuota(ETHER, 0), ETH_QUOTA);
    }
}
