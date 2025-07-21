// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/layer1/based2/IInbox.sol";
import "../iface/IPreconfWhitelist.sol";
import "../../forced-inclusion/IForcedInclusionStore.sol";

/// @title PreconfManager
/// @notice Manages batch proposals with preconfirmation access control and forced inclusion
/// validation
/// @dev Acts as a gateway to the Shasta inbox, ensuring only authorized preconfers can propose
/// batches
/// @custom:security-contact security@taiko.xyz
contract PreconfManager is EssentialContract {
    IInbox public immutable inbox;
    IPreconfWhitelist public immutable whitelist;
    IForcedInclusionStore public immutable forcedStore;
    address public immutable fallbackPreconfer;

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

    /// @notice Proposes batches to the inbox with preconf authorization and forced inclusion
    /// validation
    /// @dev This function serves as the gateway for all batch proposals, enforcing two key
    /// requirements:
    ///      1. Only authorized preconfers (from whitelist or fallback) can propose batches
    ///      2. Forced inclusions must be processed when due, and cannot be processed before their
    /// deadline
    ///
    ///      When a forced inclusion is due (determined by ForcedInclusionStore based on batch count
    /// delay),
    ///      the proposer MUST include it as the first batch in _packedBatches.
    ///
    /// @param _packedSummary Current protocol summary encoded using LibCodec.packSummary
    /// @param _packedBatches Array of batches encoded using LibCodec.packBatches. If a forced
    /// inclusion
    ///                       is due, it MUST be the first batch with isForcedInclusion = true
    /// @param _packedEvidence Evidence for batch proposal validation, including parent batch
    /// metadata
    /// @param _packedTransitionMetas Transition metadata array for state verification
    /// @return summary Updated protocol summary after successful proposal
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
        // Verify caller is authorized preconfer
        address preconfer = whitelist.getOperatorForCurrentEpoch();
        if (preconfer != address(0)) {
            require(msg.sender == preconfer, NotPreconfer());
        } else if (fallbackPreconfer != address(0)) {
            require(msg.sender == fallbackPreconfer, NotPreconfer());
        } else {
            revert NotPreconfer();
        }

        // Process forced inclusion if due
        if (forcedStore.isOldestForcedInclusionDue()) {
            IForcedInclusionStore.ForcedInclusion memory expectedInclusion =
                forcedStore.getOldestForcedInclusion();

            _validateForcedInclusionInFirstBatch(_packedBatches, expectedInclusion);

            IForcedInclusionStore.ForcedInclusion memory consumedInclusion =
                forcedStore.consumeOldestForcedInclusion(msg.sender);

            emit ForcedInclusionProcessed(consumedInclusion);
        }

        return
            inbox.propose4(_packedSummary, _packedBatches, _packedEvidence, _packedTransitionMetas);
    }

    /// @dev Validates the first batch contains the expected forced inclusion by checking:
    ///      1. isForcedInclusion flag is true
    ///      2. First blob hash matches expected
    ///      3. Blob offset and size match expected values
    function _validateForcedInclusionInFirstBatch(
        bytes calldata _packedBatches,
        IForcedInclusionStore.ForcedInclusion memory _expectedInclusion
    )
        internal
        pure
    {
        require(_packedBatches.length > 0, InvalidBatchCount());
        uint8 batchCount = uint8(_packedBatches[0]);
        require(batchCount > 0, ForcedInclusionMissing());

        bool isValid;

        // Extract and validate forced inclusion fields using assembly for gas efficiency
        assembly {
            isValid := true
            let dataPtr := add(_packedBatches.offset, 1) // Skip batch count

            // Skip fixed fields: proposer(20) + coinbase(20) + timestamp(6) + gasIssuance(4) = 50
            dataPtr := add(dataPtr, 50)

            // Verify isForcedInclusion flag
            let isForcedInclusion := byte(0, calldataload(dataPtr))
            if iszero(isForcedInclusion) { isValid := false }

            if isValid {
                dataPtr := add(dataPtr, 1)

                // Skip proverAuth string
                let proverAuthLen := and(calldataload(dataPtr), 0xffff)
                dataPtr := add(dataPtr, add(2, proverAuthLen))

                // Skip signal slots array
                let signalCount := byte(0, calldataload(dataPtr))
                dataPtr := add(dataPtr, add(1, mul(signalCount, 32)))

                // Skip anchor block IDs array
                let anchorCount := byte(0, calldataload(dataPtr))
                dataPtr := add(dataPtr, add(1, mul(anchorCount, 6)))

                // Skip blocks array (13 bytes per block)
                let blockCount := byte(0, calldataload(dataPtr))
                dataPtr := add(dataPtr, add(1, mul(blockCount, 13)))

                // Validate blobs structure
                let blobHashCount := byte(0, calldataload(dataPtr))
                if iszero(blobHashCount) { isValid := false }

                if isValid {
                    dataPtr := add(dataPtr, 1)

                    // Validate first blob hash
                    let blobHash := calldataload(dataPtr)
                    if iszero(eq(blobHash, mload(_expectedInclusion))) { isValid := false }

                    if isValid {
                        dataPtr := add(dataPtr, 32)

                        // Skip remaining blob hashes
                        dataPtr := add(dataPtr, mul(sub(blobHashCount, 1), 32))

                        // Skip firstBlobIndex and numBlobs
                        dataPtr := add(dataPtr, 2)

                        // Validate byteOffset (4 bytes, big-endian)
                        let byteOffset := and(shr(224, calldataload(dataPtr)), 0xffffffff)
                        let expectedOffset := mload(add(_expectedInclusion, 0x60))
                        if iszero(eq(byteOffset, expectedOffset)) { isValid := false }

                        if isValid {
                            dataPtr := add(dataPtr, 4)

                            // Validate byteSize (4 bytes, big-endian)
                            let byteSize := and(shr(224, calldataload(dataPtr)), 0xffffffff)
                            let expectedSize := mload(add(_expectedInclusion, 0x80))
                            if iszero(eq(byteSize, expectedSize)) { isValid := false }
                        }
                    }
                }
            }
        }

        require(isValid, InvalidForcedInclusion());
    }
}
