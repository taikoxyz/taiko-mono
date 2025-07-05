// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/based/ITaiko.sol";
import "src/shared/signal/ISignalService.sol";
import "src/shared/signal/LibSignals.sol";
import "src/layer1/verifiers/IVerifier.sol";

import "./libs/LibBatchProposal.sol";
import "./libs/LibBatchProving.sol";
import "./libs/LibBatchVerification.sol";
import "./ITaikoInbox2.sol";
import "./IProposeBatch2.sol";

/// @title TaikoInboxBase
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
abstract contract TaikoInboxBase is EssentialContract, ITaikoInbox2, IProposeBatch2, ITaiko {
    constructor() EssentialContract() { }

    /// @notice Initializes the contract with owner and genesis block hash
    /// @param _owner The owner address
    /// @param _genesisBlockHash The genesis block hash
    function v4Init(address _owner, bytes32 _genesisBlockHash) external initializer {
        __Taiko_init(_owner, _genesisBlockHash);
    }

    /// @notice Proposes and verifies batches
    /// @param _summary The current summary
    /// @param _batch The batches to propose
    /// @param _evidence The batch proposal evidence
    /// @param _trans The transition metadata for verification
    /// @return The updated summary
    function v4ProposeBatches(
        I.Summary memory _summary,
        I.Batch[] memory _batch,
        I.BatchProposeMetadataEvidence memory _evidence,
        I.TransitionMeta[] calldata _trans
    )
        public
        // override(ITaikoInbox2, IProposeBatch2)
        nonReentrant
        returns (I.Summary memory)
    {
        require(_loadSummaryHash() == keccak256(abi.encode(_summary)), SummaryMismatch());

        I.Config memory conf = _getConfig();
        LibDataUtils.ReadWrite memory rw = _getReadWrite();

        // Propose batches
        _summary = LibBatchProposal.proposeBatches(conf, rw, _summary, _batch, _evidence);

        // Verify batches
        _summary = LibBatchVerification.verifyBatches(conf, rw, _summary, _trans);

        _saveSummaryHash(keccak256(abi.encode(_summary)));
        return _summary;
    }

    /// @notice Proves batches with cryptographic proof
    /// @param _summary The current summary
    /// @param _inputs The batch prove inputs
    /// @param _proof The cryptographic proof
    /// @return The updated summary
    function v4ProveBatches(
        I.Summary memory _summary,
        I.BatchProveInput[] calldata _inputs,
        bytes calldata _proof
    )
        external
        nonReentrant
        returns (I.Summary memory)
    {
        require(_loadSummaryHash() == keccak256(abi.encode(_summary)), SummaryMismatch());

        I.Config memory conf = _getConfig();
        LibDataUtils.ReadWrite memory rw = _getReadWrite();

        // Prove batches and get aggregated hash
        bytes32 aggregatedBatchHash;
        (_summary, aggregatedBatchHash) = LibBatchProving.proveBatches(conf, rw, _summary, _inputs);

        // Verify the proof
        IVerifier2(conf.verifier).verifyProof(aggregatedBatchHash, _proof);

        _saveSummaryHash(keccak256(abi.encode(_summary)));
        return _summary;
    }

    /// @notice Checks if this contract is an inbox
    /// @return Always returns true
    function v4IsInbox() external pure override returns (bool) {
        return true;
    }

    /// @notice Gets the current configuration
    /// @return The configuration struct
    function v4GetConfig() external view virtual returns (Config memory) {
        return _getConfig();
    }

    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Initializes the Taiko contract
    /// @param _owner The owner address
    /// @param _genesisBlockHash The genesis block hash
    function __Taiko_init(address _owner, bytes32 _genesisBlockHash) internal onlyInitializing {
        __Essential_init(_owner);
        require(_genesisBlockHash != 0, InvalidGenesisBlockHash());

        I.Config memory conf = _getConfig();

        // Initialize the genesis batch metadata
        I.BatchMetadata memory meta;
        meta.buildMeta.proposedIn = uint48(block.number);
        meta.proveMeta.proposedAt = uint48(block.timestamp);
        _saveBatchMetaHash(conf, 0, LibDataUtils.hashBatch(0, meta));

        // Initialize the summary
        I.Summary memory summary;
        summary.numBatches = 1;
        _saveSummaryHash(keccak256(abi.encode(summary)));

        emit I.BatchesVerified(0, _genesisBlockHash);
    }

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

    /// @notice Creates a ReadWrite struct with function pointers
    /// @return The ReadWrite struct with all required function pointers
    function _getReadWrite() private pure returns (LibDataUtils.ReadWrite memory) {
        return LibDataUtils.ReadWrite({
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

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    /// @notice Thrown when the provided summary doesn't match the stored summary hash
    error SummaryMismatch();
    error InvalidGenesisBlockHash();
}
