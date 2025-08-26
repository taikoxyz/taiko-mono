// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { InboxTestSetup } from "../common/InboxTestSetup.sol";
import { BlobTestUtils } from "../common/BlobTestUtils.sol";
import { CommonTest } from "test/shared/CommonTest.sol";
import { console2 } from "forge-std/src/console2.sol";

// Import errors from Inbox implementation
import "contracts/layer1/shasta/impl/Inbox.sol";

/// @title AbstractProveTest
/// @notice All prove tests for Inbox implementations
abstract contract AbstractProveTest is InboxTestSetup, BlobTestUtils {
    
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    // Note: Prove tests don't need proposer selection, so no PreconfWhitelistSetup inheritance

    // ---------------------------------------------------------------
    // Setup Functions
    // ---------------------------------------------------------------

    function setUp() public virtual override {
        super.setUp();

        //TODO: Add prove-specific setup here
    }


    // ---------------------------------------------------------------
    // Abstract Functions Implementation
    // ---------------------------------------------------------------

    function deployInbox(
        address bondToken,
        address syncedBlockManager,
        address proofVerifier,
        address proposerChecker,
        address forcedInclusionStore
    )
        internal
        virtual
        override
        returns (Inbox);   
    
    /// @dev Returns the name of the test contract for snapshot identification
    function getTestContractName() internal pure virtual returns (string memory);

    // ---------------------------------------------------------------
    // Proof Input Builders
    // ---------------------------------------------------------------

    function _createProofInput() internal view returns (bytes memory) {
        // TODO: Implement proof input creation
        // This would create the necessary proof data for proving a proposal
        return bytes("");
    }

    function _buildExpectedProvedPayload(
        uint48 _proposalId
    )
        internal
        view
        returns (IInbox.ProvedEventPayload memory)
    {
        // TODO: Build expected event data for proved proposals
        // This is a placeholder structure
        IInbox.ProvedEventPayload memory payload;
        // payload.proposalId = _proposalId;
        // Add other fields as needed
        return payload;
    }

    // ---------------------------------------------------------------
    // Prove Tests (Examples/Placeholders)
    // ---------------------------------------------------------------

    function test_prove() public {
        // TODO: Implement basic prove test
        // 1. First create a proposal (or use existing proposal)
        // 2. Generate proof for the proposal
        // 3. Submit proof via inbox.prove()
        // 4. Verify proof was accepted and events emitted
    }

    function test_prove_RevertWhen_InvalidProof() public {
        // TODO: Test that invalid proofs are rejected
    }

    function test_prove_RevertWhen_ProposalNotFound() public {
        // TODO: Test proving non-existent proposal reverts
    }

}