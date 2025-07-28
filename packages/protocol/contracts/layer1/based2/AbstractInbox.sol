// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/layer1/verifiers/IVerifier.sol";
import "./libs/LibBinding.sol";
import "./libs/LibPropose.sol";
import "./libs/LibProve.sol";
import "./libs/LibVerify.sol";
import "./IInbox.sol";
import "./IPropose.sol";
import "./IProve.sol";
import "src/layer1/preconf/iface/IPreconfWhitelist.sol";
import "src/layer1/forced-inclusion/IForcedInclusionStore.sol";

/// @title AbstractInbox
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
abstract contract AbstractInbox is EssentialContract, IInbox, IPropose, IProve {
    error NotPreconfer();

    IPreconfWhitelist public immutable whitelist;
    IForcedInclusionStore public immutable forcedStore;
    address public immutable fallbackPreconfer;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(
        IPreconfWhitelist _whitelist,
        IForcedInclusionStore _forcedStore,
        address _fallbackPreconfer
    )
        EssentialContract()
    {
        whitelist = _whitelist;
        forcedStore = _forcedStore;
        fallbackPreconfer = _fallbackPreconfer;
    }

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

    /// @inheritdoc IPropose
    function propose4(bytes calldata _inputs)
        external
        override(IInbox, IPropose)
        nonReentrant
        returns (Summary memory)
    {
        // Verify if the caller is an authorized preconfer
        address preconfer = whitelist.getOperatorForCurrentEpoch();
        if (preconfer != address(0)) {
            require(msg.sender == preconfer, NotPreconfer());
        } else if (fallbackPreconfer != address(0)) {
            require(msg.sender == fallbackPreconfer, NotPreconfer());
        } else {
            revert NotPreconfer();
        }

        LibBinding.Bindings memory bindings = _getBindings();

        (
            Summary memory summary,
            Batch[] memory batches,
            ProposeBatchEvidence memory evidence,
            TransitionMeta[] memory transitionMetas
        ) = bindings.decodeProposeBatchesInputs(_inputs);
        Config memory config = _getConfig();

        // Capture the starting batch ID before proposal
        uint48 nextBatchId = summary.nextBatchId;

        // Propose batches
        summary = LibPropose.propose(bindings, config, summary, batches, evidence);

        // It is ok to pass the `nextBatchId` here because we already validated it
        if (forcedStore.isOldestForcedInclusionDue(nextBatchId)) {
            // We process the oldest forced inclusion first and then revert if the validation fails
            // to avoid retrieving it first and then calling `consumeOldestForcedInclusion`
            IForcedInclusionStore.ForcedInclusion memory processed =
                forcedStore.consumeOldestForcedInclusion(msg.sender);

            _validateForcedInclusionBatch(batches[0], processed);
        }

        // Verify batches
        summary = LibVerify.verify(bindings, config, summary, transitionMetas);

        _saveSummaryHash(keccak256(abi.encode(summary)));
        emit SummaryUpdated(bindings.encodeSummary(summary));

        return summary;
    }

    /// @inheritdoc IProve
    /// @dev In previous versions, proving a block may also trigger block verification, in this
    /// upgrade, this is no longer the case as we would like to ensure more certainty for provers
    /// and let proposers to manage the uncertainty of verification cost.
    function prove4(
        bytes calldata _inputs,
        bytes calldata _proof
    )
        external
        override(IInbox, IProve)
        nonReentrant
    {
        LibBinding.Bindings memory bindings = _getBindings();
        ProveBatchInput[] memory inputs = bindings.decodeProveBatchesInputs(_inputs);
        Config memory config = _getConfig();

        // Prove batches and get aggregated hash
        bytes32 aggregatedBatchHash = LibProve.prove(bindings, config, inputs);

        // Verify the proof
        IVerifier2(config.verifier).verifyProof(aggregatedBatchHash, _proof);
    }

    /// @notice Builds batch metadata from batch and batch context data
    /// @param _proposedIn The block number in which the batch is proposed
    /// @param _proposedAt The timestamp of the block in which the batch is proposed
    /// @param _batch The batch being proposed
    /// @param _context The batch context data containing computed values
    /// @return meta_ The populated batch metadata
    function buildBatchMetadata(
        uint48 _proposedIn,
        uint48 _proposedAt,
        Batch calldata _batch,
        BatchContext calldata _context
    )
        external
        pure
        returns (BatchMetadata memory meta_)
    {
        return LibData.buildBatchMetadata(_proposedIn, _proposedAt, _batch, _context);
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

    /// @notice Gets the blob hash for a given blob index
    /// @param _blobIndex The blob index
    /// @return The blob hash
    function _getBlobHash(uint256 _blobIndex) internal view virtual returns (bytes32);

    /// @notice Gets the block hash for a block number
    /// @param _blockNumber The block number
    /// @return The block hash
    function _getBlockHash(uint256 _blockNumber) internal view virtual returns (bytes32);

    /// @notice Checks if a signal has been sent
    /// @param _conf The configuration
    /// @param _signalSlot The signal slot
    /// @return Whether the signal was sent
    function _isSignalSent(
        Config memory _conf,
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
        Config memory _conf,
        uint64 _blockId,
        bytes32 _stateRoot
    )
        internal
        virtual;

    /// @notice Debits bond from a user
    /// @param _conf The configuration
    /// @param _user The user address
    /// @param _amount The amount to debit
    function _debitBond(Config memory _conf, address _user, uint256 _amount) internal virtual;

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

    /// @notice Loads the summary hash from storage
    /// @return The current summary hash
    function _loadSummaryHash() internal view virtual returns (bytes32);

    /// @notice Saves the summary hash to storage
    /// @param _summaryHash The summary hash to save
    function _saveSummaryHash(bytes32 _summaryHash) internal virtual;

    /// @notice Loads a batch metadata hash from storage
    /// @param _conf The configuration
    /// @param _batchId The batch ID
    /// @return The batch metadata hash
    function _loadBatchMetaHash(
        Config memory _conf,
        uint256 _batchId
    )
        internal
        view
        virtual
        returns (bytes32);

    /// @notice Saves a transition to storage
    /// @param _conf The configuration
    /// @param _batchId The batch ID
    /// @param _parentHash The parent hash
    /// @param _tranMetahash The transition metadata hash
    /// @return isFirstTransition_ Whether this is the first transition for the batch
    function _saveTransition(
        Config memory _conf,
        uint48 _batchId,
        bytes32 _parentHash,
        bytes32 _tranMetahash
    )
        internal
        virtual
        returns (bool isFirstTransition_);

    /// @notice Saves a batch metadata hash to storage
    /// @param _conf The configuration
    /// @param _batchId The batch ID
    /// @param _metaHash The metadata hash to save
    function _saveBatchMetaHash(
        Config memory _conf,
        uint256 _batchId,
        bytes32 _metaHash
    )
        internal
        virtual;

    /// @notice Loads a transition metadata hash from storage
    /// @param _conf The configuration
    /// @param _lastVerifiedBlockHash The last verified block hash
    /// @param _batchId The batch ID
    /// @return metaHash_ The transition metadata hash
    /// @return isFirstTransition_ Whether this is the first transition for the batch
    function _loadTransitionMetaHash(
        Config memory _conf,
        bytes32 _lastVerifiedBlockHash,
        uint256 _batchId
    )
        internal
        view
        virtual
        returns (bytes32 metaHash_, bool isFirstTransition_);

    /// @notice Encodes a batch context
    /// @param _context The batch context to encode
    /// @return The encoded batch context
    function _encodeBatchContext(BatchContext memory _context)
        internal
        pure
        virtual
        returns (bytes memory)
    {
        return abi.encode(_context);
    }

    /// @notice Encodes transition metas
    /// @param _transitionMetas The transition metas to encode
    /// @return The encoded transition metas
    function _encodeTransitionMetas(TransitionMeta[] memory _transitionMetas)
        internal
        pure
        virtual
        returns (bytes memory)
    {
        return abi.encode(_transitionMetas);
    }

    function _encodeSummary(Summary memory _summary) internal pure virtual returns (bytes memory) {
        return abi.encode(_summary);
    }

    /// @notice Decodes the propose inputs
    /// @param _data The inputs to decode
    /// @return The decoded inputs (summary, batches, evidence, transitionMetas)
    function _decodeProposeBatchesInputs(bytes memory _data)
        internal
        pure
        virtual
        returns (
            Summary memory,
            Batch[] memory,
            ProposeBatchEvidence memory,
            TransitionMeta[] memory
        )
    {
        return abi.decode(_data, (Summary, Batch[], ProposeBatchEvidence, TransitionMeta[]));
    }

    function _decodeProverAuth(bytes memory _data)
        internal
        pure
        virtual
        returns (ProverAuth memory)
    {
        return abi.decode(_data, (ProverAuth));
    }

    function _decodeSummary(bytes memory _data) internal pure virtual returns (Summary memory) {
        return abi.decode(_data, (Summary));
    }

    function _decodeProveBatchesInputs(bytes memory _data)
        internal
        pure
        virtual
        returns (ProveBatchInput[] memory)
    {
        return abi.decode(_data, (ProveBatchInput[]));
    }

    /// @notice Decodes a batch context
    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @notice Initializes the Taiko contract
    /// @param _owner The owner address
    /// @param _genesisBlockHash The genesis block hash
    /// @param _gasIssuancePerSecond The initial gas issuance per second
    function _init(
        address _owner,
        bytes32 _genesisBlockHash,
        uint32 _gasIssuancePerSecond
    )
        private
        onlyInitializing
    {
        __Essential_init(_owner);

        Config memory config = _getConfig();

        // Initialize the genesis batch metadata
        BatchMetadata memory meta;
        meta.buildMeta.proposedIn = uint48(block.number);
        meta.proveMeta.proposedAt = uint48(block.timestamp);

        // Initialize the summary
        Summary memory summary;
        summary.lastBatchMetaHash = LibData.hashBatch(0, meta);
        summary.gasIssuancePerSecond = _gasIssuancePerSecond;
        summary.nextBatchId = 1;

        _saveBatchMetaHash(config, 0, summary.lastBatchMetaHash);
        _saveSummaryHash(keccak256(abi.encode(summary)));

        emit Verified(0, 0, _genesisBlockHash);
    }

    /// @notice Creates a Bindings struct with function pointers
    /// @return The Bindings struct with all required function pointers
    function _getBindings() private pure returns (LibBinding.Bindings memory) {
        return LibBinding.Bindings({
            // Read functions
            loadBatchMetaHash: _loadBatchMetaHash,
            isSignalSent: _isSignalSent,
            getBlobHash: _getBlobHash,
            getBlockHash: _getBlockHash,
            loadTransitionMetaHash: _loadTransitionMetaHash,
            // Write functions
            saveTransition: _saveTransition,
            debitBond: _debitBond,
            creditBond: _creditBond,
            transferFee: _transferFee,
            syncChainData: _syncChainData,
            saveBatchMetaHash: _saveBatchMetaHash,
            // Encoding functions
            encodeBatchContext: _encodeBatchContext,
            encodeTransitionMetas: _encodeTransitionMetas,
            encodeSummary: _encodeSummary,
            // Decoding functions
            decodeProposeBatchesInputs: _decodeProposeBatchesInputs,
            decodeProverAuth: _decodeProverAuth,
            decodeSummary: _decodeSummary,
            decodeProveBatchesInputs: _decodeProveBatchesInputs
        });
    }

    function _validateSummary(bytes memory _summaryEncoded)
        private
        view
        returns (Summary memory summary_)
    {
        summary_ = _decodeSummary(_summaryEncoded);
        if (_loadSummaryHash() != keccak256(abi.encode(summary_))) revert SummaryMismatch();
    }

    /// @dev Validates a forced inclusion batch follows all required rules
    /// @param _batch The batch to validate as forced inclusion
    function _validateForcedInclusionBatch(
        I.Batch memory _batch,
        IForcedInclusionStore.ForcedInclusion memory _inclusion
    )
        private
        pure
    {
        // Batch validation
        require(_batch.isForcedInclusion, IForcedInclusionStore.InvalidForcedInclusion());
        require(_batch.blocks.length == 1, IForcedInclusionStore.InvalidForcedInclusion());
        require(_batch.blobs.hashes.length == 1, IForcedInclusionStore.InvalidForcedInclusion());
        require(_batch.gasIssuancePerSecond == 0, IForcedInclusionStore.InvalidForcedInclusion());

        // Block validation
        require(
            _batch.blocks[0].numTransactions == type(uint16).max,
            IForcedInclusionStore.InvalidForcedInclusion()
        );
        require(_batch.blocks[0].timeShift == 0, IForcedInclusionStore.InvalidForcedInclusion());
        require(_batch.blocks[0].anchorBlockId == 0, IForcedInclusionStore.InvalidForcedInclusion());
        require(
            _batch.blocks[0].signalSlots.length == 0, IForcedInclusionStore.InvalidForcedInclusion()
        );

        // Blob validation
        require(
            _batch.blobs.hashes[0] == _inclusion.blobHash,
            IForcedInclusionStore.InvalidForcedInclusion()
        );
        require(
            _batch.blobs.byteOffset == _inclusion.blobByteOffset,
            IForcedInclusionStore.InvalidForcedInclusion()
        );
        require(
            _batch.blobs.byteSize == _inclusion.blobByteSize,
            IForcedInclusionStore.InvalidForcedInclusion()
        );
        require(
            _batch.blobs.createdIn == _inclusion.blobCreatedIn,
            IForcedInclusionStore.InvalidForcedInclusion()
        );
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error SummaryMismatch();
}
