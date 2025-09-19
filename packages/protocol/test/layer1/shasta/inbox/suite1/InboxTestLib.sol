// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/layer1/shasta/iface/IInbox.sol";
import "contracts/layer1/shasta/libs/LibBlobs.sol";
import "contracts/shared/based/libs/LibBonds.sol";

/// @title InboxTestLib
/// @notice Consolidated test utility library for Inbox tests
/// @dev Single source of truth for all test data creation and manipulation
/// @custom:security-contact security@taiko.xyz
library InboxTestLib {
    // ---------------------------------------------------------------
    // Data Structures
    // ---------------------------------------------------------------

    /// @dev Test context for managing test state
    struct TestContext {
        IInbox.CoreState coreState;
        IInbox.Proposal[] proposals;
        IInbox.Transition[] transitions;
        IInbox.TransitionRecord[] transitionRecords;
        bytes32 currentParentHash;
        uint48 nextProposalId;
        uint48 lastFinalizedId;
    }

    /// @dev Chain of proposals and transitions for testing
    struct ProposalChain {
        IInbox.Proposal[] proposals;
        IInbox.Transition[] transitions;
        bytes32 initialParentHash;
        bytes32 finalTransitionHash;
    }

    // ---------------------------------------------------------------
    // Core State Management
    // ---------------------------------------------------------------

    /// @dev Creates a basic core state with proper nextProposalBlockId handling
    /// @notice nextProposalBlockId = block.number + 1 after each proposal
    function createCoreState(
        uint48 _nextProposalId,
        uint48 _lastFinalizedProposalId
    )
        internal
        pure
        returns (IInbox.CoreState memory)
    {
        return IInbox.CoreState({
            nextProposalId: _nextProposalId,
            nextProposalBlockId: 0, // Genesis default
            lastFinalizedProposalId: _lastFinalizedProposalId,
            lastFinalizedTransitionHash: bytes32(0),
            bondInstructionsHash: bytes32(0)
        });
    }

    /// @dev Creates a complete core state with all fields
    function createCoreState(
        uint48 _nextProposalId,
        uint48 _lastFinalizedProposalId,
        bytes32 _lastFinalizedTransitionHash,
        bytes32 _bondInstructionsHash
    )
        internal
        pure
        returns (IInbox.CoreState memory)
    {
        return IInbox.CoreState({
            nextProposalId: _nextProposalId,
            nextProposalBlockId: 0, // Genesis default
            lastFinalizedProposalId: _lastFinalizedProposalId,
            lastFinalizedTransitionHash: _lastFinalizedTransitionHash,
            bondInstructionsHash: _bondInstructionsHash
        });
    }

    /// @dev Creates a core state with explicit nextProposalBlockId
    function createCoreStateWithBlock(
        uint48 _nextProposalId,
        uint48 _nextProposalBlockId,
        uint48 _lastFinalizedProposalId
    )
        internal
        pure
        returns (IInbox.CoreState memory)
    {
        return IInbox.CoreState({
            nextProposalId: _nextProposalId,
            nextProposalBlockId: _nextProposalBlockId,
            lastFinalizedProposalId: _lastFinalizedProposalId,
            lastFinalizedTransitionHash: bytes32(0),
            bondInstructionsHash: bytes32(0)
        });
    }

    // ---------------------------------------------------------------
    // Assertion Helpers
    // ---------------------------------------------------------------

    /// @dev Asserts that a chain of proposals and transitions is valid
    function assertChainIntegrity(ProposalChain memory _chain) internal pure {
        require(_chain.proposals.length == _chain.transitions.length, "Chain length mismatch");

        bytes32 currentParent = _chain.initialParentHash;
        for (uint256 i = 0; i < _chain.transitions.length; i++) {
            require(
                _chain.transitions[i].parentTransitionHash == currentParent, "Invalid parent chain"
            );
            currentParent = hashTransition(_chain.transitions[i]);
        }

        require(currentParent == _chain.finalTransitionHash, "Final transition hash mismatch");
    }

    /// @dev Asserts that finalization completed correctly
    function assertFinalizationComplete(
        IInbox.CoreState memory _expectedState,
        IInbox.CoreState memory _actualState
    )
        internal
        pure
    {
        require(
            _actualState.lastFinalizedProposalId == _expectedState.lastFinalizedProposalId,
            "Last finalized ID mismatch"
        );
        require(
            _actualState.lastFinalizedTransitionHash == _expectedState.lastFinalizedTransitionHash,
            "Last finalized transition hash mismatch"
        );
    }

    /// @dev Asserts ring buffer state is as expected
    function assertRingBufferState(
        uint256 _expectedCapacity,
        uint256 _actualCapacity,
        uint48 _expectedUnfinalized,
        uint48 _actualUnfinalized
    )
        internal
        pure
    {
        require(_actualCapacity == _expectedCapacity, "Capacity mismatch");
        require(_actualUnfinalized == _expectedUnfinalized, "Unfinalized count mismatch");
    }

    // ---------------------------------------------------------------
    // Proposal Creation
    // ---------------------------------------------------------------

    /// @dev Creates a standard proposal
    function createProposal(
        uint48 _id,
        address _proposer,
        uint8 _basefeeSharingPctg
    )
        internal
        view
        returns (IInbox.Proposal memory, IInbox.Derivation memory)
    {
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encode("blob", uint256(_id % 256)));

        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: uint48(block.number - 1),
            originBlockHash: blockhash(block.number - 1),
            isForcedInclusion: false,
            basefeeSharingPctg: _basefeeSharingPctg,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 0,
                timestamp: uint48(block.timestamp)
            })
        });

        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: _id,
            proposer: _proposer,
            timestamp: uint48(block.timestamp),
            endOfSubmissionWindowTimestamp: uint48(0), // Set to 0 to match mockProposerAllowed
                // return value
            coreStateHash: bytes32(0),
            derivationHash: keccak256(abi.encode(derivation))
        });

        return (proposal, derivation);
    }

    /// @dev Creates a proposal with custom blob configuration
    function createProposalWithBlobs(
        uint48 _id,
        address _proposer,
        uint8 _basefeeSharingPctg,
        bytes32[] memory _blobHashes
    )
        internal
        view
        returns (IInbox.Proposal memory, IInbox.Derivation memory)
    {
        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: uint48(block.number - 1),
            originBlockHash: blockhash(block.number - 1),
            isForcedInclusion: false,
            basefeeSharingPctg: _basefeeSharingPctg,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: _blobHashes,
                offset: 0,
                timestamp: uint48(block.timestamp)
            })
        });

        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: _id,
            proposer: _proposer,
            timestamp: uint48(block.timestamp),
            endOfSubmissionWindowTimestamp: uint48(0), // Set to 0 to match mockProposerAllowed
                // return value
            coreStateHash: bytes32(0),
            derivationHash: keccak256(abi.encode(derivation))
        });

        return (proposal, derivation);
    }

    /// @dev Creates multiple proposals in batch
    function createProposalBatch(
        uint48 _startId,
        uint48 _count,
        address _proposer,
        uint8 _basefeeSharingPctg
    )
        internal
        view
        returns (IInbox.Proposal[] memory proposals)
    {
        proposals = new IInbox.Proposal[](_count);
        for (uint48 i = 0; i < _count; i++) {
            (proposals[i],) = createProposal(_startId + i, _proposer, _basefeeSharingPctg);
        }
    }

    // ---------------------------------------------------------------
    // Transition Creation
    // ---------------------------------------------------------------

    /// @dev Creates a standard transition
    function createTransition(
        IInbox.Proposal memory _proposal,
        bytes32 _parentTransitionHash,
        address /* _actualProver */
    )
        internal
        pure
        returns (IInbox.Transition memory)
    {
        // actualProver parameter is no longer used in Transition struct
        return IInbox.Transition({
            proposalHash: hashProposal(_proposal),
            parentTransitionHash: _parentTransitionHash,
            checkpoint: ICheckpointManager.Checkpoint({
                blockNumber: _proposal.id * 100,
                blockHash: keccak256(abi.encode(_proposal.id, "endBlockHash")),
                stateRoot: keccak256(abi.encode(_proposal.id, "stateRoot"))
            })
        });
    }

    /// @dev Creates a transition with custom block data
    function createTransitionWithBlock(
        bytes32 _proposalHash,
        bytes32 _parentTransitionHash,
        uint48 _endBlockNumber,
        bytes32 _endBlockHash,
        bytes32 _endStateRoot,
        address, /* _designatedProver */
        address /* _actualProver */
    )
        internal
        pure
        returns (IInbox.Transition memory)
    {
        // designatedProver and actualProver parameters are no longer used in Transition struct
        return IInbox.Transition({
            proposalHash: _proposalHash,
            parentTransitionHash: _parentTransitionHash,
            checkpoint: ICheckpointManager.Checkpoint({
                blockNumber: _endBlockNumber,
                blockHash: _endBlockHash,
                stateRoot: _endStateRoot
            })
        });
    }

    /// @dev Creates a chain of transitions with proper parent hashing
    function createTransitionChain(
        IInbox.Proposal[] memory _proposals,
        bytes32 _initialParentHash,
        address /* _prover */
    )
        internal
        pure
        returns (IInbox.Transition[] memory transitions)
    {
        transitions = new IInbox.Transition[](_proposals.length);
        bytes32 parentHash = _initialParentHash;

        for (uint256 i = 0; i < _proposals.length; i++) {
            transitions[i] = createTransition(_proposals[i], parentHash, address(0));
            parentHash = hashTransition(transitions[i]);
        }
    }

    // ---------------------------------------------------------------
    // TransitionRecord Creation
    // ---------------------------------------------------------------

    /// @dev Creates a transition record without bond instructions
    function createTransitionRecord(
        IInbox.Transition memory _transition,
        uint8 _span
    )
        internal
        pure
        returns (IInbox.TransitionRecord memory)
    {
        return IInbox.TransitionRecord({
            span: _span,
            bondInstructions: new LibBonds.BondInstruction[](0),
            transitionHash: hashTransition(_transition),
            checkpointHash: keccak256(abi.encode(_transition.checkpoint))
        });
    }

    /// @dev Creates a transition record with bond instructions
    function createTransitionRecordWithBonds(
        IInbox.Transition memory _transition,
        uint8 _span,
        LibBonds.BondInstruction[] memory _bondInstructions
    )
        internal
        pure
        returns (IInbox.TransitionRecord memory)
    {
        return IInbox.TransitionRecord({
            span: _span,
            bondInstructions: _bondInstructions,
            transitionHash: hashTransition(_transition),
            checkpointHash: keccak256(abi.encode(_transition.checkpoint))
        });
    }

    /// @dev Creates multiple transition records in batch
    function createTransitionRecordBatch(
        IInbox.Transition[] memory _transitions,
        uint8 _span
    )
        internal
        pure
        returns (IInbox.TransitionRecord[] memory records)
    {
        records = new IInbox.TransitionRecord[](_transitions.length);
        for (uint256 i = 0; i < _transitions.length; i++) {
            records[i] = createTransitionRecord(_transitions[i], _span);
        }
    }

    // ---------------------------------------------------------------
    // Blob Reference Creation
    // ---------------------------------------------------------------

    /// @dev Creates a blob reference with single blob
    function createBlobReference(uint8 _blobIndex)
        internal
        pure
        returns (LibBlobs.BlobReference memory)
    {
        return LibBlobs.BlobReference({ blobStartIndex: _blobIndex, numBlobs: 1, offset: 0 });
    }

    /// @dev Creates a blob reference with multiple blobs
    function createBlobReference(
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
    // Data Encoding - Simplified Interface
    // ---------------------------------------------------------------

    /// @dev Encodes propose input with default deadline and empty proposals array
    /// @notice LEGACY: Kept for backward compatibility but may cause failures in actual propose()
    /// calls
    function encodeProposeInput(
        IInbox.CoreState memory _coreState,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.TransitionRecord[] memory _transitionRecords
    )
        internal
        pure
        returns (bytes memory)
    {
        return _encodeProposeInputInternal(
            uint48(0), _coreState, new IInbox.Proposal[](0), _blobRef, _transitionRecords
        );
    }

    /// @dev Encodes propose input with custom deadline and empty proposals array
    /// @notice LEGACY: Kept for backward compatibility but may cause failures in actual propose()
    /// calls
    function encodeProposeInput(
        uint64 _deadline,
        IInbox.CoreState memory _coreState,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.TransitionRecord[] memory _transitionRecords
    )
        internal
        pure
        returns (bytes memory)
    {
        return _encodeProposeInputInternal(
            _deadline, _coreState, new IInbox.Proposal[](0), _blobRef, _transitionRecords
        );
    }

    /// @dev Internal encoding function to reduce duplication
    function _encodeProposeInputInternal(
        uint64 _deadline,
        IInbox.CoreState memory _coreState,
        IInbox.Proposal[] memory _proposals,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.TransitionRecord[] memory _transitionRecords
    )
        private
        pure
        returns (bytes memory)
    {
        // Add default numForcedInclusions = 0
        return abi.encode(_deadline, _coreState, _proposals, _blobRef, _transitionRecords, uint8(0));
    }

    /// @dev Encodes propose input for the first proposal after genesis (with validation)
    function encodeProposeInputWithGenesis(
        IInbox.CoreState memory _coreState,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.TransitionRecord[] memory _transitionRecords
    )
        internal
        pure
        returns (bytes memory)
    {
        return encodeProposeInputWithGenesis(uint48(0), _coreState, _blobRef, _transitionRecords);
    }

    /// @dev Encodes propose input for the first proposal after genesis with custom deadline
    function encodeProposeInputWithGenesis(
        uint64 _deadline,
        IInbox.CoreState memory _coreState,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.TransitionRecord[] memory _transitionRecords
    )
        internal
        pure
        returns (bytes memory)
    {
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = createGenesisProposal(_coreState);
        return _encodeProposeInputInternal(
            _deadline, _coreState, proposals, _blobRef, _transitionRecords
        );
    }

    /// @dev Encodes propose input with specific proposals for validation
    function encodeProposeInputWithProposals(
        IInbox.CoreState memory _coreState,
        IInbox.Proposal[] memory _proposals,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.TransitionRecord[] memory _transitionRecords
    )
        internal
        pure
        returns (bytes memory)
    {
        return _encodeProposeInputInternal(
            uint48(0), _coreState, _proposals, _blobRef, _transitionRecords
        );
    }

    /// @dev Encodes propose input with deadline and specific proposals for validation
    function encodeProposeInputWithProposals(
        uint64 _deadline,
        IInbox.CoreState memory _coreState,
        IInbox.Proposal[] memory _proposals,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.TransitionRecord[] memory _transitionRecords
    )
        internal
        pure
        returns (bytes memory)
    {
        return _encodeProposeInputInternal(
            _deadline, _coreState, _proposals, _blobRef, _transitionRecords
        );
    }

    /// @dev Encodes prove input
    function encodeProveInput(
        IInbox.Proposal[] memory _proposals,
        IInbox.Transition[] memory _transitions
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(_proposals, _transitions);
    }

    // ---------------------------------------------------------------
    // Hashing Functions
    // ---------------------------------------------------------------

    /// @dev Computes proposal hash
    function hashProposal(IInbox.Proposal memory _proposal) internal pure returns (bytes32) {
        return keccak256(abi.encode(_proposal));
    }

    /// @dev Computes transition hash
    function hashTransition(IInbox.Transition memory _transition) internal pure returns (bytes32) {
        return keccak256(abi.encode(_transition));
    }

    /// @dev Computes transition record hash
    function hashTransitionRecord(IInbox.TransitionRecord memory _record)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_record));
    }

    /// @dev Computes core state hash
    function hashCoreState(IInbox.CoreState memory _state) internal pure returns (bytes32) {
        return keccak256(abi.encode(_state));
    }

    // ---------------------------------------------------------------
    // Blob Hash Generation - Simplified
    // ---------------------------------------------------------------

    /// @dev Generates standard blob hashes for testing
    function generateBlobHashes(uint256 _count) internal pure returns (bytes32[] memory) {
        return generateBlobHashes(_count, "blob");
    }

    /// @dev Generates blob hashes with custom seed
    function generateBlobHashes(
        uint256 _count,
        string memory _seed
    )
        internal
        pure
        returns (bytes32[] memory hashes)
    {
        hashes = new bytes32[](_count);
        for (uint256 i = 0; i < _count; i++) {
            hashes[i] = keccak256(abi.encode(_seed, i));
        }
    }

    /// @dev Generates a single blob hash for convenience
    function generateSingleBlobHash(uint256 _index) internal pure returns (bytes32) {
        return keccak256(abi.encode("blob", _index));
    }

    // ---------------------------------------------------------------
    // Genesis & Proposal Creation Utilities
    // ---------------------------------------------------------------

    /// @dev Creates the genesis proposal (proposal id=0) that gets stored during contract
    /// initialization
    function createGenesisProposal(IInbox.CoreState memory _coreState)
        internal
        pure
        returns (IInbox.Proposal memory)
    {
        // Recreate the exact genesis proposal as created in the contract's init() function
        IInbox.Proposal memory proposal;
        // Genesis proposal has all default values except coreStateHash and derivationHash
        proposal.id = 0;
        proposal.proposer = address(0);
        proposal.timestamp = 0;
        proposal.endOfSubmissionWindowTimestamp = 0;

        // Use the passed core state to calculate the coreStateHash
        proposal.coreStateHash = keccak256(abi.encode(_coreState));

        // Hash of empty derivation (matching what init() does)
        IInbox.Derivation memory emptyDerivation;
        proposal.derivationHash = keccak256(abi.encode(emptyDerivation));

        return proposal;
    }

    /// @dev Encodes propose input for subsequent proposals (after the first one)
    function encodeProposeInputForSubsequent(
        IInbox.CoreState memory _coreState,
        IInbox.Proposal memory _previousProposal,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.TransitionRecord[] memory _transitionRecords
    )
        internal
        pure
        returns (bytes memory)
    {
        return encodeProposeInputForSubsequent(
            uint48(0), _coreState, _previousProposal, _blobRef, _transitionRecords
        );
    }

    /// @dev Encodes propose input for subsequent proposals with custom deadline
    function encodeProposeInputForSubsequent(
        uint64 _deadline,
        IInbox.CoreState memory _coreState,
        IInbox.Proposal memory _previousProposal,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.TransitionRecord[] memory _transitionRecords
    )
        internal
        pure
        returns (bytes memory)
    {
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = _previousProposal;
        return _encodeProposeInputInternal(
            _deadline, _coreState, proposals, _blobRef, _transitionRecords
        );
    }

    /// @dev Encodes propose input when ring buffer wrapping occurs (need 2 proposals for
    /// validation)
    function encodeProposeInputForWrapping(
        IInbox.CoreState memory _coreState,
        IInbox.Proposal memory _lastProposal,
        IInbox.Proposal memory _nextSlotProposal,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.TransitionRecord[] memory _transitionRecords
    )
        internal
        pure
        returns (bytes memory)
    {
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](2);
        proposals[0] = _lastProposal; // The last proposal being validated
        proposals[1] = _nextSlotProposal; // The proposal in the next slot
        return _encodeProposeInputInternal(
            uint48(0), _coreState, proposals, _blobRef, _transitionRecords
        );
    }

    /// @dev Encodes propose input with explicit numForcedInclusions
    function encodeProposeInputWithForcedInclusions(
        uint64 _deadline,
        IInbox.CoreState memory _coreState,
        IInbox.Proposal[] memory _proposals,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.TransitionRecord[] memory _transitionRecords,
        uint8 _numForcedInclusions
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(
            _deadline, _coreState, _proposals, _blobRef, _transitionRecords, _numForcedInclusions
        );
    }

    // ---------------------------------------------------------------
    // Chain Building Functions
    // ---------------------------------------------------------------

    /// @dev Creates a complete proposal chain with transitions
    function createProposalChain(
        uint48 _startId,
        uint48 _count,
        address _proposer,
        address _prover,
        bytes32 _initialParentHash,
        uint8 _basefeeSharingPctg
    )
        internal
        view
        returns (ProposalChain memory chain)
    {
        chain.proposals = createProposalBatch(_startId, _count, _proposer, _basefeeSharingPctg);
        chain.transitions = createTransitionChain(chain.proposals, _initialParentHash, _prover);
        chain.initialParentHash = _initialParentHash;

        if (_count > 0) {
            chain.finalTransitionHash = hashTransition(chain.transitions[_count - 1]);
        } else {
            chain.finalTransitionHash = _initialParentHash;
        }
    }

    /// @dev Creates a genesis transition
    function createGenesisTransition(bytes32 _genesisBlockHash)
        internal
        pure
        returns (IInbox.Transition memory)
    {
        return IInbox.Transition({
            proposalHash: bytes32(0),
            parentTransitionHash: bytes32(0),
            checkpoint: ICheckpointManager.Checkpoint({
                blockNumber: 0,
                blockHash: _genesisBlockHash,
                stateRoot: bytes32(0)
            })
        });
    }

    /// @dev Gets the genesis transition hash
    function getGenesisTransitionHash(bytes32 _genesisBlockHash) internal pure returns (bytes32) {
        return hashTransition(createGenesisTransition(_genesisBlockHash));
    }

    // ---------------------------------------------------------------
    // Proposal State Management for Tests
    // ---------------------------------------------------------------

    /// @dev Smart encoding function that determines which proposals to include based on the
    /// proposal ID
    function encodeProposeInputSmart(
        uint48 _proposalId,
        IInbox.CoreState memory _coreState,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.TransitionRecord[] memory _transitionRecords,
        IInbox.Proposal[] memory _allKnownProposals
    )
        internal
        pure
        returns (bytes memory)
    {
        if (_proposalId == 1) {
            return encodeProposeInputWithGenesis(_coreState, _blobRef, _transitionRecords);
        } else {
            IInbox.Proposal memory previousProposal =
                _findProposalById(_allKnownProposals, _proposalId - 1);
            return encodeProposeInputForSubsequent(
                _coreState, previousProposal, _blobRef, _transitionRecords
            );
        }
    }

    /// @dev Helper to find a proposal by ID from an array of known proposals
    function _findProposalById(
        IInbox.Proposal[] memory _proposals,
        uint48 _targetId
    )
        internal
        pure
        returns (IInbox.Proposal memory)
    {
        for (uint256 i = 0; i < _proposals.length; i++) {
            if (_proposals[i].id == _targetId) {
                return _proposals[i];
            }
        }
        // If not found, return a default proposal with the target ID
        // This handles the case where we might not have stored all proposals
        IInbox.Proposal memory defaultProposal;
        defaultProposal.id = _targetId;
        return defaultProposal;
    }

    // ---------------------------------------------------------------
    // Test Context Management
    // ---------------------------------------------------------------

    /// @dev Creates a new test context with default values
    function createContext(
        uint48 _nextProposalId,
        uint48 _lastFinalizedId,
        bytes32 _parentHash
    )
        internal
        view
        returns (TestContext memory ctx)
    {
        ctx.coreState = createCoreState(_nextProposalId, _lastFinalizedId, _parentHash, bytes32(0));
        ctx.currentParentHash = _parentHash;
        ctx.nextProposalId = _nextProposalId;
        ctx.lastFinalizedId = _lastFinalizedId;
        // Arrays are initialized as empty by default
    }

    /// @dev Creates a minimal test context for simple scenarios
    function createSimpleContext(
        uint48 _nextProposalId,
        bytes32 _parentHash
    )
        internal
        view
        returns (TestContext memory)
    {
        return createContext(_nextProposalId, 0, _parentHash);
    }

    /// @dev Adds a proposal to the context
    function addProposal(
        TestContext memory _ctx,
        IInbox.Proposal memory _proposal
    )
        internal
        pure
        returns (TestContext memory)
    {
        IInbox.Proposal[] memory newProposals = new IInbox.Proposal[](_ctx.proposals.length + 1);
        for (uint256 i = 0; i < _ctx.proposals.length; i++) {
            newProposals[i] = _ctx.proposals[i];
        }
        newProposals[_ctx.proposals.length] = _proposal;
        _ctx.proposals = newProposals;
        _ctx.nextProposalId++;
        return _ctx;
    }

    /// @dev Adds a transition to the context
    function addTransition(
        TestContext memory _ctx,
        IInbox.Transition memory _transition
    )
        internal
        pure
        returns (TestContext memory)
    {
        IInbox.Transition[] memory newTransitions =
            new IInbox.Transition[](_ctx.transitions.length + 1);
        for (uint256 i = 0; i < _ctx.transitions.length; i++) {
            newTransitions[i] = _ctx.transitions[i];
        }
        newTransitions[_ctx.transitions.length] = _transition;
        _ctx.transitions = newTransitions;
        _ctx.currentParentHash = hashTransition(_transition);
        return _ctx;
    }

    // ---------------------------------------------------------------
    // NextProposalBlockId Helpers
    // ---------------------------------------------------------------

    /// @dev Calculate the nextProposalBlockId after a proposal is processed
    /// @notice Proposal at block N sets nextProposalBlockId to N+1
    function calculateNextProposalBlockId(uint256 _proposalBlockNumber)
        internal
        pure
        returns (uint48)
    {
        return uint48(_proposalBlockNumber + 1);
    }

    /// @dev Get the expected nextProposalBlockId for a given proposal ID in tests
    /// @notice Assumes: genesis=2 to prevent blockhash(0) issue, first proposal at block >= 2
    function getExpectedNextProposalBlockId(
        uint48 _proposalId,
        uint256 _baseBlock
    )
        internal
        pure
        returns (uint48)
    {
        if (_proposalId == 0) {
            return 2; // Genesis value - prevents blockhash(0) issue
        } else if (_proposalId == 1) {
            return 2; // Before first proposal is made
        } else {
            // After proposal N-1, nextProposalBlockId = blockOfProposal(N-1) + 1
            // With 1-block gaps: proposal 1 at _baseBlock, proposal 2 at _baseBlock+1, etc.
            uint256 prevProposalBlock = _baseBlock + (_proposalId - 2);
            return uint48(prevProposalBlock + 1);
        }
    }

    /// @dev Calculate the block number when a proposal should be submitted
    /// @notice With 1-block gaps between proposals, first proposal must be at block >= 2
    function calculateProposalBlock(
        uint48 _proposalId,
        uint256 _baseBlock
    )
        internal
        pure
        returns (uint256)
    {
        if (_proposalId == 0) {
            return 0; // Genesis is at block 0
        } else if (_proposalId == 1) {
            // First proposal at base block (must be >= 2 to avoid blockhash(0))
            return _baseBlock >= 2 ? _baseBlock : 2;
        } else {
            // Subsequent proposals with 1-block gap from first proposal
            uint256 firstProposalBlock = _baseBlock >= 2 ? _baseBlock : 2;
            return firstProposalBlock + (_proposalId - 1);
        }
    }
}
