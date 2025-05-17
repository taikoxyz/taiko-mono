// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ITaikoInbox.sol";

/// @title IBatchProposedCallback
/// @custom:security-contact security@taiko.xyz
interface IBatchProposedCallback {
    /// @notice Called after a batch is proposed.
    /// @param _batchInfo The batch info.
    /// @param _batchMetadata The batch metadata.
    /// @param _data The extra data to the callback.
    function onBatchProposed(
        ITaikoInbox.BatchInfo calldata _batchInfo,
        ITaikoInbox.BatchMetadata calldata _batchMetadata,
        bytes calldata _data
    )
        external;
}
