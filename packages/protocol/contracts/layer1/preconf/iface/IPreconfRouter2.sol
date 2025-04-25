// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/IProposeBatch.sol";
import "src/layer1/based/ITaikoInbox.sol";

/// @title IPreconfRouter2
/// @custom:security-contact security@taiko.xyz
interface IPreconfRouter2 {
    error ForcedInclusionNotSupported();
    error NotFallbackPreconfer();
    error NotPreconfer();
    error ProposerIsNotPreconfer();
    error InvalidLookaheadProof();
    error InvalidLookaheadTimestamp();
    error OperatorIsSlashed();
    error OperatorIsUnregistered();
    error OperatorIsNotOptedIn();

    /// @notice Allows a preconfer to propose a batch of transactions
    /// @param _lookahead The lookahead leaf and merkle proof pointing to the lookahead entry of
    /// the preconfer
    /// @param _params The parameters for the batch
    /// @param _txList The list of transactions to propose
    /// @return info_ The info of the batch
    /// @return meta_ The metadata of the batch
    function proposeBatch(
        bytes calldata _lookahead,
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        returns (ITaikoInbox.BatchInfo memory info_, ITaikoInbox.BatchMetadata memory meta_);
}
