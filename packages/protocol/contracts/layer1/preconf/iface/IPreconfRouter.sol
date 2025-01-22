// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoInbox.sol";

/// @title IPreconfRouter
/// @custom:security-contact security@taiko.xyz
interface IPreconfRouter {
    error NotTheOperator();
    error ProposerIsNotTheSender();

    /// @notice Proposes a batch of blocks that have been preconfed.
    /// @dev This function only accepts batches from an operator selected to preconf in a particular
    ///      slot or epoch and routes that batch to the TaikoInbox.
    /// @param _params ABI-encoded parameters for the preconfing operation.
    /// @param _batchParams ABI-encoded parameters specific to the batch.
    /// @param _batchTxList The transaction list associated to the batch.
    /// @return info_ The info of the proposed batch.
    /// @return meta_ The metadata of the proposed batch.
    function proposePreconfedBlocks(
        bytes calldata _params,
        bytes calldata _batchParams,
        bytes calldata _batchTxList
    )
        external
        returns (ITaikoInbox.BatchInfo memory info_, ITaikoInbox.BatchMetadata memory meta_);
}
