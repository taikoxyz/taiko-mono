// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ILookahead
/// @custom:security-contact security@taiko.xyz
interface ILookahead {
    function isCurrentPreconfer(address addr) external view returns (bool);
}
