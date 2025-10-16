// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized1Deployer } from "../deployers/InboxOptimized1Deployer.sol";
import { AbstractProposeTest } from "./AbstractPropose.t.sol";

/// @title InboxOptimized1Propose
/// @notice Test suite for propose functionality on Optimized1 Inbox implementation
contract InboxOptimized1Propose is AbstractProposeTest {
    function setUp() public virtual override {
        setDeployer(new InboxOptimized1Deployer());
        super.setUp();
    }

    // These tests are moved to separate contracts due to vm.expectEmit issues:
    // - InboxOptimized1BlobOffsetTest for test_propose_withBlobOffset
    // - InboxOptimized1MultipleBlobsTest for test_propose_withMultipleBlobs
    // - InboxOptimized1ConsecutiveTest for test_propose_twoConsecutiveProposals

    // Override them here to skip in this contract
    function test_propose_withBlobOffset() public override {
        // Tested in InboxOptimized1BlobOffsetTest
    }

    function test_propose_withMultipleBlobs() public override {
        // Tested in InboxOptimized1MultipleBlobsTest
    }

    function test_propose_twoConsecutiveProposals() public override {
        // Tested in InboxOptimized1ConsecutiveTest
    }
}
