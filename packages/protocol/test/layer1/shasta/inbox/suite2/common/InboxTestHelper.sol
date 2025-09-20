// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { CommonTest } from "test/shared/CommonTest.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { InboxHelper } from "contracts/layer1/shasta/impl/InboxHelper.sol";
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
    // Encoding helpers
    // ---------------------------------------------------------------

    InboxHelper internal inboxHelper;
    string internal inboxContractName;
    bool internal useOptimizedProposeInputEncoding;
    bool internal useOptimizedProveInputEncoding;
    bool internal useOptimizedProposedEventEncoding;

    function _initializeEncodingHelper(string memory _contractName) internal {
        inboxContractName = _contractName;
        inboxHelper = new InboxHelper();

        bytes32 nameHash = keccak256(bytes(_contractName));
        bytes32 optimized2 = keccak256(bytes("InboxOptimized2"));
        bytes32 optimized3 = keccak256(bytes("InboxOptimized3"));

        useOptimizedProposeInputEncoding = nameHash == optimized3;
        useOptimizedProveInputEncoding = nameHash == optimized3;
        useOptimizedProposedEventEncoding = nameHash == optimized2 || nameHash == optimized3;
    }

    function _getInboxContractName() internal view returns (string memory) {
        return inboxContractName;
    }

    // ---------------------------------------------------------------
    // Genesis State Builders
    // ---------------------------------------------------------------

    function _getGenesisCoreState() internal pure returns (IInbox.CoreState memory) {
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

    // ---------------------------------------------------------------
    // Input Builders
    // ---------------------------------------------------------------

    function _encodeProposeInput(IInbox.ProposeInput memory _input)
        internal
        view
        returns (bytes memory)
    {
        if (useOptimizedProposeInputEncoding) {
            return inboxHelper.encodeProposeInputOptimized(_input);
        }
        return inboxHelper.encodeProposeInput(_input);
    }

    function _encodeProposedEvent(IInbox.ProposedEventPayload memory _payload)
        internal
        view
        returns (bytes memory)
    {
        if (useOptimizedProposedEventEncoding) {
            return inboxHelper.encodeProposedEventOptimized(_payload);
        }
        return inboxHelper.encodeProposedEvent(_payload);
    }

    function _encodeProveInput(IInbox.ProveInput memory _input)
        internal
        view
        returns (bytes memory)
    {
        if (useOptimizedProveInputEncoding) {
            return inboxHelper.encodeProveInputOptimized(_input);
        }
        return inboxHelper.encodeProveInput(_input);
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
}
