// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoInbox.sol";

/// @title IPreconfRouter
/// @custom:security-contact security@taiko.xyz
interface IPreconfRouter {

    struct ForcedTx {
        bytes txList;
        uint256 timestamp;
        bool included;
        uint256 stakeAmount;
    }

    error ForcedTxListAlreadyIncluded();
    error ForcedTxListAlreadyStored();
    error ForcedTxListHashNotFound();
    error InsufficientStakeAmount();
    error NotTheOperator();
    error ProposerIsNotTheSender();


    event ForcedTxStored(bytes indexed txHash, uint256 timestamp);

    /// @notice Proposes a batch of blocks that have been preconfed.
    /// @dev This function only accepts batches from an operator selected to preconf in a particular
    ///      slot or epoch and routes that batch to the TaikoInbox.
    /// @param _params ABI-encoded parameters for the preconfing operation.
    /// @param _batchParams ABI-encoded parameters specific to the batch.
    /// @param _batchTxList The transaction list associated to the batch.
    /// @return meta_ BatchMetadata containing metadata about the proposed batch.
    function proposePreconfedBlocks(
        bytes calldata _params,
        bytes calldata _batchParams,
        bytes calldata _batchTxList,
        bool force
    )
        external
        returns (ITaikoInbox.BatchMetadata memory meta_);

    function updateBaseStakeAmount(uint256 _newBaseStakeAmount) external;

    function storeForcedTx(bytes calldata _txList) payable external;
}
