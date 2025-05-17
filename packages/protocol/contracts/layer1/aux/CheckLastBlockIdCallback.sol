// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/layer1/based/IBatchProposedCallback.sol";

/// @title CheckLastBlockIdCallback
/// @custom:security-contact security@taiko.xyz
contract CheckLastBlockIdCallback is IBatchProposedCallback {
    error LastBlockIdMismatch();

    /// @inheritdoc IBatchProposedCallback
    /// @dev Allow proposers to specify the expected last block ID in a proposal.
    function onBatchProposed(
        ITaikoInbox.BatchInfo calldata _batchInfo,
        ITaikoInbox.BatchMetadata calldata,
        bytes calldata _data
    )
        external
        pure
    {
        uint64 expectedLastBlockId = abi.decode(_data, (uint64));
        require(_batchInfo.lastBlockId == expectedLastBlockId, LastBlockIdMismatch());
    }
}
