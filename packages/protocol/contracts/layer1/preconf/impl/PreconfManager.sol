// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/layer1/based2/IInbox.sol";
import "src/layer1/based2/libs/LibCodec.sol";
import "src/layer1/based2/libs/LibData.sol";
import "../iface/IPreconfWhitelist.sol";
import "../../forced-inclusion/IForcedInclusionStore.sol";

/// @title PreconfManager
/// @notice Unified gateway for Shasta inbox combining preconf access control and forced inclusions
/// @dev Replaces PreconfRouter and TaikoWrapper with a single optimized contract
/// @custom:security-contact security@taiko.xyz
contract PreconfManager is EssentialContract {
    /// @notice The Shasta inbox contract
    IInbox public immutable inbox;

    /// @notice The preconf whitelist contract
    IPreconfWhitelist public immutable whitelist;

    /// @notice The forced inclusion store contract
    IForcedInclusionStore public immutable forcedStore;

    /// @notice Fallback preconfer address when no operator is selected
    address public immutable fallbackPreconfer;

    /// @notice Emitted when a forced inclusion is processed
    /// @param inclusion The forced inclusion that was processed
    event ForcedInclusionProcessed(IForcedInclusionStore.ForcedInclusion inclusion);


    error NotPreconfer();
    error ProposerMismatch();
    error InvalidBatch();
    error InvalidForcedInclusion();

    uint256[50] private __gap;

    constructor(
        address _inbox,
        address _whitelist,
        address _forcedStore,
        address _fallbackPreconfer
    )
        nonZeroAddr(_inbox)
        nonZeroAddr(_whitelist)
        nonZeroAddr(_forcedStore)
        EssentialContract()
    {
        inbox = IInbox(_inbox);
        whitelist = IPreconfWhitelist(_whitelist);
        forcedStore = IForcedInclusionStore(_forcedStore);
        fallbackPreconfer = _fallbackPreconfer;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @notice Proposes a batch to the Shasta inbox
    /// @dev Handles both normal proposals and forced inclusions atomically
    /// @param _batch The batch to propose
    /// @param _txList The transaction list for calldata (empty for blob batches)
    /// @param _parentMetadata The parent batch metadata for continuity validation
    /// @return summary The updated protocol summary after processing
    function propose(
        IInbox.Batch calldata _batch,
        bytes calldata _txList,
        IInbox.BatchProposeMetadata calldata _parentMetadata
    )
        external
        nonReentrant
        returns (IInbox.Summary memory summary)
    {
        address preconfer = whitelist.getOperatorForCurrentEpoch();
        if (preconfer != address(0)) {
            require(msg.sender == preconfer, NotPreconfer());
        } else if (fallbackPreconfer != address(0)) {
            require(msg.sender == fallbackPreconfer, NotPreconfer());
        }

        // Verify proposer matches sender
        require(_batch.proposer == msg.sender, ProposerMismatch());

        //TODO: we should pass this as a parameter
        IInbox.Summary memory currentSummary = _getCurrentSummary();

        // Check if forced inclusion is due and prepare batches
        IInbox.Batch[] memory batches;
        bool processingForcedInclusion = forcedStore.isOldestForcedInclusionDue();

        if (processingForcedInclusion) {
            // Build array with forced inclusion batch first, then normal batch
            //TODO: should the forced inclusion batch be the first one?
            batches = new IInbox.Batch[](2);
            batches[0] = _buildForcedInclusionBatch(_parentMetadata);
            batches[1] = _batch;
        } else {
            // Single batch proposal
            batches = new IInbox.Batch[](1);
            batches[0] = _batch;
        }

        // Prepare evidence for parent batch validation
        bytes memory evidence = _buildParentEvidence(currentSummary, _parentMetadata);

        // Pack data using Shasta's format
        bytes memory packedSummary = LibCodec.packSummary(currentSummary);
        bytes memory packedBatches = _packBatches(batches, _txList);
        bytes memory packedTransitionMetas = ""; // Empty for new proposals

        summary = inbox.propose4(packedSummary, packedBatches, evidence, packedTransitionMetas);


        return summary;
    }

    /// @notice Builds a forced inclusion batch from the oldest pending request
    /// @param _parentMetadata Parent batch metadata for timestamp calculation
    /// @return batch The forced inclusion batch
    function _buildForcedInclusionBatch(IInbox.BatchProposeMetadata memory _parentMetadata)
        internal
        returns (IInbox.Batch memory batch)
    {
        // Consume the oldest forced inclusion
        IForcedInclusionStore.ForcedInclusion memory inclusion =
            forcedStore.consumeOldestForcedInclusion(msg.sender);

        // Validate forced inclusion
        require(inclusion.blobHash != bytes32(0), InvalidForcedInclusion());

        // Build batch structure optimized for forced inclusions
        batch.proposer = msg.sender;
        batch.coinbase = address(0); // No coinbase for forced inclusions
        batch.lastBlockTimestamp = _parentMetadata.lastBlockTimestamp + 12; // Fixed 12 second
            // interval
        batch.gasIssuancePerSecond = 0; // Use protocol default
        batch.isForcedInclusion = true;
        batch.proverAuth = ""; // Open to any prover

        // No signal slots or anchor blocks for forced inclusions
        batch.signalSlots = new bytes32[](0);
        batch.anchorBlockIds = new uint48[](0);

        // Single block with maximum transactions allowed
        batch.blocks = new IInbox.Block[](1);
        batch.blocks[0] = IInbox.Block({
            numTransactions: type(uint16).max, // Allow maximum transactions
            timeShift: 0, // First block in batch has no time shift
            anchorBlockId: 0, // No anchor for forced inclusions
            numSignals: 0, // No signals
            hasAnchor: false
        });

        // Set blob data from the forced inclusion
        batch.blobs = IInbox.Blobs({
            hashes: new bytes32[](1),
            firstBlobIndex: 0,
            numBlobs: 0, // Using direct hash, not index
            byteOffset: inclusion.blobByteOffset,
            byteSize: inclusion.blobByteSize,
            createdIn: uint48(inclusion.blobCreatedIn)
        });
        batch.blobs.hashes[0] = inclusion.blobHash;

        emit ForcedInclusionProcessed(inclusion);
    }

    /// @notice Builds evidence for parent batch validation
    /// @param _parentMetadata Parent batch metadata
    /// @return evidence The encoded evidence
    function _buildParentEvidence(
        IInbox.Summary memory, // _summary - unused for now
        IInbox.BatchProposeMetadata memory _parentMetadata
    )
        internal
        pure
        returns (bytes memory evidence)
    {
        // Build evidence using the parent metadata
        // In a real implementation, leftHash and proveMetaHash would be computed
        // from the actual parent batch data
        IInbox.BatchProposeMetadataEvidence memory parentEvidence = IInbox
            .BatchProposeMetadataEvidence({
            leftHash: bytes32(0), // Would be computed from parent batch build metadata
            proveMetaHash: bytes32(0), // Would be computed from parent batch prove metadata
            proposeMeta: _parentMetadata
        });

        return LibCodec.packBatchProposeMetadataEvidence(parentEvidence);
    }

    /// @notice Packs batches and transaction data
    /// @param _batches Array of batches to pack
    /// @param _txList Transaction list for the last batch
    /// @return encoded The packed batch data
    function _packBatches(
        IInbox.Batch[] memory _batches,
        bytes calldata _txList
    )
        internal
        pure
        returns (bytes memory encoded)
    {
        // Pack all batches first
        bytes memory packedBatches = LibCodec.packBatches(_batches);

        // For Shasta, txList is appended separately after packed batches
        if (_txList.length > 0) {
            // Append txList to the packed batches
            encoded = abi.encodePacked(packedBatches, _txList);
        } else {
            encoded = packedBatches;
        }
    }

    /// @notice Gets the current protocol summary
    /// @dev Temporary implementation until inbox provides view function
    function _getCurrentSummary() internal pure returns (IInbox.Summary memory) {
        // This would ideally call a view function on the inbox
        // For now, return a minimal summary structure
        return IInbox.Summary({
            nextBatchId: 1, // Would come from inbox
            lastSyncedBlockId: 0,
            lastSyncedAt: 0,
            lastVerifiedBatchId: 0,
            gasIssuanceUpdatedAt: 0,
            gasIssuancePerSecond: 0,
            lastVerifiedBlockHash: bytes32(0),
            lastBatchMetaHash: bytes32(0)
        });
    }
}
