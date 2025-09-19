// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { CommonTest } from "test/shared/CommonTest.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";

/// @title InboxTestHelper
/// @notice Pure utility functions for Inbox tests
contract InboxTestHelper is CommonTest {
    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    bytes32 internal constant GENESIS_BLOCK_HASH = bytes32(uint256(1));
    uint256 internal constant DEFAULT_RING_BUFFER_SIZE = 100;
    uint256 internal constant DEFAULT_MAX_FINALIZATION_COUNT = 10;
    uint48 internal constant DEFAULT_PROVING_WINDOW = 1 hours;
    uint48 internal constant DEFAULT_EXTENDED_PROVING_WINDOW = 2 hours;
    uint8 internal constant DEFAULT_BASEFEE_SHARING_PCTG = 10;
    uint48 internal constant INITIAL_BLOCK_NUMBER = 100;
    uint48 internal constant INITIAL_BLOCK_TIMESTAMP = 1000;

    // Forced inclusion
    uint64 internal constant INCLUSION_DELAY = 10 minutes;
    uint64 internal constant FEE_IN_GWEI = 100;

    // ---------------------------------------------------------------
    // Genesis State Builders
    // ---------------------------------------------------------------

    function _getGenesisCoreState() internal view returns (IInbox.CoreState memory) {
        return IInbox.CoreState({
            nextProposalId: 1,
            nextProposalBlockId: 2, // Genesis value - prevents blockhash(0) issue
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });
    }

    function _getGenesisTransitionHash() internal pure returns (bytes32) {
        IInbox.Transition memory transition;
        transition.checkpoint.blockHash = GENESIS_BLOCK_HASH;
        return keccak256(abi.encode(transition));
    }

    function _createGenesisProposal() internal view returns (IInbox.Proposal memory) {
        IInbox.CoreState memory coreState = _getGenesisCoreState();

        IInbox.Derivation memory derivation;

        return IInbox.Proposal({
            id: 0,
            proposer: address(0),
            timestamp: 0,
            endOfSubmissionWindowTimestamp: 0,
            coreStateHash: keccak256(abi.encode(coreState)),
            derivationHash: keccak256(abi.encode(derivation))
        });
    }

    // ---------------------------------------------------------------
    // Blob Helpers
    // ---------------------------------------------------------------

    function _getBlobHashesForTest(uint256 _numBlobs) internal pure returns (bytes32[] memory) {
        bytes32[] memory hashes = new bytes32[](_numBlobs);
        for (uint256 i = 0; i < _numBlobs; i++) {
            hashes[i] = keccak256(abi.encode("blob", i));
        }
        return hashes;
    }

    function _createBlobRef(
        uint8 _blobStartIndex,
        uint8 _numBlobs,
        uint24 _offset
    )
        internal
        pure
        returns (LibBlobs.BlobReference memory)
    {
        return LibBlobs.BlobReference({
            blobStartIndex: _blobStartIndex,
            numBlobs: _numBlobs,
            offset: _offset
        });
    }

    // ---------------------------------------------------------------
    // Expected Event Payload Builders
    // ---------------------------------------------------------------

    function _buildExpectedProposedPayload(
        uint48 _proposalId,
        uint8 _numBlobs,
        uint24 _offset,
        address _currentProposer
    )
        internal
        view
        returns (IInbox.ProposedEventPayload memory)
    {
        // Build the expected core state after proposal
        // Line 215 sets nextProposalBlockId to block.number+1
        IInbox.CoreState memory expectedCoreState = IInbox.CoreState({
            nextProposalId: _proposalId + 1,
            nextProposalBlockId: uint48(block.number + 1), // block.number + 1
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });

        // Build the expected derivation
        IInbox.Derivation memory expectedDerivation = IInbox.Derivation({
            originBlockNumber: uint48(block.number - 1),
            originBlockHash: blockhash(block.number - 1),
            isForcedInclusion: false,
            basefeeSharingPctg: 0, // Using actual value from SimpleInbox config
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: _getBlobHashesForTest(_numBlobs),
                offset: _offset,
                timestamp: uint48(block.timestamp)
            })
        });

        // Build the expected proposal
        IInbox.Proposal memory expectedProposal = IInbox.Proposal({
            id: _proposalId,
            proposer: _currentProposer,
            timestamp: uint48(block.timestamp),
            endOfSubmissionWindowTimestamp: 0, // PreconfWhitelist returns 0 for
                // endOfSubmissionWindowTimestamp
            coreStateHash: keccak256(abi.encode(expectedCoreState)),
            derivationHash: keccak256(abi.encode(expectedDerivation))
        });

        return IInbox.ProposedEventPayload({
            proposal: expectedProposal,
            derivation: expectedDerivation,
            coreState: expectedCoreState
        });
    }
}
