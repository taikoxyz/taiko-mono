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
    /// @return meta_ The metadata of the proposed batch.
    function proposeBatch(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        returns (ITaikoInbox.BatchMetadata memory meta_);
}

/// @title IProposeBatchV2
/// @notice Similar to `IProposeBatch`, but optimized to avoid unnecessary decoding.
/// @custom:security-contact security@taiko.xyz
interface IProposeBatchV2 {
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

/// @title IProposeBatchV2WithForcedInclusion
/// @notice This interface is used to propose a batch of blocks with forced inclusion.
/// @custom:security-contact security@taiko.xyz
interface IProposeBatchV2WithForcedInclusion {
    /// @notice Proposes a batch of blocks.
    /// @param _delayedBatchParams The delayed batch params.
    /// @param _regularBatchParams The regular batch params.
    /// @param _txList The transaction list in calldata. If the txList is empty, blob will be used
    /// for data availability.
    /// @return meta_ The metadata of the proposed batch.
    function proposeBatch(
        ITaikoInbox.BatchParams calldata _delayedBatchParams,
        ITaikoInbox.BatchParams calldata _regularBatchParams,
        bytes calldata _txList) external returns (ITaikoInbox.BatchMetadata memory meta_);
}
