// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/IProposeBatch.sol";
import "src/layer1/based/ITaikoInbox.sol";

/// @title IPreconfRouter2
/// @custom:security-contact security@taiko.xyz
interface IPreconfRouter2 is IProposeBatch {
    error ForcedInclusionNotSupported();
    error InvalidCurrentLookahead();
    error InvalidLookaheadProof();
    error InvalidLookaheadTimestamp();
    error InvalidPreviousLookahead();
    error NotPreconfer();
    error NotPreconferOrFallback();
    error OperatorIsNotOptedIn();
    error OperatorIsSlashed();
    error OperatorIsUnregistered();
    error ProposerIsNotPreconfer();
}
