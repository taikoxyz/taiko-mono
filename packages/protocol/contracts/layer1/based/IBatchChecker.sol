// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ITaikoInbox.sol";

/// @title IBatchChecker
/// @custom:security-contact security@taiko.xyz
interface IBatchChecker {
    /// @notice Check if a proposed batch is as expected. This function must return false or revert
    /// if the check fails.
    /// @param _batchInfo The batch info.
    /// @param _batchMetadata The batch metadata.
    /// @param _inputs The inputs to the checker.
    function checkBatch(
        ITaikoInbox.BatchInfo calldata _batchInfo,
        ITaikoInbox.BatchMetadata calldata _batchMetadata,
        bytes calldata _inputs
    )
        external
        view
        returns (bool);
}
