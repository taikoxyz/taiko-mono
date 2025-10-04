// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestHelper } from "./common/InboxTestHelper.sol";
import { InboxDeployer } from "./deployers/InboxDeployer.sol";
import { CheckpointDelayInboxDeployer } from "./deployers/CheckpointDelayInboxDeployer.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { Inbox } from "src/layer1/shasta/impl/Inbox.sol";

/// @title InboxCheckpointSyncConfig
/// @notice Tests for checkpoint sync configuration and behavior documentation
/// @dev These tests verify the checkpoint sync configuration and document the two modes:
///
///      **Checkpoint Sync Modes:**
///
///      1. **Voluntary Sync**: Proposer provides checkpoint (blockHash != 0)
///         - Syncs immediately, regardless of minCheckpointDelay
///         - Allows proposers to proactively save checkpoints
///
///      2. **Forced Sync**: minCheckpointDelay elapsed since last checkpoint
///         - Syncs automatically when delay threshold reached
///         - Ensures regular checkpoint availability even without voluntary sync
///
///      3. **No Sync**: No finalization (finalizedCount == 0)
///         - No checkpoint saved, even if checkpoint provided or delay elapsed
///         - Checkpoint sync only occurs when proposals are finalized
///
///      **Implementation**: See Inbox.sol:_syncCheckpointIfNeeded()
///      ```solidity
///      bool syncCheckpoint = _checkpoint.blockHash != 0  // voluntary
///          || block.timestamp >= _coreState.lastCheckpointTimestamp + _minCheckpointDelay;  // forced
///      if (syncCheckpoint) {
///          require(_checkpoint.blockHash != 0, InvalidCheckpoint());
///          LibCheckpointStore.saveCheckpoint(...);
///          _coreState.lastCheckpointTimestamp = uint48(block.timestamp);
///      }
///      ```
///
///      The actual checkpoint sync logic is tested implicitly through all existing
///      propose/prove/finalize integration tests in the test suite.
contract InboxCheckpointSyncConfig is InboxTestHelper {
    function setUp() public override {
        setDeployer(new InboxDeployer());
        super.setUp();
    }

    /// @notice Test that default inbox has minCheckpointDelay = 0 (no rate limiting)
    /// @dev With minCheckpointDelay = 0, every finalization can save a checkpoint
    function test_defaultInbox_hasZeroCheckpointDelay() public view {
        IInbox.Config memory config = inbox.getConfig();

        assertEq(
            config.minCheckpointDelay,
            0,
            "Default inbox should have minCheckpointDelay = 0 (no rate limiting)"
        );
    }

    /// @notice Test maxCheckpointHistory configuration
    /// @dev Verifies that the checkpoint history size is properly configured
    function test_checkpointHistory_isConfiguredCorrectly() public view {
        IInbox.Config memory config = inbox.getConfig();

        assertEq(
            config.maxCheckpointHistory,
            100,
            "Default inbox should have maxCheckpointHistory = 100"
        );
    }

    /// @notice Test that CheckpointDelayInbox can be deployed with custom minCheckpointDelay
    /// @dev Verifies the CheckpointDelayInboxDeployer creates inbox with correct config
    function test_checkpointDelayInbox_canBeConfiguredWithCustomDelay() public {
        uint16 testDelay = 300; // 5 minutes
        CheckpointDelayInboxDeployer deployer = new CheckpointDelayInboxDeployer(testDelay);

        // Deploy inbox with custom delay
        Inbox customInbox = deployer.deployInbox(
            address(bondToken),
            100, // maxCheckpointHistory
            address(proofVerifier),
            address(proposerChecker)
        );

        IInbox.Config memory config = customInbox.getConfig();

        assertEq(
            config.minCheckpointDelay,
            testDelay,
            "Custom inbox should have configured minCheckpointDelay"
        );
    }

    /// @notice Test various minCheckpointDelay values
    /// @dev Documents that minCheckpointDelay can be set to different values for different use cases
    function test_checkpointDelay_supportsVariousDelayValues() public {
        // Test a few representative values
        uint16 oneMinute = 60;
        uint16 oneHour = 3600;

        // Test 1-minute delay
        CheckpointDelayInboxDeployer deployer1 = new CheckpointDelayInboxDeployer(oneMinute);
        Inbox inbox1 = deployer1.deployInbox(
            address(bondToken),
            100,
            address(proofVerifier),
            address(proposerChecker)
        );
        assertEq(
            inbox1.getConfig().minCheckpointDelay,
            oneMinute,
            "Inbox should support 1-minute checkpoint delay"
        );

        // Test 1-hour delay
        CheckpointDelayInboxDeployer deployer2 = new CheckpointDelayInboxDeployer(oneHour);
        Inbox inbox2 = deployer2.deployInbox(
            address(bondToken),
            100,
            address(proofVerifier),
            address(proposerChecker)
        );
        assertEq(
            inbox2.getConfig().minCheckpointDelay,
            oneHour,
            "Inbox should support 1-hour checkpoint delay"
        );
    }
}
