// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ITaikoInbox.sol";

/// @title IProposeBatch
/// @notice This interface defines the proposeBatch function that is also part of the ITaikoInbox
/// interface.
/// @custom:security-contact security@taiko.xyz
interface IProposeBatch {
    /// @notice Proposes a batch of blocks.
    /// @param _params ABI-encoded parameters.
    /// @param _txList The transaction list in calldata. If the txList is empty, blob will be used
    /// for data availability.
    /// @return info_ The info of the proposed batch.
    /// @return meta_ The mmetadata of the proposed batch.
    function proposeBatch(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        returns (ITaikoInbox.BatchInfo memory info_, ITaikoInbox.BatchMetadata memory meta_);
}
