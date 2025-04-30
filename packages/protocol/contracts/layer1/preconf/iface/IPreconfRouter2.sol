// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/IProposeBatch.sol";
import "src/layer1/based/ITaikoInbox.sol";

/// @title IPreconfRouter2
/// @custom:security-contact security@taiko.xyz
interface IPreconfRouter2 is IProposeBatch {
    error ForcedInclusionNotSupported();
    error NotPreconferOrFallback();
    error NotPreconfer();
    error ProposerIsNotPreconfer();
    error InvalidLookaheadProof();
    error InvalidLookaheadTimestamp();
    error OperatorIsSlashed();
    error OperatorIsUnregistered();
    error OperatorIsNotOptedIn();
    error InvalidCurrentLookahead();
    error InvalidPreviousLookahead();
}
