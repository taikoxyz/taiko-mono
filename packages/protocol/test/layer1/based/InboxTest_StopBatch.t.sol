// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./InboxTestBase.sol";

contract InboxTest_StopBatch is InboxTestBase {
    function pacayaConfig() internal pure override returns (ITaikoInbox.Config memory config_) {
        config_ = InboxTestBase.pacayaConfig();
        config_.maxBatchesToVerify = 1;
    }

    function setUpOnEthereum() internal override {
        bondToken = deployBondToken();
        super.setUpOnEthereum();
    }

    function test_inbox_num_batches_verified()
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(9)
        WhenMultipleBatchesAreProvedWithCorrectTransitions(1, 10)
        WhenLogAllBatchesAndTransitions
    {
        ITaikoInbox.Stats2 memory _stats2 = inbox.getStats2();
        assertEq(pacayaConfig().maxBatchesToVerify * 9, _stats2.lastVerifiedBatchId);
    }
}
