// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ITaikoInbox.sol";

/// @title IBatchChecker
/// @custom:security-contact security@taiko.xyz
interface IBatchChecker {
    /// @notice Check if a proposed batch is as expected. This function must return false or revert
    /// if the check fails.
    /// @param batchInfo_ The batch info.
    /// @param batchMetadata_ The batch metadata.
    function checkBatch(
        ITaikoInbox.BatchInfo memory batchInfo_,
        ITaikoInbox.BatchMetadata memory batchMetadata_
    )
        external
        view
        returns (bool);
}
