// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/based/LibSharedData.sol";

/// @title IFork
/// @custom:security-contact security@taiko.xyz
interface IFork {
    /// @notice Returns true if the fork is active, false otherwise
    function isForkActive() external view returns (bool);
}
