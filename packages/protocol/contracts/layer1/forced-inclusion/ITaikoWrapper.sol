// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/based/ITaiko.sol";
import "./ForcedInclusionStore.sol";

/// @title ITaikoWrapper
/// @custom:security-contact security@taiko.xyz
interface ITaikoWrapper {
    /// @dev Event emitted when a forced inclusion is processed.
    event ForcedInclusionProcessed(IForcedInclusionStore.ForcedInclusion);

    /// @dev Error thrown when the forced inclusion params are invalid.
    error InvalidForcedInclusionParams();
    /// @dev Error thrown when the oldest forced inclusion is due.
    error OldestForcedInclusionDue();

    /// @notice Proposes a batch of blocks with forced inclusion.
    /// @param _forcedInclusionParams An optional ABI-encoded BlockParams for the forced inclusion
    /// batch.
    /// @param _params ABI-encoded BlockParams.
    /// @param _txList The transaction list in calldata. If the txList is empty, blob will be used
    /// for data availability.
    /// @return info_ The info of the proposed batch.
    /// @return meta_ The metadata of the proposed batch.
    function proposeBatch(
        bytes calldata _forcedInclusionParams,
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        returns (ITaikoInbox.BatchInfo memory info_, ITaikoInbox.BatchMetadata memory meta_);
}
