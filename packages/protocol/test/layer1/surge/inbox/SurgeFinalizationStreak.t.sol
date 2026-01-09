// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestBase } from "../../core/inbox/InboxTestBase.sol";
import { MockSurgeVerifier } from "./mocks/MockContracts.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { SurgeInbox } from "src/layer1/surge/deployments/internal-devnet/SurgeInbox.sol";

contract SurgeInboxFinalizationStreak is InboxTestBase {
    uint48 internal constant MAX_FINALIZATION_DELAY_BEFORE_STREAK_RESET = 518_400;
    uint48 internal constant MAX_FINALIZATION_DELAY_BEFORE_ROLLBACK = 604_800;

    function test_prove_resetsFinalizationStreakAfterDelay() external {
        uint48 lastFinalizationTimestamp = inbox.getCoreState().lastFinalizedTimestamp;

        uint48 streakBefore = SurgeInbox(address(inbox)).getFinalizationStreak();
        assertEq(streakBefore, block.timestamp - lastFinalizationTimestamp, "streakBefore");

        IInbox.ProveInput memory proveInput = _buildBatchInput(2);

        // Wrap the time just beyond the streak reset threshold
        vm.warp(lastFinalizationTimestamp + MAX_FINALIZATION_DELAY_BEFORE_STREAK_RESET + 1);
        _prove(proveInput);

        // Streak resets
        uint48 streakAfter = SurgeInbox(address(inbox)).getFinalizationStreak();
        assertEq(streakAfter, 0, "streakAfter");
    }

    function test_prove_resetsFinalizationStreakAfterDelayEvenWithoutProving() external {
        uint48 lastFinalizationTimestamp = inbox.getCoreState().lastFinalizedTimestamp;

        uint48 streakBefore = SurgeInbox(address(inbox)).getFinalizationStreak();
        assertEq(streakBefore, block.timestamp - lastFinalizationTimestamp, "streakBefore");

        // Wrap the time just beyond the streak reset threshold
        vm.warp(lastFinalizationTimestamp + MAX_FINALIZATION_DELAY_BEFORE_STREAK_RESET + 1);

        // Streak resets
        uint48 streakAfter = SurgeInbox(address(inbox)).getFinalizationStreak();
        assertEq(streakAfter, 0, "streakAfter");
    }

    function test_prove_doesNotResetFinalizationStreakBeforeDelay() external {
        uint48 lastFinalizationTimestamp = inbox.getCoreState().lastFinalizedTimestamp;

        uint48 streakBefore = SurgeInbox(address(inbox)).getFinalizationStreak();
        assertEq(streakBefore, block.timestamp - lastFinalizationTimestamp, "streakBefore");

        IInbox.ProveInput memory proveInput = _buildBatchInput(2);

        // Wrap the time to just before crossing the threshold
        vm.warp(lastFinalizationTimestamp + MAX_FINALIZATION_DELAY_BEFORE_STREAK_RESET);
        _prove(proveInput);

        // Streak does not reset
        uint48 streakAfter = SurgeInbox(address(inbox)).getFinalizationStreak();
        assertEq(streakAfter, block.timestamp - lastFinalizationTimestamp, "streakAfter");
    }

    // ---------------------------------------------------------------------
    // Hook overrides
    // ---------------------------------------------------------------------

    function _buildConfig() internal virtual override returns (IInbox.Config memory) {
        return IInbox.Config({
            proofVerifier: address(new MockSurgeVerifier()),
            proposerChecker: address(proposerChecker),
            proverWhitelist: address(proverWhitelistContract),
            signalService: address(signalService),
            provingWindow: 2 hours,
            maxProofSubmissionDelay: 3 minutes,
            ringBufferSize: 100,
            basefeeSharingPctg: 0,
            minForcedInclusionCount: 1,
            forcedInclusionDelay: 384,
            forcedInclusionFeeInGwei: 10_000_000,
            forcedInclusionFeeDoubleThreshold: 50,
            minCheckpointDelay: 60_000, // large enough for skipping checkpoints in prove benches
            permissionlessInclusionMultiplier: 5
        });
    }

    /// @dev Override to deploy surge inbox instead of the base inbox
    function _deployInbox() internal virtual override returns (Inbox) {
        address impl = address(
            new SurgeInbox(
                config,
                MAX_FINALIZATION_DELAY_BEFORE_STREAK_RESET,
                MAX_FINALIZATION_DELAY_BEFORE_ROLLBACK
            )
        );
        return _deployProxy(impl);
    }
}
