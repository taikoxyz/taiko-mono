// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoProposerEntryPoint.sol";

/// @title IPreconfRouter
/// @custom:security-contact security@taiko.xyz
interface IPreconfRouter is ITaikoProposerEntryPoint {
    error ForcedInclusionNotSupported();
    error NotTheOperator();
    error ProposerIsNotTheSender();
}
