// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/layer1/based2/IInbox.sol";
import "src/layer1/based2/libs/LibCodec.sol";
import "../iface/IPreconfWhitelist.sol";
import "../../forced-inclusion/IForcedInclusionStore.sol";

/// @title PreconfManager
/// @notice Gateway for Shasta inbox with preconf access control and forced inclusion handling
/// @dev Optimized to minimize gas costs while maintaining simplicity
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

    /// @notice Proposes batches to the Shasta inbox with preconf validation and forced inclusion handling
    /// @dev Mirrors propose4 interface exactly to minimize overhead
    /// @param _packedSummary Current protocol summary encoded as bytes
    /// @param _packedBatches Array of batches to propose encoded as bytes
    /// @param _packedEvidence Evidence for batch proposal validation encoded as bytes
    /// @param _packedTransitionMetas Transition metadata for verification encoded as bytes
    /// @return summary The updated protocol summary after processing
    function propose(
        bytes calldata _packedSummary,
        bytes calldata _packedBatches,
        bytes calldata _packedEvidence,
        bytes calldata _packedTransitionMetas
    )
        external
        nonReentrant
        returns (IInbox.Summary memory summary)
    {
        // Verify preconf authorization
        address preconfer = whitelist.getOperatorForCurrentEpoch();
        if (preconfer != address(0)) {
            require(msg.sender == preconfer, NotPreconfer());
        } else if (fallbackPreconfer != address(0)) {
            require(msg.sender == fallbackPreconfer, NotPreconfer());
        }

        if (!forcedStore.isOldestForcedInclusionDue()) {
            // optimize for most common case where there is no forced inclusion
            return inbox.propose4(
                _packedSummary,
                _packedBatches,
                _packedEvidence,
                _packedTransitionMetas
            );
        }

        // Forced inclusion case - build and prepend the forced inclusion batch
        return _proposeWithForcedInclusion(
            _packedSummary,
            _packedBatches,
            _packedEvidence,
            _packedTransitionMetas
        );
    }

    /// @notice Builds a forced inclusion batch from the oldest pending request
    /// @param _proposer The address proposing the batch
    /// @param _parentTimestamp The timestamp of the parent batch
    /// @return batch The forced inclusion batch
    function _buildForcedInclusionBatch(
        address _proposer,
        uint48 _parentTimestamp
    )
        internal
        returns (IInbox.Batch memory batch)
    {
        // Consume the oldest forced inclusion
        IForcedInclusionStore.ForcedInclusion memory inclusion =
            forcedStore.consumeOldestForcedInclusion(_proposer);

        // Validate forced inclusion
        require(inclusion.blobHash != bytes32(0), InvalidForcedInclusion());

        // Build minimal batch structure for forced inclusion
        batch.proposer = _proposer;
        batch.coinbase = address(0); // No coinbase for forced inclusions
        batch.lastBlockTimestamp = _parentTimestamp + 12; // Fixed 12 second interval
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
            numBlobs: 1, // Single blob
            byteOffset: inclusion.blobByteOffset,
            byteSize: inclusion.blobByteSize,
            createdIn: uint48(inclusion.blobCreatedIn)
        });
        batch.blobs.hashes[0] = inclusion.blobHash;

        emit ForcedInclusionProcessed(inclusion);
    }

    /// @notice Internal function to handle proposals with forced inclusions
    /// @dev Separated to avoid stack too deep errors
    function _proposeWithForcedInclusion(
        bytes calldata _packedSummary,
        bytes calldata _packedBatches,
        bytes calldata _packedEvidence,
        bytes calldata _packedTransitionMetas
    )
        internal
        returns (IInbox.Summary memory)
    {
        // Extract parent timestamp from evidence for proper timestamp calculation
        IInbox.BatchProposeMetadataEvidence memory evidence = 
            LibCodec.unpackBatchProposeMetadataEvidence(_packedEvidence);
        
        // Build the forced inclusion batch
        IInbox.Batch memory forcedBatch = _buildForcedInclusionBatch(
            msg.sender,
            evidence.proposeMeta.lastBlockTimestamp
        );
        
        // Unpack original batches
        IInbox.Batch[] memory originalBatches = LibCodec.unpackBatches(_packedBatches);
        
        // Create array with forced inclusion first
        IInbox.Batch[] memory allBatches = new IInbox.Batch[](originalBatches.length + 1);
        allBatches[0] = forcedBatch;
        for (uint256 i = 0; i < originalBatches.length; i++) {
            allBatches[i + 1] = originalBatches[i];
        }
        
        // Pack all batches
        bytes memory finalPackedBatches = LibCodec.packBatches(allBatches);
        
        // Call inbox with forced inclusion included
        return inbox.propose4(
            _packedSummary,
            finalPackedBatches,
            _packedEvidence,
            _packedTransitionMetas
        );
    }
}