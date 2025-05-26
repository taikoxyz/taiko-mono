// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/IProposeBatch.sol";

/// @title IPreconfRouter
/// @custom:security-contact security@taiko.xyz
interface IPreconfRouter is IProposeBatch {
    error ForcedInclusionNotSupported();
    error NotPreconferOrFallback();
    error ProposerIsNotPreconfer();
}
