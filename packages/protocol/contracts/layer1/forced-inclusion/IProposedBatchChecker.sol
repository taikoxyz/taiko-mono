// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoInbox.sol";

/// @title IProposedBatchChecker
/// @custom:security-contact security@taiko.xyz
interface IProposedBatchChecker {
    /// @notice Check if a proposed batch is valid. This function must return false if the check
    /// fails.
    /// @param _taikoInbox The address of the TaikoInbox contract.
    /// @param batchInfo_ The batch info.
    /// @param batchMetadata_ The batch metadata.
    function checkProposedBatch(
        address _taikoInbox,
        ITaikoInbox.BatchInfo memory batchInfo_,
        ITaikoInbox.BatchMetadata memory batchMetadata_
    )
        external
        view
        returns (bool);
}
