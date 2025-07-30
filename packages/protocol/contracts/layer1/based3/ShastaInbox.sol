// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

abstract contract ShastaInbox {
    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    /// @notice A batch represents oen or multiple layer 2 blocks
    struct Batch {
        address proposer;
        // This is the hash of the most recent layer 1 block, which represents the most recent layer
        // 1 state.
        bytes32 parentBlockHash;
        // For simplicity, we assume the proposal is only in a single blob and the blob is used by
        // this proposal excelucely.
        bytes32 batchDataHash;
    }

    /// @notice A claim represents what you try to prove.
    struct Claim {
        bytes32 batchHash;
        bytes32 parentClaimHash;
        uint256 lastBlockId;
        bytes32 lastBlockHash;
        bytes32 lastStateRoot;
        address proposer;
        address assignedProver;
        address actualProver;
        uint256 livenessBond;
    }

    struct ExtendedClaim {
        Claim claim;
        uint256 proposedAt;
        uint256 provedAt;
    }

    struct BondRefund {
        uint256 bondId;
        address prover;
        uint256 livenessBond;
    }

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event Proposed(uint256 batchId, Batch batch);
    event Proved(uint256 batchId, Batch batch, Claim claim);
    event Verified(uint256 batchId, Claim claim, BondRefund bondRefund);

    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------

    uint256 public nextBatchId;
    uint256 public lastVerifiedBatchId;
    bytes32 public lastVerifiedClaimHash;

    uint256 public lastBlockId;
    bytes32 public lastBlockHash;
    bytes32 public lastStateRoot;

    bytes32 public bondRefundAggregation;

    mapping(uint256 batchId => mapping(bytes32 parentClaimHash => bytes32 claimHash)) private
        _claims;
    mapping(uint256 batchId => bytes32 batchHash) private _batchHashes;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor() {
        nextBatchId = 1;
    }

    // -------------------------------------------------------------------------
    // ExternalFunctions
    // -------------------------------------------------------------------------

    function propose(uint256 blobId) external {
        uint256 batchId = nextBatchId++;
        Batch memory batch = Batch({
            proposer: msg.sender,
            parentBlockHash: blockhash(block.number - 1),
            batchDataHash: blobhash(blobId)
        });

        if (batch.batchDataHash == 0) revert InvalidBatchDataHash();

        saveBatchHash(batchId, keccak256(abi.encode(batch)));
        emit Proposed(batchId, batch);
    }

    /// @dev msg.sender value doesn't matter in this function.
    function prove(
        uint256 batchId,
        Batch memory batch,
        Claim memory claim,
        bytes calldata proof
    )
        external
    {
        if (claim.batchHash != loadBatchHash(batchId)) revert BatchHashMismatch();

        ExtendedClaim memory extendedClaim = ExtendedClaim(claim, batch.proposedAt, block.timestamp);
        bytes32 extendedClaimHash = keccak256(abi.encode(extendedClaim));
        saveClaimHash(batchId, claim.parentClaimHash, extendedClaimHash);
        emit Proved(batchId, batch, claim);

        // Verify the proof for the claim.
        bytes32 claimHash = keccak256(abi.encode(extendedClaim));
        verifyProof(claimHash, proof);
    }

    function verify(ExtendedClaim memory extendedClaim) external {
        if (extendedClaim.claim.parentClaimHash != lastVerifiedClaimHash) {
            revert InvalidParentClaimHash();
        }

        bytes32 extendedClaimHash = keccak256(abi.encode(extendedClaim));
        uint256 batchId = lastVerifiedBatchId + 1;

        require(
            loadClaimHash(batchId, lastVerifiedClaimHash) == extendedClaimHash, "Invalid claim hash"
        );

        lastVerifiedBatchId = batchId;
        lastVerifiedClaimHash = extendedClaimHash;

        lastBlockId = extendedClaim.claim.lastBlockId;
        lastBlockHash = extendedClaim.claim.lastBlockHash;
        lastStateRoot = extendedClaim.claim.lastStateRoot;

        // On layer 2, the assigned prover has paid the bond for this batch. Now we need to signal
        // the bond shall be returned to the assigned prover, otherwise, we should signal the bond
        // paid by the assigned prover slall be partially paid the the actual prover on layer 2)
        uint256 bondAmount;
        address bondReceiver;

        if (extendedClaim.provedAt < extendedClaim.proposedAt + 1 hours) {
            bondAmount = extendedClaim.claim.livenessBond;
            bondReceiver = extendedClaim.claim.assignedProver;
        } else {
            bondAmount = extendedClaim.claim.livenessBond / 2;
            bondReceiver = extendedClaim.claim.actualProver;
        }

        BondRefund memory bondRefund = BondRefund(batchId, bondReceiver, bondAmount);
        bondRefundAggregation = keccak256(abi.encode(bondRefundAggregation, bondRefund));

        emit Verified(batchId, extendedClaim.claim, bondRefund);
    }

    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    function saveBatchHash(uint256 batchId, bytes32 batchHash) internal virtual {
        _batchHashes[batchId] = batchHash;
    }

    function loadBatchHash(uint256 batchId) internal view virtual returns (bytes32) {
        return _batchHashes[batchId];
    }

    function saveClaimHash(
        uint256 batchId,
        bytes32 parentClaimHash,
        bytes32 claimHash
    )
        internal
        virtual
    {
        _claims[batchId][parentClaimHash] = claimHash;
    }

    function loadClaimHash(
        uint256 batchId,
        bytes32 parentClaimHash
    )
        internal
        view
        virtual
        returns (bytes32)
    {
        return _claims[batchId][parentClaimHash];
    }

    function debetBond(address from, uint256 amount) internal virtual;

    /// @dev Verifies a proof for one or multiple claims.
    ///      This funciton must revert if the proof is invalid.
    function verifyProof(bytes32 claimHash, bytes calldata proof) internal virtual;

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error BatchHashMismatch();
    error InvalidParentClaimHash();
    error InvalidBatchDataHash();
}
