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
        IInbox.Claim[] claims;
        IInbox.ClaimRecord[] claimRecords;
        bytes32 currentParentHash;
        uint48 nextProposalId;
        uint48 lastFinalizedId;
    }

    /// @dev Chain of proposals and claims for testing
    struct ProposalChain {
        IInbox.Proposal[] proposals;
        IInbox.Claim[] claims;
        bytes32 initialParentHash;
        bytes32 finalClaimHash;
    }

    // ---------------------------------------------------------------
    // Core State Management
    // ---------------------------------------------------------------

    /// @dev Creates a basic core state
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
            lastFinalizedProposalId: _lastFinalizedProposalId,
            lastFinalizedClaimHash: bytes32(0),
            bondInstructionsHash: bytes32(0)
        });
    }

    /// @dev Creates a complete core state with all fields
    function createCoreState(
        uint48 _nextProposalId,
        uint48 _lastFinalizedProposalId,
        bytes32 _lastFinalizedClaimHash,
        bytes32 _bondInstructionsHash
    )
        internal
        pure
        returns (IInbox.CoreState memory)
    {
        return IInbox.CoreState({
            nextProposalId: _nextProposalId,
            lastFinalizedProposalId: _lastFinalizedProposalId,
            lastFinalizedClaimHash: _lastFinalizedClaimHash,
            bondInstructionsHash: _bondInstructionsHash
        });
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
        returns (IInbox.Proposal memory)
    {
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encode("blob", uint256(_id % 256)));

        return IInbox.Proposal({
            id: _id,
            proposer: _proposer,
            originTimestamp: uint48(block.timestamp),
            originBlockNumber: uint48(block.number),
            isForcedInclusion: false,
            basefeeSharingPctg: _basefeeSharingPctg,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 0,
                timestamp: uint48(block.timestamp)
            })
        });
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
        returns (IInbox.Proposal memory)
    {
        return IInbox.Proposal({
            id: _id,
            proposer: _proposer,
            originTimestamp: uint48(block.timestamp),
            originBlockNumber: uint48(block.number),
            isForcedInclusion: false,
            basefeeSharingPctg: _basefeeSharingPctg,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: _blobHashes,
                offset: 0,
                timestamp: uint48(block.timestamp)
            })
        });
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
            proposals[i] = createProposal(_startId + i, _proposer, _basefeeSharingPctg);
        }
    }

    // ---------------------------------------------------------------
    // Claim Creation
    // ---------------------------------------------------------------

    /// @dev Creates a standard claim
    function createClaim(
        IInbox.Proposal memory _proposal,
        bytes32 _parentClaimHash,
        address _actualProver
    )
        internal
        pure
        returns (IInbox.Claim memory)
    {
        return IInbox.Claim({
            proposalHash: hashProposal(_proposal),
            parentClaimHash: _parentClaimHash,
            endBlockNumber: _proposal.id * 100,
            endBlockHash: keccak256(abi.encode(_proposal.id, "endBlockHash")),
            endStateRoot: keccak256(abi.encode(_proposal.id, "stateRoot")),
            designatedProver: _proposal.proposer,
            actualProver: _actualProver
        });
    }

    /// @dev Creates a claim with custom block data
    function createClaimWithBlock(
        bytes32 _proposalHash,
        bytes32 _parentClaimHash,
        uint48 _endBlockNumber,
        bytes32 _endBlockHash,
        bytes32 _endStateRoot,
        address _designatedProver,
        address _actualProver
    )
        internal
        pure
        returns (IInbox.Claim memory)
    {
        return IInbox.Claim({
            proposalHash: _proposalHash,
            parentClaimHash: _parentClaimHash,
            endBlockNumber: _endBlockNumber,
            endBlockHash: _endBlockHash,
            endStateRoot: _endStateRoot,
            designatedProver: _designatedProver,
            actualProver: _actualProver
        });
    }

    /// @dev Creates a chain of claims with proper parent hashing
    function createClaimChain(
        IInbox.Proposal[] memory _proposals,
        bytes32 _initialParentHash,
        address _prover
    )
        internal
        pure
        returns (IInbox.Claim[] memory claims)
    {
        claims = new IInbox.Claim[](_proposals.length);
        bytes32 parentHash = _initialParentHash;

        for (uint256 i = 0; i < _proposals.length; i++) {
            claims[i] = createClaim(_proposals[i], parentHash, _prover);
            parentHash = hashClaim(claims[i]);
        }
    }

    // ---------------------------------------------------------------
    // ClaimRecord Creation
    // ---------------------------------------------------------------

    /// @dev Creates a claim record without bond instructions
    function createClaimRecord(
        IInbox.Claim memory _claim,
        uint8 _span
    )
        internal
        pure
        returns (IInbox.ClaimRecord memory)
    {
        return IInbox.ClaimRecord({
            claim: _claim,
            span: _span,
            bondInstructions: new LibBonds.BondInstruction[](0)
        });
    }

    /// @dev Creates a claim record with bond instructions
    function createClaimRecordWithBonds(
        IInbox.Claim memory _claim,
        uint8 _span,
        LibBonds.BondInstruction[] memory _bondInstructions
    )
        internal
        pure
        returns (IInbox.ClaimRecord memory)
    {
        return
            IInbox.ClaimRecord({ claim: _claim, span: _span, bondInstructions: _bondInstructions });
    }

    /// @dev Creates multiple claim records in batch
    function createClaimRecordBatch(
        IInbox.Claim[] memory _claims,
        uint8 _span
    )
        internal
        pure
        returns (IInbox.ClaimRecord[] memory records)
    {
        records = new IInbox.ClaimRecord[](_claims.length);
        for (uint256 i = 0; i < _claims.length; i++) {
            records[i] = createClaimRecord(_claims[i], _span);
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
    // Data Encoding
    // ---------------------------------------------------------------

    /// @dev Encodes proposal data with default deadline
    function encodeProposalData(
        IInbox.CoreState memory _coreState,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.ClaimRecord[] memory _claimRecords
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(uint64(0), _coreState, _blobRef, _claimRecords);
    }

    /// @dev Encodes proposal data with custom deadline
    function encodeProposalData(
        uint64 _deadline,
        IInbox.CoreState memory _coreState,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.ClaimRecord[] memory _claimRecords
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(_deadline, _coreState, _blobRef, _claimRecords);
    }

    /// @dev Encodes prove data
    function encodeProveData(
        IInbox.Proposal[] memory _proposals,
        IInbox.Claim[] memory _claims
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(_proposals, _claims);
    }

    // ---------------------------------------------------------------
    // Hashing Functions
    // ---------------------------------------------------------------

    /// @dev Computes proposal hash
    function hashProposal(IInbox.Proposal memory _proposal) internal pure returns (bytes32) {
        return keccak256(abi.encode(_proposal));
    }

    /// @dev Computes claim hash
    function hashClaim(IInbox.Claim memory _claim) internal pure returns (bytes32) {
        return keccak256(abi.encode(_claim));
    }

    /// @dev Computes claim record hash
    function hashClaimRecord(IInbox.ClaimRecord memory _record) internal pure returns (bytes32) {
        return keccak256(abi.encode(_record));
    }

    /// @dev Computes core state hash
    function hashCoreState(IInbox.CoreState memory _state) internal pure returns (bytes32) {
        return keccak256(abi.encode(_state));
    }

    // ---------------------------------------------------------------
    // Blob Hash Generation
    // ---------------------------------------------------------------

    /// @dev Generates standard blob hashes for testing
    function generateBlobHashes(uint256 _count) internal pure returns (bytes32[] memory hashes) {
        hashes = new bytes32[](_count);
        for (uint256 i = 0; i < _count; i++) {
            hashes[i] = keccak256(abi.encode("blob", i));
        }
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

    // ---------------------------------------------------------------
    // Chain Building Functions
    // ---------------------------------------------------------------

    /// @dev Creates a complete proposal chain with claims
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
        chain.claims = createClaimChain(chain.proposals, _initialParentHash, _prover);
        chain.initialParentHash = _initialParentHash;

        if (_count > 0) {
            chain.finalClaimHash = hashClaim(chain.claims[_count - 1]);
        } else {
            chain.finalClaimHash = _initialParentHash;
        }
    }

    /// @dev Creates a genesis claim
    function createGenesisClaim(bytes32 _genesisBlockHash)
        internal
        pure
        returns (IInbox.Claim memory)
    {
        return IInbox.Claim({
            proposalHash: bytes32(0),
            parentClaimHash: bytes32(0),
            endBlockNumber: 0,
            endBlockHash: _genesisBlockHash,
            endStateRoot: bytes32(0),
            designatedProver: address(0),
            actualProver: address(0)
        });
    }

    /// @dev Gets the genesis claim hash
    function getGenesisClaimHash(bytes32 _genesisBlockHash) internal pure returns (bytes32) {
        return hashClaim(createGenesisClaim(_genesisBlockHash));
    }

    // ---------------------------------------------------------------
    // Test Context Management
    // ---------------------------------------------------------------

    /// @dev Creates a new test context
    function createContext(
        uint48 _nextProposalId,
        uint48 _lastFinalizedId,
        bytes32 _parentHash
    )
        internal
        pure
        returns (TestContext memory ctx)
    {
        ctx.coreState = createCoreState(_nextProposalId, _lastFinalizedId, _parentHash, bytes32(0));
        ctx.proposals = new IInbox.Proposal[](0);
        ctx.claims = new IInbox.Claim[](0);
        ctx.claimRecords = new IInbox.ClaimRecord[](0);
        ctx.currentParentHash = _parentHash;
        ctx.nextProposalId = _nextProposalId;
        ctx.lastFinalizedId = _lastFinalizedId;
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

    /// @dev Adds a claim to the context
    function addClaim(
        TestContext memory _ctx,
        IInbox.Claim memory _claim
    )
        internal
        pure
        returns (TestContext memory)
    {
        IInbox.Claim[] memory newClaims = new IInbox.Claim[](_ctx.claims.length + 1);
        for (uint256 i = 0; i < _ctx.claims.length; i++) {
            newClaims[i] = _ctx.claims[i];
        }
        newClaims[_ctx.claims.length] = _claim;
        _ctx.claims = newClaims;
        _ctx.currentParentHash = hashClaim(_claim);
        return _ctx;
    }
}
