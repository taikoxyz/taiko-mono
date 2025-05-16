// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoInbox.sol";

/// @title IProposedBatchChecker
/// @custom:security-contact security@taiko.xyz
interface IProposedBatchChecker {
    /// @notice Check if a proposed batch is valid. This function must revert if the check fails
    /// @param batchInfo_ The batch info.
    /// @param batchMetadata_ The batch metadata.
    function checkProposedBatch(
        ITaikoInbox.BatchInfo memory batchInfo_,
        ITaikoInbox.BatchMetadata memory batchMetadata_
    )
        external;
}
