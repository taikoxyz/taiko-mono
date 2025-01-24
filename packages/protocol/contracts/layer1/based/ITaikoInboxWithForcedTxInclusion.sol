// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ITaikoInbox.sol";
import "./IForcedInclusionStore.sol";

/// @title ITaikoInboxWithForcedTxInclusion
/// @custom:security-contact security@taiko.xyz
interface ITaikoInboxWithForcedTxInclusion {
    event ForcedInclusionProcessed(IForcedInclusionStore.ForcedInclusion);

    /// @notice Proposes a batch of blocks with forced inclusion.
    /// @param _forcedInclusionParams An optional ABI-encoded BlockParams for the forced inclusion batch.
    /// @param _params ABI-encoded BlockParams.
    /// @param _txList The transaction list in calldata. If the txList is empty, blob will be used
    /// for data availability.
    function proposeBatchWithForcedInclusion(
        bytes calldata _forcedInclusionParams,
        bytes calldata _params,
        bytes calldata _txList
    ) external;
}