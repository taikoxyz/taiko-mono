// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./InboxTestBase.sol";

contract InboxTest_Stage2 is InboxTestBase {
    function pacayaConfig() internal pure override returns (ITaikoInbox.Config memory) {
        ITaikoInbox.ForkHeights memory forkHeights;

        return ITaikoInbox.Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            maxUnverifiedBatches: 10,
            batchRingBufferSize: 11,
            maxBatchesToVerify: 5,
            blockMaxGasLimit: 240_000_000,
            livenessBondBase: 125e18, // 125 Taiko token per batch
            livenessBondPerBlock: 0, // deprecated
            stateRootSyncInternal: 5,
            maxAnchorHeightOffset: 64,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 8,
                sharingPctg: 75,
                gasIssuancePerSecond: 5_000_000,
                minGasExcess: 1_340_000_000, // correspond to 0.008847185 gwei basefee
                maxGasIssuancePerBlock: 600_000_000 // two minutes: 5_000_000 * 120
             }),
            provingWindow: 1 hours,
            cooldownWindow: 0 hours,
            maxSignalsToReceive: 16,
            maxBlocksPerBatch: 768,
            forkHeights: forkHeights,
            maxVerificationDelay: 7 days
        });
    }

    function setUpOnEthereum() internal override {
        bondToken = deployBondToken();
        super.setUpOnEthereum();
    }

    function test_inbox_verification_streak_parameters_is_initialized_correctly() external view {
        uint256 verificationStreakStartedAt = inbox.getVerificationStreakStartedAt();
        assertEq(verificationStreakStartedAt, 1);
    }

    function test_inbox_verification_streak_view_is_reset_when_verification_delay_is_exceeded()
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        uint256 verificationStreakStartedAt = inbox.getVerificationStreakStartedAt();

        vm.warp(verificationStreakStartedAt + 7 days - 1);
        // Verification streak currently holds
        assertEq(inbox.getVerificationStreakStartedAt(), verificationStreakStartedAt);

        vm.warp(verificationStreakStartedAt + 7 days + 1);
        // Verification streak is reset
        assertEq(inbox.getVerificationStreakStartedAt(), block.timestamp);
    }

    function test_inbox_verification_streak_storage_is_reset_when_verification_delay_is_exceeded()
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        uint256 verificationStreakStartedAt = inbox.getStats1().verificationStreakStartedAt;

        vm.warp(verificationStreakStartedAt + 7 days + 1);
        // Verification streak in storage still holds, but view value is reset
        assertEq(inbox.getStats1().verificationStreakStartedAt, verificationStreakStartedAt);
        assertEq(inbox.getVerificationStreakStartedAt(), block.timestamp);

        // Prove and verify the batch
        _proveBatchesWithCorrectTransitions(batchIds);

        // Verification streak in storage is reset
        assertEq(inbox.getStats1().verificationStreakStartedAt, block.timestamp);
    }
}
