// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { CommonTest } from "test/shared/CommonTest.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { Inbox } from "src/layer1/shasta/impl/Inbox.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { InboxHelper } from "src/layer1/shasta/impl/InboxHelper.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";
import { LibHashing } from "src/layer1/shasta/libs/LibHashing.sol";

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
    // Encoding helpers
    // ---------------------------------------------------------------

    InboxHelper internal inboxHelper;
    string internal inboxContractName;
    bool internal useOptimizedProposeInputEncoding;
    bool internal useOptimizedProveInputEncoding;
    bool internal useOptimizedProposedEventEncoding;
    bool internal useLibHashing;

    function _initializeEncodingHelper(string memory _contractName) internal {
        inboxContractName = _contractName;
        inboxHelper = new InboxHelper();

        bytes32 nameHash = keccak256(bytes(_contractName));
        bytes32 optimized2 = keccak256(bytes("InboxOptimized2"));

        useOptimizedProposeInputEncoding = nameHash == optimized2;
        useOptimizedProveInputEncoding = nameHash == optimized2;
        useOptimizedProposedEventEncoding = nameHash == optimized2;
        // InboxOptimized2 now uses LibHashing (merged from InboxOptimized3)
        useLibHashing = nameHash == optimized2;
    }

    function _getInboxContractName() internal view returns (string memory) {
        return inboxContractName;
    }

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
        IInbox.Transition memory transition;
        transition.checkpoint.blockHash = GENESIS_BLOCK_HASH;
        return _hashTransition(transition);
    }

    function _createGenesisProposal() internal view returns (IInbox.Proposal memory) {
        IInbox.CoreState memory coreState = _getGenesisCoreState();

        IInbox.Derivation memory derivation;

        return IInbox.Proposal({
            id: 0,
            proposer: address(0),
            timestamp: 0,
            endOfSubmissionWindowTimestamp: 0,
            coreStateHash: _hashCoreState(coreState),
            derivationHash: _hashDerivation(derivation)
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

    function _getBlobHashesForTestStartingAt(uint256 _startIndex, uint256 _numBlobs)
        internal
        pure
        returns (bytes32[] memory)
    {
        bytes32[] memory hashes = new bytes32[](_numBlobs);
        for (uint256 i = 0; i < _numBlobs; i++) {
            hashes[i] = keccak256(abi.encode("blob", _startIndex + i));
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
        return _buildExpectedProposedPayloadWithStartIndex(
            _proposalId, 0, _numBlobs, _offset, _currentProposer
        );
    }

    function _buildExpectedProposedPayloadWithStartIndex(
        uint48 _proposalId,
        uint16 _blobStartIndex,
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

        // Build the expected derivation with multi-source format
        // Extract the correct subset of blob hashes from the full set setup by _setupBlobHashes
        bytes32[] memory fullBlobHashes = _getBlobHashesForTest(DEFAULT_TEST_BLOB_COUNT);
        bytes32[] memory selectedBlobHashes = new bytes32[](_numBlobs);
        for (uint256 i = 0; i < _numBlobs; i++) {
            selectedBlobHashes[i] = fullBlobHashes[_blobStartIndex + i];
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
            coreStateHash: _hashCoreState(expectedCoreState),
            derivationHash: _hashDerivation(expectedDerivation)
        });

        return IInbox.ProposedEventPayload({
            proposal: expectedProposal,
            derivation: expectedDerivation,
            coreState: expectedCoreState
        });
    }

    function _buildExpectedForcedInclusionPayload(
        uint48 _proposalId,
        uint16 _blobStartIndex,
        uint8 _numBlobs,
        uint24 _offset,
        uint48 _timestamp
    )
        internal
        view
        returns (IInbox.ProposedEventPayload memory)
    {
        IInbox.CoreState memory expectedCoreState = IInbox.CoreState({
            nextProposalId: _proposalId + 1,
            nextProposalBlockId: uint48(block.number + 1),  // Set to block.number + 1 as per propose() logic
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });

        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: true,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: _getBlobHashesForTestStartingAt(_blobStartIndex, _numBlobs),
                offset: _offset,
                timestamp: _timestamp
            })
        });

        IInbox.Derivation memory expectedDerivation = IInbox.Derivation({
            originBlockNumber: uint48(block.number - 1),
            originBlockHash: blockhash(block.number - 1),
            basefeeSharingPctg: 0,
            sources: sources
        });

        IInbox.Proposal memory expectedProposal = IInbox.Proposal({
            id: _proposalId,
            proposer: address(0), // will be checked in encoded event equality, proposer not used here
            timestamp: _timestamp,
            endOfSubmissionWindowTimestamp: 0,
            coreStateHash: _hashCoreState(expectedCoreState),
            derivationHash: _hashDerivation(expectedDerivation)
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

    function _encodeProposeInput(IInbox.ProposeInput memory _input)
        internal
        view
        returns (bytes memory)
    {
        if (useOptimizedProposeInputEncoding) {
            return inboxHelper.encodeProposeInput(_input);
        }
        return abi.encode(_input);
    }

    function _encodeProposedEvent(IInbox.ProposedEventPayload memory _payload)
        internal
        view
        returns (bytes memory)
    {
        if (useOptimizedProposedEventEncoding) {
            return inboxHelper.encodeProposedEvent(_payload);
        }
        return abi.encode(_payload);
    }

    function _decodeProposedEvent(bytes memory _data)
        internal
        view
        returns (IInbox.ProposedEventPayload memory)
    {
        if (useOptimizedProposedEventEncoding) {
            return inboxHelper.decodeProposedEvent(_data);
        }
        return abi.decode(_data, (IInbox.ProposedEventPayload));
    }

    function _encodeProveInput(IInbox.ProveInput memory _input)
        internal
        view
        returns (bytes memory)
    {
        if (useOptimizedProveInputEncoding) {
            return inboxHelper.encodeProveInput(_input);
        }
        return abi.encode(_input);
    }

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

        return _encodeProposeInput(input);
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

        return _encodeProposeInput(input);
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

    // ---------------------------------------------------------------
    // Conditional Hashing Functions
    // ---------------------------------------------------------------

    function _hashTransition(IInbox.Transition memory _transition)
        internal
        view
        returns (bytes32)
    {
        if (useLibHashing) {
            return LibHashing.hashTransition(_transition);
        }
        return keccak256(abi.encode(_transition));
    }

    function _hashCoreState(IInbox.CoreState memory _coreState) internal view returns (bytes32) {
        if (useLibHashing) {
            return LibHashing.hashCoreState(_coreState);
        }
        return keccak256(abi.encode(_coreState));
    }

    function _hashDerivation(IInbox.Derivation memory _derivation)
        internal
        view
        returns (bytes32)
    {
        if (useLibHashing) {
            return LibHashing.hashDerivation(_derivation);
        }
        return keccak256(abi.encode(_derivation));
    }

    function _hashCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint)
        internal
        view
        returns (bytes32)
    {
        if (useLibHashing) {
            return LibHashing.hashCheckpoint(_checkpoint);
        }
        return keccak256(abi.encode(_checkpoint));
    }

    function _hashProposal(IInbox.Proposal memory _proposal) internal view returns (bytes32) {
        if (useLibHashing) {
            return LibHashing.hashProposal(_proposal);
        }
        return keccak256(abi.encode(_proposal));
    }
}
