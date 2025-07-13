// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/shared/based/ITaiko.sol";
import "src/layer1/verifiers/IVerifier.sol";
import "./libs/LibCodec.sol";
import "./libs/LibPropose.sol";
import "./libs/LibProve.sol";
import "./libs/LibVerify.sol";
import "./IInbox.sol";
import "./IPropose.sol";
import "./IProve.sol";

/// @title BaseInbox
/// @notice Acts as the inbox for the Taiko Alethia protocol, a simplified version of the
/// original Taiko-Based Contestable Rollup (BCR) but with the tier-based proof system and
/// contestation mechanisms removed.
///
/// Key assumptions of this protocol:
/// - Block proposals and proofs are asynchronous. Proofs are not available at proposal time,
///   unlike Taiko Gwyneth, which assumes synchronous composability.
/// - Proofs are presumed error-free and thoroughly validated, with subproofs/multiproofs management
/// delegated to IVerifier contracts.
///
/// @dev Registered in the address resolver as "taiko".
/// @custom:security-contact security@taiko.xyz
abstract contract BaseInbox is EssentialContract, IInbox, IPropose, IProve, ITaiko {
    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor() EssentialContract() { }

    // -------------------------------------------------------------------------
    // External Functions
    // -------------------------------------------------------------------------

    /// @notice Initializes the contract with owner and genesis block hash
    /// @param _owner The owner address
    /// @param _genesisBlockHash The genesis block hash
    /// @param _gasIssuancePerSecond The initial gas issuance per second
    function init4(
        address _owner,
        bytes32 _genesisBlockHash,
        uint32 _gasIssuancePerSecond
    )
        external
        initializer
    {
        _init(_owner, _genesisBlockHash, _gasIssuancePerSecond);
    }

    /// @notice Proposes and verifies batches
    /// @param _packedSummary The current summary, packed into bytes
    /// @param _packedBatches The batches to propose, packed into bytes
    /// @param _packedEvidence The batch proposal evidence, packed into bytes
    /// @param _packedTrans The packed transition metadata for verification
    /// @return The updated summary
    function propose4(
        bytes calldata _packedSummary,
        bytes calldata _packedBatches,
        bytes calldata _packedEvidence,
        bytes calldata _packedTrans
    )
        external
        override(I, IPropose)
        nonReentrant
        returns (I.Summary memory)
    {
        I.Summary memory summary = _validateSummary(_packedSummary);
        I.Batch[] memory batches = LibCodec.unpackBatches(_packedBatches);
        I.BatchProposeMetadataEvidence memory evidence =
            LibCodec.unpackBatchProposeMetadataEvidence(_packedEvidence);
        I.TransitionMeta[] memory trans = LibCodec.unpackTransitionMetas(_packedTrans);

        I.Config memory conf = _getConfig();
        LibState.ReadWrite memory rw = _getReadWrite();

        // Propose batches
        summary = LibPropose.propose(conf, rw, summary, batches, evidence);

        // Verify batches
        summary = LibVerify.verify(conf, rw, summary, trans);

        _saveSummaryHash(keccak256(abi.encode(summary)));
        return summary;
    }

    /// @notice Proves batches with cryptographic proof
    /// @param _packedSummary The current summary packed as bytes
    /// @param _packedBatchProveInputs The batch prove inputs
    /// @param _proof The cryptographic proof
    /// @return The updated summary
    function prove4(
        bytes calldata _packedSummary,
        bytes calldata _packedBatchProveInputs,
        bytes calldata _proof
    )
        external
        override(I, IProve)
        nonReentrant
        returns (I.Summary memory)
    {
        I.Summary memory summary = _validateSummary(_packedSummary);
        I.BatchProveInput[] memory inputs = LibCodec.unpackBatchProveInputs(_packedBatchProveInputs);

        I.Config memory conf = _getConfig();
        LibState.ReadWrite memory rw = _getReadWrite();

        // Prove batches and get aggregated hash
        bytes32 aggregatedBatchHash;
        (summary, aggregatedBatchHash) = LibProve.prove(conf, rw, summary, inputs);

        // Verify the proof
        IVerifier2(conf.verifier).verifyProof(aggregatedBatchHash, _proof);

        _saveSummaryHash(keccak256(abi.encode(summary)));
        return summary;
    }

    /// @notice Builds batch metadata from batch and batch context data
    /// @param _blockNumber The block number in which the batch is proposed
    /// @param _blockTimestamp The timestamp of the block in which the batch is proposed
    /// @param _batch The batch being proposed
    /// @param _context The batch context data containing computed values
    /// @return meta_ The populated batch metadata
    function buildBatchMetadata(
        uint48 _blockNumber,
        uint48 _blockTimestamp,
        I.Batch calldata _batch,
        I.BatchContext calldata _context
    )
        external
        pure
        returns (I.BatchMetadata memory meta_)
    {
        return LibData.buildBatchMetadata(_blockNumber, _blockTimestamp, _batch, _context);
    }

    /// @notice Checks if this contract is an inbox
    /// @return Always returns true
    function isInbox4() external pure returns (bool) {
        return true;
    }

    /// @notice Gets the current configuration
    /// @return The configuration struct
    function config4() external view virtual returns (Config memory) {
        return _getConfig();
    }

    // -------------------------------------------------------------------------
    // Internal Virtual Functions
    // -------------------------------------------------------------------------

    /// @notice Gets the configuration (must be implemented by derived contracts)
    /// @return The configuration struct
    function _getConfig() internal view virtual returns (Config memory);

    /// @notice Gets the blob hash for a block number
    /// @param _blockNumber The block number
    /// @return The blob hash
    function _getBlobHash(uint256 _blockNumber) internal view virtual returns (bytes32);

    /// @notice Checks if a signal has been sent
    /// @param _conf The configuration
    /// @param _signalSlot The signal slot
    /// @return Whether the signal was sent
    function _isSignalSent(
        I.Config memory _conf,
        bytes32 _signalSlot
    )
        internal
        view
        virtual
        returns (bool);

    /// @notice Syncs chain data to the signal service
    /// @param _conf The configuration
    /// @param _blockId The block ID
    /// @param _stateRoot The state root
    function _syncChainData(
        I.Config memory _conf,
        uint64 _blockId,
        bytes32 _stateRoot
    )
        internal
        virtual;

    /// @notice Debits bond from a user
    /// @param _conf The configuration
    /// @param _user The user address
    /// @param _amount The amount to debit
    function _debitBond(I.Config memory _conf, address _user, uint256 _amount) internal virtual;

    /// @notice Credits bond to a user
    /// @param _user The user address
    /// @param _amount The amount to credit
    function _creditBond(address _user, uint256 _amount) internal virtual;

    /// @notice Transfers fee tokens between addresses
    /// @param _feeToken The fee token address
    /// @param _from The sender address
    /// @param _to The recipient address
    /// @param _amount The amount to transfer
    function _transferFee(
        address _feeToken,
        address _from,
        address _to,
        uint256 _amount
    )
        internal
        virtual;

    function _loadSummaryHash() internal view virtual returns (bytes32);

    function _saveSummaryHash(bytes32 _summaryHash) internal virtual;

    function _loadBatchMetaHash(
        I.Config memory _conf,
        uint256 _batchId
    )
        internal
        view
        virtual
        returns (bytes32);

    function _saveTransition(
        I.Config memory _conf,
        uint48 _batchId,
        bytes32 _parentHash,
        bytes32 _tranMetahash
    )
        internal
        virtual
        returns (bool isFirstTransition_);

    function _saveBatchMetaHash(
        I.Config memory _conf,
        uint256 _batchId,
        bytes32 _metaHash
    )
        internal
        virtual;

    function _loadTransitionMetaHash(
        I.Config memory _conf,
        bytes32 _lastVerifiedBlockHash,
        uint256 _batchId
    )
        internal
        view
        virtual
        returns (bytes32 metaHash_, bool isFirstTransition_);

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @notice Initializes the Taiko contract
    /// @param _owner The owner address
    /// @param _genesisBlockHash The genesis block hash
    function _init(
        address _owner,
        bytes32 _genesisBlockHash,
        uint32 _gasIssuancePerSecond
    )
        private
        onlyInitializing
    {
        __Essential_init(_owner);
        require(_genesisBlockHash != 0, InvalidGenesisBlockHash());

        I.Config memory conf = _getConfig();

        // Initialize the genesis batch metadata
        I.BatchMetadata memory meta;
        meta.buildMeta.proposedIn = uint48(block.number);
        meta.proveMeta.proposedAt = uint48(block.timestamp);

        // Initialize the summary
        I.Summary memory summary;
        summary.lastBatchMetaHash = LibData.hashBatch(0, meta);
        summary.gasIssuancePerSecond = _gasIssuancePerSecond;
        summary.nextBatchId = 1;

        _saveBatchMetaHash(conf, 0, summary.lastBatchMetaHash);
        _saveSummaryHash(keccak256(abi.encode(summary)));

        emit I.Verified(0, _genesisBlockHash);
    }

    /// @notice Creates a ReadWrite struct with function pointers
    /// @return The ReadWrite struct with all required function pointers
    function _getReadWrite() private pure returns (LibState.ReadWrite memory) {
        return LibState.ReadWrite({
            // Read functions
            loadBatchMetaHash: _loadBatchMetaHash,
            isSignalSent: _isSignalSent,
            getBlobHash: _getBlobHash,
            loadTransitionMetaHash: _loadTransitionMetaHash,
            // Write functions
            saveTransition: _saveTransition,
            debitBond: _debitBond,
            creditBond: _creditBond,
            transferFee: _transferFee,
            syncChainData: _syncChainData,
            saveBatchMetaHash: _saveBatchMetaHash
        });
    }

    function _validateSummary(bytes calldata _packedSummary)
        private
        view
        returns (I.Summary memory summary_)
    {
        summary_ = LibCodec.unpackSummary(_packedSummary);
        require(_loadSummaryHash() == keccak256(abi.encode(summary_)), SummaryMismatch());
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    /// @notice Thrown when the provided summary doesn't match the stored summary hash
    error SummaryMismatch();
    error InvalidGenesisBlockHash();
}
