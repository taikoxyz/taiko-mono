// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { CommonTest } from "test/shared/CommonTest.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { IInboxCodec } from "src/layer1/shasta/iface/IInboxCodec.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";

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
    uint256 internal constant DEFAULT_TEST_BLOB_COUNT = 9;

    // Forced inclusion
    uint64 internal constant INCLUSION_DELAY = 10 minutes;
    uint64 internal constant FEE_IN_GWEI = 100;

    // ---------------------------------------------------------------
    // Codec Interface
    // ---------------------------------------------------------------

    IInboxCodec internal inboxCodec;

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

    function _getGenesisTransitionHash() internal view returns (bytes32) {
        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: bytes32(0),
            parentTransitionHash: bytes32(0),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 0,
                blockHash: GENESIS_BLOCK_HASH,
                stateRoot: bytes32(0)
            })
        });
        return inboxCodec.hashTransition(transition);
    }

    function _createGenesisProposal() internal view returns (IInbox.Proposal memory) {
        IInbox.CoreState memory coreState = _getGenesisCoreState();

        IInbox.Derivation memory derivation;

        return IInbox.Proposal({
            id: 0,
            proposer: address(0),
            timestamp: 0,
            endOfSubmissionWindowTimestamp: 0,
            coreStateHash: inboxCodec.hashCoreState(coreState),
            derivationHash: inboxCodec.hashDerivation(derivation)
        });
    }

    // ---------------------------------------------------------------
    // Blob Helpers
    // ---------------------------------------------------------------

    function _setupBlobHashes() internal {
        _setupBlobHashes(DEFAULT_TEST_BLOB_COUNT);
    }

    function _setupBlobHashes(uint256 _numBlobs) internal {
        vm.blobhashes(_getBlobHashesForTest(_numBlobs));
    }

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
        // WORKAROUND: There seems to be a weird issue where block.number + 1 evaluates incorrectly
        // Use an intermediate variable to work around this
        uint256 currentBlock = block.number;
        uint48 nextBlock = uint48(currentBlock) + 1;

        IInbox.CoreState memory expectedCoreState = IInbox.CoreState({
            nextProposalId: _proposalId + 1,
            nextProposalBlockId: nextBlock,
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });

        // Build the expected derivation with multi-source format
        // Extract the correct subset of blob hashes from the full set setup by _setupBlobHashes
        bytes32[] memory fullBlobHashes = _getBlobHashesForTest(DEFAULT_TEST_BLOB_COUNT);
        bytes32[] memory selectedBlobHashes = new bytes32[](_numBlobs);
        for (uint256 i = 0; i < _numBlobs; i++) {
            selectedBlobHashes[i] = fullBlobHashes[i]; // Start from index 0 as per _createBlobRef
        }

        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: selectedBlobHashes,
                offset: _offset,
                timestamp: uint48(block.timestamp)
            })
        });

        IInbox.Derivation memory expectedDerivation = IInbox.Derivation({
            originBlockNumber: uint48(block.number - 1),
            originBlockHash: blockhash(block.number - 1),
            basefeeSharingPctg: 0, // Using actual value from SimpleInbox config
            sources: sources
        });

        // Build the expected proposal
        IInbox.Proposal memory expectedProposal = IInbox.Proposal({
            id: _proposalId,
            proposer: _currentProposer,
            timestamp: uint48(block.timestamp),
            endOfSubmissionWindowTimestamp: 0, // PreconfWhitelist returns 0 for
                // endOfSubmissionWindowTimestamp
            coreStateHash: inboxCodec.hashCoreState(expectedCoreState),
            derivationHash: inboxCodec.hashDerivation(expectedDerivation)
        });

        return IInbox.ProposedEventPayload({
            proposal: expectedProposal,
            derivation: expectedDerivation,
            coreState: expectedCoreState
        });
    }

    // ---------------------------------------------------------------
    // Input Builders
    // ---------------------------------------------------------------

    function _createProposeInputWithCustomParams(
        uint48 _deadline,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.Proposal[] memory _parentProposals,
        IInbox.CoreState memory _coreState
    )
        internal
        view
        returns (bytes memory)
    {
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: _deadline,
            coreState: _coreState,
            parentProposals: _parentProposals,
            blobReference: _blobRef,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: blockhash(block.number - 1),
                stateRoot: bytes32(uint256(100))
            }),
            transitionRecords: new IInbox.TransitionRecord[](0),
            numForcedInclusions: 0
        });

        return inboxCodec.encodeProposeInput(input);
    }

    function _createFirstProposeInput() internal view returns (bytes memory) {
        IInbox.CoreState memory coreState = _getGenesisCoreState();

        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _createGenesisProposal();

        LibBlobs.BlobReference memory blobRef = _createBlobRef(0, 1, 0);

        IInbox.ProposeInput memory input;
        input.coreState = coreState;
        input.parentProposals = parentProposals;
        input.blobReference = blobRef;

        return inboxCodec.encodeProposeInput(input);
    }

    function _createProposeInputWithDeadline(uint48 _deadline)
        internal
        view
        returns (bytes memory)
    {
        IInbox.CoreState memory coreState = _getGenesisCoreState();
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _createGenesisProposal();

        return _createProposeInputWithCustomParams(
            _deadline, _createBlobRef(0, 1, 0), parentProposals, coreState
        );
    }

    function _createProposeInputWithBlobs(
        uint8 _numBlobs,
        uint24 _offset
    )
        internal
        view
        returns (bytes memory)
    {
        IInbox.CoreState memory coreState = _getGenesisCoreState();
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _createGenesisProposal();

        LibBlobs.BlobReference memory blobRef = _createBlobRef(0, _numBlobs, _offset);

        return _createProposeInputWithCustomParams(0, blobRef, parentProposals, coreState);
    }
}
