// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestBridge2Base.sol";

/// @dev Exercises the reported griefing scenario against the real QuotaManager, configured like
/// mainnet (250 Ether per 24 hours). A send-fail-recall cycle costs the attacker nothing, so it
/// must leave the quota untouched: other users' recalls keep working and L2 -> L1 withdrawals
/// still find the full quota, which keeps bounding those withdrawals and refills over the period.
contract TestBridge2_quotaRecall is TestBridge2Base {
    uint256 private constant ETH_QUOTA = 250 ether;
    address private constant ETHER = address(0);

    QuotaManager private qm;

    function setUpOnEthereum() internal virtual override {
        // The base deploys the signal service and a bridge with no quota manager. The bridge and
        // the quota manager reference each other through immutables, so wire them up the way
        // mainnet did: bind the quota manager to the existing bridge proxy, then upgrade the proxy
        // to an implementation that carries the quota manager.
        super.setUpOnEthereum();
        qm = deployQuotaManager(address(eBridge), address(0));
        eBridge.upgradeTo(
            address(new Bridge(address(resolver), address(eSignalService), address(qm), address(0)))
        );
        assertEq(address(eBridge.quotaManager()), address(qm));
        qm.updateQuota(ETHER, uint104(ETH_QUOTA));
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
}
