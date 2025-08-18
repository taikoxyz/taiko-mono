// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ITaikoInbox.sol";

/// @title IProposeBatch
/// @notice This interface defines the proposeBatch function that is also part of the ITaikoInbox
/// interface.
/// @custom:security-contact security@taiko.xyz
interface IProposeBatch {
    /// @notice Proposes a batch of blocks.
    /// @param _params BatchParams struct containing batch parameters.
    /// @param _txList The transaction list in calldata. If the txList is empty, blob will be used
    /// for data availability.
    /// @return meta_ The metadata of the proposed batch.
    function proposeBatch(
        ITaikoInbox.BatchParams calldata _params,
        bytes calldata _txList
    )
        external
        returns (ITaikoInbox.BatchMetadata memory meta_);
}
