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
    /// @param txList_ The transaction list.
    function checkBatch(
        ITaikoInbox.BatchInfo calldata batchInfo_,
        ITaikoInbox.BatchMetadata calldata batchMetadata_,
        bytes calldata txList_
    )
        external
        view
        returns (bool);
}
