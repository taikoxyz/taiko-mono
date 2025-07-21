// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/layer1/based2/IInbox.sol";
import "../iface/IPreconfWhitelist.sol";
import "../../forced-inclusion/IForcedInclusionStore.sol";

/// @title PreconfManager
/// @notice Gateway for Shasta inbox with preconf access control and forced inclusion validation
/// @dev Optimized for gas efficiency - proposers build forced inclusions off-chain
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
    error ForcedInclusionMissing();
    error InvalidForcedInclusion();
    error InvalidBatchCount();

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

    /// @notice Proposes batches to inbox contract, including forced included batches. Only one forced inclusion can be processed at a time, and it must be due.
    /// @dev Only the current preconfer can propose.
    /// @dev Proposers must include forced inclusions when due.
    /// @param _packedSummary Current protocol summary encoded as bytes
    /// @param _packedBatches Array of batches to propose encoded as bytes. If forced inclusions are due, the first batch must be the forced inclusion.
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
        // 1. Verify preconf authorization
        address preconfer = whitelist.getOperatorForCurrentEpoch();
        if (preconfer != address(0)) {
            require(msg.sender == preconfer, NotPreconfer());
        } else if (fallbackPreconfer != address(0)) {
            require(msg.sender == fallbackPreconfer, NotPreconfer());
        } else {
            revert NotPreconfer();
        }

        // 2. Check if forced inclusion is due
        if (forcedStore.isOldestForcedInclusionDue()) {
            // Get expected forced inclusion
            IForcedInclusionStore.ForcedInclusion memory expectedInclusion =
                forcedStore.getOldestForcedInclusion();

            // Validate the first batch contains the forced inclusion
            _validateForcedInclusionInFirstBatch(_packedBatches, expectedInclusion);

            // Consume the forced inclusion
            IForcedInclusionStore.ForcedInclusion memory consumedInclusion =
                forcedStore.consumeOldestForcedInclusion(msg.sender);

            emit ForcedInclusionProcessed(consumedInclusion);
        }

        // 3. Forward to inbox - no modification needed
        //TODO: we probably don't need to retun a value since it is emitted as an event on the inbox contract already
        return
            inbox.propose4(_packedSummary, _packedBatches, _packedEvidence, _packedTransitionMetas);
    }

    /// @notice Validates that the first batch contains the expected forced inclusion
    /// @dev Efficiently extracts only necessary fields from packed data
    /// @param _packedBatches The packed batches data
    /// @param _expectedInclusion The expected forced inclusion
    function _validateForcedInclusionInFirstBatch(
        bytes calldata _packedBatches,
        IForcedInclusionStore.ForcedInclusion memory _expectedInclusion
    )
        internal
        pure
    {
        // Ensure we have at least one batch
        require(_packedBatches.length > 0, InvalidBatchCount());
        uint8 batchCount = uint8(_packedBatches[0]);
        require(batchCount > 0, ForcedInclusionMissing());

        // Use assembly to efficiently read specific fields from the first batch
        // We only need to check: isForcedInclusion flag, first blob hash, offset, and size
        assembly {
            let dataPtr := add(_packedBatches.offset, 1) // Skip batch count

            // Skip proposer (20 bytes) + coinbase (20 bytes) + timestamp (6 bytes) + gasIssuance (4
            // bytes)
            dataPtr := add(dataPtr, 50)

            // Read isForcedInclusion flag (1 byte)
            let isForcedInclusion := byte(0, calldataload(dataPtr))
            if iszero(isForcedInclusion) {
                // revert with InvalidForcedInclusion()
                let ptr := mload(0x40)
                mstore(ptr, 0x5d2e3a7400000000000000000000000000000000000000000000000000000000)
                revert(ptr, 4)
            }
            dataPtr := add(dataPtr, 1)

            // Skip proverAuth - read length (2 bytes) then skip data
            let proverAuthLen := and(calldataload(dataPtr), 0xffff)
            dataPtr := add(dataPtr, add(2, proverAuthLen))

            // Skip signal slots - read count (1 byte) then skip data
            let signalCount := byte(0, calldataload(dataPtr))
            dataPtr := add(dataPtr, add(1, mul(signalCount, 32)))

            // Skip anchor block IDs - read count (1 byte) then skip data
            let anchorCount := byte(0, calldataload(dataPtr))
            dataPtr := add(dataPtr, add(1, mul(anchorCount, 6)))

            // Skip blocks array - read count (1 byte) then skip data
            let blockCount := byte(0, calldataload(dataPtr))
            dataPtr := add(dataPtr, add(1, mul(blockCount, 13))) // 13 bytes per block

            // Now at blobs structure
            // Read blob hash count (1 byte)
            let blobHashCount := byte(0, calldataload(dataPtr))
            if iszero(blobHashCount) {
                // revert with InvalidForcedInclusion() - need at least one blob
                let ptr := mload(0x40)
                mstore(ptr, 0x5d2e3a7400000000000000000000000000000000000000000000000000000000)
                revert(ptr, 4)
            }
            dataPtr := add(dataPtr, 1)

            // Read first blob hash (32 bytes)
            let blobHash := calldataload(dataPtr)
            dataPtr := add(dataPtr, 32)

            // Validate blob hash matches expected
            if iszero(eq(blobHash, mload(_expectedInclusion))) {
                // revert with InvalidForcedInclusion()
                let ptr := mload(0x40)
                mstore(ptr, 0x5d2e3a7400000000000000000000000000000000000000000000000000000000)
                revert(ptr, 4)
            }

            // Skip remaining blob hashes
            dataPtr := add(dataPtr, mul(sub(blobHashCount, 1), 32))

            // Skip firstBlobIndex (1) and numBlobs (1)
            dataPtr := add(dataPtr, 2)

            // Read byteOffset (4 bytes)
            let byteOffset := and(shr(224, calldataload(dataPtr)), 0xffffffff)
            dataPtr := add(dataPtr, 4)

            // Read byteSize (4 bytes)
            let byteSize := and(shr(224, calldataload(dataPtr)), 0xffffffff)

            // Validate offset and size match expected
            let expectedOffset := mload(add(_expectedInclusion, 0x60)) // offset in struct
            let expectedSize := mload(add(_expectedInclusion, 0x80)) // size in struct

            if iszero(eq(byteOffset, expectedOffset)) {
                // revert with InvalidForcedInclusion()
                let ptr := mload(0x40)
                mstore(ptr, 0x5d2e3a7400000000000000000000000000000000000000000000000000000000)
                revert(ptr, 4)
            }

            if iszero(eq(byteSize, expectedSize)) {
                // revert with InvalidForcedInclusion()
                let ptr := mload(0x40)
                mstore(ptr, 0x5d2e3a7400000000000000000000000000000000000000000000000000000000)
                revert(ptr, 4)
            }
        }
    }
}
