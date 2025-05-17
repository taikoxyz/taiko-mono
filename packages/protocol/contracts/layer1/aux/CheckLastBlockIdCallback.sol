// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/layer1/based/IBatchProposedCallback.sol";

/// @title CheckLastBlockIdCallback
/// @notice This callback demonstrates the process of verifying the last block ID in a proposal. If
/// there's a mismatch between the last block ID and the expected one, the callback will trigger a
/// revert, subsequently causing the inbox to also revert.
/// It's advisable for proposers to avoid transactions that may revert, hence this callback is more
/// effective when used with revert protection.
/// @custom:security-contact security@taiko.xyz
contract CheckLastBlockIdCallback is IBatchProposedCallback {
    error LastBlockIdMismatch();

    /// @inheritdoc IBatchProposedCallback
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
